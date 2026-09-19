# Production Readiness — NumberFlutter

Audit compiled during the V0.19 pass. **Nothing in this document has been fixed** — it is
deliberately a decision list, because most of the top items need product choices (the real app
ID, a keystore, whether the shop ships at all) that shouldn't be guessed at.

Items are grouped by consequence, not by effort. Every entry names the file and line it was
found at. Line numbers refer to the state of the tree when this was written; the V0.19 changes
to `game_state.dart`, `tutorial_overlay.dart`, `neural_canvas.dart` and `main_layout.dart` will
have shifted some of them.

**The app is not shippable until §1 is resolved.**

---

## 1. Release blockers

### 1.1 Placeholder application IDs on both platforms
- `android/app/build.gradle:24` — `applicationId = "com.example.number_flutter"`
- `android/app/build.gradle:10` — `namespace = "com.example.number_flutter"`
- `ios/Runner.xcodeproj/project.pbxproj:371,550,572` — `PRODUCT_BUNDLE_IDENTIFIER = com.example.numberFlutter`

Google Play rejects `com.example.*` outright. More importantly the ID is **permanent once
published** — it cannot be changed later without shipping a brand new app and abandoning every
installed user.

Changing it is not a one-line edit. It also requires updating:
- `lib/config/app_config.dart:44-45` — `defaultOauthRedirectUrl = 'com.example.number_flutter://login-callback'`
- `android/app/src/main/AndroidManifest.xml` — the deep-link `scheme`
- `ios/Runner/Info.plist` — the registered URL type
- the Supabase dashboard's Auth redirect allow-list
- the Google Cloud OAuth client (Android client needs the new package name **and** the release
  SHA-1; `lib/logic/supabase_service.dart:122-126` already carries an error string admitting
  this is unverified)

### 1.2 Release builds are signed with the debug keystore
`android/app/build.gradle:33-38`:

```gradle
release {
    // TODO: Add your own signing config for the release build.
    signingConfig = signingConfigs.debug
}
```

There is no `key.properties`, no keystore, and no `minifyEnabled` / `shrinkResources` /
ProGuard rules. A debug-signed APK cannot be uploaded to Play.

iOS side: `ios/Runner.xcodeproj/project.pbxproj:335,455,512` sets
`CODE_SIGN_IDENTITY = "iPhone Developer"` with no `DEVELOPMENT_TEAM`.

### 1.3 `assets/.env` is committed to git *and* bundled into the app
`git ls-files assets/` confirms the file is tracked, and `pubspec.yaml` lists `assets/.env`
under `flutter: assets:`, so it ships inside the APK/IPA.

It contains `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_PROJECT_ID`,
`SUPABASE_OAUTH_REDIRECT_URL` and `GOOGLE_WEB_CLIENT_ID`.

To be fair to the design: the Supabase **anon** key is meant to be public, and shipping it in a
client is normal. The problems are that (a) it is in git history permanently, so rotating it
later doesn't retroactively help, and (b) it is only safe *because of* RLS — and §1.4 shows the
RLS posture is weaker than it looks.

Also committed: `supabase/.temp/linked-project.json` and `supabase/.temp/project-ref`, which
leak the project ref and organisation ID. That's CLI scratch state and should never be in VCS.

`.gitignore` covers neither. Recommended: untrack both, add `assets/.env` and `supabase/.temp/`
to `.gitignore`, and decide whether the history rewrite is worth it.

### 1.4 Leaderboard has no server-side validation, and progress is world-readable
- `supabase/schema.sql:86-92` — `progress_update_own` lets a client write
  `highest_number_numeric` to whatever it likes. Scores are entirely client-authored.
- `supabase/schema.sql:51-55, 73-77` — both `profiles` and `player_progress` grant
  `SELECT ... to authenticated using (true)`. **Any signed-in user can read every other
  player's country, city and full progress row.**
- No `DELETE` policy exists on any table, so there is no path for a user to delete their own
  account data. That is a GDPR problem and an App Store review problem.
