from datetime import datetime
from uuid import UUID
from sqlalchemy import JSON, Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base
class AuditLog(Base):
    __tablename__ = "audit_logs"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ts: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default="now()", index=True)
    actor_id: Mapped[UUID | None] = mapped_column()
    club_id: Mapped[UUID | None] = mapped_column()
    action: Mapped[str] = mapped_column(String(50))
    resource_type: Mapped[str | None] = mapped_column(String(30))
    resource_id: Mapped[UUID | None] = mapped_column()
    success: Mapped[bool] = mapped_column(Boolean)
    ip: Mapped[str | None] = mapped_column(String(45))
    user_agent: Mapped[str | None] = mapped_column(String(200))
    detail: Mapped[dict | None] = mapped_column(JSON)
