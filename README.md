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
flutter run -d chrome \
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

## Railway (high level)

1. Create a Railway service from this repo; set **root directory** to `backend/` **or** use a Dockerfile path `backend/Dockerfile`.
2. Set environment variables in Railway:

   - `DATABASE_URL` (Supabase or other Postgres)
   - `REDIS_URL` (Upstash TLS URL)
   - `GOOGLE_APPLICATION_CREDENTIALS` — prefer mounting the JSON as a **secret file** and set this env to the **in-container path**, **or** bake path in Dockerfile from a build secret (advanced).
   - `CORS_ALLOWED_ORIGINS` — include your future Flutter web origin, e.g. `https://your-app.web.app` (update when known).
   - Railway provides **`PORT`** automatically; the server listens on `PORT`.

3. Build uses [`backend/Dockerfile`](backend/Dockerfile): multi-stage Go build, minimal runtime image.

See [`backend/README.md`](backend/README.md) for backend-specific notes.

## Redis session cache (Phase 1)

After a successful `/api/v1/me` request, the server sets:

- **Key:** `session:user:{firebaseUid}`
- **Value:** JSON (camelCase): `userId`, `email`, `displayName`, `lastVerifiedAt` (RFC3339)
- **TTL:** 86400 seconds; refreshed on each successful authenticated `/api/v1/me`.

## Out of scope (Phase 1)

WebSockets, chat messages, Signal/E2EE, Google Drive uploads, FCM, typing/presence, and pagination are **not** implemented here. See `DEV_PROGRESS.md` for phase 2+.

## Rate limiting

Not implemented in Phase 1; consider IP or token bucket limits for `/api/v1/me` in a later iteration.
