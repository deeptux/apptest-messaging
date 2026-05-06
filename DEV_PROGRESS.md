# Agent progress (shared)

This file is the **single shared source of truth** for where the messaging MVP stands.  
**General Inquiry**, **Code Planning**, and **Code Implementation** agents (and humans) should **read it at the start** of a turn and **update it at the end** when work materially changes.

---

## How to use this file

### General Inquiry Agent

- **Before** answering questions about stack, phases, deployment, or “where we are”: read **Current snapshot**, **Active phase**, **Blockers**, and **Recent sessions**.
- **After** the human confirms a decision that affects implementation (e.g. auth provider, static host): you may **append one line** to **Decision log** or ask the human to do so; do not invent repo state—if this file is stale, say so.

### Code Planning Agent

- **Before** planning or generating an Implementation prompt: read this file fully.
- **After** producing a phase plan the human accepts: update **Active phase**, **Planned next actions** (if any), and append **Recent sessions** with date + summary.
- Your charter prompt should include: *“Read `DEV_PROGRESS.md` at repo root first.”*

### Code Implementation Agent

- **Before** coding: read **Active phase**, **Acceptance criteria for active phase**, **Blockers**, and **Repo map** (if filled).
- **After** each implementation session (or logical PR-sized chunk): update **Recent sessions**, **Acceptance criteria** checkboxes if done, **Repo map** if structure changed, **Blockers**, and **Last updated** metadata at the bottom.
- If you discover a spec conflict: add a **Blocker** row instead of guessing.

### Human

- Resolve **Blockers** when they appear.
- Optionally tighten **Decision log** after major choices.

---

## Current snapshot (stack)

| Layer | Choice |
|-------|--------|
| Repo | Monorepo: `/frontend` (Flutter), `/backend` (Go) |
| Client | Flutter; SQLite via **Drift**; **Riverpod** (Phase 1+) |
| API | Go + **Gin** (Phase 1+) + **gorilla/websocket** (later phases) |
| API host | **Railway** + **Serverless (App-Sleeping / wake)** |
| Flutter web | **Firebase Hosting** (Phase 1 deploy baseline; see `frontend/README.md`, `frontend/firebase.json`) |
| Primary DB | **PostgreSQL** via **Supabase** (hosted DB; auth is Firebase—see below) |
| Cache | **Upstash Redis** (prod); **Redis** via Docker Compose locally |
| Local dev | **Docker Compose** (Postgres + Redis) |
| Auth | **Google SSO** via **Firebase Auth** |
| E2EE | **Signal-style protocol** |
| Files | **Google Drive** per user; server permission flow; **server must not read file plaintext bodies** |
| Upload cap | **Redis** daily counter + **max bytes** |
| Push | **FCM** (alongside DB + sockets) |

**Recorded intent:** **Firebase Auth + Supabase-hosted Postgres** is an intentional split: identity from Firebase, relational data in Supabase. Do not switch auth or DB hosting in code without updating this file and the Phase plan.

**Phase 1 implementation lock (Planning 2026-05-04):** **Gin**, **Riverpod**, **Drift**; **Flutter web** hosted on **Firebase Hosting** (P1-S6) — set `CORS_ALLOWED_ORIGINS` (comma-separated exact origins) for localhost (fixed `--web-port`) and production `https://<project-id>.web.app` (see root `README.md`).

---

## Roadmap phases (status)

| Phase | Name | Status | Notes |
|-------|------|--------|-------|
| 1 | Skeleton — monorepo, auth, profiles, Redis sessions, Railway, CORS | `done` | Implemented: Docker Compose, Gin `/healthz` `/readyz` `/api/v1/me`, Firebase Admin + Redis session, Flutter Google sign-in + Drift profile cache, `backend/Dockerfile`. |
| 2 | Nervous system — WS protocol, Postgres messages, SQLite sync, acks | `not_started` | Handoff ready for Code Implementation Agent #2. |
| 3 | Shield — Signal bundles, encrypt on wire | `not_started` | |
| 4 | Vault — Drive, limits, queue, decrypt to SQLite | `not_started` | |
| 5 | Polish — FCM, pagination, typing/presence | `not_started` | |

**Status values:** `not_started` | `in_progress` | `blocked` | `done`

**Active phase:** `2` (next: Nervous system — do not start until Planning prompt accepted)

---

## Acceptance criteria — active phase

_Paste or summarize criteria from the Planning Agent for the phase in progress. Check off as the Implementation Agent completes them._

**Phase 1 — Skeleton (Firebase Auth)** — **COMPLETE**

- [x] Monorepo exists: `frontend/` (Flutter), `backend/` (Go), root `docker-compose.yml` runs Postgres + Redis for local dev.
- [x] Backend: Go module, **Gin** HTTP server, clean layout `cmd/server`, `internal/handlers`, `internal/services`, `internal/repositories`, `internal/redis`, `internal/config`, `internal/middleware`.
- [x] `GET /healthz` returns 200 JSON `{ "status": "ok" }` without DB/Redis.
- [x] `GET /readyz` returns 200 only when Postgres + Redis reachable; otherwise 503 with `{ "status": "degraded", "details": { ... } }`.
- [x] Postgres: migration creates `users` table; repository upserts user on authenticated `/api/v1/me`.
- [x] Auth middleware: `Authorization: Bearer <Firebase ID token>` verified with **Firebase Admin SDK**; credentials via **`GOOGLE_APPLICATION_CREDENTIALS`** (path to service account JSON) — documented in `backend/README.md`.
- [x] `GET /api/v1/me` returns persisted profile JSON **camelCase**; 401 if token missing/invalid.
- [x] Redis: `session:user:{firebaseUid}` JSON (`userId`, `email`, `displayName`, `lastVerifiedAt`) TTL **86400**s, refreshed on each successful `/api/v1/me`.
- [x] CORS: `CORS_ALLOWED_ORIGINS` comma-separated allowlist; rejects disallowed `Origin` for browser requests.
- [x] Railway: `backend/Dockerfile` (multi-stage), listens on **`PORT`**; env vars documented in root `README.md`.
- [x] Flutter: `lib/features/auth/`, `lib/features/profile/`, `lib/core/`; **Riverpod** + **Dio** + **Drift** `local_users`; sync from `/api/v1/me` after login.
- [x] Flutter: Google sign-in via **Firebase Auth** + `google_sign_in`; ID token in memory; calls `/api/v1/me` with Bearer.
- [x] Root `README.md`: runbook, env template (`.env.example`), Firebase / FlutterFire manual steps.

