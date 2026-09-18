# V0.19 — Rebalance, Tutorial Rebuild, Neural Centering, Prod Audit

Living checklist. Tick items as they land. Status legend: `[ ]` todo · `[x]` done · `[~]` partial · `[-]` deliberately deferred.

## Status

**Parts 1-4 are implemented.** `flutter analyze` sits at its pre-existing 19 issues (no new
ones), `flutter test` is green at **62 tests** (up from 1), and `flutter build web --release`
compiles clean.

Outstanding: the **on-device manual passes** at the bottom of this file. They could not be run
here — `flutter build windows` fails on this machine until Developer Mode is enabled (symlink
support), and no Android device was attached. Automated coverage now stands in for part of what
those passes were meant to catch:

| Manual check | Now covered by |
|---|---|
| SKIP works on every step | `tutorial_overlay_test.dart` — asserts SKIP on all 38 steps in every mode |
| No step renders broken | `tutorial_overlay_test.dart` — every step pumped, no exceptions |
| Narrow window doesn't crash | `tutorial_overlay_test.dart` — 320/300/280/240/200px wide |
| Centring correct per neuron added | `neural_layout_test.dart` — all 16 growth states, exact |
| Nav-bar occlusion | `neural_layout_test.dart` — honest vs. inflated viewport |
| Pacing curve shape | `economy_test.dart` — monotonic requirement, declining PP/h |

Still genuinely needs a device or a Developer-Mode desktop build: resuming mid-tutorial after
an app kill (three points), the cloud `tutorial_completed = false` case, the re-center control's
feel, and the 60fps profile check.

---

## Context

Three things needed attention before this can be considered shippable:

1. **The economy ran backwards.** The prestige requirement was a flat 100M forever
   (`game_state.dart:508-513`) while the reward grew `3 × 1.35^n`. That inverted the whole
   progression: every prestige was *cheaper* in real terms than the last. Simulated with
   optimal reinvestment, PP/hour rose **~850×** from run 1 to run 16 and the entire
   16-prestige arc took **~22 h** against a 40-60 h design target. Separately the idle tier
   ladder was degenerate (the tier-1 Auto-Clicker was the mathematically correct purchase
   essentially forever) and the entire CLICK category was mechanically irrelevant.
2. **The tutorial was structurally fragile.** 39 steps for four tutorials in one flat enum,
   classified into render modes by three hand-maintained boolean sets. The current step was
   never persisted, so any app kill mid-tutorial either restarted it or lost it permanently.
   Several steps could wedge with no SKIP available.
3. **The neural canvas mis-centered as the network grew** — two independent causes.

Plus a ~40-item production-readiness audit, documented only.

### Measured pacing — before vs. target

Cumulative hours to reach each prestige, optimal reinvestment. "After" is measured against
the **shipped** constants (requirement `100M x 2.1^n`, idle ratio 150, base click 10):

| Prestige | Before (flat 100M) | After (shipped) |
|---|---|---|
| 1 | 3.7 h | 1.3 h |
| 5 | 13.1 h | ~5 h |
| 10 | 18.6 h | ~11 h |
| 13 | 20.5 h | 21 h |
| 15 | 21.3 h | ~45 h |
| 16 | 21.8 h | 68 h |
| PP/h shape | 0.8 → **680** (runaway) | peaks ~43 at run 9, then declines |

The shape is what matters: PP/hour now rises to a peak and falls away, instead of compounding
without limit. Prestige 15 at ~45 h sits inside the intended 40-60 h band.

---

## Part 1 — Economy rebalance

### 1a. Geometric prestige requirement
- [x] `prestigeRequirement` calls `prestigeRequirementAtCount(prestigeCount)` instead of returning a constant (`game_state.dart:508-525`)
- [x] Production base 100M, test-env base 10,000, growth `2.1^n`
- [x] Keep the test-env branch on the instance getter (the `AtCount` helper is `static`, the flag is an instance field)
- [x] First prestige lands in the 1-2 h band (trim early idle costs in 1b, not the prestige curve)

### 1b. Idle tier ladder
Cost per **+1/s** before the change — the ladder was inverted:

