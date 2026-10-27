# PostgreSQL backend

FastAPI backend for the Sick of Football Flutter application. Persistence is
PostgreSQL 16 through SQLAlchemy 2 async and asyncpg. Alembic owns the schema;
the application never falls back to in-memory persistence.

## Requirements

- Python 3.11+
- PostgreSQL 16 (or `docker compose up db`)
- Python 3.12+

## Run locally

From `backend`:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
# Fill DATABASE_URL, SICK_OF_FOOTBALL_JWT_SECRET and
# SICK_OF_FOOTBALL_DATA_ENCRYPTION_KEYS with generated values.
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Access tokens are short-lived JWTs without role or club claims. Refresh tokens
are opaque, hashed at rest, rotated on every use, and reuse revokes their
entire family. Integration tests require `DATABASE_URL` and are skipped when
PostgreSQL is unavailable.

The API documentation is available at http://127.0.0.1:8000/docs.

The versioned API is exposed below `/api/v1`. The previous `/api` endpoints
remain available for compatibility with the current Flutter client.

## Test accounts

| Email | Password | Role |
| --- | --- | --- |
| `admin` | `admin` | coach |
| `player@example.com` | `password123` | player |

## Main endpoints

- `GET /api/v1/health`
- `POST /api/v1/auth/register-coach`
- `POST /api/v1/auth/register-player`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/users/me`
- `GET /api/v1/club`
- `GET /api/v1/events`
- `PUT /api/v1/events/{event_id}/availability`
- `GET /api/v1/medical-reports` (coach only)
- `GET /api/v1/tactics`
- `POST /api/v1/devices`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `GET /api/auth/me`
- `GET /api/events`
- `POST /api/events` (coach only)
- `POST /api/events/{event_id}/attendance` (player only)
- `GET /api/team/members`
- `GET /api/tactics`
- `POST /api/tactics` (coach only)
- `PUT /api/tactics/{tactic_id}` (coach only)
- `GET /api/medical-reports` (coach only)

Protected endpoints require `Authorization: Bearer <access_token>`.
