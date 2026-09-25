import 'package:flutter/material.dart' show IconData, Icons;

import 'trial_calendar.dart';

/// Each week pairs one [TrialModifierKind.twist] (changes *how* you play)
/// with one [TrialModifierKind.rule] (changes the economy). Both are the
/// same for every player that week.
enum TrialModifierKind { twist, rule }

enum TrialModifier {
  // ── Twists ──────────────────────────────────────────────────────────────
  momentum(
    kind: TrialModifierKind.twist,
    title: 'Momentum',
    summary: 'Tapping builds a combo, up to ×4 production',
    description:
        'Every tap adds to a combo that multiplies ALL production, up to ×4. '
        'Stop tapping and it drains within a few seconds.',
    icon: Icons.bolt,
  ),
  handsOff(
    kind: TrialModifierKind.twist,
    title: 'Hands Off',
    summary: 'No tapping, production ×3',
    description: 'Tapping is disabled for the whole week. In exchange, every '
        'generator produces ×3. Pure strategy: what you buy is all that counts.',
    icon: Icons.do_not_touch_outlined,
  ),
  market(
    kind: TrialModifierKind.twist,
    title: 'Volatile Market',
    summary: 'Prices swing ±40% every 3 minutes',
    description: 'All prices drift between −40% and +40% on a 3-minute wave. '
        'The gauge shows where they are. Buy the dip.',
    icon: Icons.show_chart,
  ),
  jackpot(
    kind: TrialModifierKind.twist,
    title: 'Jackpot',
    summary: '1 in 150 taps pays a minute of production',
    description: 'Every tap has a 1-in-150 chance to pay out a full minute of '
        'your production at once.',
    icon: Icons.casino_outlined,
  ),
  nightShift(
    kind: TrialModifierKind.twist,
    title: 'Night Shift',
    summary: 'Away earnings ×4, live production ×0.5',
    description: 'While you are away from the Trial it earns ×4. While you are '
        'watching, production is halved. Check in, spend, leave.',
    icon: Icons.nightlight_outlined,
  ),
  chainReaction(
    kind: TrialModifierKind.twist,
    title: 'Chain Reaction',
    summary: 'Each generator boosts the next one up',
    description:
        'Every unit of a generator boosts the generator one tier above it '
        'by +3%. Cheap tiers are never wasted.',
    icon: Icons.link,
  ),

  // ── Rules ───────────────────────────────────────────────────────────────
  glassCannon(
    kind: TrialModifierKind.rule,
    title: 'Glass Cannon',
    summary: 'Taps ×10, generators ×0.5',
    description:
        'Taps are ten times stronger, but generators produce half as much. '
        'A week for active players.',
    icon: Icons.flash_on,
  ),
  inflation(
    kind: TrialModifierKind.rule,
    title: 'Inflation',
    summary: 'Prices climb faster, production ×2',
    description:
        'Every purchase raises that generator\'s price faster than usual, '
        'but all production is doubled. Spread your buys.',
    icon: Icons.trending_up,
  ),
  blackout(
    kind: TrialModifierKind.rule,
    title: 'Blackout',
    summary: 'Away earnings 10%, live production ×2',
    description:
        'While you are away the Trial only earns 10%. While you are here, '
        'production is doubled.',
    icon: Icons.power_off_outlined,
  ),
  minimalist(
    kind: TrialModifierKind.rule,
    title: 'Minimalist',
    summary: 'Only 4 generators, each ×4',
    description: 'The top two generators do not exist this week. The four that '
        'remain produce ×4.',
    icon: Icons.filter_4,
  ),
  milestoneMadness(
    kind: TrialModifierKind.rule,
    title: 'Milestone Madness',
    summary: 'Milestones every 10 units',
    description:
        'Generators hit a milestone every 10 units (×1.5) instead of every '
        '25 (×2). Wide builds pay off.',
    icon: Icons.stacked_bar_chart,
  ),
  wildcard(
    kind: TrialModifierKind.rule,
    title: 'Wildcard',
    summary: 'Drafts offer 4 perks instead of 3',
    description:
        'Every Draft offers four perks to choose from instead of three.',
    icon: Icons.style_outlined,
  );

  const TrialModifier({
    required this.kind,
    required this.title,
    required this.summary,
    required this.description,
    required this.icon,
  });

  final TrialModifierKind kind;
  final String title;
  final String summary;
  final String description;
  final IconData icon;

  static List<TrialModifier> get twists =>
      values.where((m) => m.kind == TrialModifierKind.twist).toList();
  static List<TrialModifier> get rules =>
      values.where((m) => m.kind == TrialModifierKind.rule).toList();
}

/// Pairs that cancel each other out or make no sense together.
bool _conflicts(TrialModifier twist, TrialModifier rule) {
  if (twist == TrialModifier.handsOff && rule == TrialModifier.glassCannon) {
    return true;
  }
  if (twist == TrialModifier.nightShift && rule == TrialModifier.blackout) {
    return true;
  }
  return false;
}

