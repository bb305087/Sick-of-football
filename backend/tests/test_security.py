import asyncio

from app.security import hash_password, verify_password


def test_passwords_are_stored_as_argon2id_hashes() -> None:
    password = "Strong-password-for-test-42!"

    password_hash = asyncio.run(hash_password(password))

    assert password_hash.startswith("$argon2id$")
    assert password not in password_hash
    assert asyncio.run(verify_password(password_hash, password))
    assert not asyncio.run(verify_password(password_hash, "wrong-password"))
