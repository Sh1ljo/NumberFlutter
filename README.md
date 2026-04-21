# NumberFlutter

Incremental number game built with Flutter.

## Supabase Setup

1. In Supabase SQL Editor, run `supabase/schema.sql`.
2. Create OAuth providers in Supabase Auth (Google and Apple), plus email/password.
3. Rotate any exposed secret/service keys and keep them out of the app codebase.

### Configure the app (choose one)

**Option A — `assets/.env` (default, plain `flutter run`)**

1. Copy `.env.example` to `assets/.env` (or edit the committed `assets/.env` stub).
2. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` from **Project Settings → API** (use the **anon** key only).
3. **Google / Apple sign-in:** add these to **Supabase → Authentication → URL Configuration → Redirect URLs** (add both so trailing slashes never break the flow):
   - `com.example.number_flutter://login-callback`
   - `com.example.number_flutter://login-callback/`
4. **Google Cloud (OAuth client used by Supabase):** under **Credentials → your Web client → Authorized redirect URIs**, include Supabase's callback (copy from **Supabase → Authentication → Providers → Google**), usually:
   - `https://<YOUR_PROJECT_REF>.supabase.co/auth/v1/callback`
5. Rebuild the app after changing Android deep links (`flutter run` or a clean build).

If Google opens in the browser but then shows **"This site can't be reached"**, the browser failed to hand off the custom URL to the app. The project sets `flutter_deeplinking_enabled` to `false` so `app_links` (used by `supabase_flutter`) can receive the OAuth return URL; `MainActivity` uses `singleTask` and `onNewIntent` for a reliable return on Android.
6. Optional: set `SUPABASE_OAUTH_REDIRECT_URL` in `assets/.env` only if you use a custom redirect; otherwise the default above is used.

### Google Sign-In on Android (native, no browser)

The app uses the native **Google Sign-In** SDK on Android/iOS via `google_sign_in` and hands the resulting ID token to Supabase with `signInWithIdToken`. This avoids browser redirects, custom URL schemes, and Supabase's redirect allow list entirely. You **must** complete these one-time Google Cloud steps or sign-in will fail with "No ID token returned by Google":

1. **Web application client ID (already exists).**
   In Google Cloud Console → **APIs & Services → Credentials**, find the **Web application** OAuth 2.0 client you already created for Supabase (Authorized redirect URI `https://<ref>.supabase.co/auth/v1/callback`). Copy its Client ID and put it in `assets/.env` as `GOOGLE_WEB_CLIENT_ID=...`.

2. **Android OAuth client — REQUIRED.**
   Still in **Credentials**, click **+ CREATE CREDENTIALS → OAuth client ID → Android**.
   - **Package name:** `com.example.number_flutter`
   - **SHA-1 certificate fingerprint:** your debug keystore's SHA-1. Get it with either:

     ```powershell
     # From repo root, Windows PowerShell (easiest):
     cd android
     .\gradlew signingReport
     ```

     In the output, find the block where `Variant: debug` and `Config: debug`, then copy the `SHA1:` value (looks like `AA:BB:CC:...`).

     Or directly with keytool:

     ```powershell
     keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
     ```

   Click **Create**. You don't need to copy this client ID anywhere — Google Play Services looks it up automatically by matching your app's package name and signing fingerprint at runtime.

3. **Supabase → Authentication → Providers → Google.**
   Make sure the **Web application Client ID** from step 1 is in the **Client IDs** field (comma-separated list). The **Client Secret** must also be set (from the Web client). The toggle must be **enabled**. Save.

4. **Rebuild.** After changing `assets/.env` or adding the Android client:

   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

5. **Release builds** use a different keystore, so you must add a second SHA-1 to the Android OAuth client (or create a separate one) for the Play Store upload/release certificate.

### Troubleshooting

**"Account created, check your email" but no email arrives**

Supabase's default shared SMTP service is limited to roughly 2 emails/hour and frequently fails to deliver (especially to Gmail / Outlook). You have two options:

- **Easiest (recommended for development):** disable email confirmation.
  Supabase dashboard → **Authentication → Providers → Email** → turn off **"Confirm email"** → save. New signups will be logged in instantly with no email required.
- **Production-ready:** configure your own SMTP provider.
  Supabase dashboard → **Authentication → Emails → SMTP Settings** → enable custom SMTP and fill in credentials from Resend / Postmark / SendGrid / Mailgun / etc. Then re-send or retry signup.

**Google Sign-In errors on Android**

- `PlatformException(sign_in_failed, ..., ApiException: 10)` — Android OAuth client doesn't exist for this package+SHA-1 combination. Re-check step 2 above; the SHA-1 must match the keystore that signed the APK you're running (debug vs release).
- `No ID token returned by Google` — you forgot to set `GOOGLE_WEB_CLIENT_ID` or used the Android client ID instead of the Web client ID. Must be the **Web application** client.
- Invalid ID token / audience mismatch in Supabase logs — the `GOOGLE_WEB_CLIENT_ID` in `.env` and the **Client IDs** list in Supabase → Google provider don't match. They should be the same Web client.
- Google opens then immediately closes with no sign-in — device has no Google account, or Play Services is out of date. Add a Google account in Settings and update Play Services from the Play Store.

**Google Sign-In on other platforms**

- **Web / desktop**: the app automatically falls back to the browser OAuth flow. For web, make sure `http://localhost:PORT` is listed in **Supabase → Authentication → URL Configuration**.
- **Windows / macOS / Linux desktop**: native Google Sign-In is not supported by `google_sign_in`; use email/password for desktop testing.

**Option B — compile-time defines (CI / no env file)**

```bash
flutter run \
  --dart-define=SUPABASE_PROJECT_ID=your-project-id \
  --dart-define=SUPABASE_URL=https://your-project-id.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=SUPABASE_OAUTH_REDIRECT_URL=com.example.number_flutter://login-callback
```

Values in `assets/.env` override empty `--dart-define` entries when both are present.

Do not place `sb_secret` or service-role keys inside Flutter client code.

## Data Ownership

- Apple App Store and Google Play distribute the app.
- User progression, accounts, and leaderboard data are stored in Supabase.
- Local `SharedPreferences` remains as offline cache and migration source.

## Offline-first account (optional)

- You can play without signing in; progress is saved locally.
- Sign in from **System** when you want cloud backup, cross-device sync, and the global leaderboard.
- On first sign-in, local progress is merged with the cloud using the same “highest progression wins” rule as returning users.
