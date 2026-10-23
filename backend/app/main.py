from __future__ import annotations

import asyncio
import base64
import logging
import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import Annotated, Any, Literal
from uuid import uuid4

import jwt
from cryptography.exceptions import InvalidTag
from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field, field_validator

from .crypto import FieldCipher, reason_aad
from .security import DUMMY_HASH, hash_password, new_opaque_token, sha256_hex, verify_password

log = logging.getLogger(__name__)
JWT_ALGORITHM = "HS256"
JWT_SECRET = os.getenv("SICK_OF_FOOTBALL_JWT_SECRET", "local-development-secret-change-me-32")
if len(JWT_SECRET) < 32:
    raise RuntimeError("SICK_OF_FOOTBALL_JWT_SECRET must contain at least 32 characters")
JWT_ISSUER = os.getenv("SICK_OF_FOOTBALL_JWT_ISSUER", "sick-of-football")
JWT_AUDIENCE = os.getenv("SICK_OF_FOOTBALL_JWT_AUDIENCE", "sick-of-football-mobile")
ACCESS_TOKEN_MINUTES = 15
REFRESH_TOKEN_DAYS = 14


def _clean(value: str, *, multiline: bool = False) -> str:
    value = value.strip()
    if any(ord(char) < 32 and char != "\n" for char in value):
        raise ValueError("control characters are not allowed")
    if not multiline and "\n" in value:
        raise ValueError("line breaks are not allowed")
    return value


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class LoginRequest(StrictModel):
    email: str = Field(min_length=1, max_length=254)
    password: str = Field(min_length=1, max_length=128)


class RefreshRequest(StrictModel):
    refresh_token: str = Field(min_length=20, max_length=512)


class EventCreateRequest(StrictModel):
    type: Literal["match", "training"]
    title: str = Field(min_length=1, max_length=120)
    starts_at: datetime
    location: str = Field(min_length=1, max_length=200)

    @field_validator("title", "location")
    @classmethod
    def clean_text(cls, value: str) -> str:
        return _clean(value)

    @field_validator("starts_at")
    @classmethod
    def aware_datetime(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("datetime must include a timezone")
        return value.astimezone(timezone.utc)


class AttendanceRequest(StrictModel):
    status: Literal["present", "absent_work", "absent_injury", "absent_illness"]
    reason: str | None = Field(default=None, max_length=300)

    @field_validator("reason")
    @classmethod
    def clean_reason(cls, value: str | None) -> str | None:
        return None if value is None else _clean(value, multiline=True)


class TacticRequest(StrictModel):
    title: str = Field(min_length=1, max_length=120)
    content: str = Field(min_length=1, max_length=5000)
    published: bool = False

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str) -> str:
        return _clean(value)

    @field_validator("content")
    @classmethod
    def clean_content(cls, value: str) -> str:
        return _clean(value, multiline=True)


def _user(user_id: int, email: str, password: str, name: str, role: str) -> dict[str, Any]:
    return {
        "id": user_id, "email": email, "password_hash": password, "name": name,
        "role": role, "team_id": 1, "is_active": True,
        "tokens_valid_after": datetime.now(timezone.utc),
    }


# This in-memory repository keeps the Flutter demo usable while exposing the same
# security boundaries as the PostgreSQL implementation described in the plan.
users: list[dict[str, Any]] = [
    _user(1, "admin", "admin", "Trener Demo", "coach"),
    _user(2, "player@example.com", "password123", "Jan Kowalski", "player"),
]
users[0]["password_hash"] = asyncio.run(hash_password("admin"))
users[1]["password_hash"] = asyncio.run(hash_password("password123"))
events: list[dict[str, Any]] = [
    {"id": 1, "type": "match", "title": "LKS B-Klasa vs Orzeł II",
     "starts_at": "2026-10-25T13:00:00+00:00", "location": "Boisko boczne", "team_id": 1},
    {"id": 2, "type": "training", "title": "Trening zespołu",
     "starts_at": "2026-10-27T16:30:00+00:00", "location": "Boisko boczne", "team_id": 1},
]
team_members = [
    {"id": 2, "name": "Jan Kowalski", "email": "player@example.com", "team_id": 1, "availability": "present"},
    {"id": 3, "name": "Adam Nowak", "email": "adam.nowak@example.com", "team_id": 1,
     "availability": "absent_work", "absence_reason": "Druga zmiana w pracy"},
]
attendance: list[dict[str, Any]] = [{"event_id": 1, "user_id": 2, "status": "present",
                                      "reason_ciphertext": None, "reason_key_id": None}]
tactics: list[dict[str, Any]] = [{"id": 1, "title": "Stałe fragmenty gry",
    "content": "Rzut rożny: wariant pierwszy", "published": True, "team_id": 1,
    "updated_at": "2026-10-19T16:00:00+00:00"}]
