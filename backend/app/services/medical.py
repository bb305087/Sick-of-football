from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models import MedicalReport, User

async def list_reports(db: AsyncSession, club_id: UUID) -> list[MedicalReport]:
    return list((await db.scalars(select(MedicalReport).where(
        MedicalReport.club_id == club_id))).all())

async def create_report(db: AsyncSession, *, club_id: UUID, player_id: UUID,
                        created_by: UUID, diagnosis: str, details: str | None = None,
                        occurred_on=None, cleared_on=None) -> MedicalReport:
    player = await db.scalar(select(User).where(User.id == player_id, User.club_id == club_id))
    if player is None:
        raise ValueError("player_not_found")
    report = MedicalReport(club_id=club_id, player_id=player_id, created_by=created_by,
                           diagnosis=diagnosis, details=details,
                           occurred_on=occurred_on, cleared_on=cleared_on)
    db.add(report)
    await db.flush()
    return report
