from datetime import date
from uuid import UUID
from sqlalchemy import Date, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base, CreatedAt, UUIDPrimaryKey

class MedicalReport(UUIDPrimaryKey, CreatedAt, Base):
    __tablename__ = "medical_reports"
    club_id: Mapped[UUID] = mapped_column(ForeignKey("clubs.id", ondelete="CASCADE"), nullable=False, index=True)
    player_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    diagnosis: Mapped[str] = mapped_column(String(200), nullable=False)
    details: Mapped[str | None] = mapped_column(Text)
    occurred_on: Mapped[date | None] = mapped_column(Date)
    cleared_on: Mapped[date | None] = mapped_column(Date)
    created_by: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
