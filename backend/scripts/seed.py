"""Idempotent demo data bootstrap; run only in development/demo deployments."""
import asyncio
from datetime import datetime, timezone
from uuid import uuid4
from sqlalchemy import select
from app.db.session import session_factory
from app.models import Club, MedicalReport, Tactic, User
from app.models.user import Role
from app.security import hash_password

async def main() -> None:
    async with session_factory()() as db:
        club = await db.scalar(select(Club).where(Club.name == "Demo Club"))
        if club is None:
            club = Club(id=uuid4(), name="Demo Club")
            db.add(club)
            await db.flush()
        users = {}
        for email, password, name, role in (
            ("admin", "admin", "Trener Demo", Role.COACH),
            ("player@example.com", "password123", "Jan Kowalski", Role.PLAYER),
        ):
            user = await db.scalar(select(User).where(User.email == email))
            if user is None:
                user = User(email=email, password_hash=await hash_password(password),
                            full_name=name, role=role, club_id=club.id,
                            tokens_valid_after=datetime.now(timezone.utc))
                db.add(user)
                await db.flush()
            users[email] = user
        if await db.scalar(select(MedicalReport).where(
            MedicalReport.club_id == club.id,
            MedicalReport.diagnosis == "Kontuzja kolana",
        )) is None:
            db.add(MedicalReport(
                club_id=club.id,
                player_id=users["player@example.com"].id,
                created_by=users["admin"].id,
                diagnosis="Kontuzja kolana",
                details="Raport demonstracyjny",
            ))
        if await db.scalar(select(Tactic).where(
            Tactic.club_id == club.id,
            Tactic.title == "Taktyka demonstracyjna",
        )) is None:
            db.add(Tactic(
                club_id=club.id,
                created_by=users["admin"].id,
                title="Taktyka demonstracyjna",
                description="Przykładowe ustawienie meczowe",
                is_published=True,
            ))
        await db.commit()

if __name__ == "__main__":
    asyncio.run(main())
