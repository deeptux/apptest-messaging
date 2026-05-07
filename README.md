# apptest-messaging (MVP monorepo)

Phase 1 delivers a **skeleton**: local Postgres + Redis (Docker), Go **Gin** API with Firebase ID token auth, **Flutter** client with Google sign-in, **Riverpod**, and **Drift** (local profile cache). WebSockets, chat, E2EE, Drive, and FCM are **later phases** (see repo root `DEV_PROGRESS.md`).

## Prerequisites

- [Go](https://go.dev/dl/) **1.22+**
- [Flutter](https://docs.flutter.dev/get-started/install) (stable channel)
- [Docker](https://docs.docker.com/get-docker/) + Docker Compose v2
- [golang-migrate](https://github.com/golang-migrate/migrate) CLI (`migrate` command)

## Repository layout

| Path | Purpose |
|------|---------|
| `backend/` | Go Gin API (`cmd/server`, `internal/...`) |
| `frontend/` | Flutter app |
| `docker-compose.yml` | Local Postgres 16 + Redis 7 |
| `.env.example` | Environment variable template (copy to `.env`) |

**Go module path:** `github.com/apptest-messaging/backend` — replace with your real module path before publishing if needed (documented in `backend/README.md`).

## Environment variables

Copy `.env.example` to `.env` in the **repo root** (used when running from root) or set the same variables in your shell / Railway.

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT` | No | HTTP listen port (default **8080**). **Railway** sets this automatically. |
| `DATABASE_URL` | Yes | Postgres URL, e.g. `postgres://app:app@localhost:5433/app?sslmode=disable` for local Docker (port **5433** avoids a local Postgres on 5432). |
| `REDIS_URL` | Yes | Redis URL, e.g. `redis://localhost:6379/0` locally; **Upstash** `rediss://...` in production (same variable name). |
| `CORS_ALLOWED_ORIGINS` | Yes\* | Comma-separated **exact** origins (no spaces). Browser clients must send `Origin` that matches one entry. Example for Flutter web: `http://localhost:7357,http://127.0.0.1:7357`. Mobile apps often omit `Origin`; those requests are not blocked by CORS. \*Set before testing Flutter web against the API. |
| `GOOGLE_APPLICATION_CREDENTIALS` | Yes (API) | Filesystem path to Firebase **service account** JSON (server only). Never commit this file. |

No secrets belong in git. Use `.gitignore`d `.env` and local JSON paths only.

### Supabase / `DATABASE_URL` and migrations

Production may use **Supabase**. The **transaction pooler** (port 6543) can break DDL or session features used by some tools. For **`migrate`****, prefer the **direct** (session) connection string from the Supabase dashboard when applying migrations, then point the running app at the pooler if you choose—documented in Supabase docs. Local Docker uses a single URL for both.

## Local development — exact commands

### 1) Start Postgres and Redis

```bash
docker compose up -d
```

Wait until `docker compose ps` shows `healthy` for both services.

Start/Stop/Reset/Verify

### 2) Run database migrations

From the **`backend/`** directory (install `migrate` first — see [golang-migrate](https://github.com/golang-migrate/migrate/tree/master/cmd/migrate)):

```bash
cd backend
set DATABASE_URL=postgres://app:app@localhost:5433/app?sslmode=disable
migrate -path ./migrations -database "%DATABASE_URL%" up
```

PowerShell:

```powershell
cd backend
$env:DATABASE_URL = "postgres://app:app@localhost:5433/app?sslmode=disable"
migrate -path ./migrations -database $env:DATABASE_URL up
```

### 3) Run the API

```bash
cd backend
set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\your-service-account.json
set DATABASE_URL=postgres://app:app@localhost:5433/app?sslmode=disable
set REDIS_URL=redis://localhost:6379/0
set CORS_ALLOWED_ORIGINS=http://localhost:7357,http://127.0.0.1:7357
go run ./cmd/server
```

Defaults: `PORT=8080` if unset.

### 4) Quick API checks (curl)

```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
curl -i http://localhost:8080/api/v1/me
```

Expect `401` for `/api/v1/me` without `Authorization: Bearer <Firebase ID token>`.

### 5) Run Flutter

From **`frontend/`** (requires Flutter SDK + `flutterfire configure` — see Firebase section):

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port=59392 \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=GOOGLE_OAUTH_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

`GOOGLE_OAUTH_WEB_CLIENT_ID` is the OAuth 2.0 **Web client** ID from Google Cloud Console → Credentials (required for **`google_sign_in` on web**). Alternatively add the `<meta name="google-signin-client_id" …>` tag in `frontend/web/index.html` — see `frontend/README.md`.

If `flutter pub get` reports missing platform folders, run `flutter create . --platforms=android,ios,web` once inside `frontend/` (review diffs before committing).

For **Android emulator**, use your host machine IP or `10.0.2.2` instead of `localhost`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## Firebase + Flutter (human-assisted)

1. Create a **Firebase** project; enable **Authentication** → **Google** sign-in.
2. Register **Android**, **iOS**, and **Web** apps in the Firebase console.
3. Install [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) and run from `frontend/`:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   **Windows:** If `flutterfire` is not recognized, Pub installs the executable under `%LOCALAPPDATA%\Pub\Cache\bin`, which is often **not** on `PATH`. Either add that folder to your user **PATH** and open a new terminal, or run:

   ```bash
   dart pub global run flutterfire_cli:flutterfire configure
   ```

   Commit generated **`lib/firebase_options.dart`** (and platform files per FlutterFire output) — these are **not** server secrets.

4. **Android:** set `minSdkVersion` per current `firebase_auth` / `google_sign_in` docs (FlutterFire usually updates `android/app/build.gradle`).
5. **iOS:** add URL schemes / reversed client ID if `google_sign_in` requires it (see package README).
6. **Web:** add authorized domains (e.g. `localhost`, production host) in Firebase console.

**Backend:** In Firebase console → Project settings → Service accounts → **Generate new private key**. Save JSON locally; set `GOOGLE_APPLICATION_CREDENTIALS` to its path. **Do not** commit the JSON.

## Testing `GET /api/v1/me` with a real token

Do **not** add a debug token endpoint to the server. Recommended:

1. Run the Flutter app, sign in with Google, and temporarily log the ID token in debug mode (remove before shipping), **or**
2. Use a **local-only** script (not committed) that uses your own refresh token — high risk; prefer Flutter.

Minimum: follow the Flutter flow above; the app calls `/api/v1/me` with `Authorization: Bearer <idToken>`.

## Deploy backend to Railway (step-by-step)

This runbook assumes you already have **Supabase** (Postgres), **Upstash** (Redis), **Firebase** (same project as Flutter), and a **Railway** account.

### 1) Accounts and prerequisites

| Service | What you need |
|---------|----------------|
| **Railway** | Project + new service from this GitHub repo |
| **Supabase** | Project; copy **Postgres** connection strings |
| **Upstash** | Redis database; copy **TLS** URL (`rediss://…`) |
| **Firebase** | Project; ability to download **Admin SDK** JSON (service account) |

Build entrypoint: [`backend/Dockerfile`](backend/Dockerfile) (multi-stage Go build). In Railway, either set the service **root directory** to `backend/` or point the Docker build at `backend/Dockerfile` with repo root as context (see Railway UI).

### 2) Obtain `DATABASE_URL` (Supabase)

1. In Supabase → **Project Settings** → **Database**, copy a Postgres URL.
2. **Migrations (`migrate up`):** use the **direct / session** connection string (often port **5432**). The **transaction pooler** (often **6543**) can fail DDL used by `golang-migrate`.
3. **Running app:** you may use the pooler for runtime if you prefer; many teams use one URL for both to start—if `migrate` fails, switch `migrate` to the session URL only.

Example shape (values are yours, not copy-paste):

```text
postgres://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres?sslmode=require
```

Set this as Railway variable **`DATABASE_URL`**.

### 3) Obtain `REDIS_URL` (Upstash)

1. In Upstash → your Redis → **Connect** → choose **TLS** URL.
2. It should start with **`rediss://`** (note the extra **`s`**). The Go client and this app expect that for TLS.

Set as Railway variable **`REDIS_URL`** (same name as local).

### 4) Firebase Admin JSON (never commit)

1. Firebase Console → **Project settings** → **Service accounts** → **Generate new private key**.
2. Save the `.json` locally only; **do not** commit it.

### 5) Railway environment variables

Set these in the Railway service (**Variables** tab):

| Variable | Example / notes |
|----------|------------------|
| `DATABASE_URL` | Supabase Postgres URL (`sslmode=require` as required) |
| `REDIS_URL` | Upstash `rediss://default:...@...upstash.io:6379` |
| `CORS_ALLOWED_ORIGINS` | Comma-separated **exact** origins, **no spaces**. Include your **production** Flutter web origin when known, e.g. `https://your-app.web.app` (see also **Production CORS** below). |
| `GOOGLE_APPLICATION_CREDENTIALS` | **In-container path** to the mounted Admin JSON (next step), e.g. `/secrets/firebase-admin.json` |
| `PORT` | **Do not set manually** — Railway injects `PORT`; the server listens on it. |

### 6) Mount the Admin JSON as a Railway secret file

Railway can mount a file at a fixed path so `GOOGLE_APPLICATION_CREDENTIALS` matches a real path inside the container.

1. In Railway → your service → **Variables** (or **Settings** → secrets/files, depending on UI), add the JSON as a **secret file**.
2. Note the **mount path** Railway shows (e.g. `/secrets/firebase-admin.json`).
3. Set **`GOOGLE_APPLICATION_CREDENTIALS`** to that **exact** path.

If the path is wrong, Firebase Admin will fail at startup or on first token verify.

### 7) Run migrations against production (before or after first deploy)

From your machine (with `migrate` installed), use the **session/direct** Supabase URL:

```powershell
cd backend
$env:DATABASE_URL = "<SUPABASE_SESSION_POSTGRES_URL>"
migrate -path ./migrations -database $env:DATABASE_URL up
```

### 8) Verification checklist (after deploy)

Replace `<railway-host>` with your public Railway URL (no trailing slash).

```bash
curl -sS https://<railway-host>/healthz
curl -sS https://<railway-host>/readyz
curl -i https://<railway-host>/api/v1/me
```

- **`/healthz`:** `200` JSON `{"status":"ok"}` (no DB/Redis required).
- **`/readyz`:** `200` only if Postgres + Redis reachable; `503` if degraded (check env vars and URLs).
- **`/api/v1/me`:** `401` without `Authorization: Bearer <Firebase ID token>` is expected.

Then run **Flutter** (web or mobile) with `--dart-define=API_BASE_URL=https://<railway-host>` and complete Google sign-in; confirm profile loads from `/api/v1/me`.

### 9) Troubleshooting (Railway)

| Symptom | Things to check |
|---------|------------------|
| App won’t bind / wrong port | Ensure you did **not** override `PORT`; server must listen on Railway’s `PORT`. |
| `password authentication failed` / DB errors | Wrong `DATABASE_URL`, typo in password, or using pooler URL for migrations. |
| Redis connection errors | `REDIS_URL` must be Upstash **`rediss://`** TLS URL; region / token correct. |
| Firebase / token verify errors | `GOOGLE_APPLICATION_CREDENTIALS` path must match **mounted** file; JSON must be for the **same** Firebase project as the client. |
| CORS errors from browser | `CORS_ALLOWED_ORIGINS` must include the **exact** `Origin` the browser sends (scheme + host + port). No `*`. |

See [`backend/README.md`](backend/README.md) for backend-focused notes and Redis session verification locally.

## Production CORS for Firebase Hosting

Browser requests from Flutter web include an **`Origin`** header. The API allowlists origins via **`CORS_ALLOWED_ORIGINS`** (comma-separated, **no spaces**). Entries must match **exactly** — scheme (`http` vs `https`), host, and port.

- **Do not** use `*` in production.
- **Do not** rely on wildcards; list each origin you serve (e.g. `https://<project-id>.web.app`).

**Development (local Flutter web):** use a **fixed** dev port and list both localhost forms if needed:

```text
CORS_ALLOWED_ORIGINS=http://localhost:59392,http://127.0.0.1:59392
```

**Production (Firebase Hosting):** set the deployed site origin(s) only, for example:

```text
CORS_ALLOWED_ORIGINS=https://<project-id>.web.app
```

If you add a **custom domain** in Firebase Hosting, append it as another comma-separated entry (same rules).

After changing Railway env vars, **redeploy** or restart the service so the new allowlist is picked up.

## Production / integration troubleshooting

Use this checklist when the hosted Flutter web app talks to the Railway API.

| Symptom | What to verify |
|---------|----------------|
| Browser **CORS** error (`Access-Control-Allow-Origin`, blocked by CORS policy) | `CORS_ALLOWED_ORIGINS` on Railway includes the **exact** `Origin` (https + host, no trailing slash). No `*`. Dev vs prod origins differ — update both sides when you change ports or hosts. |
| **`/readyz` returns 503** | `DATABASE_URL` correct for Supabase; `REDIS_URL` is Upstash **`rediss://`**; secrets mounted; outbound network from Railway OK. |
| **Google sign-in fails on the hosted site** | Firebase Console → Authentication → **Authorized domains** includes your Hosting domain; **OAuth Web client ID** used in `flutter build web` (or `web/index.html` meta) matches Google Cloud; [People API](https://console.cloud.google.com/apis/library/people.googleapis.com) enabled if you saw `people.googleapis.com` errors. |
| **`origin_mismatch` (OAuth)** | Google Cloud OAuth **Authorized JavaScript origins** must list your Hosting URL (and dev URL + port if testing locally). |
| **401 on `/api/v1/me` after sign-in** | API URL in `--dart-define=API_BASE_URL` matches Railway; Firebase project matches Admin SDK JSON on the server; clock skew unusual but possible. |

## Redis session cache (Phase 1)

After a successful `/api/v1/me` request, the server sets:

- **Key:** `session:user:{firebaseUid}`
- **Value:** JSON (camelCase): `userId`, `email`, `displayName`, `lastVerifiedAt` (RFC3339)
- **TTL:** 86400 seconds; refreshed on each successful authenticated `/api/v1/me`.

## Out of scope (Phase 1)

WebSockets, chat messages, Signal/E2EE, Google Drive uploads, FCM, typing/presence, and pagination are **not** implemented here. See `DEV_PROGRESS.md` for phase 2+.

## Rate limiting

Not implemented in Phase 1; consider IP or token bucket limits for `/api/v1/me` in a later iteration.