from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Annotated
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.db.session import get_db
from app.main import cipher_from_settings, create_access_token
from app.models import Availability, Club, DeviceToken, Event, Invitation, Tactic, User
from app.models.device_token import Platform
from app.models.event import AvailabilityStatus, EventType
from app.models.user import Role
from app.models.refresh_token import RefreshToken
from app.api.deps import get_current_user, require_club_member, require_coach
from app.schemas.v1 import (
    AvailabilityIn, ChangePassword, ClubUpdate, DeviceIn, EventCreate, EventUpdate,
    InvitationCreate, InvitationPreview, Login, Refresh, RegisterCoach, RegisterPlayer,
    TacticIn, TacticUpdate, TokenPair, UpdateMe, UserMe,
)
from app.security import hash_password, new_opaque_token, sha256_hex, validate_password_strength, verify_password
from app.services.audit import audit
from app.services.scoping import get_event_or_404, get_tactic_or_404
from app.core.crypto import reason_aad

router = APIRouter(prefix="/api/v1")


def user_out(user: User) -> UserMe:
    return UserMe.model_validate(user)


def token_pair(user: User, settings: Settings, raw: str) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(user.id, settings),
        refresh_token=raw,
        expires_in=settings.access_token_ttl_min * 60,
    )


def event_out(event: Event) -> dict:
    return {
        "id": event.id, "type": event.type, "title": event.title,
        "starts_at": event.starts_at, "ends_at": event.ends_at,
        "location": event.location, "opponent": event.opponent, "notes": event.notes,
    }


def tactic_out(tactic: Tactic) -> dict:
    return {
        "id": tactic.id, "title": tactic.title, "event_id": tactic.event_id,
        "formation": tactic.formation, "description": tactic.description,
        "lineup": tactic.lineup or [], "set_pieces": tactic.set_pieces or [],
        "is_published": tactic.is_published, "version": tactic.version,
        "updated_at": tactic.created_at,
    }


@router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/auth/register-coach", response_model=UserMe, status_code=201)
async def register_coach(
    payload: RegisterCoach, db: Annotated[AsyncSession, Depends(get_db)],
) -> UserMe:
    email = payload.email.casefold()
    try:
        validate_password_strength(payload.password, email, payload.full_name)
    except ValueError as exc:
        raise HTTPException(422, "invalid_password") from exc
    if await db.scalar(select(User).where(User.email == email)):
        raise HTTPException(409, "email_taken")
    club = Club(name=payload.club_name)
    db.add(club)
    user = User(email=email, password_hash=await hash_password(payload.password),
                full_name=payload.full_name, role=Role.COACH, club=club)
    db.add(user)
    await db.flush()
    await audit(db, "auth.register", actor_id=user.id, club_id=club.id)
    await db.commit()
    await db.refresh(user)
    return user_out(user)


@router.post("/auth/register-player", response_model=UserMe, status_code=201)
async def register_player(
    payload: RegisterPlayer, db: Annotated[AsyncSession, Depends(get_db)],
) -> UserMe:
    email = payload.email.casefold()
    try:
        validate_password_strength(payload.password, email, payload.full_name)
    except ValueError as exc:
        raise HTTPException(422, "invalid_password") from exc
    invitation = await db.scalar(select(Invitation).where(
        Invitation.token_hash == sha256_hex(payload.invite_token),
    ).with_for_update())
    now = datetime.now(timezone.utc)
    if (invitation is None or invitation.revoked_at is not None
            or invitation.expires_at <= now or invitation.used_count >= invitation.max_uses):
        raise HTTPException(400, "invalid_invitation")
    if await db.scalar(select(User).where(User.email == email)):
        raise HTTPException(409, "email_taken")
    invitation.used_count += 1
    user = User(email=email, password_hash=await hash_password(payload.password),
                full_name=payload.full_name, role=Role.PLAYER, club_id=invitation.club_id)
    db.add(user)
    await db.flush()
    await audit(db, "invitation.use", actor_id=user.id, club_id=user.club_id,
                resource_id=invitation.id)
    await db.commit()
    await db.refresh(user)
    return user_out(user)


