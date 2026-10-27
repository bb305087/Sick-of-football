from __future__ import annotations

import base64
import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Annotated
from uuid import UUID, uuid4

import jwt
from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from .core.config import Settings, get_settings
from .core.crypto import FieldCipher, reason_aad
from .db.session import get_db
from .models import Availability, Event, RefreshToken, Tactic, User, Invitation, DeviceToken, MedicalReport
from .models.device_token import Platform
from .models.event import AvailabilityStatus, EventType
from .schemas import (AttendanceIn, EventCreateIn, LoginIn, RefreshIn, TokenOut, UserOut,
                      TacticIn, RegisterIn, PasswordChangeIn, InvitationCreateIn,
                      InvitationOut, DeviceTokenIn, MedicalReportIn)
from .security import (
    DUMMY_HASH,
    hash_password,
    new_opaque_token,
    sha256_hex,
    validate_password_strength,
    verify_password,
)
from .api.deps import get_current_user, require_coach, require_club_member
from .services.scoping import get_event_or_404, get_tactic_or_404
from .services.audit import audit

logger = logging.getLogger("sick_of_football")
limiter = Limiter(key_func=get_remote_address)

def create_access_token(user_id: UUID, settings: Settings) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {"sub": str(user_id), "iat": now, "nbf": now,
         "exp": now + timedelta(minutes=settings.access_token_ttl_min),
         "iss": settings.jwt_issuer, "aud": settings.jwt_audience,
         "jti": uuid4().hex, "typ": "access"},
        settings.jwt_secret.get_secret_value(), algorithm="HS256",
    )

def public_user(user: User) -> UserOut:
    return UserOut.model_validate(user)

def cipher_from_settings(settings: Settings) -> FieldCipher:
    keys = json.loads(settings.data_encryption_keys.get_secret_value())
    return FieldCipher({int(k): base64.b64decode(v) for k, v in keys.items()},
                       settings.active_encryption_key_id)

app = FastAPI(title="Sick of Football API", version="2.0.0")
app.state.limiter = limiter

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return Response("rate limit exceeded", status_code=429)
app.add_middleware(CORSMiddleware, allow_origins=["http://localhost"],
                   allow_credentials=False, allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
                   allow_headers=["Authorization", "Content-Type"])

@app.middleware("http")
async def security_middleware(request: Request, call_next):
    request_id = request.headers.get("x-request-id") or str(uuid4())
    if request.headers.get("content-length") and int(request.headers["content-length"]) > 1_048_576:
        return Response("request too large", status_code=413, headers={"X-Request-ID": request_id})
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    return response

@app.get("/api/health")
async def health(db: Annotated[AsyncSession, Depends(get_db)]) -> dict[str, str]:
    await db.execute(select(1))
    return {"status": "ok"}

@app.post("/api/auth/login", response_model=TokenOut)
@limiter.limit("10/minute")
async def login(
    credentials: LoginIn, request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenOut:
    email = credentials.email.casefold()
    user = await db.scalar(select(User).where(User.email == email))
    valid = await verify_password(user.password_hash if user else DUMMY_HASH, credentials.password)
    now = datetime.now(timezone.utc)
    if user is not None and user.locked_until and user.locked_until > now:
        raise HTTPException(429, "account_locked")
    if user is None or not valid or not user.is_active:
        if user is not None:
            user.failed_login_attempts += 1
            if user.failed_login_attempts >= 5:
                user.locked_until = now + timedelta(minutes=15)
            await db.commit()
        await audit(db, "login_failed", actor_id=user.id if user else None,
                    ip=request.client.host if request.client else None)
        await db.commit()
        raise HTTPException(401, "invalid_credentials")
    raw, digest = new_opaque_token()
    user.failed_login_attempts = 0
    user.locked_until = None
    await audit(db, "login_success", actor_id=user.id,
                ip=request.client.host if request.client else None,
                user_agent=request.headers.get("user-agent"))
    db.add(RefreshToken(user_id=user.id, family_id=uuid4(), token_hash=digest,
                        expires_at=now + timedelta(days=settings.refresh_token_ttl_days),
                        user_agent=request.headers.get("user-agent", "")[:200]))
    user.last_login_at = now
    await db.commit()
    return TokenOut(access_token=create_access_token(user.id, settings), refresh_token=raw,
                    expires_in=settings.access_token_ttl_min * 60, user=public_user(user))

@app.post("/api/auth/register", response_model=TokenOut, status_code=201)
async def register(request: RegisterIn, db: Annotated[AsyncSession, Depends(get_db)],
                   settings: Annotated[Settings, Depends(get_settings)]) -> TokenOut:
    email = request.email.casefold()
    try:
        validate_password_strength(request.password, email, request.full_name)
    except ValueError as exc:
        raise HTTPException(422, "invalid_password") from exc
    if await db.scalar(select(User).where(User.email == email)):
        raise HTTPException(409, "email_in_use")
    club_id = None
    invitation = None
    if request.invitation_token:
        invitation = await db.scalar(select(Invitation).where(
            Invitation.token_hash == sha256_hex(request.invitation_token)).with_for_update())
        now = datetime.now(timezone.utc)
        if invitation is None or invitation.revoked_at or invitation.expires_at <= now or invitation.used_count >= invitation.max_uses:
            raise HTTPException(400, "invalid_invitation")
        club_id = invitation.club_id
    user = User(email=email, password_hash=await hash_password(request.password), full_name=request.full_name,
                role="player", club_id=club_id)
    db.add(user)
    if invitation:
        invitation.used_count += 1
    await db.flush()
    raw, digest = new_opaque_token()
    db.add(RefreshToken(user_id=user.id, family_id=uuid4(), token_hash=digest,
                        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_ttl_days)))
    await db.commit()
    return TokenOut(access_token=create_access_token(user.id, settings), refresh_token=raw,
                    expires_in=settings.access_token_ttl_min * 60, user=public_user(user))

