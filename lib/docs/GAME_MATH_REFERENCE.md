# Game Math Reference

**Accurate as of the V0.19 rebalance.** Every formula here was read back out of
`lib/logic/game_state.dart` and its siblings at the time of writing. `test/economy_test.dart`
locks the load-bearing ones, so if you change a number there and this file disagrees, the test
should be the thing that fails first.

The previous revision of this file had drifted badly — it documented a flat-growth prestige
requirement, a `1.18^n` reward, a `0.028 + 0.011i` delta, and a "Permanent Prestige Shop" whose
code no longer exists anywhere in `lib/`. None of that was true. Treat any formula not covered
here as unverified.

---

## 1. Currencies

There are exactly two real currencies.

| Currency | Field | Earned by | Spent on |
|---|---|---|---|
| **Number** (`N`) | `BigInt number` | clicks, idle ticker, offline gains, Temporal Collapse burst, Surge Protocol carry-over | all upgrades, the whole neural network |
| **Prestige Points** (`PP`) | `double prestigeCurrency` | `prestige()` | Nexus research nodes only |

The shop screen displays USD prices but is a non-functional mock — no IAP plugin is wired up.
See `PROD_READINESS.md`.

---

## 2. Upgrade cost model

Shared by every upgrade (`Upgrade.costForLevel`, applied in `getPurchaseInfo`):

```
cost(L) = floor(baseCost × costMultiplier^L × upgradeCostReductionFactor)

upgradeCostReductionFactor = clamp(1.0 - 0.01 × optProtocolLevel, 0.01, 1.0)
```

`L` is the *current* level, so buying level 1 costs `cost(0)`.

### Milestone multiplier

Thresholds `[25, 50, 100, 250, 500, 1000]` (`upgradeMilestoneThresholds`):

```
milestoneMult(L) = 2 ^ (number of thresholds <= L)     // 1, 2, 4, 8, 16, 32, 64
```

Applied to the **effect**, never to the cost. A level-1000 upgrade is 64× as effective as its
raw level implies.

---

## 3. Idle branch

All eleven generator tiers are purely **additive** into `autoClickRate`:

```
autoClickRate += effectValue × level × milestoneMult(level)
```

### Tier table

Post-rebalance every tier shares one growth rate and one cost-per-effect ratio
(`baseCost = 150 × effectValue`):

| id | +N/s per level | baseCost | costMultiplier |
|---|---|---|---|
| `idle_auto_clicker` | 1 | 150 | 1.16 |
| `idle_quantum_multiplier` | 10 | 1,500 | 1.16 |
| `idle_fractal_engine` | 100 | 15,000 | 1.16 |
| `idle_singularity_core` | 1,000 | 150,000 | 1.16 |
| `idle_tesseract_array` | 10,000 | 1,500,000 | 1.16 |
| `idle_entropy_harvester` | 100,000 | 15,000,000 | 1.16 |
| `idle_void_resonance` | 1,000,000 | 150,000,000 | 1.16 |
| `idle_dark_matter` | 10,000,000 | 1.5e9 | 1.16 |
| `idle_neutron_reactor` | 1e8 | 1.5e10 | 1.16 |
| `idle_multiverse_synthesizer` | 1e9 | 1.5e11 | 1.16 |
| `idle_tachyon_accelerator` | 1e10 | 1.5e12 | 1.16 |

The last three are also prestige-gated: Neutron Reactor needs 3 prestiges,
Multiverse Synthesizer 6, Tachyon Accelerator 10 (`minPrestigeForUpgrade`).

**Why uniform.** Cost per `+1/s` is therefore `150 × 1.16^L` for *every* tier, independent of
which tier it is. The optimal play becomes "buy the lowest-level tier you can afford", which
walks the player up the ladder naturally as absolute prices come into reach — and no tier can
ever be permanently dominated.

Before the rebalance the tiers had growth rates from 1.15 to 1.85 while their L0 ratios were
all within 3× of each other. That made the tier-1 Auto-Clicker the mathematically correct
purchase essentially forever (a greedy simulation took it to **level 86** while every other
tier sat at 18-27), and made Quantum Multiplier a strict trap pick — worst ratio *and*
second-worst growth. `test/economy_test.dart` now asserts both properties can't come back.

