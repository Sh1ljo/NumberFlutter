# NumberFlutter - Gameplay Math Reference (Current)

This is the current math as implemented in code.

## 1) Notation

- `floor(x)` = integer floor.
- `L` = upgrade level.
- `eff(L)` = effective level after milestone multiplier.
- `PC` = `prestigeCount`.

## 2) Milestone Multiplier

Milestone thresholds:

- 25, 50, 100, 250, 500, 1000

Milestone multiplier:

- `milestoneMultiplier(L) = 2^(#thresholds reached by L)`

Effective level used by most special mechanics:

- `eff(L) = L * milestoneMultiplier(L)`

## 3) Upgrade Cost Model

For an upgrade with base cost `B` and cost multiplier `r`:

- Next-level cost at level `L`:  
  `cost(L) = floor(B * r^L)`

Bulk purchase:

- `k` buys sum the next `k` step costs.
- `MAX` buys step-by-step until currency is insufficient.

## 4) Click and Idle Core Equations

### 4.1 Click gain per tap

Base click gain:

- `baseClick = clickPower * prestigeMultiplier * permanentClickMultiplier`

Kinetic contribution:

- `kineticBonus = totalIdleRate * kineticShare`

Momentum:

- `momentumMult` (from Momentum rules below)

Probability Strike:

- if triggered, multiply by `probabilityStrikeMult`

Final tap gain:

- `tapGain = floor((baseClick + kineticBonus) * momentumMult * strikeFactor)`
- where `strikeFactor = probabilityStrikeMult` if strike triggers, else `1`

### 4.2 Idle gain rate

- `totalIdleRate = autoClickRate * prestigeMultiplier * permanentIdleMultiplier * overclockFactor`
- `overclockFactor = overclockIdleMultiplier` when overclock active, else `1`

Ticker:

- Runs every `100 ms` (10 ticks/sec)
- adds `totalIdleRate / 10` into an accumulator
- converts integer part of accumulator to `number`

## 5) Upgrade Catalog (Current Values)

## CLICK upgrades

1. `Click Power`
   - base cost: `100`
   - cost multiplier: `1.45`
   - effect: `clickPower += 50 * eff(L)`

2. `Probability Strike`
   - base cost: `2500`
   - cost multiplier: `1.72`
   - chance (if `eff(L) > 0`): `5%` fixed
   - strike multiplier: `10 + 2 * (eff(L) - 1)`

3. `Momentum`
   - base cost: `8000`
   - cost multiplier: `1.68`
   - per-click combo bonus:  
     `momentumPerClickBonus = 0.02 + 0.006 * (eff(L) - 1)` for `eff(L) > 0`
   - cap:  
     `momentumCap = 2.0 + 0.35 * (eff(L) - 1)` for `eff(L) > 0`
   - decay window:  
     `momentumDecayWindowMs = min(2500, 1000 + 120 * (eff(L) - 1))`
   - grace period before decay: `2000 ms`
   - clicks-to-cap helper:  
     `clicksToCap = max(5, ceil((momentumCap - 1) / momentumPerClickBonus) + 1)`

4. `Kinetic Synergy`
   - base cost: `40000`
   - cost multiplier: `1.75`
   - idle-to-click share: `kineticShare = 0.01 * eff(L)`

5. `Overclock`
   - base cost: `125000`
   - cost multiplier: `1.82`
   - streak trigger requirement:  
     `overclockStreakRequirement = max(20, 50 - 3 * (eff(L) - 1))`
   - idle multiplier while active:  
     `overclockIdleMultiplier = 2.0 + 0.4 * (eff(L) - 1)`
   - active duration (seconds):  
     `overclockDurationSeconds = min(180, 30 + 5 * (eff(L) - 1))`

## IDLE upgrades

All idle effects add directly to `autoClickRate`:

1. `Auto-Clicker`
   - base cost: `50`
   - multiplier: `1.15`
   - effect: `+1 * eff(L)` numbers/sec

