# Backend (Go + Gin)

Module: `github.com/apptest-messaging/backend` — replace with your real module path before open-sourcing if needed.

## Run locally

Prerequisites: Go 1.22+, Postgres + Redis (see repo root `docker-compose.yml`), Firebase **service account** JSON, `migrate` CLI.

```powershell
cd backend
$env:DATABASE_URL = "postgres://app:app@localhost:5433/app?sslmode=disable"
$env:REDIS_URL = "redis://localhost:6379/0"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"
$env:CORS_ALLOWED_ORIGINS = "http://localhost:7357,http://127.0.0.1:7357"
migrate -path ./migrations -database $env:DATABASE_URL up
go run ./cmd/server
```

## Migrations

Uses [golang-migrate](https://github.com/golang-migrate/migrate):

```bash
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
```

For **Supabase**, use the **direct (session)** connection string when running `migrate up`; the pooler URL can fail for DDL.

## Firebase credentials (single supported path)

Set **`GOOGLE_APPLICATION_CREDENTIALS`** to the filesystem path of your Firebase Admin service account JSON (same Firebase project as the Flutter app). Do not commit this file.

On **Railway**, mount the JSON as a secret file and set `GOOGLE_APPLICATION_CREDENTIALS` to the in-container path (e.g. `/secrets/firebase.json`).

## HTTP routes

| Method | Path | Auth |
|--------|------|------|
| GET | `/healthz` | No |
| GET | `/readyz` | No |
| GET | `/api/v1/me` | Bearer Firebase ID token |

## Redis session keys

After a successful `/api/v1/me`:

- Key: `session:user:{firebaseUid}`
- TTL: 86400 seconds (refreshed on each successful `/api/v1/me`)

## Docker image

From repo root (or `backend/` as context):

```bash
docker build -f backend/Dockerfile -t apptest-api ./backend
```

The server listens on **`PORT`** (default `8080`). Railway injects `PORT` automatically.