| Tier | L0 | L10 | L30 |
|---|---|---|---|
| Auto-Clicker (r=1.15) | 50 | 202 | **3.3e3** |
| Quantum (r=1.85) | 150 | 7.0e4 | 1.6e10 |
| Fractal (r=1.55) | 75 | 6.0e3 | 3.9e7 |
| Singularity (r=1.58) | 65 | 6.3e3 | 5.9e7 |
| Tesseract (r=1.62) | 75 | 9.3e3 | 1.5e8 |
| Entropy (r=1.66) | 90 | 1.4e4 | 3.6e8 |
| Void (r=1.70) | 120 | 2.4e4 | 9.8e8 |

All seven within 3× at L0, and Auto-Clicker's much lower growth made it the best buy forever
(a greedy sim took it to **level 86** while every other tier sat at 18-27). Quantum was
strictly dominated — worst ratio *and* second-worst growth.

Fix: uniform growth `1.16`, `baseCost = 150 × effectValue`. Cost-per-+1/s becomes
`150 × 1.16^L` for every tier, so the optimal play is "buy the lowest-level tier you can
afford", which walks the player up the ladder as absolute prices come into reach.

The ratio was tuned to 150 (not the 70 first drafted) to land the first prestige inside the
1-2 h band — at 70 it came out at 44 min. Note this puts Quantum back at its *original*
1,500 base: the old bases were broadly fine, it was the per-tier growth rates that were wrong.

- [x] `idle_auto_clicker` — base **150**, mult **1.16**
- [x] `idle_quantum_multiplier` — base **1,500**, mult **1.16**
- [x] `idle_fractal_engine` — base **15,000**, mult **1.16**
- [x] `idle_singularity_core` — base **150,000**, mult **1.16**
- [x] `idle_tesseract_array` — base **1,500,000**, mult **1.16**
- [x] `idle_entropy_harvester` — base **15,000,000**, mult **1.16**
- [x] `idle_void_resonance` — base **150,000,000**, mult **1.16**
- [x] Auto-Clicker's entry price rose from 50 to 150, so the tutorial's hardcoded 50/100 number gates would have stranded the player on an unaffordable purchase. Both are now **derived** from the relevant upgrade's `baseCost` (`GameState.tutorialFirstClickTarget` / `tutorialIdleWatchTarget`), and the overlay copy interpolates them

### 1c. Make the click branch matter
Production base click was `1` (`:810`) and Click Power's effect was divided by 50 (`:836-838`),
so Click Power gave **+1 per level** against Auto-Clicker's 50 for +1/s permanently.

- [x] Delete the `effectValue ~/ BigInt.from(50)` production divisor (`:836-838`)
- [x] Production base click `1` → `10` (`:810`)
- [x] `click_power` `costMultiplier` `1.45` → `1.30` (`:161`)
- [x] Remove the now-pointless `clickPower` load floors (`:556-558`, `:1425-1427`) — both are overwritten by `_recalculateDerivedStatsFromUpgrades()` at `:597` anyway
- [x] Verify click income sits within ~2× of idle income through the first prestige; retune `1.30` if it diverges

### 1d. Nexus and neural pacing
- [x] Nexus costs geometric — `research_node.dart:34-35` `(level+1) × base` → `base × 1.6^level`. Linear PP costs against an exponential number economy meant the full 1,469 PP tree was bought out within a few prestiges of unlocking, after which **PP had no sink at all**
- [x] `_neuralDecayK` `0.000001` → `0.000005`. A maxed network needed **~13.7 days of wall clock** to reach the loss floor with zero interaction available; `0.000005` is ≈2.7 days
- [x] Note in the audit that a post-tree PP sink is still needed

### 1e. Correct the stale design docs
- [x] Rewrite `lib/docs/GAME_MATH_REFERENCE.md` — contradicts code on prestige requirement, reward, delta and click scaling, and `:187-212` documents a "Permanent Prestige Shop" that no longer exists in `lib/`
- [x] Rewrite `lib/docs/NEURAL_NETWORK_MATH.md` — wrong on `k` (80×), boost scale, soft cap, gradient max and the accuracy remap
- [x] Fix the live UI/logic mismatch: `neuron_detail_sheet.dart:387,435` says `GR x/5` and draws 5 pips while `isGradientMaxed` is `gradientLevel >= 9` (`neural_network.dart:49`)

---

## Part 2 — Tutorial step machine restructure

Everything was driven from a 39-case `_keyForStep` switch (`tutorial_overlay.dart:61-128`),
three hand-maintained boolean sets — `isTapToContinue` (`:217-235`), `isWatchIdle` (`:236-241`),
`isNavStep` (`:242-251`) — a `_copyForStep` switch, and `_requiresHoleBeforeShow` (`:186-195`)
for exactly three steps. A step omitted from all three sets, or in the wrong one, silently
produced a broken frame. That was the root cause of most bugs below.