**Phase 2 — (not started)** — criteria TBD by Planning Agent.

---

## Blockers

| ID | Description | Owner |
|----|-------------|--------|
| _None currently_ | Phase 1 local auth + profile smoke path completed; ready to begin Phase 2 planning/implementation. | — |

---

## Decision log

| Date | Decision | By |
|------|----------|-----|
| 2026-05-04 | Phase 1 Implementation: **`GOOGLE_APPLICATION_CREDENTIALS`** only for Firebase Admin (no `FIREBASE_CREDENTIALS_JSON` code path) | Code Implementation Agent |
| 2026-05-04 | Auth: **Google SSO via Firebase Auth**; Postgres remains **Supabase** (pairing locked for MVP) | Human |
| 2026-05-04 | Final stack restated: Drive = per-user storage, caps = Redis + max bytes, E2EE = Signal-style, push = FCM; local Redis in Docker | Human + Code Implementation Agent |
| 2026-05-04 | Stack per ideation doc; API on Railway with App-Sleeping | Human + General Inquiry |
| 2026-05-04 | Phase 1 frameworks: **Gin**, **Riverpod**, **Drift** (Planning prompt to Implementation) | Code Planning |
| 2026-05-05 | Flutter web host locked: **Firebase Hosting** (P1-S6); Railway + Hosting deploy runbooks and prod CORS docs in root / `frontend` READMEs | Code Implementation Agent #1 |

---

## Repo map

_Update paths as the monorepo grows._

| Path | Purpose |
|------|---------|
| `reference/` | Ideation PDFs and supporting docs |
| `reference/CODE_PLANNING_AGENT_CHARTER.md` | Copy-paste Planning Agent charter + repo file usage |
| `DEV_PROGRESS.md` | This file |
| `docker-compose.yml` | Local Postgres 16 + Redis 7 |
| `.env.example` | Env template (copy to `.env`) |
| `README.md` | Monorepo runbook + Railway + Firebase notes |
| `backend/` | Go Gin API (`cmd/server`, `internal/…`, `migrations/`, `Dockerfile`) |
| `frontend/` | Flutter app (`lib/core`, `lib/features`, `web/`) |

---

## Recent sessions

_Append newest first. Each entry: date (ISO), agent role, short summary, optional “files touched”._

| Date | Agent | Summary |
|------|-------|---------|
| 2026-05-05 | Code Implementation Agent #1 | **P1-S6 (ATM-29..31):** Railway step-by-step deploy runbook + verification in root/`backend` READMEs; Firebase Hosting deploy runbook + `firebase.json` hosting (`public`: `build/web`, SPA rewrite); production CORS + troubleshooting in root README; **Current snapshot** locks Flutter web to **Firebase Hosting**. |
| 2026-05-05 | Code Implementation Agent #1 | **Phase 1 local completion confirmed:** FlutterFire config generated (`firebase_options.dart` no longer stub), Google web sign-in fixed for localhost, backend `/api/v1/me` path verified from signed-in Flutter web, Drift cache rendered; Phase 2 handoff prepared for Code Implementation Agent #2. |
| 2026-05-04 | Code Implementation Agent | **Phase 1 Skeleton shipped:** root Compose + `.env.example`; Go Gin `healthz`/`readyz`/`api/v1/me` + Firebase verify + Redis session + CORS; SQL migrations; `backend/Dockerfile`; Flutter Riverpod+Dio+Drift+Google sign-in; README + `AGENT_PROGRESS` sync. |
| 2026-05-04 | Code Planning | Phase 1 Skeleton: copy-paste **Implementation Agent** prompt generated (Firebase Auth, Gin, Riverpod, Drift, Docker, Railway shape, CORS env, Redis session cache, `/healthz` `/readyz` `/api/v1/me`). |
| 2026-05-04 | Code Implementation Agent | Synced **Current snapshot** to recorded final stack: Firebase Auth, Signal-style E2EE, Drive without server plaintext, Redis local+Upstash, caps; added Phase 1 locks (frameworks + static host). |
| 2026-05-04 | General Inquiry | Expanded `reference/CODE_PLANNING_AGENT_CHARTER.md`: repo file paths, read/update rules, Implementation prompt preamble; synced item (10). |
| 2026-05-04 | General Inquiry | Initialized `DEV_PROGRESS.md`; stack table + phase table seeded. |

---

## Prompt boilerplate (optional paste)

**Start of any agent turn:**

```text
Read the repo root file DEV_PROGRESS.md for current phase, blockers, and decisions before proceeding.
```

**End of Implementation Agent turn:**

```text
Update DEV_PROGRESS.md: Recent sessions, phase status, acceptance checkboxes, Repo map, Blockers, Last updated.
```

---

## Metadata (always update when you edit this file)

- **Last updated:** 2026-05-05
- **Last editor:** Code Implementation Agent #1 (P1-S6 deploy docs + Firebase Hosting stack lock)
