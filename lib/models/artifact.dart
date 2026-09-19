import 'dart:math' as math;

class ArtifactDef {
  final String id;
  final String name;
  final String tagline;

  /// Effect text at [level] (level >= 1).
  final String Function(int level) describe;

  const ArtifactDef({
    required this.id,
    required this.name,
    required this.tagline,
    required this.describe,
  });
}

/// Persistent artifact progress: which artifacts are owned and at what
/// level, how many prestige milestones have been claimed, and the offer
/// waiting on the next unclaimed milestone.
class ArtifactState {
  /// Prestige counts that each grant one artifact choice.
  static const List<int> milestones = [1, 5, 10, 15, 20, 30, 40, 50];
  static const int offerSize = 3;

  static const double empowerBaseCost = 15.0;
  static const double empowerCostGrowth = 1.45;

  final Map<String, int> levels;
  int claimedMilestones;
  List<String>? currentOffer;
  int seed;

  ArtifactState({
    Map<String, int>? levels,
    this.claimedMilestones = 0,
    this.currentOffer,
    int? seed,
  })  : levels = levels ?? <String, int>{},
        seed = seed ?? math.Random().nextInt(1 << 30);

  int levelOf(String id) => levels[id] ?? 0;
  int get ownedCount => levels.values.where((l) => l > 0).length;
  int get highestLevel => levels.values.fold<int>(0, (m, l) => l > m ? l : m);

  static int milestonesReached(int prestigeCount) =>
      milestones.where((m) => prestigeCount >= m).length;

  /// Prestige count of the next milestone not yet reached, or null.
  static int? nextMilestoneAfter(int prestigeCount) {
    for (final m in milestones) {
      if (m > prestigeCount) return m;
    }
    return null;
  }

  int pendingChoices(int prestigeCount) {
    final pending = milestonesReached(prestigeCount) - claimedMilestones;
    return pending < 0 ? 0 : pending;
  }

  /// PP cost to raise an artifact from [level] to level + 1.
  static double empowerCost(int level) =>
      empowerBaseCost * math.pow(empowerCostGrowth, level - 1).toDouble();

  /// The offer for the next unclaimed milestone, generated deterministically
  /// from [seed] the first time it is needed so an app restart can't reroll
  /// it. Returns null when nothing is pending.
  List<String>? ensureOffer(int prestigeCount, List<String> allIds) {
    if (pendingChoices(prestigeCount) <= 0) return null;
    final existing = currentOffer;
    if (existing != null && existing.isNotEmpty) return existing;
    final pool = allIds.where((id) => levelOf(id) == 0).toList();
    if (pool.isEmpty) return null;
    final rng = math.Random(seed + claimedMilestones * 7919);
    pool.shuffle(rng);
    currentOffer = pool.take(offerSize).toList();
    return currentOffer;
  }

  /// Takes [id] from the current offer. Returns false if it isn't on offer.
  bool choose(String id) {
    final offer = currentOffer;
    if (offer == null || !offer.contains(id)) return false;
    levels[id] = 1;
    claimedMilestones++;
    currentOffer = null;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'levels': levels,
        'claimed': claimedMilestones,
        'offer': currentOffer,
        'seed': seed,
      };

  factory ArtifactState.fromJson(Map<String, dynamic> j) {
    final rawLevels = j['levels'];
    final levels = <String, int>{};
    if (rawLevels is Map) {
      rawLevels.forEach((k, v) {
        if (k is String && v is num && v > 0) levels[k] = v.toInt();
      });
    }
    final rawOffer = j['offer'];
    return ArtifactState(
      levels: levels,
      claimedMilestones:
          ((j['claimed'] as num?)?.toInt() ?? 0).clamp(0, milestones.length),
      currentOffer:
          rawOffer is List ? rawOffer.whereType<String>().toList() : null,
      seed: (j['seed'] as num?)?.toInt(),
    );
  }
}
