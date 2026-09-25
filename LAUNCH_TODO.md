# Launch TODO — NumberFlutter

Everything that stands between the current build and a store release. Each item
was checked against the code on 2026-09-25, after the Firebase migration.

This file replaces the old `PROD_READINESS.md` audit, which was written when the
backend was Supabase and has been removed.

Tick an item off (`[x]`) only once it's done **and verified on a release build**.

---

## 1. Store blockers: the app is rejected or can't be uploaded without these

- [ ] **Choose the final app ID.** It's still a placeholder:
  - `android/app/build.gradle`: `namespace` and `applicationId` = `com.example.number_flutter`
  - `ios/Runner.xcodeproj/project.pbxproj`: `PRODUCT_BUNDLE_IDENTIFIER` = `com.example.numberFlutter`
  - Play rejects `com.example.*`. **The ID can never change after publishing.**
  - Also update the Kotlin package path under `android/app/src/main/kotlin/`
    and the URL scheme in `ios/Runner/Info.plist` (`CFBundleURLSchemes`).
  - Register the new IDs in Firebase, then re-run `flutterfire configure` so
    `lib/firebase_options.dart` and `android/app/google-services.json` match.
- [ ] **Set up Android release signing.** `android/app/build.gradle` signs
  `release` with `signingConfigs.debug`.
  - Create an upload keystore and a `key.properties` (keep both out of git,
    add them to `.gitignore`, and **back up the keystore**).
  - Enroll in Play App Signing.
  - Add the upload-key and Play-signing **SHA-1** fingerprints to Firebase, or
    Google Sign-In will fail in release.
  - Consider `minifyEnabled` / `shrinkResources` with R8 rules.
- [ ] **Set up iOS signing.** No `DEVELOPMENT_TEAM` is set. You need an Apple
  Developer account, a team, and a distribution certificate/profile.
- [ ] **Check Google Sign-In on iOS.** `Info.plist` has no reversed-client-ID
  URL scheme and no `GIDClientID`, and `firebase_options.dart` has no
  `iosClientId`. iOS sign-in will probably crash or fail as things stand. Test
  it on a real device.
- [ ] **Remove the cheat tools from release builds.**
  `lib/ui/screens/settings_screen.dart` (~L314–381) shows the "02. TESTING"
  section (Test Environment toggle and "ADD 500 PRESTIGE POINTS") to every
  player. There's no `kDebugMode` guard anywhere in `lib/`.
  - Wrap the UI in `if (kDebugMode)`.
  - Make `GameState.setTestEnvironmentEnabled` / `addPrestigePointsForTesting`
    do nothing in release.
  - On load, force `testEnvironmentEnabled = false` in release, so any
    tester's saved flag gets cleared.
- [ ] **Make the Privacy Policy and Terms of Service links work.**
  `_buildLinkRow` in `settings_screen.dart` has no `onTap`.
  - Write and host both documents. They must cover Google sign-in, the
    Firestore cloud save, the leaderboard (name/country/city), ads, and IAP.
  - Add `url_launcher` and open the URLs.
  - Put the same privacy URL in the Play Console and App Store Connect.
- [ ] **Add in-app account deletion.** Both stores require it for apps with
  sign-in. No code path exists, and `firestore.rules` has
  `allow delete: if false` everywhere.
  - Delete `profiles/{uid}` (and its `sessions` subcollection),
    `player_progress/{uid}`, `leaderboard/{uid}`, then the Auth user.
  - Update the rules to allow owner deletes. For the subcollection, a Cloud
    Function is the reliable route.
- [ ] **Store paperwork:** Play Data Safety form, App Store privacy
  nutrition labels, content rating questionnaire, target audience (if under-13s
  are in scope, the ad and data rules get much stricter).

## 2. Monetization: ads and in-app purchases

### In-app purchases
- [ ] **Turn off the free shop.** `GameState.mockShopPurchases = true`
  (`lib/logic/game_state.dart`) grants every paid item for free right now.
- [ ] Add `in_app_purchase` (or RevenueCat) and create the products in both
  stores, using the IDs in `lib/data/shop_catalog.dart`. Those IDs are also
  persisted ownership keys, so don't change them.
- [ ] Fill in the `TODO(iap)` in `purchaseShopProduct`: launch billing,
  **verify the receipt** (server-side for anything that matters), then call
  `_grantShopProduct`. Handle pending, cancelled and failed purchases.
- [ ] Show real localized prices from the store instead of the hard-coded
  `priceLabel` strings (`€0.29`, etc.).
- [ ] Add a **Restore Purchases** button (Apple requires it for permanent items).
- [ ] Sync permanent purchases to the cloud save, so they survive a reinstall or
  a new device.
- [ ] Test with Play license testers and a StoreKit sandbox account.

### Ads
- [ ] Add `google_mobile_ads` and create an AdMob app and ad units.
- [ ] Add a **GDPR/UMP consent form** (required in the EU/UK) and ATT on iOS
  (`NSUserTrackingUsageDescription`).
- [ ] Put the AdMob app ID in `AndroidManifest.xml` and `Info.plist`.
- [ ] Decide on placements. Rewarded ads fit this game well (for example,
  double offline gains). Avoid interstitials that interrupt tapping.
- [ ] If you sell an "ad-free" item, make sure it actually turns ads off and
  survives Restore.
- [ ] Use **test ad unit IDs** during development. Clicking your own live ads
  gets AdMob accounts banned.

## 3. Strongly recommended before launch

- [ ] **Stop leaderboard cheating.** Scores are client-reported and trusted.
  `firestore.rules` only checks types and lengths. The first modded client
  will take over the board. Minimum: write leaderboard rows from a Cloud
  Function that sanity-checks progress against elapsed time/prestige. This
  needs the Firebase Blaze plan.
- [ ] **Untrack `assets/.env`.** It's committed and bundled into the app.
  Today it only holds the Google web client ID, which is not really secret, but
  add it to `.gitignore` before anything sensitive ever goes in.
- [ ] **Crash reporting and analytics:** add Firebase Crashlytics (and
  optionally Analytics) so you find out about launch crashes before the reviews
  do.
- [ ] **Store identity:**
  - `pubspec.yaml`: `version: 0.0.1+1` → e.g. `1.0.0+1`; description is still
    "A new Flutter project."
  - Decide the final display name (currently "Number" on both platforms).
  - Final launcher icon (`flutter_launcher_icons`, `lib/img/Logo.png`),
    screenshots, feature graphic, store description.
- [ ] **Check the save and sync edge cases** from the old audit that may still
  apply after the Firebase move:
  - cloud sync conflict handling (last-write-wins on device clock?)
  - local save versioning (`schemaVersion`)
  - `progressScore` int64 overflow in very late game
  - corrupt neural-network JSON silently resetting the network

## 4. Final verification (do last, on real devices)

- [ ] `flutter analyze` is clean and `flutter test` passes.
- [ ] `flutter build appbundle --release` and `flutter build ipa` succeed.
- [ ] Install the **release** build on a physical Android phone and iPhone and check:
  - [ ] fresh install → tutorial → first prestige
  - [ ] Google sign-in, sign-out, and sign-in on a second device restores progress
  - [ ] offline play, then reconnecting, syncs correctly
  - [ ] no TESTING section in Settings
  - [ ] a real (sandbox) purchase, then a restore on reinstall
  - [ ] ads load, the consent form appears in an EU locale, and ad-free removes them
  - [ ] Privacy/Terms links open, and account deletion actually wipes the data
- [ ] Internal testing track (Play) / TestFlight with a few real players
  before production.
