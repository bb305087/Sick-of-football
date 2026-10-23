# Mock backend

FastAPI backend for the Sick of Football Flutter application. The demo
repository is in-memory for local development; its authentication and data
boundaries mirror the planned PostgreSQL deployment.

## Requirements

- Python 3.11+
- `argon2-cffi` and `cryptography`

## Run locally

From the repository root:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
$env:SICK_OF_FOOTBALL_JWT_SECRET = "use-at-least-32-random-characters"
$env:SICK_OF_FOOTBALL_DATA_KEY = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Never use the development defaults in a deployed environment. Access tokens
are short-lived JWTs without role or club claims. Refresh tokens are opaque,
hashed at rest, rotated on every use, and reuse revokes their entire family.

The API documentation is available at http://127.0.0.1:8000/docs.

## Test accounts

| Email | Password | Role |
| --- | --- | --- |
| `admin` | `admin` | coach |
| `player@example.com` | `password123` | player |

## Main endpoints

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
