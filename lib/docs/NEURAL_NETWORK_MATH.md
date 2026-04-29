# Neural Network — Loss / Accuracy / Multiplier Math

This is the current math as implemented in code. All formulas below appear
in either `lib/models/neural_network.dart` or `lib/logic/game_state.dart`.

## 1) Notation

| Symbol | Meaning |
|---|---|
| `loss` | Current training loss in `(0, 1]`. Decays over time. Persists across prestige. |
| `lowestLossEver` | Best (lowest) loss this network has ever reached. Cloud-synced. Drives the leaderboard. |
| `accuracy` | `1 − loss`, clamped to `[0, 1]`. Pure UI projection of `loss`. |
| `strength` | Network "training power" derived from neuron upgrades. Drives decay rate. |
| `gradientLevel` | Per-neuron upgrade level, `0..5`. |
| `activationFn` | Per-neuron activation: `linear`, `relu`, `sigmoid`, `tanh`. |
| `layer.index` | Layer position, `0..6` (input → output, pyramid). |
| `prestigeCount` | How many times the player has prestiged. |
| `dt` | Ticker period, `0.1` seconds. |
| `k` | Decay constant, `0.00008`. |

## 2) Per-Neuron Contribution

Each neuron contributes to the network's raw "training signal" sum.

```
contribution(neuron) = (gradientLevel + 1)
                     × layerDepthBonus(layer.index)
                     × activationBonus(layer.index, activationFn)
```

Where:

```
layerDepthBonus(i) = 1.0 + 0.25 * i
```

| Layer `i` | depthBonus |
|---|---|
| 0 | 1.00 |
| 1 | 1.25 |
| 2 | 1.50 |
| 3 | 1.75 |
| 4 | 2.00 |
| 5 | 2.25 |
| 6 | 2.50 |

Deeper layers are worth more — there's incentive to keep branching.

```
activationBonus(i, fn) = 1.10  if fn == preferredActivationByLayer[i]
                       = 1.00  otherwise
```

Preferred activation per layer (locked rule):

| Layer `i` | role | preferred fn |
|---|---|---|
| 0 | input | `linear` |
| 1 | hidden | `relu` |
| 2 | hidden | `relu` |
| 3 | hidden | `relu` |
| 4 | hidden | `relu` |
| 5 | deep hidden | `tanh` |
| 6 | output | `linear` |

> **Why `(gradientLevel + 1)`?** So a fresh, level-0 neuron still contributes
> something nonzero (just a small amount). Otherwise an unupgraded network
> would have zero strength → zero decay forever.

## 3) Network Strength

```
strength = ln(1 + Σ contribution(neuron))
```

Natural log applied to `1 + Σ` — so:
- A weak network has near-zero strength (matches intuition).
- The marginal value of adding another upgrade *decreases* as the network
  gets stronger (log-shaped curve). This prevents late-game decay from
  becoming so fast that loss falls off a cliff.

### 3.1 Marginal Δstrength (per neuron)

The detail sheet shows what removing *this* neuron's contribution would do:

```
marginalΔ = ln(1 + Σ_total) − ln(1 + Σ_total − contribution(this))
```

That's the actual log-strength delta this neuron is responsible for — and
since `loss` decay is driven by `strength`, this is the number that matters
when deciding whether to upgrade.

## 4) Loss Decay (per tick, every 100 ms)

```
loss_next = max( loss * exp(-k * strength * dt), MIN_LOSS )
```

With:
- `dt = 0.1` (seconds per tick)
- `k = 0.00008` (decay constant)
- `MIN_LOSS = 1e-6` (loss never reaches true zero)

This is **continuous exponential decay**, not linear. Each tick, loss is
multiplied by a factor `< 1` whose magnitude depends on current strength.

Over a wall-clock interval `T` seconds (assuming constant strength):

```
loss(T) = loss(0) * exp(-k * strength * T)
```

Time to reach a target loss:

```
T_target = ln(loss_start / loss_target) / (k * strength)
```

### 4.1 First-pass tuning target

`k = 0.00008` is calibrated so a **fully-tuned** network reaches `loss ≈ 0.01`
in roughly 24 hours of continuous play. Adjust during playtest.

A fully-tuned network is:
- All 22 neurons present (1+2+4+8+4+2+1).
- Every neuron at gradient 5.
- Every neuron's activation matches its layer's preferred fn.

For that network:

```
Σ contributions ≈ Σ over all neurons of (5+1) × depthBonus × 1.10
                ≈ 6 × 1.10 × Σ (1, 2×1.25, 4×1.50, 8×1.75, 4×2.00, 2×2.25, 1×2.50)
                ≈ 6.6 × 31.5
                ≈ 207.9
strength       ≈ ln(1 + 207.9) ≈ 5.34
```

Time to go from `loss = 1.0` → `loss = 0.01`:

```
T = ln(1.0 / 0.01) / (0.00008 × 5.34)
  = 4.605 / 0.000427
  ≈ 10,780 seconds
  ≈ 3.0 hours
```

(So the "24 h" target is conservative — real play has the network ramping
up slowly, not starting fully-tuned. The constant is set so the journey
to ~99% accuracy takes a meaningful day-or-two of play, not a weekend.)

## 5) Accuracy (UI display)

```
accuracy = clamp(1 − loss, 0, 1)
```

That's it. Accuracy is a pure presentation of `loss` — the canvas HUD
shows `accuracy × 100` as `"Accuracy: 99.21%"`. The leaderboard shows the
same projection.

| `loss` | `accuracy` shown as |
|---|---|
| 1.000  | 0.00% |
| 0.500  | 50.00% |
| 0.100  | 90.00% |
| 0.010  | 99.00% |
| 0.001  | 99.90% |
| 1e-6   | 99.9999% |

