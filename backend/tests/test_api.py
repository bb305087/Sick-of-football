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


def test_player_sees_only_published_tactics() -> None:
    token = login("player@example.com", "password123")

    response = client.get(
        "/api/tactics",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    assert all(tactic["published"] for tactic in response.json())
