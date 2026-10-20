from datetime import datetime, timedelta, timezone
from typing import Annotated, Any, Literal
import os

import jwt
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field


Role = Literal["coach", "player"]
AttendanceStatus = Literal[
    "present",
    "absent_work",
    "absent_injury",
    "absent_illness",
]

JWT_ALGORITHM = "HS256"
JWT_SECRET = os.getenv("SICK_OF_FOOTBALL_JWT_SECRET", "local-development-secret")
ACCESS_TOKEN_MINUTES = 30
REFRESH_TOKEN_DAYS = 7

app = FastAPI(
    title="Sick of Football Mock API",
    version="0.1.0",
    description="Development-only API used by the Flutter application.",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBearer(auto_error=False)

users: list[dict[str, Any]] = [
    {
        "id": 1,
        "email": "admin",
        "password": "admin",
        "name": "Trener Demo",
        "role": "coach",
        "team_id": 1,
    },
    {
        "id": 2,
        "email": "player@example.com",
        "password": "password123",
        "name": "Jan Kowalski",
        "role": "player",
        "team_id": 1,
    },
]

events: list[dict[str, Any]] = [
    {
        "id": 1,
        "type": "match",
        "title": "LKS B-Klasa vs Orzeł II",
        "starts_at": "2026-10-25T15:00:00+02:00",
        "location": "Boisko boczne",
        "team_id": 1,
    },
    {
        "id": 2,
        "type": "training",
        "title": "Trening zespołu",
        "starts_at": "2026-10-27T18:30:00+02:00",
        "location": "Boisko boczne",
        "team_id": 1,
    },
]

team_members: list[dict[str, Any]] = [
    {
        "id": 2,
        "name": "Jan Kowalski",
        "email": "player@example.com",
        "team_id": 1,
        "availability": "present",
    },
    {
        "id": 3,
        "name": "Adam Nowak",
        "email": "adam.nowak@example.com",
        "team_id": 1,
        "availability": "absent_work",
        "absence_reason": "Druga zmiana w pracy",
    },
]

attendance: list[dict[str, Any]] = [
    {"event_id": 1, "user_id": 2, "status": "present", "reason": None}
]

tactics: list[dict[str, Any]] = [
    {
        "id": 1,
        "title": "Stałe fragmenty gry",
        "content": "Rzut rożny: wariant pierwszy",
        "published": True,
        "team_id": 1,
        "updated_at": "2026-10-19T18:00:00+02:00",
    }
]

medical_reports: list[dict[str, Any]] = [
    {
        "id": 1,
        "user_id": 3,
        "player_name": "Adam Nowak",
        "reason": "Kontuzja kolana",
        "details": "Przerwa treningowa do konsultacji lekarskiej",
        "team_id": 1,
    }
]


class LoginRequest(BaseModel):
    email: str = Field(min_length=1)
    password: str = Field(min_length=1)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class EventCreateRequest(BaseModel):
    type: Literal["match", "training"]
    title: str = Field(min_length=1, max_length=120)
    starts_at: datetime
    location: str = Field(min_length=1, max_length=160)


class AttendanceRequest(BaseModel):
    status: AttendanceStatus
    reason: str | None = Field(default=None, max_length=300)


class TacticRequest(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    content: str = Field(min_length=1, max_length=5000)
    published: bool = False


def public_user(user: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": user["id"],
        "email": user["email"],
        "name": user["name"],
        "role": user["role"],
        "team_id": user["team_id"],
    }


def create_token(user: dict[str, Any], token_type: Literal["access", "refresh"]) -> str:
    now = datetime.now(timezone.utc)
    expires_delta = (
        timedelta(minutes=ACCESS_TOKEN_MINUTES)
        if token_type == "access"
        else timedelta(days=REFRESH_TOKEN_DAYS)
    )
    payload = {
        "sub": str(user["id"]),
        "role": user["role"],
        "team_id": user["team_id"],
        "type": token_type,
        "iat": now,
        "exp": now + expires_delta,
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def find_user(user_id: int) -> dict[str, Any]:
    user = next((item for item in users if item["id"] == user_id), None)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Użytkownik nie istnieje",
        )
    return user


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Wymagany token Bearer",
        )
    try:
        payload = jwt.decode(
            credentials.credentials,
            JWT_SECRET,
            algorithms=[JWT_ALGORITHM],
        )
        if payload.get("type") != "access":
            raise ValueError("Nieprawidłowy typ tokena")
        user_id = int(payload["sub"])
    except (jwt.InvalidTokenError, KeyError, TypeError, ValueError) as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Nieprawidłowy lub wygasły token",
        ) from error
    return find_user(user_id)


def require_role(role: Role):
    def dependency(
        current_user: Annotated[dict[str, Any], Depends(get_current_user)],
    ) -> dict[str, Any]:
        if current_user["role"] != role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Brak uprawnień do wykonania tej operacji",
            )
        return current_user

    return dependency


