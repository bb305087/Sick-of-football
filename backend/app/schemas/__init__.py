from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, field_validator
from app.models.event import EventType, AvailabilityStatus

class InputModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    @field_validator("*", mode="before")
    @classmethod
    def reject_control_characters(cls, value):
        if isinstance(value, str) and any(ord(c) < 32 and c not in "\n" for c in value):
            raise ValueError("control characters are not allowed")
        return value

class LoginIn(InputModel):
    email: str = Field(min_length=1, max_length=254)
    password: str = Field(min_length=1, max_length=128)

class RefreshIn(InputModel):
    refresh_token: str = Field(min_length=20, max_length=512)

class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    email: str
    full_name: str
    role: str
    club_id: UUID | None

class EventCreateIn(InputModel):
    type: EventType
    title: str = Field(min_length=1, max_length=120)
    starts_at: datetime
    ends_at: datetime | None = None
    location: str | None = Field(default=None, max_length=200)

class AttendanceIn(InputModel):
    status: AvailabilityStatus
    reason: str | None = Field(default=None, max_length=300)

class TacticIn(InputModel):
    title: str = Field(min_length=1, max_length=120)
    content: str = Field(min_length=1, max_length=5000)
    published: bool = False

class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut | None = None
