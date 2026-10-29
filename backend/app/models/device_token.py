import enum
from datetime import datetime
from uuid import UUID
from sqlalchemy import DateTime, Enum, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base, CreatedAt, UUIDPrimaryKey
class Platform(str, enum.Enum):
    ANDROID = "android"
    IOS = "ios"
class DeviceToken(UUIDPrimaryKey, CreatedAt, Base):
    __tablename__ = "device_tokens"
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    fcm_token: Mapped[str] = mapped_column(String, unique=True)
    platform: Mapped[Platform] = mapped_column(
        Enum(Platform, name="device_platform", native_enum=False)
    )
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