medical_reports = [{"id": 1, "user_id": 3, "player_name": "Adam Nowak",
                    "reason": "Kontuzja kolana", "details": "Przerwa treningowa do konsultacji lekarskiej", "team_id": 1}]
refresh_tokens: dict[str, dict[str, Any]] = {}
refresh_lock = asyncio.Lock()
field_cipher = FieldCipher({1: base64.urlsafe_b64decode(
    os.getenv("SICK_OF_FOOTBALL_DATA_KEY", base64.urlsafe_b64encode(secrets.token_bytes(32)).decode())
)}, 1)

app = FastAPI(title="Sick of Football API", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=os.getenv("SICK_OF_FOOTBALL_ALLOWED_ORIGINS", "http://localhost").split(","),
                   allow_credentials=False, allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
                   allow_headers=["Authorization", "Content-Type"])
security = HTTPBearer(auto_error=False)


def public_user(user: dict[str, Any]) -> dict[str, Any]:
    return {key: user[key] for key in ("id", "email", "name", "role", "team_id")}


def create_access_token(user_id: int) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode({"sub": str(user_id), "iat": now, "nbf": now,
                       "exp": now + timedelta(minutes=ACCESS_TOKEN_MINUTES),
                       "iss": JWT_ISSUER, "aud": JWT_AUDIENCE, "jti": uuid4().hex, "typ": "access"},
                      JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> dict[str, Any]:
    claims = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM],
                        audience=JWT_AUDIENCE, issuer=JWT_ISSUER,
                        options={"require": ["exp", "iat", "nbf", "sub", "iss", "aud", "jti"]})
    if claims.get("typ") != "access":
        raise jwt.InvalidTokenError("wrong token type")
    return claims


def unauthorized() -> HTTPException:
    return HTTPException(401, detail="unauthorized", headers={"WWW-Authenticate": "Bearer"})


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise unauthorized()
    try:
        claims = decode_access_token(credentials.credentials)
        user_id = int(claims["sub"])
        user = next((item for item in users if item["id"] == user_id), None)
        if user is None or not user["is_active"] or claims["iat"] < int(user["tokens_valid_after"].timestamp()):
            raise unauthorized()
        return user
    except (jwt.PyJWTError, KeyError, TypeError, ValueError):
        raise unauthorized()


def require_role(role: Literal["coach", "player"]):
    async def dependency(user: Annotated[dict[str, Any], Depends(get_current_user)]) -> dict[str, Any]:
        if user["role"] != role:
            raise HTTPException(403, detail="forbidden")
        return user
    return dependency


def get_event_or_404(event_id: int, team_id: int) -> dict[str, Any]:
    event = next((item for item in events if item["id"] == event_id and item["team_id"] == team_id), None)
    if event is None:
        raise HTTPException(404, detail="not_found")
    return event


def public_attendance(item: dict[str, Any]) -> dict[str, Any]:
    result = {key: item[key] for key in ("event_id", "user_id", "status")}
    if item["reason_ciphertext"] is None:
        result["reason"] = None
        return result
    try:
        result["reason"] = field_cipher.decrypt(
            item["reason_key_id"],
            item["reason_ciphertext"],
            reason_aad(item["event_id"], item["user_id"]),
        )
    except (InvalidTag, ValueError, UnicodeDecodeError):
        log.exception("availability reason decryption failed")
        raise HTTPException(500, detail="internal_error")
    return result


@app.get("/api/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/auth/login")
async def login(request: LoginRequest, http_request: Request) -> dict[str, Any]:
    email = _clean(request.email).casefold()
    user = next((item for item in users if item["email"].casefold() == email), None)
    valid = await verify_password(user["password_hash"] if user else DUMMY_HASH, request.password)
    if user is None or not valid or not user["is_active"]:
        raise HTTPException(401, detail="invalid_credentials")
    raw, digest = new_opaque_token()
    refresh_tokens[digest] = {"user_id": user["id"], "family_id": uuid4().hex,
                              "created_at": datetime.now(timezone.utc), "expires_at": datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_DAYS),
                              "revoked_at": None, "user_agent": http_request.headers.get("user-agent", "")[:200]}
    return {"access_token": create_access_token(user["id"]), "refresh_token": raw,
            "token_type": "bearer", "expires_in": ACCESS_TOKEN_MINUTES * 60, "user": public_user(user)}


@app.get("/api/auth/me")
async def me(user: Annotated[dict[str, Any], Depends(get_current_user)]) -> dict[str, Any]:
    return public_user(user)