### 2a. Declarative step table
- [x] Add `TutorialStepSpec { mode, target, requiredTab, title, body, allowSkip }`
- [x] Add `TutorialMode { tapToContinue, spotlightAction, floatingHint, inSheet }`
- [x] Add `TutorialTarget` enum + a key registry owned by `MainLayout`, replacing hardcoded `navKeys[1]`/`navKeys[3]` indices (`:67,73,77,83,91,93,97,101`) and the hardcoded neuron id `'layer_0_neuron_0'` (`neural_canvas.dart:221`)
- [x] One `const Map<TutorialStep, TutorialStepSpec>` table; one render path per mode
- [x] Test asserting the table covers **every** `TutorialStep` except `done`

### 2b. Persist the current step
`_tutorialStep` was the only tutorial state never saved — `StorageService` persisted four
booleans (`storage_service.dart:16-19`) and `_init` only restored `done` if
`tutorialCompleted` (`game_state.dart:608-611`).

- [x] Persist `tutorialStep` **by name**, not index (index breaks the moment the enum is reordered)
- [x] Move `_upgradeTutorialSeen = true` from the *start* of the sub-tutorial (`:1733`) to `_completeUpgradeTutorial` — currently a mid-deep-dive kill short-circuits to `learnPrestige` and the **100M grant and purchased levels are never clawed back**
- [x] Nexus and neural tutorials survive a kill (both fire on one-time events — `stabilizeNexus()` and the `neural_genesis` purchase — so they were lost **permanently**)

### 2c. Escape hatch on every step
The `isWatchIdle` path returns `SizedBox.shrink()` when copy is null (`:260`) and **never draws
SKIP**, unlike the other two paths (`:331-346`, `:451-464`).

- [x] Render SKIP in **all** modes
- [x] **B1** `demonstrateMomentum` — `momentumBarKey` is declared (`:16,29`) and returned (`:99`) but **`MainLayout` never passes it** (`main_layout.dart:358-368`). No spotlight, no dim, no tap-to-continue; only exit was ~51 consecutive clicks. Pass the key; the dead branch at `game_state.dart:1671` becomes live
- [x] **B3** `buyMomentum` / `buyProbabilityStrike` — floating card, no dim, no SKIP, no tap advance, no `onMainTabChanged` case; leaving the Upgrades tab wedged the tutorial
- [x] **B4** the three neural in-sheet steps — dismissing the sheet left zero tutorial UI and no SKIP. Add a `TutorialMode.inSheet` fallback card for when the sheet is closed, and let `onNeuronTapped` (`game_state.dart:474-479`) re-hint on re-entry
- [x] **B10** `triggerProbabilityStrike` — gated on a 5% RNG roll with no pity floor; force the strike after N tutorial clicks
- [x] **B13** `skipTutorial` from an upgrade step jumped to `learnPrestige` (`:1771`) rather than ending, so SKIP could need four presses. Always jump straight to `done` for the tutorial in scope

### 2d. Positioning bugs
- [x] **Narrow-window crash** — `_CaptionCard` does `left.clamp(hMargin, width - cardWidth - hMargin)` (`:532,539,559`) with `cardWidth = 280`, `hMargin = 24`. Below 328 px wide `min > max` and **`clamp` throws**. Compute `cardWidth = min(280, width - 2*hMargin)` first
- [x] **Assumed card height** — 200/220/260 px hardcoded in every vertical clamp (`:534-556`) while real height is content-driven, so long bodies run off the bottom on short screens
- [x] **Hole never follows scroll or pan** — `_doHoleUpdate` (`:136-181`) resolves the rect once via `Scrollable.ensureVisible` with no scroll listener. Worse for the neural neuron, which lives inside an `InteractiveViewer` (`neural_canvas.dart:185`) where `ensureVisible` does nothing and the user can pan the target fully off-screen. Listen to the `ScrollPosition` / `TransformationController` and recompute
- [x] **Retries give up permanently** — 5 × 100 ms then silence (`:143-149`), no recovery when the target appears later. Keep retrying on a longer backoff while the step is active
- [x] **Unclamped rect** — `left`/`top` clamped to `>= 0` but `right`/`bottom` never clamped to the screen, so a partially-offscreen target yields negative-dimension dim bars that no-op, leaving undimmed gaps. Intersect the hole with the screen rect

