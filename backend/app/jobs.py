"""Small, idempotent maintenance jobs, suitable for a scheduler or a one-shot worker."""
from datetime import datetime, timezone
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models import RefreshToken, Event

async def cleanup_refresh_tokens(db: AsyncSession) -> int:
    result = await db.execute(delete(RefreshToken).where(
        RefreshToken.expires_at < datetime.now(timezone.utc)))
    await db.commit()
    return result.rowcount or 0

async def upcoming_event_reminders(db: AsyncSession, *, within_hours: int = 24) -> list[Event]:
    from datetime import timedelta
    now = datetime.now(timezone.utc)
    return list((await db.scalars(select(Event).where(
        Event.starts_at >= now, Event.starts_at <= now + timedelta(hours=within_hours)))).all())
