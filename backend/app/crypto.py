import os
from uuid import UUID

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


class FieldCipher:
    def __init__(self, keys: dict[int, bytes], active_id: int) -> None:
        if active_id not in keys or any(len(key) != 32 for key in keys.values()):
            raise ValueError("AES-256 keys are required")
        self._keys = keys
        self._active = active_id

    def encrypt(self, plaintext: str, aad: bytes) -> tuple[int, bytes]:
        nonce = os.urandom(12)
        return self._active, nonce + AESGCM(self._keys[self._active]).encrypt(
            nonce, plaintext.encode(), aad
        )

    def decrypt(self, key_id: int, blob: bytes, aad: bytes) -> str:
        if key_id not in self._keys or len(blob) < 28:
            raise ValueError("invalid encrypted field")
        return AESGCM(self._keys[key_id]).decrypt(blob[:12], blob[12:], aad).decode()


def reason_aad(event_id: UUID | int, user_id: UUID | int) -> bytes:
    return f"availability|{event_id}|{user_id}".encode()