@app.post("/api/auth/refresh")
async def refresh(request: RefreshRequest) -> dict[str, Any]:
    digest = sha256_hex(request.refresh_token)
    async with refresh_lock:
        record = refresh_tokens.get(digest)
        if record is None:
            raise HTTPException(401, detail="invalid_token")
        if record["revoked_at"] is not None:
            for item in refresh_tokens.values():
                if item["family_id"] == record["family_id"] and item["revoked_at"] is None:
                    item["revoked_at"] = datetime.now(timezone.utc)
            raise HTTPException(401, detail="invalid_token")
        now = datetime.now(timezone.utc)
        user = next((item for item in users if item["id"] == record["user_id"]), None)
        if record["expires_at"] <= now or user is None or not user["is_active"]:
            raise HTTPException(401, detail="invalid_token")
        record["revoked_at"] = now
        raw, new_digest = new_opaque_token()
        refresh_tokens[new_digest] = {**record, "created_at": now, "expires_at": now + timedelta(days=REFRESH_TOKEN_DAYS),
                                      "revoked_at": None}
        return {"access_token": create_access_token(user["id"]), "refresh_token": raw,
                "token_type": "bearer", "expires_in": ACCESS_TOKEN_MINUTES * 60}


@app.post("/api/auth/logout", status_code=204)
async def logout(request: RefreshRequest) -> Response:
    record = refresh_tokens.get(sha256_hex(request.refresh_token))
    if record:
        for item in refresh_tokens.values():
            if item["family_id"] == record["family_id"]:
                item["revoked_at"] = datetime.now(timezone.utc)
    return Response(status_code=204)


@app.get("/api/events")
async def list_events(user: Annotated[dict[str, Any], Depends(get_current_user)]) -> list[dict[str, Any]]:
    return [item for item in events if item["team_id"] == user["team_id"]]


@app.post("/api/events", status_code=201)
async def create_event(request: EventCreateRequest, user: Annotated[dict[str, Any], Depends(require_role("coach"))]) -> dict[str, Any]:
    event = {"id": max((item["id"] for item in events), default=0) + 1, **request.model_dump(mode="json"), "team_id": user["team_id"]}
    events.append(event)
    return event


@app.post("/api/events/{event_id}/attendance")
async def set_attendance(event_id: int, request: AttendanceRequest,
                          user: Annotated[dict[str, Any], Depends(require_role("player"))]) -> dict[str, Any]:
    get_event_or_404(event_id, user["team_id"])
    existing = next((item for item in attendance if item["event_id"] == event_id and item["user_id"] == user["id"]), None)
    if existing is None:
        existing = {"event_id": event_id, "user_id": user["id"]}
        attendance.append(existing)
    key_id = ciphertext = None
    if request.reason is not None and request.status != "present":
        key_id, ciphertext = field_cipher.encrypt(
            request.reason, reason_aad(event_id, user["id"])
        )
    existing.update({"status": request.status, "reason_ciphertext": ciphertext,
                     "reason_key_id": key_id})
    return public_attendance(existing)


@app.get("/api/team/members")
async def list_team_members(user: Annotated[dict[str, Any], Depends(get_current_user)]) -> list[dict[str, Any]]:
    members = [item for item in team_members if item["team_id"] == user["team_id"]]
    return members if user["role"] == "coach" else [{k: v for k, v in item.items() if k != "absence_reason"} for item in members]


@app.get("/api/tactics")
async def list_tactics(user: Annotated[dict[str, Any], Depends(get_current_user)]) -> list[dict[str, Any]]:
    return [item for item in tactics if item["team_id"] == user["team_id"] and (user["role"] == "coach" or item["published"])]


@app.post("/api/tactics", status_code=201)
async def create_tactic(request: TacticRequest, user: Annotated[dict[str, Any], Depends(require_role("coach"))]) -> dict[str, Any]:
    tactic = {"id": max((item["id"] for item in tactics), default=0) + 1, **request.model_dump(),
              "team_id": user["team_id"], "updated_at": datetime.now(timezone.utc).isoformat()}
    tactics.append(tactic)
    return tactic


@app.put("/api/tactics/{tactic_id}")
async def update_tactic(tactic_id: int, request: TacticRequest,
                        user: Annotated[dict[str, Any], Depends(require_role("coach"))]) -> dict[str, Any]:
    tactic = next((item for item in tactics if item["id"] == tactic_id and item["team_id"] == user["team_id"]), None)
    if tactic is None:
        raise HTTPException(404, detail="not_found")
    tactic.update(request.model_dump())
    tactic["updated_at"] = datetime.now(timezone.utc).isoformat()
    return tactic


@app.get("/api/medical-reports")
async def list_medical_reports(user: Annotated[dict[str, Any], Depends(require_role("coach"))]) -> list[dict[str, Any]]:
    return [item for item in medical_reports if item["team_id"] == user["team_id"]]