/// Picks a week's modifiers. Twists and rules each step forward every week,
/// so back-to-back weeks never repeat either one, and the offset between the
/// two cycles shifts every 6 weeks so all 36 pairings come up over time.
List<TrialModifier> modifiersForWeek(TrialWeek week) =>
    modifiersForWeekIndex(week.index);

List<TrialModifier> modifiersForWeekIndex(int weekIndex) {
  final twists = TrialModifier.twists;
  final rules = TrialModifier.rules;
  final twist = twists[weekIndex % twists.length];
  var ruleIndex = (weekIndex + weekIndex ~/ twists.length + 2) % rules.length;
  // Neighbouring weeks use rule index −1 and +1/+2, so jumping by half the
  // cycle can't land on either of them. Each twist conflicts with at most
  // one rule, so one jump always clears the conflict.
  if (_conflicts(twist, rules[ruleIndex])) {
    ruleIndex = (ruleIndex + rules.length ~/ 2) % rules.length;
  }
  return [twist, rules[ruleIndex]];
}

/// Perks offered by Drafts. They stack: picking the same one twice applies
/// it twice.
enum TrialPerk {
  sharpTaps(
    title: 'Sharp Taps',
    description: 'Taps ×3',
    icon: Icons.touch_app_outlined,
    needsTapping: true,
  ),
  critical(
    title: 'Critical Taps',
    description: '15% of taps hit ×10',
    icon: Icons.gps_fixed,
    needsTapping: true,
  ),
  overtime(
    title: 'Overtime',
    description: 'All production ×1.5',
    icon: Icons.speed,
  ),
  discount(
    title: 'Bulk Discount',
    description: 'All prices −25%',
    icon: Icons.sell_outlined,
  ),
  windfall(
    title: 'Windfall',
    description: 'Instantly gain 20 minutes of production',
    icon: Icons.savings_outlined,
  ),
  nightOwl(
    title: 'Night Owl',
    description: 'Away earnings ×2 and +4h away cap',
    icon: Icons.bedtime_outlined,
    needsAwayEarnings: true,
  ),
  specialist(
    title: 'Specialist',
    description: 'Your highest generator ×3',
    icon: Icons.workspace_premium_outlined,
  ),
  synergy(
    title: 'Synergy',
    description: '+15% production per generator type owned',
    icon: Icons.hub_outlined,
  ),
  bootstrap(
    title: 'Bootstrap',
    description: 'Your two cheapest generators ×6',
    icon: Icons.rocket_launch_outlined,
  );

  const TrialPerk({
    required this.title,
    required this.description,
    required this.icon,
    this.needsTapping = false,
    this.needsAwayEarnings = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool needsTapping;
  final bool needsAwayEarnings;
}

/// The perks a Draft offers. Seeded by week and draft number, so everyone
/// who reaches the same Draft in the same week sees the same choices; the
/// difference between players is what they pick.
List<TrialPerk> draftOptions({
  required int weekIndex,
  required int draftNumber,
  required List<TrialModifier> modifiers,
}) {
  final pool = TrialPerk.values.where((perk) {
    if (perk.needsTapping && modifiers.contains(TrialModifier.handsOff)) {
      return false;
    }
    if (perk.needsAwayEarnings && modifiers.contains(TrialModifier.blackout)) {
      return false;
    }
    return true;
  }).toList();
  final count = modifiers.contains(TrialModifier.wildcard) ? 4 : 3;
  final rng = TrialRandom(weekIndex * 1009 + draftNumber * 7919 + 17);
  // Partial Fisher–Yates: the first [count] entries end up shuffled.
  for (var i = 0; i < count && i < pool.length; i++) {
    final j = i + rng.nextInt(pool.length - i);
    final tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }
  return pool.take(count).toList();
}

/// Park–Miller generator. Dart's own `Random(seed)` is not guaranteed to give
/// the same sequence on the web as on mobile, and Drafts must be identical
/// for everyone. Every intermediate stays below 2^53, so it is exact when
/// compiled to JavaScript too.
class TrialRandom {
  static const int _modulus = 2147483647;
  static const int _multiplier = 48271;

  int _state;

  TrialRandom(int seed) : _state = _normalise(seed);

  static int _normalise(int seed) {
    final s = seed.abs() % _modulus;
    return s == 0 ? 1 : s;
  }

  int _next() {
    _state = (_state * _multiplier) % _modulus;
    return _state;
  }

  /// Uniform in [0, max).
  int nextInt(int max) {
    assert(max > 0);
    return _next() % max;
  }

  /// Uniform in [0, 1).
  double nextDouble() => (_next() - 1) / (_modulus - 1);
}
