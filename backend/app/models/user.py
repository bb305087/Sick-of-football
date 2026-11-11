import enum
from datetime import datetime
from uuid import UUID
from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, String, text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, CreatedAt, UUIDPrimaryKey

class Role(str, enum.Enum):
    COACH = "coach"
    PLAYER = "player"

class User(UUIDPrimaryKey, CreatedAt, Base):
    __tablename__ = "users"
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String, nullable=False)
    full_name: Mapped[str] = mapped_column(String(100), nullable=False)
    nationality: Mapped[str | None] = mapped_column(String(80))
    date_of_birth: Mapped[datetime | None] = mapped_column(DateTime)
    position: Mapped[str | None] = mapped_column(String(40))
    preferred_foot: Mapped[str | None] = mapped_column(String(10))
    role: Mapped[Role] = mapped_column(
        Enum(Role, name="user_role", native_enum=False), nullable=False
    )
    club_id: Mapped[UUID | None] = mapped_column(ForeignKey("clubs.id", ondelete="SET NULL"))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))
    failed_login_attempts: Mapped[int] = mapped_column(Integer, server_default=text("0"))
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    tokens_valid_after: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"))
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    club = relationship("Club", back_populates="users")
