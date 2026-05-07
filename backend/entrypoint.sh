#!/bin/sh
# Container bootstrap. Server still consumes file-based credentials only.
# When FIREBASE_CREDENTIALS_B64 is provided (e.g. on hosts without a native
# secret-file mount), decode it to GOOGLE_APPLICATION_CREDENTIALS at startup.
# Locally / when a real file is mounted, this block is a no-op.
set -eu

if [ -n "${FIREBASE_CREDENTIALS_B64:-}" ]; then
  : "${GOOGLE_APPLICATION_CREDENTIALS:=/tmp/firebase-admin.json}"
  export GOOGLE_APPLICATION_CREDENTIALS
  printf '%s' "$FIREBASE_CREDENTIALS_B64" | base64 -d > "$GOOGLE_APPLICATION_CREDENTIALS"
  chmod 600 "$GOOGLE_APPLICATION_CREDENTIALS" 2>/dev/null || true
fi

exec /app/server
