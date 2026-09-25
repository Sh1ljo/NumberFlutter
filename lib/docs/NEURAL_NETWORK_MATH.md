# Neural Network Math

**Accurate as of the V0.19 rebalance.** Read back out of `lib/models/neural_network.dart` and
`lib/logic/game_state.dart` at the time of writing.

The previous revision of this file was wrong on nearly every constant — it documented
`k = 0.00008` (80× the real value), a boost scale of 50, a soft cap of 8 per prestige, a
`MIN_LOSS` of `1e-6`, a gradient range of 0..5, and `accuracy = 1 - loss`. None of that was
true. It also claimed "~3 hours to loss 0.01", which was off by roughly two orders of
magnitude.

> **V0.20:** the network now grows past the pyramid into four prestige-gated **deep layers**
> and loops through **Epochs**. See §9. Where the sections below say "22 neurons" or "GL9",
> that's the pyramid and Epoch 0.

---

## 1. Structure

A left-to-right pyramid of up to **7 layers / 22 neurons**:

```
targetNeuronCountForLayer:  [1, 2, 4, 8, 4, 2, 1]
```

Layer index ≥ 7 returns 0. Neuron ids are `layer_<layerIndex>_neuron_<slot>`, and the **slot
is parsed back out of the id** for positioning — so an existing neuron never moves when a
sibling appears.

### Expansion rules

Only the *leading* neurons may branch once the pyramid starts shrinking
(`isEligibleParentIndex`):

| Layer | Eligible parents | Children created |
|---|---|---|
| 0, 1, 2 | all | fills the next layer's target |
| 3 | neurons 0 and 1 | 4 in layer 4 |
| 4 | neuron 0 | 2 in layer 5 |
| 5 | neuron 0 | 1 in layer 6 |
| 6 | none (terminal) | — |

Expansion is strictly left-to-right, gated by `activeExpansionLayerIndex`: the leftmost layer
that still has an unbranched eligible neuron. A neuron in a later layer cannot branch until
every eligible parent in the active layer has.

When a parent branches, it spawns only **its own slice** of the next layer
(`perParent = targetNext ~/ eligibleCount`, starting at
`startSlot = eligibleIndexOfParent × perParent`), so children appear under their parent's
column as each sibling branches rather than all at once. Children are kept sorted by slot.

---

## 2. Costs — all paid in `number`

### Gradient

```
maxGradientLevel = 9
gradientUpgradeCost = 50,000 × 12^gradientLevel
```

→ 50K, 600K, 7.2M, 86.4M, ~1.04B, ~12.4B, ~149.3B, ~1.79T, ~21.5T. Maxing all 22 neurons is
**~516 T**.

Deep layers (past the 7-layer pyramid) multiply this by an extra `15^depth`, so late-game deep
neurons cost dramatically more than pyramid ones at the same gradient level — see
`NeuralNeuron.baseGradientCost`.

`NeuralNeuron.maxGradientLevel` is the single source of truth — `NeuronDetailSheet` reads it
for both the `GR x/y` badge and the pip row. Those used to be hardcoded to 5 while the logic
capped at 9, so the UI claimed the neuron was maxed at level 5.

### Activation

```
activationChangeCost(fn) = 0        if fn == current, or fn == 'linear',
                                    or fn already in unlockedActivations
                         = 5,000,000  otherwise
```

`linear` is free and implicitly always unlocked. Once paid for, switching back to an
activation is free forever.

### Branching (adds a layer)

```
addLayerCost(currentLayerCount) = 4,000,000 × 10^(currentLayerCount - 1)
```

→ 4M, 40M, 400M, 4B, 40B, 400B. Charged **per branch** using the *current layer count*, so
every parent in the same expansion wave pays the same price. Fully expanding the pyramid costs
`4M + 2×40M + 4×400M + 2×4B + 40B + 400B ≈ **450 B**`.

---

## 3. Strength

```
depthBonus(layerIndex)      = 1.0 + 0.25 × layerIndex
activationBonus(neuron)     = 1.10 if neuron.activationFn == preferredActivationByLayer[idx]
                              else 1.00
contribution(neuron)        = (gradientLevel + 1) × depthBonus × activationBonus

strength = ln(1 + Σ contributions)
```

Preferred activations by layer: `0: linear, 1-4: relu, 5: tanh, 6: linear`.

Fully maxed (22 neurons, GL9, all preferred): `Σ ≈ 346.5`, so **strength ≈ 5.85**.

Log-shaped on purpose — late-game additions slow down gracefully instead of falling off a
cliff.

---

## 4. Loss decay

```
_neuralDt    = 0.1          // ticker period, seconds
_neuralDecayK = 0.000005
_neuralMinLoss = 0.001      // floor

loss <- clamp(loss × exp(-k × strength × dt), minLoss, 1.0)
```

Runs every tick whenever the network is unlocked, **regardless of whether the player owns an
auto-clicker**, and is applied in one shot for elapsed time on resume
(`_calculateOfflineProgress`).

Stochastic training jitter exists in the code but is currently disabled so accuracy progression
is strictly monotonic.

### Time to floor

```
t = ln(1 / minLoss) / (k × strength) = ln(1000) / (k × strength)
```

| Build | Strength | Time to loss 0.001 |
|---|---|---|
| Fully maxed | 5.85 | **~2.7 days** |
| Mid-game | 3.0 | ~5.3 days |
| Single neuron, GL0 | 0.69 | ~23 days |