### Gated idle upgrades

| id | Requires | baseCost | mult | maxLevel | Effect |
|---|---|---|---|---|---|
| `idle_cascade_resonator` | 5 prestiges | 5e9 | 4.0 | 5 | `totalIdleRate ×= 2^L` — multiplicative, excluded from `autoClickRate` |

### Total idle rate

```
if (autoClickRate <= 0) return 0            // hard gate: no generator, no idle

idleRate = (autoClickRate + permanentIdleBonus)
         × prestigeMultiplier
         × resonanceMultiplier               // 1.05 ^ resonanceCoreLevel
         × neuralLossMultiplier
if (overclockActive) idleRate ×= overclockIdleMultiplier
if (cascadeLevel > 0) idleRate ×= 2 ^ cascadeLevel
```

Ticker runs at 100 ms and adds `rate / 10` per tick, flushing the integer part into `number`.

**Stacking:** generator effects are additive into `autoClickRate`; every *meta* source
(prestige, resonance, neural, overclock, cascade) is multiplicative and they all compound with
no diminishing-returns term.

---

## 4. Click branch

```
baseClickGain = clickPower × prestigeMultiplier × neuralLossMultiplier
kineticBonus  = totalIdleRate × kineticSynergyShare   // already carries neuralLossMultiplier
gain = floor((baseClickGain + kineticBonus) × momentumMultiplier × strikeMultiplier?)
```

`clickPower` is rebuilt from scratch by `_recalculateDerivedStatsFromUpgrades()`:

```
clickPower = productionBaseClickPower (1)           // or 10,000 in test environment
           + Σ  effectValue × level × milestoneMult(level)     // click upgrades
           + floor(prestigeMultiplier × level × 500)           // Dimensional Tap
```

Production base click is `1`: a fresh save clicks for exactly one number. Click Power adds a
realistic `+1` per level and is priced to match (15 base, ×1.15). Bigger flat gains come from
a ladder of flat click upgrades, each a higher tier with a higher cost. From Quantum Fingertip
up, each tier's price per point of click power doubles (10,000 → 20,000 → … → 640,000),
so a new tier is never a strictly better deal than the one below it. When Subatomic Tap was
cheaper per point than Singularity Press, the upgrade advisor chased click tiers forever and
never recommended an idle generator.

### Click upgrades

| id | baseCost | mult | maxLevel | Effect |
|---|---|---|---|---|
| `click_power` | 15 | 1.15 | ∞ | `+1 × L × milestoneMult` click power |
| `click_reinforced_tap` | 4,000 | 1.15 | ∞ | `+5 × L × milestoneMult` click power |
| `click_probability_strike` | 25,000 | 1.72 | ∞ | fixed **5%** chance; multiplier `10 + 2(L-1)` |
| `click_kinetic_amplifier` | 60,000 | 1.15 | ∞ | `+25 × L × milestoneMult` click power |
| `click_momentum` | 80,000 | 1.68 | ∞ | see below |
| `click_kinetic_synergy` | 400,000 | 1.75 | ∞ | `share = 0.01 × L` of `totalIdleRate` added to click |
| `click_resonant_touch` | 750,000 | 1.15 | ∞ | `+150 × L × milestoneMult` click power |
| `click_overclock` | 1,250,000 | 1.82 | ∞ | see below |
| `click_quantum_fingertip` | 1e7 | 1.15 | ∞ | `+1,000 × L × milestoneMult` click power |
| `click_singularity_press` | 1.5e8 | 1.15 | ∞ | `+7,500 × L × milestoneMult` click power |
| `click_subatomic_tap` | 2e9 | 1.15 | ∞ | `+50,000 × L × milestoneMult` click power |
| `click_quantum_forge` | 4e10 | 1.15 | ∞ | `+500,000 × L × milestoneMult` click power |
| `click_chronos_press` | 8e11 | 1.15 | ∞ | `+5e6 × L × milestoneMult` click power; needs 2 prestiges |
| `click_hyperdimensional_strike` | 1.6e13 | 1.15 | ∞ | `+5e7 × L × milestoneMult` click power; needs 4 prestiges |
| `click_omni_touch` | 6.4e14 | 1.15 | ∞ | `+1e9 × L × milestoneMult` click power; needs 7 prestiges |
| `click_dimensional_tap` | 5e8 | 2.10 | ∞ | `+floor(prestigeMultiplier × L × 500)`; **no** milestone mult; needs 1 prestige |
| `click_temporal_collapse` | 5e10 | 3.5 | 5 | burst `= floor(totalIdleRate × 60 × L)`, ×2 prestige mult for `30 + 15L` s, cooldown `max(80, 180 - 20L)` s; needs 8 prestiges |