- `supabase/schema.sql:94-110` — `leaderboard_view` is created without
  `security_invoker = true`, so it runs as its owner and bypasses RLS. Harmless today only
  because `SELECT` is already `true`.

Combined with §1.5, leaderboard integrity is currently impossible.

### 1.5 The cheat surface ships to players
`lib/ui/screens/settings_screen.dart:303-337` renders a user-visible **"02. TESTING"** section
with a *Test Environment* toggle, subtitled `Click: 10k, Prestige: 10k`. It is backed by
`GameState.setTestEnvironmentEnabled` and drops the prestige requirement from 100M to 10,000
while raising base click power from 10 to 10,000.

`lib/ui/screens/settings_screen.dart:347-372` renders an **"ADD 500 PRESTIGE POINTS"** button
wired to `GameState.addPrestigePointsForTesting`. 500 PP is roughly a fifth of the entire
research tree.

Neither is behind `kDebugMode` — there is **no `kDebugMode` or `kReleaseMode` guard anywhere in
`lib/`**, so none of this is compiled out of a release build. Both persist to disk, and the
results upload to the leaderboard.

`lib/logic/storage_service.dart:130-149` — `clearAllData()` removes 17 keys but **not**
`testEnvironmentEnabled`, so the cheat survives a Factory Reset.

Related: `lib/logic/game_state.dart:45-46,65` still carry debug field initialisers
(`clickPower = 10000`, `_prestigeCurrency = 10000.0`, `prestigeCount = 500`). `_init()`
overwrites them on a successful load, but they are the values in effect before load completes,
in any `GameState` built without `_init`, and — per §2.3 — after a *failed* load.

### 1.6 The shop advertises real prices and cannot take money
`lib/ui/screens/shop_screen.dart:50-84` lists four items at `$4.99` / `$4.99` / `$4.99` /
`$3.99`. There is no `onTap` on any of them, no IAP plugin in `pubspec.yaml`, and no
purchase / restore / receipt-validation logic anywhere. `_ShopItem` (`:94-205`) is display-only.

One of the items is "Ad-Free Experience" in an app that has no ads.

Both stores reject apps that present purchasable items with no working purchase flow. Decide
whether the shop ships at all in V1 — hiding the tab is a legitimate answer.

### 1.7 Privacy Policy and Terms of Service links are dead
`lib/ui/screens/settings_screen.dart:387-388` renders both rows via `_buildLinkRow`
(`:699-718`), which has **no `onTap`** — they are decoration with a misleading
external-link arrow.

Both documents are mandatory for Play and the App Store given that the app has accounts, and
doubly so once IAP exists.

---

## 2. Data loss and correctness

### 2.1 The neural network's topology is never synced to the cloud — *resolved in V0.20*
The full network JSON now travels in `player_progress.neural_network`.

`lib/models/player_progress.dart:15-16, 94-111` carries only `neuralLoss` and
`neuralLowestLoss`. There is no field for layers or neurons, and
`GameState._applyCloudProgress` merges only those two doubles.

So restoring on a new device hands the player a **maxed accuracy value attached to an empty
canvas**: the loss multiplier is live, `computeStrength()` is near zero, and every neuron,
gradient level and activation they paid for is gone. Reinstalling loses the entire end game.

### 2.2 Schema drift — `schema.sql` cannot bootstrap a working project
`lib/models/player_progress.dart:104` writes `'nexus_levels'` on every upsert, but
`public.player_progress` as defined in `supabase/schema.sql:15-29` has **no `nexus_levels`
column**, and no migration adds one — `nexus_levels` appears only on `session_archive`
(`supabase/migrations/20260427_session_archive.sql:15`).

Either the live database has drifted from the repo (someone added the column by hand), or every
progress upsert is failing with PostgREST error `PGRST204`. Both are bad; the first means the
migrations no longer reproduce production.

