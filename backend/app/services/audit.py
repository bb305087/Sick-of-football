from typing import Any
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from app.models import AuditLog

async def audit(db: AsyncSession, action: str, *, actor_id: UUID | None = None,
                club_id: UUID | None = None, resource_type: str | None = None,
                resource_id: UUID | None = None, success: bool = True,
                ip: str | None = None, user_agent: str | None = None,
                detail: dict[str, Any] | None = None) -> None:
    db.add(AuditLog(actor_id=actor_id, club_id=club_id, action=action,
                    resource_type=resource_type, resource_id=resource_id,
                    success=success, ip=ip, user_agent=(user_agent or "")[:200],
                    detail=detail))