### Early-game balance

Every click upgrade except Click Power itself costs 10× what it used to (Temporal Collapse
and Dimensional Tap are prestige-gated and unchanged). A tap is worth
`clickPower × momentum × strike`, so at 4 taps/s one point of click power earned ~40-80×
more per Number spent than one point of idle. Before the repricing, a player following the
upgrade advisor at 4 taps/s reached the first prestige in **~9 minutes without ever buying
a generator**, while a light tapper needed ~52.

First run, always taking the advisor's pick (`test/pacing_test.dart` guards the shape):

| Player | First generator | Idle ≥ tapping | First prestige (100M) |
|---|---|---|---|
| 4 taps/s | 1.5 min | 10.6 min | 25.5 min |
| 2 taps/s | 2.3 min | 4.9 min | 34.3 min |
| 1 tap/s | 2.2 min | 6.7 min | 40.8 min |
| 0.5 taps/s | 3.3 min | 7.0 min | 51.8 min |
| 3 taps/s, 10 min on / 50 min away | 1.8 min | 4.4 min | 92.5 min |

The light tapper's time is the idle ladder's own pace and did not change; only the tapping
advantage shrank, from ~5.6× to ~2×. Tapping still pays, but idle is the backbone of every
run within about ten minutes, which is also what earns while the app is closed.

**A realistic note on the click branch.** Raw Click Power scales *linearly* in levels while
idle stacks eleven exponential tiers, so raw clicking will never rival late-game idle income —
and it isn't meant to. Its two real jobs are:

1. carrying the first few minutes of a run, before any generator is affordable, and
2. converting idle income back into click income via **Kinetic Synergy**
   (`+1%` of `totalIdleRate` per level), which *is* competitive at scale.

Momentum, Probability Strike and Overclock are multipliers on top of that. Judge the branch on
whether Kinetic Synergy is worth buying, not on whether Click Power out-earns Void Resonance.

### Momentum

```
perClickBonus  = 0.02 + 0.006 × (L - 1)
cap            = 2.0 + 0.35 × (L - 1) + 0.1 × kineticSurgeLevel
decayWindowMs  = min(2500, 1000 + 120 × (L - 1))
gracePeriodMs  = 2000                       // before decay starts
clicksToCap    = max(5, ceil((cap - 1) / perClickBonus) + 1)
```

### Overclock

```
streakRequirement = max(20, 50 - 3 × (L - 1))
idleMultiplier    = 2.0 + 0.4 × (L - 1)
durationSeconds   = min(180, 30 + 5 × (L - 1))
```

---

## 5. Prestige

### Requirement — the load-bearing pacing constant

```
requirement(n) = 100,000,000 × (21/10)^n        // n = completed prestiges
               = 10,000 × (21/10)^n             // test environment
```

Held as the **exact rational 21/10**, not a double. Computing `base × pow(2.1, n)` in floating
point and handing the result to `BigInt.from` saturates at int64 max
(`9223372036854775807`) around prestige 35 — which silently flattens the curve back into the
exact bug this constant exists to fix. Clamped at `maxPrestigeRequirementExponent = 1000`
(`100M × 2.1^1000 ≈ 1e338`, far past anything reachable) so a corrupt save reporting a wild
count can't blow up the BigInt arithmetic.

This used to be a **flat 100M forever**, while the reward grew `1.35^n`. That inverted the
whole progression — every prestige was cheaper in real terms than the last, PP/hour rose
~850× from run 1 to run 16, and the full 16-prestige arc took ~22 h.

### Reward and multiplier

```
reward(n)   = 3.0 × 1.35^n                      // PP, ×prestigePointsMultiplier on payout
delta(i)    = 0.20 + 0.05 × i                   // multiplier gained by the prestige at index i
multiplier(n) = 1 + Σ delta(i) for i in [0, n)  = 1 + 0.20n + 0.05·n(n-1)/2
```