@app.get("/api/auth/me", response_model=UserOut)
async def me(user: Annotated[User, Depends(get_current_user)]) -> UserOut:
    return public_user(user)

@app.post("/api/auth/refresh", response_model=TokenOut)
async def refresh(
    request: RefreshIn, db: Annotated[AsyncSession, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenOut:
    now = datetime.now(timezone.utc)
    token = await db.scalar(select(RefreshToken).where(
        RefreshToken.token_hash == sha256_hex(request.refresh_token)).with_for_update())
    if token is None:
        raise HTTPException(401, "invalid_token")
    if token.revoked_at is not None:
        await db.execute(RefreshToken.__table__.update().where(
            RefreshToken.family_id == token.family_id, RefreshToken.revoked_at.is_(None)
        ).values(revoked_at=now))
        await db.commit()
        raise HTTPException(401, "invalid_token")
    user = await db.get(User, token.user_id)
    if token.expires_at <= now or user is None or not user.is_active or token.created_at < user.tokens_valid_after:
        raise HTTPException(401, "invalid_token")
    token.revoked_at = now
    raw, digest = new_opaque_token()
    replacement = RefreshToken(user_id=user.id, family_id=token.family_id, token_hash=digest,
                               expires_at=now + timedelta(days=settings.refresh_token_ttl_days))
    db.add(replacement)
    await db.flush()
    token.replaced_by_id = replacement.id
    await db.commit()
    return TokenOut(access_token=create_access_token(user.id, settings), refresh_token=raw,
                    expires_in=settings.access_token_ttl_min * 60)

@app.post("/api/auth/logout", status_code=204)
async def logout(request: RefreshIn, db: Annotated[AsyncSession, Depends(get_db)]) -> Response:
    token = await db.scalar(select(RefreshToken).where(
        RefreshToken.token_hash == sha256_hex(request.refresh_token)))
    if token:
        await db.execute(RefreshToken.__table__.update().where(
            RefreshToken.family_id == token.family_id, RefreshToken.revoked_at.is_(None)
        ).values(revoked_at=datetime.now(timezone.utc)))
        await db.commit()
    return Response(status_code=204)

@app.post("/api/auth/password", status_code=204)
async def change_password(request: PasswordChangeIn, user: Annotated[User, Depends(get_current_user)],
                          db: Annotated[AsyncSession, Depends(get_db)]) -> Response:
    if not await verify_password(user.password_hash, request.current_password):
        raise HTTPException(400, "invalid_password")
    try:
        validate_password_strength(request.new_password, user.email, user.full_name)
    except ValueError as exc:
        raise HTTPException(422, "invalid_password") from exc
    user.password_hash = await hash_password(request.new_password)
    user.tokens_valid_after = datetime.now(timezone.utc)
    await db.execute(RefreshToken.__table__.update().where(
        RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None)
    ).values(revoked_at=datetime.now(timezone.utc)))
    await db.commit()
    return Response(status_code=204)

@app.get("/api/events")
async def list_events(user: Annotated[User, Depends(require_club_member)],
                      db: Annotated[AsyncSession, Depends(get_db)]) -> list[dict]:
    rows = (await db.scalars(select(Event).where(Event.club_id == user.club_id).order_by(Event.starts_at))).all()
    return [{"id": str(e.id), "type": e.type.value, "title": e.title,
             "starts_at": e.starts_at, "ends_at": e.ends_at, "location": e.location} for e in rows]

@app.post("/api/events", status_code=201)
async def create_event(request: EventCreateIn, user: Annotated[User, Depends(require_coach)],
                       db: Annotated[AsyncSession, Depends(get_db)]) -> dict:
    event = Event(**request.model_dump(), club_id=user.club_id, created_by=user.id)
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return {"id": str(event.id), **request.model_dump(mode="json")}

@app.post("/api/events/{event_id}/attendance")
async def set_attendance(event_id: UUID, request: AttendanceIn,
                         user: Annotated[User, Depends(require_club_member)],
                         db: Annotated[AsyncSession, Depends(get_db)],
                         settings: Annotated[Settings, Depends(get_settings)]) -> dict:
    await get_event_or_404(db, event_id, user.club_id)
    row = await db.scalar(select(Availability).where(
        Availability.event_id == event_id, Availability.user_id == user.id))
    if row is None:
        row = Availability(event_id=event_id, user_id=user.id)
        db.add(row)
    row.status = request.status
    row.reason_ciphertext = row.reason_key_id = None
    if request.reason is not None and request.status != AvailabilityStatus.PRESENT:
        row.reason_key_id, row.reason_ciphertext = cipher_from_settings(settings).encrypt(
            request.reason, reason_aad(event_id, user.id))
    await db.commit()
    return {"event_id": str(event_id), "user_id": str(user.id), "status": row.status.value, "reason": None}

@app.get("/api/tactics")
async def list_tactics(user: Annotated[User, Depends(require_club_member)],
                       db: Annotated[AsyncSession, Depends(get_db)]) -> list[dict]:
    query = select(Tactic).where(Tactic.club_id == user.club_id)
    if user.role.value != "coach":
        query = query.where(Tactic.is_published.is_(True))
    rows = (await db.scalars(query)).all()
    return [{"id": str(t.id), "title": t.title, "content": t.description or "",
             "published": t.is_published, "updated_at": t.created_at} for t in rows]

@app.post("/api/tactics", status_code=201)
async def create_tactic(request: TacticIn, user: Annotated[User, Depends(require_coach)],
                        db: Annotated[AsyncSession, Depends(get_db)]) -> dict:
    tactic = Tactic(club_id=user.club_id, created_by=user.id, title=request.title,
                    description=request.content, is_published=request.published)
    db.add(tactic)
    await db.commit()
    await db.refresh(tactic)
    return {"id": str(tactic.id), **request.model_dump(), "updated_at": tactic.created_at}

@app.put("/api/tactics/{tactic_id}")
async def update_tactic(tactic_id: UUID, request: TacticIn,
                        user: Annotated[User, Depends(require_coach)],
                        db: Annotated[AsyncSession, Depends(get_db)]) -> dict:
    tactic = await get_tactic_or_404(db, tactic_id, user.club_id)
    tactic.title, tactic.description, tactic.is_published = request.title, request.content, request.published
    tactic.version += 1
    await db.commit()
    return {"id": str(tactic.id), **request.model_dump(), "updated_at": tactic.created_at}

@app.get("/api/team/members")
async def team_members(user: Annotated[User, Depends(require_club_member)],
                       db: Annotated[AsyncSession, Depends(get_db)]) -> list[dict]:
    rows = (await db.scalars(select(User).where(User.club_id == user.club_id).order_by(User.full_name))).all()
    return [{"id": str(member.id), "name": member.full_name, "email": member.email}
            for member in rows]

@app.delete("/api/team/members/{member_id}", status_code=204)
async def remove_member(member_id: UUID, user: Annotated[User, Depends(require_coach)],
                        db: Annotated[AsyncSession, Depends(get_db)]) -> Response:
    if member_id == user.id:
        raise HTTPException(400, "cannot_remove_self")
    member = await db.scalar(select(User).where(User.id == member_id, User.club_id == user.club_id))
    if member is None:
        raise HTTPException(404, "member_not_found")
    member.club_id = None
    member.is_active = False
    await db.commit()
    return Response(status_code=204)

@app.get("/api/invitations")
async def list_invitations(user: Annotated[User, Depends(require_coach)],
                           db: Annotated[AsyncSession, Depends(get_db)]) -> list[dict]:
    rows = (await db.scalars(select(Invitation).where(Invitation.club_id == user.club_id)
                             .order_by(Invitation.created_at.desc()))).all()
    return [{"id": str(row.id), "expires_at": row.expires_at, "max_uses": row.max_uses,
             "used_count": row.used_count, "revoked": row.revoked_at is not None} for row in rows]

@app.delete("/api/invitations/{invitation_id}", status_code=204)
async def revoke_invitation(invitation_id: UUID, user: Annotated[User, Depends(require_coach)],
                            db: Annotated[AsyncSession, Depends(get_db)]) -> Response:
    row = await db.scalar(select(Invitation).where(Invitation.id == invitation_id,
                                                    Invitation.club_id == user.club_id))
    if row is None:
        raise HTTPException(404, "invitation_not_found")
    row.revoked_at = datetime.now(timezone.utc)
    await db.commit()
    return Response(status_code=204)

@app.get("/api/medical-reports")
async def medical_reports(user: Annotated[User, Depends(require_coach)],
                          db: Annotated[AsyncSession, Depends(get_db)]) -> list[dict]:
    rows = (await db.scalars(select(MedicalReport).where(MedicalReport.club_id == user.club_id))).all()
    return [{"id": str(r.id), "player_id": str(r.player_id), "diagnosis": r.diagnosis,
             "details": r.details, "occurred_on": r.occurred_on, "cleared_on": r.cleared_on} for r in rows]

@app.post("/api/medical-reports", status_code=201)
async def create_medical_report(request: MedicalReportIn, user: Annotated[User, Depends(require_coach)],
                                db: Annotated[AsyncSession, Depends(get_db)]) -> dict:
    player = await db.scalar(select(User).where(User.id == request.player_id, User.club_id == user.club_id))
    if player is None:
        raise HTTPException(404, "player_not_found")
    report = MedicalReport(club_id=user.club_id, player_id=player.id, created_by=user.id,
                           diagnosis=request.diagnosis, details=request.details,
                           occurred_on=request.occurred_on.date() if request.occurred_on else None,
                           cleared_on=request.cleared_on.date() if request.cleared_on else None)
    db.add(report); await db.commit(); await db.refresh(report)
    return {"id": str(report.id), "player_id": str(report.player_id), "diagnosis": report.diagnosis}

@app.post("/api/invitations", response_model=InvitationOut, status_code=201)
async def create_invitation(request: InvitationCreateIn, user: Annotated[User, Depends(require_coach)],
                            db: Annotated[AsyncSession, Depends(get_db)]) -> InvitationOut:
    raw, digest = new_opaque_token()
    expires = datetime.now(timezone.utc) + timedelta(days=request.expires_in_days)
    db.add(Invitation(club_id=user.club_id, created_by=user.id, token_hash=digest,
                      expires_at=expires, max_uses=request.max_uses))
    await db.commit()
    return InvitationOut(token=raw, expires_at=expires, max_uses=request.max_uses)

@app.post("/api/devices", status_code=204)
async def register_device(request: DeviceTokenIn, user: Annotated[User, Depends(get_current_user)],
                          db: Annotated[AsyncSession, Depends(get_db)]) -> Response:
    try:
        platform = Platform(request.platform.casefold())
    except ValueError:
        raise HTTPException(422, "invalid_platform")
    row = await db.scalar(select(DeviceToken).where(DeviceToken.fcm_token == request.fcm_token))
    now = datetime.now(timezone.utc)
    if row is None:
        db.add(DeviceToken(user_id=user.id, fcm_token=request.fcm_token, platform=platform, last_seen_at=now))
    else:
        row.user_id, row.platform, row.last_seen_at = user.id, platform, now
    await db.commit()
    return Response(status_code=204)

@app.delete("/api/devices/{token}", status_code=204)
async def delete_device(token: str, user: Annotated[User, Depends(get_current_user)],
                        db: Annotated[AsyncSession, Depends(get_db)]) -> Response:
    await db.execute(DeviceToken.__table__.delete().where(DeviceToken.fcm_token == token,
                                                           DeviceToken.user_id == user.id))
    await db.commit()
    return Response(status_code=204)


from .api.v1 import router as v1_router

app.include_router(v1_router)