`k` was `0.000001` before V0.19, which put a *fully maxed* network at **~13.7 days of pure
waiting** with no interaction available — a timer, not an end game. `test/economy_test.dart`
asserts the maxed figure stays in the 1-5 day band.

---

## 5. Displayed accuracy

```
x = clamp(1 - loss, 0, 1)
accuracy = log(1 + 9x) / log(10)
```

A log remap, **not** `1 - loss`. Early upgrades feel impactful and the curve asymptotes toward
100% without ever touching it. Consequences worth knowing:

- `loss = 1.0` → accuracy 0%
- `loss = 0.5` → accuracy **~74%** (not 50%)
- `loss = 0.001` → accuracy ~99.96%

The HUD additionally smooths the displayed percentage with an EMA (`alpha = 0.22`) so it
doesn't jitter at 10 Hz.

---

## 6. Gain multiplier

```
_neuralBoostScale        = 30.0
_neuralSoftCapPerPrestige = 5.0

raw      = max(1.0, 1 + (1 - loss) × 30)
softCap  = 1 + prestigeCount × 5
neuralLossMultiplier = min(raw, softCap)
```

Maximum raw is **31×** at the loss floor. The soft cap stops binding at `prestigeCount >= 6`,
so it only throttles a player who somehow reached the neural network unusually early — which
the ~800 PP unlock path (≈15 prestiges) makes unlikely by construction.

`neuralLossMultiplier` multiplies **both** idle and click income. `kineticBonus` derives from
`totalIdleRate`, which already carries the multiplier, so it is deliberately *not* applied a
second time there.

The HUD shows `MULT × (capped)` when `neuralLossMultiplier < neuralLossRawMultiplier`.

---

## 7. Persistence

`_saveVersion = 4`, with real migrations — this is the **one** save path in the project that
versions itself properly, and it's the pattern the rest of the game should follow
(see local save versioning in `LAUNCH_TODO.md`).

- v0/v1 → v2: layer/neuron normalisation
- pre-v4: activation grandfathering (a neuron already using a non-linear activation gets it
  added to `unlockedActivations` free, so existing players aren't re-charged)
- v3+: `loss` and `lowestLossEver` are persisted

`lowestLossEver` is monotonic and is merged across devices by taking the **minimum** of local
and remote, so a stale upload can never wipe a better training run.

**V0.20:** the full network JSON (`_saveVersion = 5`, adds `epochs`) now syncs to the cloud
as `player_progress.neural_network`. Rows written by older builds only carry the loss values,
and for those the local topology is kept.

A corrupt `neural_network` blob currently resets to `NeuralNetwork.initial()` **silently**,
with no warning and no backup (item 12).

---

## 8. Layout / rendering

Canvas geometry lives in `neural_canvas.dart` in canvas-local pixels:

```
_layerSpacing  = 120    _neuronSpacing = 80
_neuronSize    = 48     _canvasPadding = 80
_minScale      = 0.3    _maxScale      = 3.0
```

```
x = _canvasPadding + layer.index × _layerSpacing + _neuronSize / 2
y = canvasCenterY - ((slots - 1) × _neuronSpacing) / 2 + slot × _neuronSpacing
```

where `slots` is the layer's **target** count, so a neuron's position never shifts as siblings
fill in around it.

`_fitAndCenter` must compute its bounds from the **actual** neuron positions, not from the
target pyramid. Using targets meant that with layers 0(1), 1(2), 2(4), 3(2-of-8) the real
content spanned y 104→504 (centre 304) while the fit box spanned 80→688 (centre 384) — the
network rendered 80 px high and zoomed out over mostly-empty canvas until every slot filled.
See Part 3 of `IMPLEMENTATION_PLAN.md`.

---

## 9. Deep layers and Epochs (V0.20)

### Deep layers

```
layerTargets = [1, 2, 4, 8, 4, 2, 1,   2, 4, 2, 1]     // 22 pyramid + 9 deep = 31
deep layer 7 / 8 / 9 / 10 unlock at prestige 18 / 22 / 26 / 30
```

Eligibility is now a formula over `layerTargets` (it reproduces the old hand-written pyramid
rule exactly; `test/neural_expansion_test.dart` checks it). When growing into a bigger layer
every neuron branches. When shrinking, the first `ceil(next/2)` do. A neuron whose next layer
is still prestige-locked reports `NeuronBranchBlock.depthLocked`.

- Branch cost keeps the ×8 curve, so layer 7 costs ~262B and layer 10 ~134T.
- Deep gradient levels cost `10^(layer − 6)` times the pyramid price.
- Each existing deep layer raises the boost scale by 10, from `30` up to `70`. Deep layers
  raise the ceiling instead of only making training faster.

### Epochs

Available once `loss ≤ 0.01`. An Epoch resets `loss` to 1 and every gradient level to 0, and
keeps the topology, activations and `lowestLossEver`. Each Epoch permanently grants:

```
production          × (1 + 0.1 × epochs)             // via globalProductionMultiplier
soft cap / prestige   5 + epochs
gradient cap          min(9 + epochs, 15)
decay k               k × 0.85^epochs                 // each Epoch trains slower
```

So each loop takes longer than the last but pays more, and the higher gradient cap adds
something new to buy every time.