Quadratic: `n=10 → 4.25×`, `n=50 → 72.25×`, `n=100 → 268.5×`.

`prestigeRequirementGrowth (2.1)` must stay **above** `prestigeRewardGrowth (1.35)` or the loop
runs backwards again. That invariant is asserted in `test/economy_test.dart`.

### Measured pacing (optimal reinvestment)

| Run | Requirement | Multiplier | Run time | Cumulative | PP/h |
|---|---|---|---|---|---|
| 1 | 1.0e8 | 1.00 | 1.3 h | 1.3 h | ~2 |
| 5 | 1.9e9 | 2.10 | ~0.8 h | ~5 h | ~13 |
| 9 | 3.8e10 | 4.00 | ~1.4 h | ~9 h | **~43 (peak)** |
| 13 | 7.4e11 | 6.70 | ~4.4 h | 21 h | ~25 |
| 15 | 3.2e12 | 8.35 | ~13 h | ~45 h | ~16 |
| 16 | 6.8e12 | 9.25 | ~23 h | 68 h | ~12 |

Run 1 in this table predates the early-game click repricing; the measured first run by tap
pace is in "Early-game balance" (25-52 min). Later runs have not been re-measured.

PP/hour rises to a peak around run 9 and then declines — the correct shape. Prestige 15 at
~45 h sits inside the intended 40-60 h band.

### What prestige resets

**Reset:** `number → 0`, `clickPower → base`, `autoClickRate → 0`, all `upgrade.level → 0`,
momentum / overclock / temporal state.

**Preserved:** `prestigeCurrency`, `prestigeMultiplier`, `prestigeCount`, all Nexus
`researchNodes` levels, the entire `neuralNetwork` **including `loss`**, `highestNumber`,
`nexusStabilized`.

Surge Protocol refunds `netWorthBefore × 0.005 × level` (0.5% per level, max 2.5%).

---

## 6. Nexus (research tree) — spends PP

Unlocked by `nexusStabilized`, gated behind `prestigeCount >= 3`. Stabilization itself is free.

```
costForNextLevel = costsScale ? baseCostPerLevel × 1.6^level : baseCostPerLevel
```

Geometric as of V0.19. It was linear (`(level + 1) × base`), which put PP on a linear curve
against an exponential number economy: the whole tree got bought out within a few prestiges of
unlocking and PP had **no sink at all** afterwards.

| id | Tier | Prereq | base/lvl | maxLvl | Effect |
|---|---|---|---|---|---|
| `opt_protocol` | 1 | — | 3 | 10 | -1% all upgrade costs per level (max -10%) |
| `surge_protocol` | 1 | — | 6 | 5 | +0.5% pre-prestige net worth carried per level |
| `enhanced_extraction` | 1 | — | 6 | 5 | +10% prestige delta per level |
| `idle_foundation` | 2 | opt ≥3 | 6 | 10 | +1.0/s permanent idle per level |
| `quick_resume` | 2 | opt ≥5 | 9 | 5 | +10% offline gains per level |
| `kinetic_surge` | 2 | surge ≥3 | 9 | 3 | +0.1 momentum cap per level |
| `resonance_core` | 3 | idle_foundation ≥5 | 15 | 5 | `×1.05^L` idle |
| `echo_protocol` | 3 | enhanced_extraction ≥3 | 12 | 5 | +10% PP earned per level |
| `neural_genesis` | 4 | resonance 5 **and** echo 5 | 200 flat | 1 | unlocks the Neural Network; also grants exactly the neural tutorial's costs (first gradient + one paid activation + first branch, ≈9M) if that tutorial hasn't run |

**Totals.** Maxing everything now costs **~2,640 PP** (was 1,469). The minimum path to
`neural_genesis` is **~800 PP** (was 776) — deliberately close to unchanged, so the neural
network still unlocks around prestige 15 while the *completionist* tree gained a long tail.

Known rough edge: at `costGrowth = 1.6` the 10-level nodes get steep at the tail
(`opt_protocol` L10 ≈ 206 PP for a single 1% cost reduction). That's intentional as a late-game
sink, but it's the first thing to revisit if the tail feels bad.

