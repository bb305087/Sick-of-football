"""Idempotent demo data bootstrap; run only in development/demo deployments."""
import asyncio
from datetime import datetime, timezone
from uuid import uuid4
from sqlalchemy import select
from app.db.session import session_factory
from app.models import Club, User
from app.models.user import Role
from app.security import hash_password

async def main() -> None:
    async with session_factory()() as db:
        club = await db.scalar(select(Club).where(Club.name == "Demo Club"))
        if club is None:
            club = Club(id=uuid4(), name="Demo Club")
            db.add(club)
            await db.flush()
        for email, password, name, role in (
            ("admin", "admin", "Trener Demo", Role.COACH),
            ("player@example.com", "password123", "Jan Kowalski", Role.PLAYER),
        ):
            user = await db.scalar(select(User).where(User.email == email))
            if user is None:
                db.add(User(email=email, password_hash=await hash_password(password),
                            full_name=name, role=role, club_id=club.id,
                            tokens_valid_after=datetime.now(timezone.utc)))
        await db.commit()

if __name__ == "__main__":
    asyncio.run(main())
