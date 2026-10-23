from uuid import UUID
from sqlalchemy import Boolean, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base, CreatedAt, UUIDPrimaryKey
class Tactic(UUIDPrimaryKey, CreatedAt, Base):
    __tablename__ = "tactics"
    club_id: Mapped[UUID] = mapped_column(ForeignKey("clubs.id", ondelete="CASCADE"), index=True)
    event_id: Mapped[UUID | None] = mapped_column(ForeignKey("events.id", ondelete="SET NULL"))
    title: Mapped[str] = mapped_column(String(120))
    formation: Mapped[str | None] = mapped_column(String(20))
    description: Mapped[str | None] = mapped_column(String(5000))
    lineup: Mapped[list] = mapped_column(JSON, default=list)
    set_pieces: Mapped[list] = mapped_column(JSON, default=list)
    is_published: Mapped[bool] = mapped_column(Boolean, default=False)
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_by: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
