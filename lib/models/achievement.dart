import '../logic/game_state.dart';

enum AchievementCategory {
  numbers('NUMBERS'),
  clicks('CLICKS'),
  upgrades('UPGRADES'),
  prestige('PRESTIGE'),
  nexus('NEXUS'),
  neural('NEURAL'),
  mechanics('MECHANICS'),
  artifacts('ARTIFACTS'),
  secret('SECRET');

  const AchievementCategory(this.label);
  final String label;
}

class AchievementDef {
  final String id;
  final AchievementCategory category;
  final String title;
  final String description;

  /// Polled state check. Null for event achievements, which GameState
  /// unlocks directly at the moment they happen.
  final bool Function(GameState state)? isMet;

  /// Hidden achievements show as ??? until unlocked.
  final bool hidden;

  const AchievementDef({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    this.isMet,
    this.hidden = false,
  });
}