2. `Quantum Multiplier`
   - base cost: `1500`
   - multiplier: `1.85`
   - effect: `+10 * eff(L)` numbers/sec

3. `Fractal Engine`
   - base cost: `7500`
   - multiplier: `1.55`
   - effect: `+100 * eff(L)` numbers/sec

4. `Singularity Core`
   - base cost: `65000`
   - multiplier: `1.58`
   - effect: `+1000 * eff(L)` numbers/sec

5. `Tesseract Array`
   - base cost: `750000`
   - multiplier: `1.62`
   - effect: `+10000 * eff(L)` numbers/sec

6. `Entropy Harvester`
   - base cost: `9000000`
   - multiplier: `1.66`
   - effect: `+100000 * eff(L)` numbers/sec

7. `Void Resonance`
   - base cost: `120000000`
   - multiplier: `1.70`
   - effect: `+1000000 * eff(L)` numbers/sec

## 6) Prestige Math

### 6.1 Requirement and reward

- Requirement for next prestige:
  - `prestigeRequirement(PC) = floor(10000 * 1.32^PC)`

- Reward for next prestige:
  - `prestigeReward(PC) = 1.0 * 1.18^PC`

- Prestige points earned on activate:
  - if `number < requirement`, earn `0`
  - else earn exactly `prestigeReward(PC)`

### 6.2 Prestige multiplier growth

Per-prestige delta at prestige index `i` (0-based):

- `prestigeDelta(i) = 0.028 + 0.011 * i`

On prestige:

- `prestigeCurrency += prestigeReward(PC)`
- `prestigeMultiplier += prestigeDelta(PC)`
- `prestigeCount += 1`
- then reset number and non-permanent upgrades/progression runtime state

Closed-form total after `n` prestiges (derived from implemented sequence):

- `prestigeMultiplier(n) = 1 + n * 0.028 + 0.011 * n * (n - 1) / 2`

## 7) Permanent Prestige Shop Math (Logic Exists, UI Hidden)

Even though the shop UI is removed, these formulas still exist in state logic.

### 7.1 Cost

Cost at shop rank `r`:

- `shopCost(r) = 1 + r / 14`

### 7.2 Permanent multiplier growth

Per-purchase delta at purchase index `i`:

- `permDelta(i) = 0.014 + 0.006 * i`

Permanent multiplier after `n` purchases:

- `permMultiplier(n) = 1 + sum(i=0..n-1) permDelta(i)`
- equivalent closed form:
  - `permMultiplier(n) = 1 + n * 0.014 + 0.006 * n * (n - 1) / 2`

Applied as:

- `permanentClickMultiplier` in click equation
- `permanentIdleMultiplier` in idle equation

## 8) Offline Progress Formula

If `lastPlayed` exists and `autoClickRate > 0`:

- `secondsAway = now - lastPlayed`
- `offlineRate = autoClickRate * prestigeMultiplier * permanentIdleMultiplier`
- `offlineGains = floor(offlineRate * secondsAway)`

`offlineGains` is added to `number` at load and shown in the offline gains dialog.

## 9) Sync / Leaderboard Progress Score Math

Cloud winner selection primarily uses `progressScore`.

Progress score:

- `numberDigits = len(number as string)` (minimum 1)
- `upgradesTotal = sum(all upgrade levels)`
- `shopTotal = permanentClickPurchases + permanentIdlePurchases`
- `prestigeCurrencyScaled = floor(prestigeCurrency * 1000)`
- `logScore = floor(log10(numberDigits + 1) * 1000)`

Score:

- `progressScore = clamp(prestigeCount * 100000000, 0, 9e18)`
  `+ prestigeCurrencyScaled * 10000`
  `+ shopTotal * 1000`
  `+ upgradesTotal * 10`
  `+ logScore`

Tie-breakers:

1. Higher `progressScore`
2. Higher `highestNumber`
3. Newer `updatedAt`
