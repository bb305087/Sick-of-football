# PostgreSQL backend

FastAPI backend for the Sick of Football Flutter application. Persistence is
PostgreSQL 16 through SQLAlchemy 2 async and asyncpg. Alembic owns the schema;
the application never falls back to in-memory persistence.

## Requirements

- Docker Desktop with Docker Compose
- Python 3.12+ only when running the API outside Docker

## Run API and PostgreSQL in Docker

From the repository root, create the local environment file:

```powershell
cd backend
Copy-Item .env.example .env
```

Generate the two application secrets:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
python -c "import secrets,base64,json; print(json.dumps({'1': base64.b64encode(secrets.token_bytes(32)).decode()}))"
```

Put the first result in `SICK_OF_FOOTBALL_JWT_SECRET` and the second in
`SICK_OF_FOOTBALL_DATA_ENCRYPTION_KEYS` in `.env`. Keep `.env` local; never
commit it.

`SICK_OF_FOOTBALL_DATA_ENCRYPTION_KEYS` must be a JSON object, not the raw
Base64 value. If `.env` already contains a raw Base64 key, convert it in
PowerShell without printing the secret:

```powershell
$path = ".env"
$lines = Get-Content $path
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -like "SICK_OF_FOOTBALL_DATA_ENCRYPTION_KEYS=*") {
    $raw = $lines[$i].Split("=", 2)[1]
    $lines[$i] = "SICK_OF_FOOTBALL_DATA_ENCRYPTION_KEYS={`"1`":`"$raw`"}"
  }
}
Set-Content $path $lines
```

Start the database and API:

```powershell
docker compose up --build -d
docker compose ps
docker compose logs -f api
```

The API is available at `http://127.0.0.1:8000`. Check the database-backed
health endpoint and open Swagger UI:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/api/health
Start-Process http://127.0.0.1:8000/docs
```

The API container runs Alembic as `sof_migrator`, then runs the demo seed and
the application as the restricted `sof_app` user.

Stop containers while preserving data:

```powershell
docker compose down
```

Remove containers and the local PostgreSQL volume (deletes all local data):

```powershell
docker compose down -v
```

## Tests

Run the API tests against the PostgreSQL service:

```powershell
docker compose exec api pytest -q
```

## Run FastAPI on the host

Docker can run only PostgreSQL while FastAPI runs from a Python virtual
environment:

```powershell
cd backend
docker compose up -d db
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
```

Change `DATABASE_URL` in `.env` from the Compose hostname `db` to `localhost`,
then run:

```powershell
alembic upgrade head
python scripts/seed.py
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Demo accounts

| Email | Password | Role |
| --- | --- | --- |
| `admin` | `admin` | coach |
| `player@example.com` | `password123` | player |

## API

Documentation: `http://127.0.0.1:8000/docs`

Main endpoints include:

- `GET /api/health`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `GET /api/auth/me`
- `GET /api/events`
- `POST /api/events` (coach only)
- `GET /api/team/members`
- `GET /api/tactics`
- `POST /api/tactics` (coach only)
- `GET /api/medical-reports` (coach only)

Chronione endpointy wymagaja naglowka `Authorization` z tokenem dostepowym
w schemacie Bearer. Wersjonowane endpointy sa dostepne pod `/api/v1`; trasy
`/api` pozostaja dostepne dla obecnego klienta Flutter.
