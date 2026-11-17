from __future__ import annotations

from collections import Counter
from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.event import AvailabilityStatus, EventType
from app.models.user import Role


class StrictInput(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    @field_validator("*", mode="before")
    @classmethod
    def reject_control_characters(cls, value: Any) -> Any:
        if isinstance(value, str) and any(ord(char) < 32 and char != "\n" for char in value):
            raise ValueError("control characters are not allowed")
        return value


class UserMe(BaseModel):
    id: UUID
    email: str
    full_name: str
    role: Role
    club_id: UUID | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class RegisterCoach(StrictInput):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=12, max_length=128)
    full_name: str = Field(min_length=1, max_length=100)
    club_name: str = Field(min_length=1, max_length=100)


class RegisterPlayer(StrictInput):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=12, max_length=128)
    full_name: str = Field(min_length=1, max_length=100)
    invite_token: str = Field(min_length=20, max_length=512)


class Login(StrictInput):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=1, max_length=128)


class Refresh(StrictInput):
    refresh_token: str = Field(min_length=20, max_length=512)


class ChangePassword(StrictInput):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=12, max_length=128)


class UpdateMe(StrictInput):
    full_name: str = Field(min_length=1, max_length=100)


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class ClubUpdate(StrictInput):
    name: str | None = Field(default=None, max_length=100)
    league_url: str | None = Field(default=None, max_length=500)


class EventCreate(StrictInput):
    type: EventType
    title: str = Field(min_length=1, max_length=120)
    starts_at: datetime
    ends_at: datetime | None = None
    location: str | None = Field(default=None, max_length=200)
    opponent: str | None = Field(default=None, max_length=120)
    notes: str | None = Field(default=None, max_length=5000)

    @model_validator(mode="after")
    def validate_dates(self) -> "EventCreate":
        if self.starts_at.tzinfo is None or (
            self.ends_at is not None and self.ends_at.tzinfo is None
        ):
            raise ValueError("datetimes must include timezone")
        if self.ends_at is not None and self.ends_at < self.starts_at:
            raise ValueError("ends_at must not precede starts_at")
        if self.type != EventType.MATCH and self.opponent is not None:
            raise ValueError("opponent is only valid for matches")
        return self


class EventUpdate(StrictInput):
    type: EventType | None = None
    title: str | None = Field(default=None, min_length=1, max_length=120)
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    location: str | None = Field(default=None, max_length=200)
    opponent: str | None = Field(default=None, max_length=120)
    notes: str | None = Field(default=None, max_length=5000)


class AvailabilityIn(StrictInput):
    status: AvailabilityStatus
    reason: str | None = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def validate_reason(self) -> "AvailabilityIn":
        if self.status == AvailabilityStatus.PRESENT and self.reason is not None:
            raise ValueError("present availability cannot have a reason")
        return self


class TacticIn(StrictInput):
    title: str = Field(min_length=1, max_length=120)
    event_id: UUID | None = None
    formation: str | None = Field(default=None, max_length=20)
    description: str | None = Field(default=None, max_length=5000)
    lineup: list[dict[str, Any]] = Field(default_factory=list, max_length=25)
    set_pieces: list[dict[str, Any]] = Field(default_factory=list, max_length=20)
    published: bool = False

    @model_validator(mode="after")
    def validate_lineup(self) -> "TacticIn":
        formations = {
            "4-3-3": ["GK", "LB", "CB", "CB", "RB", "CM", "CM", "CM", "LW", "ST", "RW"],
            "4-4-2": ["GK", "LB", "CB", "CB", "RB", "LM", "CM", "CM", "RM", "ST", "ST"],
            "3-5-2": ["GK", "CB", "CB", "CB", "LM", "CM", "CM", "CM", "RM", "ST", "ST"],
        }
        expected_positions = formations.get(self.formation)
        starting_lineup = [
            player for player in self.lineup if player.get("substitute") is not True
        ]
        if expected_positions is not None:
            if len(starting_lineup) != len(expected_positions):
                raise ValueError("all starting positions must be filled")
            actual_positions = [player.get("position") for player in starting_lineup]
            if any(not isinstance(position, str) or not position.strip()
                   for position in actual_positions):
                raise ValueError("lineup positions must be non-empty strings")
            if Counter(actual_positions) != Counter(expected_positions):
                raise ValueError("lineup positions do not match the formation")

        selected_players: set[str] = set()
        for player in self.lineup:
            player_id = player.get("player_id")
            if player_id is None:
                continue
            if not isinstance(player_id, str) or not player_id.strip():
                raise ValueError("lineup player_id must be a non-empty string")
            if player_id in selected_players:
                raise ValueError("a player can only appear once in a lineup")
            selected_players.add(player_id)
        return self


class TacticUpdate(TacticIn):
    expected_version: int = Field(ge=1)


class InvitationCreate(StrictInput):
    expires_in_hours: int = Field(default=72, ge=1, le=168)
    max_uses: int = Field(default=1, ge=1, le=20)


class InvitationPreview(StrictInput):
    token: str = Field(min_length=20, max_length=512)


class DeviceIn(StrictInput):
    fcm_token: str = Field(min_length=20, max_length=4096)
    platform: str


class Pagination(StrictInput):
    limit: int = Field(default=20, ge=1, le=100)
    offset: int = Field(default=0, ge=0, le=10000)