`schema.sql` is stale in two further ways: it lacks `neural_loss` / `neural_lowest_loss` (added
only in `20260428_neural_loss.sql`) and declares a 3-argument `get_leaderboard` while the client
passes a 4th `metric` argument (`lib/logic/supabase_service.dart:289-299`).

**Anyone bootstrapping from `schema.sql` gets a project where saving is broken.**

### 2.3 A corrupt save boots the game dead, silently
`lib/logic/storage_service.dart:65-128` — `loadGame()` has **no `try`/`catch` at all**. The
`jsonDecode` at `:86`, the `as Map<String, dynamic>` cast, and the `(value as num).toInt()` at
`:88` all throw on a corrupt or hand-edited prefs blob.

That throw propagates into `GameState._init()`, which has a `try` / **`finally`** with no
`catch`. The consequences:
- `_readyCompleter` completes, so the loading screen clears and the app looks fine
- `_startTicker()` is never reached, so there is **no idle income and no autosave**
- the debug field defaults from §1.5 are still in place — the player appears to be at
  prestige 500 with 10,000 PP
- nothing is shown to the user

Needs a `catch`, a corrupt-blob backup written aside for diagnosis, and a visible message.

### 2.4 Local saves are unversioned
`lib/logic/storage_service.dart` writes ~18 discrete `SharedPreferences` keys with no
`schemaVersion`. Migrations are implicit and scattered — the legacy `globalMultiplier` →
`prestigeCount` conversion and the `prestigeCurrency` BigInt→double conversion both live inline
in `GameState._init()`.

`NeuralNetwork` is the counter-example and the pattern to copy: `lib/models/neural_network.dart`
has `_saveVersion = 4` with real migrations (v0/v1 → v2 normalisation, pre-v4 activation
grandfathering). Extend that to the rest of the save.

### 2.5 Corrupt neural JSON silently wipes the network
`lib/logic/game_state.dart` (the `nnJson` block in `_init`) catches the parse failure and
resets to `NeuralNetwork.initial()` with no warning and no backup. The player loses the deepest
system in the game and is told nothing.

### 2.6 Cloud sync is last-write-wins on the device clock
`lib/logic/sync_service.dart:49-92`. Local `updatedAt` comes from `DateTime.now()` on the
device, while the remote value is **rewritten server-side** by the
`player_progress_set_updated_at` trigger (`supabase/schema.sql:41-45`). So:
- any clock skew silently discards a session
- a remote win overwrites local progress wholesale, with no prompt and no merge — only
  `neuralLowestLoss` is merged monotonically (`:58-70`)

There is no retry, no backoff and no offline queue; `syncWithCloud` just records
`error.toString()` on failure.

### 2.7 `progressScore` overflows int64 in the late game
`lib/models/player_progress.dart:51-58`. The `prestigeCount` term is clamped to 9e18, but
`prestigeCurrencyScaled * 10000` is not. With `prestigeCurrency` growing as `3 × 1.35^n`, that
term passes int64 around prestige ~70 and the `bigint` column write fails.

### 2.8 Offline gains are uncapped — *resolved in V0.20*
Idle income is capped at 12h away (plus Chrono Lens). The forward-clock exploit is bounded by
the same cap.

`GameState._calculateOfflineProgress` puts no ceiling on `secondsAway`. Thirty days away pays
2.6M seconds at the full current rate, multiplied by up to 1.5× from Quick Resume. It is
currently the strongest income source in the game, and it rewards not playing.

A forward clock change is free money; a backward one is caught by the `diff <= 0` guard.

### 2.9 Session archive has no dedupe
`lib/logic/supabase_service.dart:321-341` inserts on every prestige with
`session_number = prestigeCount + 1` and no unique constraint — there is an index but nothing
preventing duplicates on a retry.

In the same migration, `update_profile_session_stats` never populates
`average_highest_number_numeric` (a dead column), and its
`max(highest_number_numeric order by (highest_number_numeric::numeric) desc)` will **throw and
fail the insert** on any value `numeric` can't parse.

### 2.10 The leaderboard ranks by string length
`supabase/schema.sql:98-102`, repeated in both later migrations:

