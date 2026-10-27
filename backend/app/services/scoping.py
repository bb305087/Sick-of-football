from uuid import UUID
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.event import Event
from app.models.tactic import Tactic

async def get_event_or_404(db: AsyncSession, event_id: UUID, club_id: UUID) -> Event:
    item = await db.scalar(select(Event).where(Event.id == event_id, Event.club_id == club_id))
    if item is None:
        raise HTTPException(404, "not_found")
    return item

async def get_tactic_or_404(
    db: AsyncSession, tactic_id: UUID, club_id: UUID, only_published: bool = False,
) -> Tactic:
    query = select(Tactic).where(Tactic.id == tactic_id, Tactic.club_id == club_id)
    if only_published:
        query = query.where(Tactic.is_published.is_(True))
    item = await db.scalar(query)
    if item is None:
        raise HTTPException(404, "not_found")
    return item
