from typing import Annotated
from uuid import UUID
import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.config import Settings, get_settings
from app.db.session import get_db
from app.models.user import User, Role

bearer = HTTPBearer(auto_error=False)
def unauthorized() -> HTTPException:
    return HTTPException(401, "unauthorized", headers={"WWW-Authenticate": "Bearer"})

async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    db: Annotated[AsyncSession, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> User:
    if credentials is None:
        raise unauthorized()
    try:
        claims = jwt.decode(credentials.credentials, settings.jwt_secret.get_secret_value(),
            algorithms=["HS256"], audience=settings.jwt_audience, issuer=settings.jwt_issuer,
            options={"require": ["exp", "iat", "nbf", "sub", "iss", "aud", "jti"]})
        if claims.get("typ") != "access":
            raise unauthorized()
        user = await db.get(User, UUID(str(claims["sub"])))
    except (jwt.PyJWTError, ValueError, TypeError):
        raise unauthorized()
    if user is None or not user.is_active or claims["iat"] < int(user.tokens_valid_after.timestamp()):
        raise unauthorized()
    return user

async def require_club_member(user: Annotated[User, Depends(get_current_user)]) -> User:
    if user.club_id is None:
        raise HTTPException(403, "forbidden")
    return user

async def require_coach(user: Annotated[User, Depends(require_club_member)]) -> User:
    if user.role != Role.COACH:
        raise HTTPException(403, "forbidden")
    return user
