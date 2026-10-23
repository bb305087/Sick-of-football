from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, CreatedAt, UUIDPrimaryKey
class Club(UUIDPrimaryKey, CreatedAt, Base):
    __tablename__ = "clubs"
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    league_url: Mapped[str | None] = mapped_column(String(500))
    users = relationship("User", back_populates="club")
