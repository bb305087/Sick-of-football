import os
from uuid import uuid4

import pytest

if not os.getenv("DATABASE_URL"):
    pytest.skip("PostgreSQL integration tests require DATABASE_URL", allow_module_level=True)

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def login(email: str, password: str) -> str:
    response = client.post(
        "/api/auth/login",
        json={"email": email, "password": password},
    )
    assert response.status_code == 200
    return response.json()["access_token"]


def test_health_endpoint() -> None:
    response = client.get("/api/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_login_returns_access_token_and_role() -> None:
    response = client.post(
        "/api/auth/login",
        json={"email": "admin", "password": "admin"},
    )

    assert response.status_code == 200
    assert response.json()["user"]["role"] == "coach"
    assert response.json()["token_type"] == "bearer"


def test_coach_registration_login_and_tactic_creation() -> None:
    email = f"coach-{uuid4().hex}@example.com"
    password = "Secure-Orange-47!"

    registration = client.post(
        "/api/v1/auth/register-coach",
        json={
            "email": email,
            "password": password,
            "full_name": "Test Coach",
            "club_name": "Test Club",
        },
    )

    assert registration.status_code == 201
    assert registration.json()["role"] == "coach"

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )

    assert login_response.status_code == 200
    token = login_response.json()["access_token"]

    tactic = client.post(
        "/api/v1/tactics",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "title": "Test formation",
            "formation": "4-3-3",
            "description": "Test lineup",
            "lineup": [
                {"position": position, "player_id": f"player-{index}"}
                for index, position in enumerate(
                    ["GK", "LB", "CB", "CB", "RB", "CM", "CM", "CM", "LW", "ST", "RW"]
                )
            ] + [
                {"position": "SUB", "player_id": "player-11", "substitute": True}
            ],
        },
    )

    assert tactic.status_code == 201
    assert tactic.json()["lineup"][0]["player_id"] == "player-0"

    listed_tactics = client.get(
        "/api/v1/tactics",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert listed_tactics.status_code == 200
    assert listed_tactics.json()["items"][0]["lineup"][0]["player_id"] == "player-0"
    assert listed_tactics.json()["items"][0]["lineup"][-1] == {
        "position": "SUB",
        "player_id": "player-11",
        "substitute": True,
    }


def test_refresh_token_returns_new_access_token() -> None:
    response = client.post(
        "/api/auth/login",
        json={"email": "admin", "password": "admin"},
    )

    refresh_response = client.post(
        "/api/auth/refresh",
        json={"refresh_token": response.json()["refresh_token"]},
    )

    assert refresh_response.status_code == 200
    assert refresh_response.json()["token_type"] == "bearer"
    assert refresh_response.json()["access_token"]


def test_player_cannot_read_medical_reports() -> None:
    token = login("player@example.com", "password123")

    response = client.get(
        "/api/medical-reports",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 403


def test_coach_can_read_medical_reports() -> None:
    token = login("admin", "admin")

    response = client.get(
        "/api/medical-reports",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    assert response.json()[0]["reason"] == "Kontuzja kolana"


def test_coach_sees_at_least_eleven_seeded_players() -> None:
    token = login("admin", "admin")

    response = client.get(
        "/api/team/members",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    players = [member for member in response.json() if member["role"] == "player"]
    assert len(players) >= 11
    assert any(member["name"] == "Jan Kowalski" for member in players)


def test_player_sees_only_published_tactics() -> None:
    token = login("player@example.com", "password123")

    response = client.get(
        "/api/tactics",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    assert all(tactic["published"] for tactic in response.json())