@router.post("/auth/login", response_model=TokenPair)
async def login(
    payload: Login, request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenPair:
    email = payload.email.casefold()
    user = await db.scalar(select(User).where(User.email == email))
    if user is None:
        await verify_password("not-a-valid-argon2-hash", payload.password)
        raise HTTPException(401, "invalid_credentials")
    now = datetime.now(timezone.utc)
    if user.locked_until and user.locked_until > now:
        raise HTTPException(401, "invalid_credentials")
    valid = await verify_password(user.password_hash, payload.password)
    if not valid or not user.is_active:
        user.failed_login_attempts += 1
        if user.failed_login_attempts >= 5:
            user.locked_until = now + timedelta(minutes=15)
            user.failed_login_attempts = 0
        await audit(db, "auth.login.failure", actor_id=user.id, club_id=user.club_id,
                    ip=request.client.host if request.client else None)
        await db.commit()
        raise HTTPException(401, "invalid_credentials")
    user.failed_login_attempts = 0
    user.locked_until = None
    user.last_login_at = now
    raw, digest = new_opaque_token()
    db.add(RefreshToken(user_id=user.id, family_id=uuid4(), token_hash=digest,
                        expires_at=now + timedelta(days=settings.refresh_token_ttl_days)))
    await audit(db, "auth.login.success", actor_id=user.id, club_id=user.club_id)
    await db.commit()
    return token_pair(user, settings, raw)


@router.post("/auth/refresh", response_model=TokenPair)
async def refresh(
    payload: Refresh, db: Annotated[AsyncSession, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenPair:
    now = datetime.now(timezone.utc)
    token = await db.scalar(select(RefreshToken).where(
        RefreshToken.token_hash == sha256_hex(payload.refresh_token),
    ).with_for_update())
    if token is None:
        raise HTTPException(401, "invalid_token")
    if token.revoked_at is not None:
        await db.execute(RefreshToken.__table__.update().where(
            RefreshToken.family_id == token.family_id,
            RefreshToken.revoked_at.is_(None),
        ).values(revoked_at=now))
        await db.commit()
        raise HTTPException(401, "invalid_token")
    user = await db.scalar(select(User).where(User.id == token.user_id))
    if (token.expires_at <= now or user is None or not user.is_active
            or token.created_at < user.tokens_valid_after):
        raise HTTPException(401, "invalid_token")
    token.revoked_at = now
    raw, digest = new_opaque_token()
    replacement = RefreshToken(user_id=user.id, family_id=token.family_id,
                               token_hash=digest,
                               expires_at=now + timedelta(days=settings.refresh_token_ttl_days))
    db.add(replacement)
    await db.flush()
    token.replaced_by_id = replacement.id
    await db.commit()
    return token_pair(user, settings, raw)


@router.post("/auth/logout", status_code=204)
async def logout(payload: Refresh, db: Annotated[AsyncSession, Depends(get_db)]) -> Response:
    token = await db.scalar(select(RefreshToken).where(
        RefreshToken.token_hash == sha256_hex(payload.refresh_token),
    ))
    if token is not None:
        await db.execute(RefreshToken.__table__.update().where(
            RefreshToken.family_id == token.family_id,
            RefreshToken.revoked_at.is_(None),
        ).values(revoked_at=datetime.now(timezone.utc)))
        await db.commit()
    return Response(status_code=204)


@router.post("/auth/logout-all", status_code=204)
async def logout_all(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    now = datetime.now(timezone.utc)
    user.tokens_valid_after = now
    await db.execute(RefreshToken.__table__.update().where(
        RefreshToken.user_id == user.id,
        RefreshToken.revoked_at.is_(None),
    ).values(revoked_at=now))
    await db.commit()
    return Response(status_code=204)


@router.post("/auth/change-password", response_model=TokenPair)
async def change_password(
    payload: ChangePassword, user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenPair:
    if not await verify_password(user.password_hash, payload.current_password):
        raise HTTPException(400, "invalid_password")
    try:
        validate_password_strength(payload.new_password, user.email, user.full_name)
    except ValueError as exc:
        raise HTTPException(422, "invalid_password") from exc
    user.password_hash = await hash_password(payload.new_password)
    now = datetime.now(timezone.utc)
    user.tokens_valid_after = now
    await db.execute(RefreshToken.__table__.update().where(
        RefreshToken.user_id == user.id,
        RefreshToken.revoked_at.is_(None),
    ).values(revoked_at=now))
    raw, digest = new_opaque_token()
    db.add(RefreshToken(user_id=user.id, family_id=uuid4(), token_hash=digest,
                        expires_at=now + timedelta(days=settings.refresh_token_ttl_days)))
    await db.commit()
    return token_pair(user, settings, raw)


@router.get("/users/me", response_model=UserMe)
async def get_me(user: Annotated[User, Depends(get_current_user)]) -> UserMe:
    return user_out(user)


@router.patch("/users/me", response_model=UserMe)
async def update_me(
    payload: UpdateMe, user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> UserMe:
    user.full_name = payload.full_name
    await db.commit()
    await db.refresh(user)
    return user_out(user)


@router.get("/club")
async def get_club(
    user: Annotated[User, Depends(require_club_member)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    club = await db.scalar(select(Club).where(Club.id == user.club_id))
    if club is None:
        raise HTTPException(404, "club_not_found")
    return {"id": club.id, "name": club.name, "league_url": club.league_url}


@router.patch("/club")
async def update_club(
    payload: ClubUpdate, user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    club = await db.scalar(select(Club).where(Club.id == user.club_id))
    if club is None:
        raise HTTPException(404, "club_not_found")
    if "name" in payload.model_fields_set and payload.name is not None:
        club.name = payload.name
    if "league_url" in payload.model_fields_set:
        club.league_url = payload.league_url
    await db.commit()
    return {"id": club.id, "name": club.name, "league_url": club.league_url}


@router.get("/club/members")
async def list_members(
    user: Annotated[User, Depends(require_club_member)],
    db: Annotated[AsyncSession, Depends(get_db)],
    limit: int = 20, offset: int = 0,
) -> dict:
    if not 1 <= limit <= 100 or not 0 <= offset <= 10000:
        raise HTTPException(422, "invalid_pagination")
    query = select(User).where(User.club_id == user.club_id).order_by(User.full_name).limit(limit).offset(offset)
    members = list((await db.scalars(query)).all())
    total = await db.scalar(select(func.count(User.id)).where(User.club_id == user.club_id))
    items = [{"id": member.id, "full_name": member.full_name, "role": member.role,
              **({"email": member.email} if user.role == Role.COACH else {})} for member in members]
    return {"items": items, "total": total or 0, "limit": limit, "offset": offset}


@router.get("/events")
async def list_events(
    user: Annotated[User, Depends(require_club_member)],
    db: Annotated[AsyncSession, Depends(get_db)],
    limit: int = 20, offset: int = 0,
) -> dict:
    query = select(Event).where(Event.club_id == user.club_id).order_by(Event.starts_at).limit(limit).offset(offset)
    events = list((await db.scalars(query)).all())
    total = await db.scalar(select(func.count(Event.id)).where(Event.club_id == user.club_id))
    return {"items": [event_out(event) for event in events], "total": total or 0,
            "limit": limit, "offset": offset}


@router.post("/events", status_code=201)
async def create_event(
    payload: EventCreate, user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    event = Event(**payload.model_dump(), club_id=user.club_id, created_by=user.id)
    db.add(event)
    await db.flush()
    await audit(db, "event.create", actor_id=user.id, club_id=user.club_id, resource_id=event.id)
    await db.commit()
    await db.refresh(event)
    return event_out(event)


@router.get("/events/{event_id}")
async def get_event(
    event_id: UUID, user: Annotated[User, Depends(require_club_member)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    return event_out(await get_event_or_404(db, event_id, user.club_id))


@router.patch("/events/{event_id}")
async def update_event(
    event_id: UUID, payload: EventUpdate, user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    event = await get_event_or_404(db, event_id, user.club_id)
    values = payload.model_dump(exclude_unset=True)
    for key, value in values.items():
        setattr(event, key, value)
    if event.ends_at is not None and event.ends_at < event.starts_at:
        raise HTTPException(422, "invalid_event_dates")
    await db.commit()
    await db.refresh(event)
    return event_out(event)


@router.delete("/events/{event_id}", status_code=204)
async def delete_event(
    event_id: UUID, user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    event = await get_event_or_404(db, event_id, user.club_id)
    await db.delete(event)
    await db.commit()
    return Response(status_code=204)


@router.put("/events/{event_id}/availability")
async def set_availability(
    event_id: UUID, payload: AvailabilityIn,
    user: Annotated[User, Depends(require_club_member)],
    db: Annotated[AsyncSession, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    event = await get_event_or_404(db, event_id, user.club_id)
    if event.starts_at <= datetime.now(timezone.utc):
        raise HTTPException(409, "event_started")
    row = await db.scalar(select(Availability).where(
        Availability.event_id == event.id, Availability.user_id == user.id,
    ))
    if row is None:
        row = Availability(event_id=event.id, user_id=user.id)
        db.add(row)
    row.status = payload.status
    row.reason_ciphertext = row.reason_key_id = None
    if payload.reason is not None:
        row.reason_key_id, row.reason_ciphertext = cipher_from_settings(settings).encrypt(
            payload.reason, reason_aad(event.id, user.id),
        )
    await db.commit()
    return {"status": row.status, "reason": payload.reason, "updated_at": row.created_at}


@router.get("/events/{event_id}/availability/me")
async def get_my_availability(
    event_id: UUID, user: Annotated[User, Depends(require_club_member)],
    db: Annotated[AsyncSession, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    await get_event_or_404(db, event_id, user.club_id)
    row = await db.scalar(select(Availability).where(
        Availability.event_id == event_id, Availability.user_id == user.id,
    ))
    if row is None:
        raise HTTPException(404, "availability_not_found")
    reason = None
    if row.reason_ciphertext is not None and row.reason_key_id is not None:
        reason = cipher_from_settings(settings).decrypt(
            row.reason_key_id, row.reason_ciphertext, reason_aad(event_id, user.id),
        )
    return {"status": row.status, "reason": reason, "updated_at": row.created_at}


@router.get("/events/{event_id}/availability/summary")
async def availability_summary(
    event_id: UUID, user: Annotated[User, Depends(require_club_member)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, int]:
    await get_event_or_404(db, event_id, user.club_id)
    rows = list((await db.scalars(select(Availability).where(Availability.event_id == event_id))).all())
    present = sum(row.status == AvailabilityStatus.PRESENT for row in rows)
    return {"present": present, "absent": len(rows) - present, "no_response": 0}


@router.get("/events/{event_id}/availability")
async def list_availability(
    event_id: UUID, user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
    limit: int = 20, offset: int = 0,
) -> dict:
    await get_event_or_404(db, event_id, user.club_id)
    query = select(User, Availability).join(
        Availability, Availability.user_id == User.id, isouter=True,
    ).where(User.club_id == user.club_id, Availability.event_id == event_id
            ).order_by(User.full_name).limit(limit).offset(offset)
    rows = (await db.execute(query)).all()
    items = [{"user_id": member.id, "full_name": member.full_name,
              "status": availability.status if availability else "no_response"}
             for member, availability in rows]
    return {"items": items, "limit": limit, "offset": offset}


@router.get("/medical-reports")
async def medical_reports(
    user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
    response: Response,
    limit: int = 20, offset: int = 0,
) -> dict:
    response.headers["Cache-Control"] = "no-store"
    query = select(Availability, Event, User).join(
        Event, Event.id == Availability.event_id,
    ).join(User, User.id == Availability.user_id).where(
        Availability.reason_ciphertext.is_not(None),
        Event.club_id == user.club_id,
    ).order_by(Event.starts_at.desc()).limit(limit).offset(offset)
    rows = (await db.execute(query)).all()
    cipher = cipher_from_settings(settings)
    items = []
    for availability, event, player in rows:
        reason = cipher.decrypt(
            availability.reason_key_id, availability.reason_ciphertext,
            reason_aad(event.id, player.id),
        )
        items.append({
            "availability_id": availability.id, "event_id": event.id,
            "event_title": event.title, "starts_at": event.starts_at,
            "player_id": player.id, "player_name": player.full_name,
            "status": availability.status, "reason": reason,
            "reported_at": availability.created_at,
        })
    await audit(db, "medical.read", actor_id=user.id, club_id=user.club_id,
                detail={"count": len(items), "limit": limit, "offset": offset})
    await db.commit()
    return {"items": items, "limit": limit, "offset": offset}


@router.get("/tactics")
async def list_tactics(
    user: Annotated[User, Depends(require_club_member)],
    db: Annotated[AsyncSession, Depends(get_db)],
    limit: int = 20, offset: int = 0,
) -> dict:
    query = select(Tactic).where(Tactic.club_id == user.club_id)
    if user.role != Role.COACH:
        query = query.where(Tactic.is_published.is_(True))
    query = query.order_by(Tactic.created_at.desc()).limit(limit).offset(offset)
    rows = list((await db.scalars(query)).all())
    return {"items": [tactic_out(row) for row in rows], "total": len(rows), "limit": limit, "offset": offset}


@router.get("/tactics/{tactic_id}")
async def get_tactic(
    tactic_id: UUID, user: Annotated[User, Depends(require_club_member)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    return tactic_out(await get_tactic_or_404(db, tactic_id, user.club_id, user.role != Role.COACH))


@router.post("/club/invitations", status_code=201)
async def create_invitation(
    payload: InvitationCreate, user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    raw, digest = new_opaque_token()
    expires_at = datetime.now(timezone.utc) + timedelta(hours=payload.expires_in_hours)
    invitation = Invitation(club_id=user.club_id, created_by=user.id,
                            token_hash=digest, expires_at=expires_at,
                            max_uses=payload.max_uses)
    db.add(invitation)
    await db.flush()
    await audit(db, "invitation.create", actor_id=user.id, club_id=user.club_id,
                resource_id=invitation.id)
    await db.commit()
    return {"id": invitation.id, "token": raw,
            "deep_link": f"bklasa://invite/{raw}",
            "expires_at": expires_at, "max_uses": payload.max_uses}


@router.get("/club/invitations")
async def list_invitations(
    user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[dict]:
    rows = list((await db.scalars(select(Invitation).where(
        Invitation.club_id == user.club_id,
        Invitation.revoked_at.is_(None),
        Invitation.expires_at > datetime.now(timezone.utc),
    ).order_by(Invitation.created_at.desc()))).all())
    return [{"id": row.id, "expires_at": row.expires_at, "max_uses": row.max_uses,
             "used_count": row.used_count} for row in rows]


@router.delete("/club/invitations/{invitation_id}", status_code=204)
async def revoke_invitation(
    invitation_id: UUID, user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    invitation = await db.scalar(select(Invitation).where(
        Invitation.id == invitation_id, Invitation.club_id == user.club_id,
    ))
    if invitation is None:
        raise HTTPException(404, "not_found")
    invitation.revoked_at = datetime.now(timezone.utc)
    await db.commit()
    return Response(status_code=204)


@router.post("/tactics", status_code=201)
async def create_tactic(
    payload: TacticIn, user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    if payload.event_id is not None:
        await get_event_or_404(db, payload.event_id, user.club_id)
    values = payload.model_dump()
    values["is_published"] = values.pop("published")
    tactic = Tactic(**values, club_id=user.club_id, created_by=user.id)
    db.add(tactic)
    await db.flush()
    await audit(db, "tactic.create", actor_id=user.id, club_id=user.club_id, resource_id=tactic.id)
    await db.commit()
    await db.refresh(tactic)
    return tactic_out(tactic)


@router.put("/tactics/{tactic_id}")
async def update_tactic(
    tactic_id: UUID, payload: TacticUpdate, user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    tactic = await get_tactic_or_404(db, tactic_id, user.club_id)
    if tactic.version != payload.expected_version:
        raise HTTPException(409, "version_conflict")
    if payload.event_id is not None:
        await get_event_or_404(db, payload.event_id, user.club_id)
    values = payload.model_dump(exclude={"expected_version"})
    values["is_published"] = values.pop("published")
    for key, value in values.items():
        setattr(tactic, key, value)
    tactic.version += 1
    await db.commit()
    await db.refresh(tactic)
    return tactic_out(tactic)


@router.delete("/tactics/{tactic_id}", status_code=204)
async def delete_tactic(
    tactic_id: UUID, user: Annotated[User, Depends(require_coach)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    tactic = await get_tactic_or_404(db, tactic_id, user.club_id)
    await db.delete(tactic)
    await audit(db, "tactic.delete", actor_id=user.id, club_id=user.club_id,
                resource_id=tactic_id)
    await db.commit()
    return Response(status_code=204)


@router.post("/devices", status_code=201)
async def register_device(
    payload: DeviceIn, user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, UUID]:
    try:
        platform = Platform(payload.platform.casefold())
    except ValueError as exc:
        raise HTTPException(422, "invalid_platform") from exc
    now = datetime.now(timezone.utc)
    device = await db.scalar(select(DeviceToken).where(DeviceToken.fcm_token == payload.fcm_token))
    if device is None:
        device = DeviceToken(user_id=user.id, fcm_token=payload.fcm_token,
                             platform=platform, last_seen_at=now)
        db.add(device)
    else:
        device.user_id, device.platform, device.last_seen_at = user.id, platform, now
    await db.flush()
    old_devices = list((await db.scalars(select(DeviceToken).where(
        DeviceToken.user_id == user.id).order_by(DeviceToken.created_at.desc()).offset(10))).all())
    for old in old_devices:
        await db.delete(old)
    await db.commit()
    return {"id": device.id}


@router.post("/invitations/preview")
async def preview_invitation(
    payload: InvitationPreview, db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, str]:
    invitation = await db.scalar(select(Invitation).where(
        Invitation.token_hash == sha256_hex(payload.token),
        Invitation.revoked_at.is_(None),
        Invitation.expires_at > datetime.now(timezone.utc),
        Invitation.used_count < Invitation.max_uses,
    ))
    if invitation is None:
        raise HTTPException(404, "invalid_invitation")
    club = await db.scalar(select(Club).where(Club.id == invitation.club_id))
    if club is None:
        raise HTTPException(404, "invalid_invitation")
    return {"club_name": club.name}
