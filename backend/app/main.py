from __future__ import annotations

import base64
import json
from datetime import datetime, timedelta, timezone
from typing import Annotated
from uuid import UUID, uuid4

import jwt
from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .core.config import Settings, get_settings
from .core.crypto import FieldCipher, reason_aad
from .db.session import get_db
from .models import Availability, Event, RefreshToken, Tactic, User
from .models.event import AvailabilityStatus, EventType
from .schemas import AttendanceIn, EventCreateIn, LoginIn, RefreshIn, TokenOut, UserOut, TacticIn
from .security import DUMMY_HASH, hash_password, new_opaque_token, sha256_hex, verify_password
from .api.deps import get_current_user, require_coach, require_club_member
from .services.scoping import get_event_or_404, get_tactic_or_404

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
app.add_middleware(CORSMiddleware, allow_origins=["http://localhost"],
                   allow_credentials=False, allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
                   allow_headers=["Authorization", "Content-Type"])

@app.get("/api/health")
async def health(db: Annotated[AsyncSession, Depends(get_db)]) -> dict[str, str]:
    await db.execute(select(1))
    return {"status": "ok"}

@app.post("/api/auth/login", response_model=TokenOut)
async def login(
    request: LoginIn, http_request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenOut:
    email = request.email.casefold()
    user = await db.scalar(select(User).where(User.email == email))
    valid = await verify_password(user.password_hash if user else DUMMY_HASH, request.password)
    if user is None or not valid or not user.is_active:
        raise HTTPException(401, "invalid_credentials")
    raw, digest = new_opaque_token()
    now = datetime.now(timezone.utc)
    db.add(RefreshToken(user_id=user.id, family_id=uuid4(), token_hash=digest,
                        expires_at=now + timedelta(days=settings.refresh_token_ttl_days),
                        user_agent=http_request.headers.get("user-agent", "")[:200]))
    user.last_login_at = now
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

@app.get("/api/medical-reports")
async def medical_reports(user: Annotated[User, Depends(require_coach)]) -> list[dict]:
    return []