```sql
order by char_length(pp.highest_number_numeric) desc,
         pp.highest_number_numeric desc
```

This is only correct for unsigned integer strings with no decimal point, no sign and no leading
zeros. It also disagrees with the `::numeric` cast the archive trigger uses on the same column.
Store the value as `numeric`, or rank explicitly on (digit count, normalised value).

---

## 3. Economy gaps left open after V0.19

These are known and deliberate, listed so they don't get lost:

- *(Resolved in V0.20: prestige artifacts are empowered with PP at `15 × 1.45^(L-1)` with no
  cap.)* **PP has no sink once the Nexus tree is maxed.** V0.19 made node costs geometric, raising the
  full tree from 1,469 to ~2,640 PP, which buys a much longer tail — but a dedicated late-game
  PP sink is still missing. This is the single biggest remaining economy gap.
- **`idle_foundation` doesn't deliver its promise.** Its `+1/s` permanent idle bonus does not
  bypass the `autoClickRate <= 0` gate in `GameState.totalIdleRate`, so the "survives prestige"
  selling point is void until the player re-buys an Auto-Clicker.
- **Nexus tail values are steep.** At `costGrowth = 1.6` the 10-level nodes get expensive at
  the top (`opt_protocol` L10 ≈ 206 PP for a single 1% cost reduction). Intentional as a sink,
  but the first thing to revisit if it feels bad.
- **Surge Protocol's data is vestigial.** `lib/data/nexus_data.dart` declares
  `effectPerLevel: 30.0` / `surgeSeconds` while the code uses `level × 50` basis points.

---

## 4. Polish and hygiene

| # | Issue | Location |
|---|---|---|
| 4.1 | Live trophy buttons show `'Leaderboard coming soon!'` even though `leaderboard_screen.dart` exists and is wired correctly from `main_game_screen.dart:163` | `prestige_screen.dart:45-48,257`, `upgrades_screen.dart:30-33,108` |
| 4.2 | "Auto-Save Protocol / Interval: 60 Seconds" toggle is backed only by a local `_autoSaveEnabled` that is never read; the real interval is 5s and isn't configurable. The toggle widget is literally named `_buildDummyToggle` | `settings_screen.dart:281-293,520` |
| 4.3 | Hardcoded `'Software Version', '0.01'` and a fake `'Terminal ID', '#882-QX-01'`, while `pubspec.yaml:20` says `0.0.1+1` and git history says V0.18 | `settings_screen.dart:384-385` |
| 4.4 | `description: "A new Flutter project."`; `web/manifest.json` still has `"name": "number_flutter"`, the default Flutter blue `#0175C2` and default icons | `pubspec.yaml:2`, `web/manifest.json` |
| 4.5 | No `mipmap-anydpi-v26/`, so no Android adaptive icon — legacy letterboxed icon on Android 8+ | `android/app/src/main/res/` |
| 4.6 | No `SystemChrome.setPreferredOrientations` anywhere; iOS still permits landscape on iPhone although the UI is portrait-only | app-wide, `Info.plist` |
| 4.7 | Unconditional 2,500ms artificial loading delay on every launch | `main.dart:66` |
| 4.8 | Taps above 30/s are silently dropped with no feedback; `_lastWarningTime` is declared and never read | `main_game_screen.dart:29,41-45` |
| 4.9 | User-facing errors leak internal setup instructions ("needs Supabase configured in assets/.env", "disable Confirm email in Supabase → Authentication"). `syncWithCloud` renders raw `error.toString()` in the UI | `auth_screen.dart:62-68`, `neural_network_screen.dart:33-39`, `upgrades_screen.dart:38-44`, `prestige_screen.dart:53-59`, `game_state.dart` |
| 4.10 | `OverlayEntry` remove-then-insert with no guard; racing notices can leak or double-remove | `main_layout.dart:235,241` |
| 4.11 | `shouldRepaint => true` unconditionally | `nexus/widgets/connections_painter.dart:64` |
| 4.12 | Unawaited `SharedPreferences` write every 5s from inside the ticker; overlapping writes are possible. The 350ms save debounce also means a kill inside that window loses the last mutation | `game_state.dart` |
| 4.13 | `_completeTutorialOnPrestige()` is an empty no-op that is still called; stochastic neural jitter is left disabled | `game_state.dart` |
| 4.14 | 19 `flutter analyze` warnings — unused imports/fields/elements. `analysis_options.yaml` is stock `flutter_lints`; `unawaited_futures` and `use_build_context_synchronously` are worth enabling | `main_game_screen.dart`, `main_layout.dart`, `shop_screen.dart`, `upgrades_screen.dart`, `prestige_screen.dart` |
| 4.15 | No crash reporting, no `ErrorWidget.builder`, no `FlutterError.onError`. A release crash is currently invisible to you | `main.dart` |
| 4.16 | `.claude/worktrees/thirsty-allen-069a9c` is a **stale git worktree committed as a gitlink** at V0.17 (5.2MB). Remove with `git worktree remove`, untrack, and add `.claude/worktrees/` to `.gitignore` | repo root |
| 4.17 | Assets and design docs live under `lib/` — `lib/docs/`, `lib/img/`, `lib/countries/`, and `lib/sounds/` which is **empty** with no audio code anywhere in the project | `lib/` |
| 4.18 | Windows builds require Developer Mode (symlink support) — `flutter build windows` currently fails on this machine. Web and test compilation are unaffected | local env |