`idle_foundation`'s `+1/s` does **not** bypass the `autoClickRate <= 0` gate on `totalIdleRate`,
so its "survives prestige" promise is void until an Auto-Clicker is re-bought. Flagged, not
yet fixed.

---

## 7. Progress score (leaderboard tiebreak)

```
score = clamp(prestigeCount × 1e8, 0, 9e18)
      + prestigeCurrencyScaled × 10,000          // floor(prestigeCurrency × 1000)
      + upgradesTotal × 10
      + floor(log10(numberDigits + 1) × 1000)
```

**Known bug:** the `prestigeCurrencyScaled × 10000` term is unclamped and overflows int64
around prestige ~70. See `PROD_READINESS.md`.

---

## 8. Offline gains

```
credited      = min(secondsAway, offlineCapHours × 3600)
offlineGains  = floor(totalIdleRate × credited × offlineGainMultiplier)
offlineGainMultiplier = (1 + 0.10 × quickResumeLevel) × chronoLensMultiplier
offlineCapHours       = 12 + chronoLensCapBonus               // V0.20
```

The cap applies to idle income only. Neural training still runs for the whole absence.
Being away 8h or more unlocks the hidden *The Long Sleep* achievement.

---

## 9. Achievements (V0.20)

Defined in `lib/data/achievement_data.dart` (46 entries). Each unlocked achievement adds a
flat **+1%** to all production:

```
achievementBonus = 1 + 0.01 × unlockedCount          // ≈ 1.46× with everything
```

State-based achievements are polled once a second from the ticker and immediately after
purchases, research, neural actions and prestige. Event achievements (first strike, first
Overclock, first Temporal Collapse, full momentum, Neural Spark, first Epoch, long absence)
are unlocked where they happen. Unlocks and `lifetimeClicks` are merged across devices, never
overwritten.

---

## 10. Global production multiplier (V0.20)

Everything outside the prestige multiplier that scales *all* production is folded into one
factor, applied to both `totalIdleRate` and the click base:

```
globalProductionMultiplier = achievementBonus × resonancePrism × (1 + 0.1 × epochs)
```

Temporal Collapse's ×2 is now its own transient factor as well. It used to be written into
`prestigeMultiplier`, which made it permanent if the player prestiged or saved mid-window.

---

## 11. Prestige artifacts — the PP sink (V0.20)

Prestige milestones **1, 5, 10, 15, 20, 30, 40, 50** each grant one artifact, picked from three
drawn out of the unowned pool (seeded and persisted, so it can't be rerolled). There are 12
artifacts, so a full run ends with 8 of them. Artifacts start at Lv 1 and are **empowered with
PP forever**:

```
empowerCost(L → L+1) = 15 × 1.45^(L-1) PP          // no max level
```

| Artifact | Lv 1 | Per level | Cap |
|---|---|---|---|
| Chrono Lens | offline cap +4h, offline ×1.2 | +1h, +0.05 | — |
| Echo Chamber | every 50th tap pays 100% of the last 10 taps | +10% | — |
| Tithe Engine | +3% PP per artifact owned | +0.5% | — |
| Genesis Kit | first 3 idle tiers start at Lv 10 after prestige | +2 | Lv 100 |
| Perpetual Motion | momentum floor 40% of cap | +3% | 90% |
| Loaded Dice | strike chance 8%, 25% chain chance (≤3 chains) | +0.25% | 15% |
| Overclock Core | auto-Overclock every 15 min | −30s | 5 min |
| Synapse Crown | neural costs ×0.75, preferred activation ×1.25 | cost ×0.97 | ×0.4 |
| Compound Vault | every 60s gain 0.5% of number, ≤ 5 min of idle | +0.1%, +1 min | 3% |
| Tempo Anchor | Collapse cooldown −25%, duration ×1.5 | −3%, +0.05 | −70%, floor 40s |
| Resonance Prism | +3% production per maxed Nexus node | +0.5% | — |
| Milestone Compass | milestone base ×2 → ×2.2 | +0.02 | ×2.6 |

The curves are in `lib/data/artifact_data.dart`. Level 0 always returns the neutral value, and
`test/artifact_test.dart` pins the caps at Lv 200.
