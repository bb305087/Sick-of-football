from datetime import datetime
from uuid import UUID
from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base, CreatedAt, UUIDPrimaryKey
class RefreshToken(UUIDPrimaryKey, CreatedAt, Base):
    __tablename__ = "refresh_tokens"
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    family_id: Mapped[UUID] = mapped_column(index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    replaced_by_id: Mapped[UUID | None] = mapped_column(ForeignKey("refresh_tokens.id"))
    user_agent: Mapped[str | None] = mapped_column(String(200))
    ip: Mapped[str | None] = mapped_column(String(45))
