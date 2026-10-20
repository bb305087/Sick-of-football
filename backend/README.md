# Mock backend

Development-only FastAPI backend for the Sick of Football Flutter application.
The current implementation uses in-memory data so it can be replaced by a
PostgreSQL repository without changing the API used by the app.

## Requirements

- Python 3.11+

## Run locally

From the repository root:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
$env:SICK_OF_FOOTBALL_JWT_SECRET = "replace-this-for-local-development"
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

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