def get_team_event(event_id: int, current_user: dict[str, Any]) -> dict[str, Any]:
    event = next(
        (
            item
            for item in events
            if item["id"] == event_id
            and item["team_id"] == current_user["team_id"]
        ),
        None,
    )
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Wydarzenie nie istnieje")
    return event


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/auth/login")
def login(request: LoginRequest) -> dict[str, Any]:
    user = next(
        (
            item
            for item in users
            if item["email"].lower() == request.email.strip().lower()
            and item["password"] == request.password
        ),
        None,
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Nieprawidłowy e-mail lub hasło",
        )
    return {
        "access_token": create_token(user, "access"),
        "refresh_token": create_token(user, "refresh"),
        "token_type": "bearer",
        "user": public_user(user),
    }


@app.get("/api/auth/me")
def me(
    current_user: Annotated[dict[str, Any], Depends(get_current_user)],
) -> dict[str, Any]:
    return public_user(current_user)


@app.post("/api/auth/refresh")
def refresh(request: RefreshRequest) -> dict[str, str]:
    try:
        payload = jwt.decode(
            request.refresh_token,
            JWT_SECRET,
            algorithms=[JWT_ALGORITHM],
        )
        if payload.get("type") != "refresh":
            raise ValueError("Nieprawidłowy typ tokena")
        user_id = int(payload["sub"])
    except (jwt.InvalidTokenError, KeyError, TypeError, ValueError) as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Nieprawidłowy lub wygasły refresh token",
        ) from error

    user = find_user(user_id)
    return {
        "access_token": create_token(user, "access"),
        "token_type": "bearer",
    }


@app.get("/api/events")
def list_events(
    current_user: Annotated[dict[str, Any], Depends(get_current_user)],
) -> list[dict[str, Any]]:
    return [item for item in events if item["team_id"] == current_user["team_id"]]


@app.post("/api/events", status_code=status.HTTP_201_CREATED)
def create_event(
    request: EventCreateRequest,
    current_user: Annotated[dict[str, Any], Depends(require_role("coach"))],
) -> dict[str, Any]:
    next_id = max((item["id"] for item in events), default=0) + 1
    event = {
        "id": next_id,
        **request.model_dump(mode="json"),
        "team_id": current_user["team_id"],
    }
    events.append(event)
    return event


@app.post("/api/events/{event_id}/attendance")
def set_attendance(
    event_id: int,
    request: AttendanceRequest,
    current_user: Annotated[dict[str, Any], Depends(require_role("player"))],
) -> dict[str, Any]:
    get_team_event(event_id, current_user)
    existing = next(
        (
            item
            for item in attendance
            if item["event_id"] == event_id and item["user_id"] == current_user["id"]
        ),
        None,
    )
    if existing is None:
        existing = {"event_id": event_id, "user_id": current_user["id"]}
        attendance.append(existing)
    existing.update({"status": request.status, "reason": request.reason})
    return existing


@app.get("/api/team/members")
def list_team_members(
    current_user: Annotated[dict[str, Any], Depends(get_current_user)],
) -> list[dict[str, Any]]:
    members = [item for item in team_members if item["team_id"] == current_user["team_id"]]
    if current_user["role"] == "coach":
        return members
    return [
        {key: value for key, value in member.items() if key != "absence_reason"}
        for member in members
    ]


@app.get("/api/tactics")
def list_tactics(
    current_user: Annotated[dict[str, Any], Depends(get_current_user)],
) -> list[dict[str, Any]]:
    return [
        item
        for item in tactics
        if item["team_id"] == current_user["team_id"]
        and (current_user["role"] == "coach" or item["published"])
    ]


@app.post("/api/tactics", status_code=status.HTTP_201_CREATED)
def create_tactic(
    request: TacticRequest,
    current_user: Annotated[dict[str, Any], Depends(require_role("coach"))],
) -> dict[str, Any]:
    tactic = {
        "id": max((item["id"] for item in tactics), default=0) + 1,
        **request.model_dump(),
        "team_id": current_user["team_id"],
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    tactics.append(tactic)
    return tactic


@app.put("/api/tactics/{tactic_id}")
def update_tactic(
    tactic_id: int,
    request: TacticRequest,
    current_user: Annotated[dict[str, Any], Depends(require_role("coach"))],
) -> dict[str, Any]:
    tactic = next(
        (
            item
            for item in tactics
            if item["id"] == tactic_id and item["team_id"] == current_user["team_id"]
        ),
        None,
    )
    if tactic is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Taktyka nie istnieje")
    tactic.update(request.model_dump())
    tactic["updated_at"] = datetime.now(timezone.utc).isoformat()
    return tactic


@app.get("/api/medical-reports")
def list_medical_reports(
    current_user: Annotated[dict[str, Any], Depends(require_role("coach"))],
) -> list[dict[str, Any]]:
    return [item for item in medical_reports if item["team_id"] == current_user["team_id"]]
