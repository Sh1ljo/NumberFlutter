# NumberFlutter

Incremental number game built with Flutter.

## Firebase Setup

The backend is Firebase: **Auth** for accounts and **Firestore** for profiles, cloud saves and the leaderboard. The Firebase project is `number-65099`. Its app config is generated into `lib/firebase_options.dart`, `android/app/google-services.json` and `firebase.json` by `flutterfire configure`.

1. **Authentication → Sign-in method:** enable **Email/Password** and **Google** (and **Apple** if you ship on iOS).
2. **Firestore Database:** create it in production mode.
3. **Deploy the rules and indexes** from the repo root:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```

   Rules live in `firestore.rules`, and the composite indexes for the country and city leaderboards are in `firestore.indexes.json`.

### Data model

| Collection | Doc ID | Who can read | Contents |
|---|---|---|---|
| `profiles` | uid | any signed-in player | name, country, city, tutorial flag, session stats |
| `profiles/{uid}/sessions` | auto | owner | one doc per archived prestige run |
| `player_progress` | uid | owner | the full cloud save (`PlayerProgress.toDatabase()`) |
| `leaderboard` | uid | any signed-in player | public ranking row, written alongside every cloud save |

Firestore can't sort huge numbers stored as text, so each leaderboard row also stores `highest_number_log10`, which sorts in the same order (see `lib/logic/leaderboard_ranking.dart`). The app computes ranks and caches leaderboard results for 3 minutes to save reads.

### Google Sign-In on Android (native, no browser)

The app uses the native **Google Sign-In** SDK on Android/iOS via `google_sign_in` and hands the resulting ID token to Firebase with `signInWithCredential`. One-time setup:

1. **Web client ID.** Firebase console → **Authentication → Sign-in method → Google → Web SDK configuration**. Copy the **Web client ID** into `assets/.env` as `GOOGLE_WEB_CLIENT_ID=...` (see `.env.example`).
2. **SHA-1 fingerprint.** Get your debug keystore's SHA-1:

   ```powershell
   cd android
   .\gradlew signingReport
   ```

   Copy the `SHA1:` value from the `Variant: debug` block and add it in Firebase console → **Project settings → Your apps → Android app → Add fingerprint**.
3. **Refresh the config** so `google-services.json` includes the new OAuth client, then rebuild:

   ```powershell
   flutterfire configure
   flutter clean
   flutter run
   ```

4. **Release builds** use a different keystore, so add its SHA-1 (and the Play Store app signing SHA-1) too.

### Troubleshooting

**Google Sign-In errors on Android**

- `PlatformException(sign_in_failed, ..., ApiException: 10)` — no SHA-1 is registered for the keystore that signed the APK you're running (debug vs release). Re-check step 2 above.
- `No ID token returned by Google` — `GOOGLE_WEB_CLIENT_ID` is missing or is the Android client ID instead of the Web client ID.
- Google opens then immediately closes with no sign-in — device has no Google account, or Play Services is out of date.

**Other platforms**

- **Web:** Google uses a browser popup.
- **Windows / macOS / Linux desktop:** Firebase has no Google sign-in flow there, so the button is hidden; use email/password.
- **iOS:** Google and Apple sign-in are wired up but untested. Google also needs the iOS OAuth client's reversed client ID added as a URL scheme in `ios/Runner/Info.plist`.

**Compile-time defines (CI / no env file)**

```bash
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=your-web-client-id
```

Values in `assets/.env` override empty `--dart-define` entries when both are present.

## Data Ownership

- Apple App Store and Google Play distribute the app.
- User progression, accounts, and leaderboard data are stored in Firebase (Auth + Firestore).
- Local `SharedPreferences` remains as offline cache and migration source.

## Offline-first account (optional)

- You can play without signing in; progress is saved locally.
- Sign in from **System** when you want cloud backup, cross-device sync, and the global leaderboard.
- On first sign-in, local progress is merged with the cloud using the same “highest progression wins” rule as returning users.
