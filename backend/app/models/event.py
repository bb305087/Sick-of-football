import enum
from datetime import datetime
from uuid import UUID
from sqlalchemy import DateTime, Enum, ForeignKey, LargeBinary, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base, CreatedAt, UUIDPrimaryKey
class EventType(str, enum.Enum):
    TRAINING = "training"
    MATCH = "match"
class AvailabilityStatus(str, enum.Enum):
    PRESENT = "present"
    WORK = "work"
    INJURY_ILLNESS = "injury_illness"
class Event(UUIDPrimaryKey, CreatedAt, Base):
    __tablename__ = "events"
    club_id: Mapped[UUID] = mapped_column(ForeignKey("clubs.id", ondelete="CASCADE"), index=True)
    type: Mapped[EventType] = mapped_column(Enum(EventType, name="event_type"))
    title: Mapped[str] = mapped_column(String(120))
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    location: Mapped[str | None] = mapped_column(String(200))
    opponent: Mapped[str | None] = mapped_column(String(120))
    notes: Mapped[str | None] = mapped_column(String(5000))
    created_by: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
class Availability(UUIDPrimaryKey, CreatedAt, Base):
    __tablename__ = "availabilities"
    __table_args__ = (UniqueConstraint("event_id", "user_id"),)
    event_id: Mapped[UUID] = mapped_column(ForeignKey("events.id", ondelete="CASCADE"))
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    status: Mapped[AvailabilityStatus] = mapped_column(Enum(AvailabilityStatus, name="availability_status"))
    reason_ciphertext: Mapped[bytes | None] = mapped_column(LargeBinary)
    reason_key_id: Mapped[int | None] = mapped_column()
