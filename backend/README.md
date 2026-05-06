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

“This backend only supports file-based Admin credentials via GOOGLE_APPLICATION_CREDENTIALS.”
“We do not support providing the JSON contents in an env var (e.g. FIREBASE_CREDENTIALS_JSON).”
“Create/download it from Firebase Console → Project settings → Service accounts → Generate new private key.”

Set **`GOOGLE_APPLICATION_CREDENTIALS`** to the filesystem path of your Firebase Admin service account JSON (same Firebase project as the Flutter app). Do not commit this file.

On **Railway**, mount the JSON as a secret file and set `GOOGLE_APPLICATION_CREDENTIALS` to the in-container path (e.g. `/secrets/firebase-admin.json`).

## Deploy to Railway (step-by-step summary)

Full narrative is in the repo root [`README.md`](../README.md#deploy-backend-to-railway-step-by-step). Backend operators: use this checklist when wiring the service.

### Prerequisites (copy)

| Item | Where |
|------|--------|
| `DATABASE_URL` | Supabase → Database settings. Use **session/direct** URL for `migrate up`; pooler (6543) may break DDL. |
| `REDIS_URL` | Upstash → **TLS** URL (`rediss://…`). |
| Admin SDK JSON | Firebase Console → Project settings → Service accounts → **Generate new private key**. Never commit. |

### Railway variables (required)

| Variable | Notes |
|----------|--------|
| `DATABASE_URL` | Postgres connection string (production). |
| `REDIS_URL` | Upstash `rediss://` URL. |
| `CORS_ALLOWED_ORIGINS` | Comma-separated exact origins for browser clients (e.g. prod `https://<site>.web.app` when hosting Flutter web). |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path **inside the container** to the mounted JSON, e.g. `/secrets/firebase-admin.json`. |
| `PORT` | Leave unset; Railway sets it. The server listens on `os.Getenv("PORT")` (default `8080` only for local). |

### Secret file mounting (Firebase Admin)

1. In Railway, upload the service account JSON as a **secret file** (not as a pasted multi-line env var—this repo’s server expects a **filesystem path**).
2. Set `GOOGLE_APPLICATION_CREDENTIALS` to Railway’s mount path exactly (case-sensitive).
3. Redeploy after changing the file or path.

### Migrations (production)

Run from a trusted machine (CI or laptop) against the **session** Supabase URL:

```powershell
cd backend
$env:DATABASE_URL = "<SUPABASE_SESSION_POSTGRES_URL>"
migrate -path ./migrations -database $env:DATABASE_URL up
```

### Verification checklist (production)

After the service is live, replace `<host>` with your Railway public hostname:

```bash
curl -sS https://<host>/healthz
curl -sS https://<host>/readyz
curl -i https://<host>/api/v1/me
```

| Endpoint | Expected |
|----------|----------|
| `GET /healthz` | `200`, `{"status":"ok"}` |
| `GET /readyz` | `200` if Postgres + Redis OK; `503` with details if degraded |
| `GET /api/v1/me` | `401` without `Authorization: Bearer` |

Then verify an authenticated call from the Flutter app (`API_BASE_URL=https://<host>`) after Google sign-in.

### Troubleshooting quick reference

| Issue | Likely cause |
|-------|----------------|
| `readyz` 503 | Bad `DATABASE_URL` / network; wrong `REDIS_URL` (non-TLS vs TLS); Redis firewall |
| Token verify errors | Wrong `GOOGLE_APPLICATION_CREDENTIALS` path; JSON for different Firebase project |
| Listen / crash on boot | Overriding `PORT` incorrectly; missing required env |
| Browser CORS failure | `CORS_ALLOWED_ORIGINS` missing the browser’s exact `Origin` |

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

Verify locally (PowerShell, assumes Redis from `docker compose up -d`):

```powershell
# Replace with the firebaseUid returned by /api/v1/me
$uid = "YOUR_FIREBASE_UID"

docker compose exec -T redis redis-cli EXISTS "session:user:$uid"
docker compose exec -T redis redis-cli TTL "session:user:$uid"

# Call /api/v1/me again, then re-check TTL to confirm it refreshed.
docker compose exec -T redis redis-cli TTL "session:user:$uid"
```

## Docker image

From repo root (or `backend/` as context):

```bash
docker build -f backend/Dockerfile -t apptest-api ./backend
```

The server listens on **`PORT`** (default `8080`). Railway injects `PORT` automatically.
