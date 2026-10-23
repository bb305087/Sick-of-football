from datetime import datetime
from uuid import UUID
from sqlalchemy import DateTime, ForeignKey, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base, CreatedAt, UUIDPrimaryKey
class Invitation(UUIDPrimaryKey, CreatedAt, Base):
    __tablename__ = "invitations"
    club_id: Mapped[UUID] = mapped_column(ForeignKey("clubs.id", ondelete="CASCADE"), index=True)
    created_by: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    max_uses: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    used_count: Mapped[int] = mapped_column(SmallInteger, default=0, nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