### 2e. State-machine gaps
- [x] **B9** `selectIdle` unreachable if the category is already IDLE — `setSelectedUpgradeCategory` early-returns at `game_state.dart:1158` *before* the tutorial check at `:1160`. Move the check above the return
- [x] **B11** `onMainTabChanged` has no wrong-tab handling (`:1785-1824`) — every branch is `step == X && index == Y`, so any other tab silently does nothing and leaves a spotlight pointing at a nav item while a different screen shows. Use `requiredTab`. Delete the dead `goodLuck && index == 0` self-assignment (`:1820-1824`)
- [x] **B14** cloud can restart a finished tutorial — `setTutorialCompletionFromProfile(false)` forces `_tutorialStep = welcome` (`:1578-1580`) and runs on every profile fetch (`main_layout.dart:151`, `auth_session_listener.dart:38`); a fresh Supabase row defaults `tutorial_completed` to false (`supabase_service.dart:228`). Make local `true` authoritative — only sync completion *upward*
- [x] **B12** `_completeUpgradeTutorial` wipes state unconditionally (`:1737-1745`: `number = 0`, all `u.level = 0`) and is also the SKIP path (`:1770-1774`), so skipping destroyed real upgrades. Snapshot number/levels at sub-tutorial start and restore instead of zeroing
- [x] **B5** `neuralViewAccuracy` races the sheet pop — `branchNeuron` sets the step (`:466-468`) and the sheet then pops (`neuron_detail_sheet.dart:183-185`), so the hole is computed from a frame where the HUD is still behind the sheet. Await the pop
- [x] **B18** `registerTutorialResetCallback` leaks — single slot, never cleared on dispose (`game_state.dart:121-123`, `main_layout.dart:80-82`), retaining the `MainLayout` state. Clear it in `dispose`

### 2f. Side effects out of `build`
- [x] `tutorial_overlay.dart:207-211` mutates `_lastStep`/`_lastCategory` and kicks `_updateHole` from inside `build`
- [x] `main_layout.dart:277` calls `_maybePromptForLocation()` — a network fetch plus a dialog — directly from `build`; `:285-289`/`:292`/`:298` schedule `setState`, offline notices and an `OverlayEntry` insert from `build`. The 100 ms ticker calls `notifyListeners()`, so these ran **10×/s** behind ad-hoc boolean guards. Move to `didUpdateWidget` / `didChangeDependencies` / explicit listeners

---

## Part 3 — Neural network centering

### 3a. Fit box was the *future* layout, not the current one
`_fitAndCenter` (`neural_canvas.dart:65-114`) computed bounds from
`NeuralNetwork.targetNeuronCountForLayer` — the hardcoded `1,2,4,8,4,2,1` pyramid — rather than
from the neurons that exist. Layers fill one parent at a time (`game_state.dart:440-462`), so a
new layer starts with only its low-numbered slots occupied.

Worked example — layers 0(1), 1(2), 2(4), 3(**2 of 8**): canvas height 768, `canvasCenterY`
384. Actual neurons span y 104→504, centre **304**; the fit box spanned 80→688, centre **384**.
The network rendered 80 px above the view centre, zoomed out over mostly-empty canvas, and only
self-corrected once every slot filled.

- [x] Compute `minY`/`maxY` from the real `_buildPositions` output (union of actual neuron rects)

### 3b. Viewport included the area behind the bottom nav bar
`MainLayout` renders `_screens[_currentIndex]` in a plain `Stack` with `BottomNavBar` as a
`Positioned(bottom: 0)` sibling **on top of it** (`main_layout.dart:333-355`). The nav bar is
`56 + 2×14 + 1 = 85 px` tall (`bottom_nav_bar.dart:27,103`) and takes no bottom safe-area inset.
So `NeuralCanvas`'s `LayoutBuilder` viewport was ~85 px taller than the visible region: content
sat ~42 px low and the bottom 85 px of a tall network hid behind the nav. Invisible with one
neuron, obvious with a full 8-neuron layer.

- [x] `MainLayout` publishes the nav bar height; `_fitAndCenter` subtracts it (or reserve the space so every screen gets an honest viewport)
- [x] Nav bar respects `MediaQuery.viewPadding.bottom`

