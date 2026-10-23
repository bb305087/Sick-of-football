"""Security primitives shared by the API.

Refresh tokens are deliberately opaque and are only stored as SHA-256 digests.
"""

import asyncio
import hashlib
import secrets
from typing import Final

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

_hasher = PasswordHasher()
DUMMY_HASH: Final[str] = _hasher.hash("sick-of-football-dummy-password")
_COMMON_PASSWORDS = {
    "password", "password123", "password1234", "qwerty", "qwerty123",
    "letmein", "welcome", "admin", "admin123", "123456789012",
}


async def hash_password(password: str) -> str:
    return await asyncio.to_thread(_hasher.hash, password)


async def verify_password(password_hash: str, password: str) -> bool:
    try:
        return await asyncio.to_thread(_hasher.verify, password_hash, password)
    except (VerificationError, InvalidHashError):
        return False


def needs_rehash(password_hash: str) -> bool:
    return _hasher.check_needs_rehash(password_hash)


def sha256_hex(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def new_opaque_token() -> tuple[str, str]:
    raw = secrets.token_urlsafe(48)
    return raw, sha256_hex(raw)


def validate_password_strength(password: str, email: str, full_name: str) -> None:
    """Raise ValueError for passwords which are unsafe to accept."""
    if not 12 <= len(password) <= 128:
        raise ValueError("password must contain 12 to 128 characters")
    if password.casefold() in _COMMON_PASSWORDS:
        raise ValueError("password is too common")
    lowered = password.casefold()
    local = email.split("@", 1)[0].casefold()
    name_parts = [part.casefold() for part in full_name.split() if len(part) >= 3]
    if (local and local in lowered) or any(part in lowered for part in name_parts):
        raise ValueError("password contains personal information")
    classes = sum(
        bool(any(predicate(char) for char in password))
        for predicate in (
            str.islower,
            str.isupper,
            str.isdigit,
            lambda char: not char.isalnum(),
        )
    )
    if len(password) < 16 and classes < 3:
        raise ValueError("password is too weak")
