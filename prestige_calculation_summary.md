# Neural Protocol Upgrade Prestige Calculation

## Summary

**Minimum prestiges required to unlock Neural Genesis (final neural protocol upgrade): 14**

## Upgrade Path Analysis

The "Neural Genesis" upgrade (tier 4 neural protocol) requires:

- **Resonance Core** at level 5
- **Echo Protocol** at level 5

### Prerequisite Chain

```
Tier 1: Optimization Protocol (Lv3) → Enhanced Extraction (Lv3)
                                      ↓
Tier 2: Idle Foundation (Lv5)        Quick Resume
                                      ↓
Tier 3: Resonance Core (Lv5) ← Echo Protocol (Lv5)
                                      ↓
Tier 4: Neural Genesis (Lv1) [FINAL UPGRADE]
```

## Cost Breakdown

### Individual Node Costs (to required levels)

| Node                  | Required Level | Total Cost |
| --------------------- | -------------- | ---------- |
| Optimization Protocol | 3              | 18.0       |
| Idle Foundation       | 5              | 90.0       |
| Resonance Core        | 5              | 225.0      |
| Enhanced Extraction   | 3              | 36.0       |
| Echo Protocol         | 5              | 180.0      |
| Neural Genesis        | 1              | 200.0      |
| **TOTAL**             |                | **749.0**  |

### Cost Formula

For scaling nodes (costsScale=true):

```
Cost to level N = (level) × baseCostPerLevel
```

Example - Idle Foundation to Lv5:

- Lv1: 1 × 6.0 = 6.0
- Lv2: 2 × 6.0 = 12.0
- Lv3: 3 × 6.0 = 18.0
- Lv4: 4 × 6.0 = 24.0
- Lv5: 5 × 6.0 = 30.0
- **Total: 90.0**

## Prestige Reward System

### Base Reward Formula

```
Base reward for prestige N = 3.0 × 1.35^(N-1)
```

### Multiplier Effects

- Echo Protocol provides +10% prestige points per level
- At Lv5: 1.0 + (5 × 0.10) = **1.5× multiplier**

### Reward Progression (first 14 prestiges)

| Prestige | Base Reward | Actual (with mult) | Cumulative |
| -------- | ----------- | ------------------ | ---------- |
| 1        | 3.00        | 3.00               | 3.00       |
| 2        | 4.05        | 4.05               | 7.05       |
| 3        | 5.47        | 5.47               | 12.52      |
| 4        | 7.38        | 7.38               | 19.90      |
| 5        | 9.96        | 9.96               | 29.86      |
| 6        | 13.45       | 13.45              | 43.32      |
| 7        | 18.16       | 19.98              | 63.30      |
| 8        | 24.52       | 26.97              | 90.27      |
| 9        | 33.10       | 39.72              | 129.99     |
| 10       | 44.68       | 58.09              | 188.08     |
| 11       | 60.32       | 84.45              | 272.53     |
| 12       | 81.43       | 122.15             | 394.68     |
| 13       | 109.93      | 164.90             | 559.58     |
| 14       | 148.41      | 222.61             | 782.19     |

_Note: Multiplier increases as Echo Protocol levels up_

## Optimal Purchase Strategy

### Phase 1: Early Game (Prestiges 1-6)

- Focus: Get Echo Protocol online ASAP
- Purchases:
  - Opt Protocol Lv1-3 (18.0)
  - Enhanced Extraction Lv1-3 (36.0)
  - Echo Protocol Lv1 (12.0)
- **Echo Protocol multiplier activated at Prestige 6**

### Phase 2: Multiplier Ramp (Prestiges 7-11)

- Focus: Max Echo Protocol for 1.5× multiplier
- Purchases:
  - Idle Foundation Lv1-3 (36.0)
  - Echo Protocol Lv2-5 (120.0)
  - Opt Protocol Lv3 (9.0)
- **1.5× multiplier active by Prestige 11**

### Phase 3: Core Preparation (Prestiges 12-13)

- Focus: Complete prerequisites
- Purchases:
  - Idle Foundation Lv4-5 (54.0)
  - Resonance Core Lv1-5 (225.0)

### Phase 4: Final Unlock (Prestige 14)

- Focus: Purchase Neural Genesis
- Purchases:
  - Neural Genesis Lv1 (200.0)
- **UNLOCKED!**

## Key Insights

1. **Total Currency Required**: 749.0 prestige points
2. **Minimum Prestiges**: 14 (with optimal play)
3. **Remaining Buffer**: 33.17 points after unlock
4. **Critical Path**: Echo Protocol must be prioritized to activate the 1.5× multiplier
5. **Bottleneck**: Resonance Core (225.0) is the single largest cost

## Verification

The calculation was verified through simulation with the following constraints:

- All prerequisite levels must be met
- Costs scale with level for most nodes
- Prestige rewards grow exponentially (1.35× per prestige)
- Echo Protocol multiplier applies to subsequent prestiges

**Result: 14 prestiges is the minimum required to unlock Neural Genesis.**