---

## 5. Test coverage

V0.19 took this from **one 17-line smoke test** to 62 tests:

- `test/economy_test.dart` (23) — prestige requirement/reward curves and their invariants, the
  idle tier ladder's uniformity and non-domination, click-branch competitiveness, Nexus cost
  geometry, the neural training window
- `test/neural_layout_test.dart` (11) — canvas centring at every growth step, including an
  explicit regression test proving the old target-pyramid bounds were 80px out where the new
  ones are exact
- `test/tutorial_spec_test.dart` (16) — the spec table covers every step, every spotlight step
  names a target, every step has copy and a scope, tab/category gating is coherent
- `test/tutorial_overlay_test.dart` (11) — every step renders without throwing, SKIP is present
  on every step in every mode, tap-to-continue advances, spotlight dim taps don't, narrow
  viewports don't crash
- `test/widget_test.dart` (1) — the original smoke test

Still uncovered:
- `GameState`'s runtime behaviour — the click/idle tick path, momentum, overclock, temporal
  collapse, purchase modes (x1/x10/x100/NEXT/MAX)
- `SyncService._pickWinner` — pure, trivially testable, and governs data loss (§2.6)
- `StorageService` round-trip and corrupt-blob recovery (§2.3)
- `NeuralNetwork` v0→v4 JSON migrations
- `NumberFormatter`
- `PlayerProgress.toDatabase` / `fromDatabase` — would have caught §2.2
- the neural branching/eligibility rules

The original smoke test is also fragile: it depends on dotenv *not* being loaded
(`app_config.dart:22` catches `on Object`) and on a hardcoded 3s pump to drain `main.dart`'s
2,500ms delay.

---

## 6. Suggested order

1. **Decide the app ID and make a keystore** (§1.1, §1.2). Everything else in §1 is cheaper.
2. **Strip the cheat surface** (§1.5) — small, entirely under your control, and §1.4 stays
   meaningless until it's done.
3. **Fix the schema drift** (§2.2). Until `schema.sql` reproduces production you cannot trust
   any staging environment.
4. **Sync the neural topology** (§2.1) and **handle corrupt saves** (§2.3). These are the two
   real data-loss bugs.
5. **Tighten RLS and add a delete path** (§1.4).
6. **Decide the shop's fate** (§1.6) and **write the two legal documents** (§1.7).
7. Cap offline gains (§2.8) and fix the score overflow (§2.7).
8. Work §4 down as time allows.
