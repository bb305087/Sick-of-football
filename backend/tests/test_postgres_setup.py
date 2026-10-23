from app.main import app


def test_application_is_database_backed() -> None:
    assert app.title == "Sick of Football API"
    assert not hasattr(app, "users")