### 3c. Re-fit when it matters
`_fitAndCenter` only ran when the viewport or canvas `Size` changed (`:177`), and canvas size
came from target counts — so **adding a neuron never re-centered**.

- [x] Re-fit when the neuron count changes
- [x] Add a visible "re-center" control (there was no way back from a bad pan)
- [x] Delete the misleading `activate()` override (`:49-56`) — the plain `Stack` disposes the off-tab screen rather than deactivating it, so `initState` is what re-centers. Or switch `MainLayout` to `IndexedStack`, which would also preserve pan/zoom and scroll positions across tabs

### 3d. Neural canvas performance
- [x] Hoist `_buildPositions` out of the `AnimatedBuilder` builder (`:194-197`) — the whole position map and the entire `Stack` of `Positioned`+`NeuronWidget` children rebuilt at 60 fps
- [x] `neural_painter.dart:74-77` `shouldRepaint` compares `neuronPositions` by identity against a freshly allocated map → always `true`
- [x] Share one animation controller — every `NeuronWidget` owned its own repeating 1500 ms controller (`neuron_widget.dart:30-41`), up to 22 concurrent
- [x] `_NeuralLossHud` under `Consumer<GameState>` (`neural_network_screen.dart:162`) rebuilt the HUD *and the whole canvas subtree* every 100 ms tick. Narrow to `Selector`, as `:94` already does

---

## Part 4 — Production-readiness audit

- [x] Write `PROD_READINESS.md` — prioritized, every item file:line referenced

**Documentation only this pass — no code changes for Part 4 items.** The release blockers need
product decisions (real app ID, keystore, whether the shop ships at all). Headline items:

1. `com.example.*` app IDs on both platforms — permanent once published, and changing it also means updating the OAuth deep-link scheme and the Supabase redirect allow-list
2. **Release build signed with the debug keystore** (`android/app/build.gradle:37`)
3. `assets/.env` **committed to git** *and* bundled as an asset; `supabase/.temp/*` also committed
4. **Cheat surface ships to players** — Settings → "02. TESTING" test-env toggle and an "ADD 500 PRESTIGE POINTS" button, neither `kDebugMode`-guarded, both persisted, results uploaded to the leaderboard. `clearAllData()` doesn't clear the flag, so the cheat survives Factory Reset
5. **Leaderboard has no server-side validation**; `profiles`/`player_progress` are world-readable to any signed-in user; no `DELETE` policy anywhere (no account-data deletion path)
6. **Shop is a mock with real USD prices** and no IAP plugin at all
7. **Privacy Policy / ToS rows are dead** (no `onTap`) — both mandatory for either store
8. **Neural network topology is never cloud-synced** — restore gives maxed accuracy with zero neurons
9. **Schema drift** — `toDatabase()` writes a `nexus_levels` column no tracked migration creates
10. **`StorageService.loadGame()` has no error handling**; a corrupt blob boots the game dead (no ticker, no autosave, no message) because `_init()` has `try`/`finally` with no `catch`

Full list of ~35 items goes in `PROD_READINESS.md`.

---

## Verification

- [x] `flutter analyze` no worse than the current 19 issues, clean for touched files
- [x] `flutter test` green
- [x] New tests: `test/economy_test.dart`, `test/tutorial_spec_test.dart`, `test/sync_test.dart`, `test/storage_test.dart`
- [x] Economy sim reproduces the pacing table (first prestige 1-2 h, prestige 13 ≈ 36 h, PP/h declining after run 10)
- [ ] *(needs a device)* Tutorial, on device: full run with SKIP working on **every** step; kill the app mid-step at three points (main, upgrade deep-dive, neural) and confirm resume with no lost grant; window below 328 px wide doesn't crash; signing in with `tutorial_completed = false` over a completed local save does **not** restart onboarding
- [ ] *(needs a device)* Neural centering, on device: branch through all seven layers checking after **each individual neuron**, especially the 2-of-8 layer-3 state; nothing hides behind the nav bar; re-center recovers from a deliberate off-screen pan
- [ ] *(needs a device)* Perf: `--profile` with the performance overlay on a full 22-neuron network; 60 fps rebuild storm gone
- [ ] *(needs a device / Developer Mode)* Visual checks in **release** mode — per `PERFORMANCE_GUIDE.md`, debug is 10-20× slower and misrepresents the perf work

**Not shippable until Part 4's blockers are resolved.** Part 4 is documentation only.