## 6) Loss Multiplier (the gain boost)

The neural network's payoff is a multiplier applied to all number gain.

### 6.1 Raw multiplier

```
rawMult = 1.0 + (1.0 − loss) × NEURAL_BOOST_SCALE
        = 1.0 + accuracy × 50         // since NEURAL_BOOST_SCALE = 50
```

| `accuracy` | `rawMult` |
|---|---|
|  0%  | 1.00 |
| 50%  | 26.00 |
| 90%  | 46.00 |
| 99%  | 50.50 |
| 99.9%| 50.95 |
| 100% | 51.00 |

### 6.2 Soft cap (anti-trivialization)

A returning player who unlocks the network *after* having a low `loss`
shouldn't be able to one-shot the early prestige curve. So the raw
multiplier is capped by a function of `prestigeCount`:

```
softCap = 1.0 + prestigeCount × NEURAL_SOFT_CAP_PER_PRESTIGE
        = 1.0 + prestigeCount × 8

neuralLossMultiplier = min(rawMult, softCap)
```

The cap binds early and stops binding once `prestigeCount` is high enough
for `softCap ≥ rawMult`.

| `prestigeCount` | `softCap` | binds vs `rawMult = 51`? |
|---|---|---|
| 0   | 1     | yes (huge clamp) |
| 1   | 9     | yes |
| 3   | 25    | yes |
| 5   | 41    | yes |
| 6   | 49    | yes |
| 7   | 57    | **no** — full boost from here on |
| 50  | 401   | no |

The HUD shows a `(capped)` flag next to the multiplier when the soft cap
is the active constraint, so players know more prestiges = more headroom.

If the neural network isn't unlocked at all:

```
neuralLossMultiplier = 1.0   // no boost, no cap
```

## 7) Where the Multiplier Applies

### 7.1 Idle rate

```
totalIdleRate = (autoClickRate + permanentIdleBonus)
              × prestigeMultiplier
              × resonanceMultiplier
              × neuralLossMultiplier
              × overclockIdleMultiplier  // if active
```

### 7.2 Click gain

```
baseClickGain = clickPower × prestigeMultiplier × neuralLossMultiplier
kineticBonus  = totalIdleRate × kineticShare         // already includes mult
gain          = (baseClickGain + kineticBonus) × momentumMultiplier
              × probabilityStrikeMultiplier         // if triggered
```

> The `kineticBonus` inherits `neuralLossMultiplier` *via* `totalIdleRate`,
> so we deliberately don't multiply it again — that would double-apply.

## 8) `lowestLossEver` (leaderboard metric)

Updated every tick:

```
if (loss < lowestLossEver) {
  lowestLossEver = loss;
}
```

It is a **monotonically non-increasing** field. It is never reset by
prestige, and (importantly) the cloud sync always merges it as
`min(local, remote)` even when the other side wins the timestamp
race — so a stale upload can never wipe a better training run.

The leaderboard `'loss'` metric ranks `ASC` by `neural_lowest_loss`.
The UI presents it as `Accuracy: (1 − lowestLossEver) × 100`.

## 9) Lifecycle Summary

| Event | `loss` | `lowestLossEver` |
|---|---|---|
| Genesis unlock      | initialized to `1.0` | initialized to `1.0` |
| Tick (every 100 ms) | decays via §4 | maybe lowered |
| Prestige            | **unchanged** | **unchanged** |
| Hard reset          | reset to `1.0` (network reinitialized) | reset to `1.0` |
| Cloud sync (remote wins) | `min(local, remote)` | `min(local, remote)` |
| Cloud sync (local wins)  | local | `min(local, remote)` (always) |

## 10) Tuning Constants (live in `game_state.dart`)

```dart
static const double _neuralDt                 = 0.1;     // ticker period (s)
static const double _neuralDecayK             = 0.00008; // decay constant
static const double _neuralMinLoss            = 1e-6;    // floor for loss
static const double _neuralBoostScale         = 50.0;    // mult @ accuracy=1
static const double _neuralSoftCapPerPrestige = 8.0;    // cap slope
```

All five are intentionally easy to find and change in one place. Adjust
during playtest — the formulas above will continue to hold.

## 11) Worked Example

Player has:
- A mid-game network: 12 neurons, average gradient 3, ~half on preferred
  activation.
- `prestigeCount = 4`.
- Current `loss = 0.40` (accuracy 60%).

Estimate:

```
Σ contributions ≈ 12 × (3+1) × 1.5_avg_depth × 1.05_avg_activation ≈ 75.6
strength        = ln(1 + 75.6) ≈ 4.34
decayPerSecond  = k × strength = 0.00008 × 4.34 ≈ 3.47e-4 /s
                                                  (× current loss to get loss/s)

rawMult         = 1 + (1 − 0.40) × 50 = 31.0
softCap         = 1 + 4 × 8 = 33.0
neuralLossMult  = min(31.0, 33.0) = 31.0   // raw is below cap
                                            // → HUD shows no "(capped)"
```

So this player's gain is being multiplied by **31×** right now, and the
HUD's decay readout would show `≈ 0.00035 /s` next to the multiplier and
accuracy.

Time to reach `loss = 0.01` from here at constant strength:

```
T = ln(0.40 / 0.01) / (0.00008 × 4.34)
  = 3.689 / 3.47e-4
  ≈ 10,630 seconds
  ≈ 2.95 hours
```

After two more prestiges (`prestigeCount = 6`), `softCap` becomes
`49` — still under the asymptotic max raw of `51`, so almost any
high-accuracy network will be unconstrained. From `prestigeCount = 7`
upward, the soft cap stops binding entirely.
