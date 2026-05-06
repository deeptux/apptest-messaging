# Frontend (Flutter)

Phase 1: Google sign-in via **Firebase Auth**, Riverpod state, **Drift** local cache of `/api/v1/me`, **Dio** HTTP client.

## One-time setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (stable).
2. From this directory:

   ```bash
   flutter pub get
   ```

   If you change the Drift table in `lib/core/database/app_database.dart`, run
   `dart run build_runner build --delete-conflicting-outputs` to refresh
   `app_database.g.dart` (the repo ships a generated file for convenience).

   **Web (Chrome):** Drift uses the deprecated-but-practical `WebDatabase` (sql.js).
   `web/index.html` includes the sql.js script so `flutter run -d chrome` can compile
   without `dart:ffi`. Native Android/iOS/desktop still use `drift/native.dart` via
   conditional imports (`opened_db_*.dart`, `sqlite_init_*.dart`).

   **Web: Google Sign-In client ID:** `google_sign_in_web` needs your OAuth 2.0 **Web client**
   ID (`….apps.googleusercontent.com`). It is **not** the same field as `FirebaseOptions.apiKey`.
   Find it: **Google Cloud Console** → APIs & Services → **Credentials** → OAuth 2.0 Client IDs
   → type **Web application** (often auto-created for your Firebase project).

   - **Option A (CLI):** pass at compile time (recommended for clones who don’t edit HTML):

     ```bash
     flutter run -d chrome --web-port=59392 \
       --dart-define=API_BASE_URL=http://localhost:8080 \
       --dart-define=GOOGLE_OAUTH_WEB_CLIENT_ID=YOUR_ID.apps.googleusercontent.com
     ```

   - **Option B (HTML):** uncomment and fill the `<meta name="google-signin-client_id" … />`
     line in `web/index.html` (see comment there). If the meta tag is set, you can omit the
     `GOOGLE_OAUTH_WEB_CLIENT_ID` define.

3. **Configure Firebase for this Flutter app (`flutterfire configure`)**

   Your Flutter code calls `Firebase.initializeApp(options: …)`. Those options
   (project id, API keys, Android/iOS/Web app ids, etc.) must match a real
   **Firebase project**. The **FlutterFire CLI** reads your Firebase/Google
   login, lists your Firebase projects, and **writes generated Dart + platform
   files** so the app can compile and talk to *your* Firebase.

   **What it replaces:** Until you run this, the repo may ship a small **stub**
   `lib/firebase_options.dart` that throws at startup with a clear message.
   After a successful configure, that file is **replaced** by the real one.

   **What you run (from this `frontend/` folder):**

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   **Windows:** If `flutterfire` is not found, add `%LOCALAPPDATA%\Pub\Cache\bin` to your user **PATH** (new terminal), or use:

   ```bash
   dart pub global run flutterfire_cli:flutterfire configure
   ```

   The wizard will ask you to pick the Firebase project and which platforms
   (Android, iOS, web, …) to include. It typically creates/updates:

   - `lib/firebase_options.dart` — `DefaultFirebaseOptions` for `Firebase.initializeApp`
   - Android: e.g. `android/app/google-services.json` (from Firebase)
   - iOS/macOS: e.g. `ios/Runner/GoogleService-Info.plist`
   - Web: may update `web/index.html` / related config as the tool requires

   **Commit policy:** Commit the generated **non-secret** config files the CLI
   adds (they are normal for FlutterFire). Do **not** commit Firebase **Admin**
   service account JSON (that stays on the **Go server** only).

4. Follow Firebase Console steps in the repo root `README.md` (Android / iOS / Web apps, Google sign-in, authorized domains).

5. Run against local API (adjust host for Android emulator: `http://10.0.2.2:8080`):

   ```bash
   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
   ```

## API base URL

Set `API_BASE_URL` via `--dart-define` (see above). No default is baked in: missing define shows an error at startup.

## Phase 1 limitations

- Firebase **ID token** is kept **in memory** only (Riverpod). It is cleared on app restart until the user signs in again.
- Until `flutterfire configure` is run, `firebase_options.dart` may be a **stub**
  that throws at startup; replace it by running the CLI (see step 3).
