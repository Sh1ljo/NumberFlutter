import 'dart:math' as math;

class PlayerProgress {
  final String userId;
  final BigInt number;
  final BigInt clickPower;
  final double autoClickRate;
  final double prestigeCurrency;
  final double prestigeMultiplier;
  final int prestigeCount;
  final Map<String, int> upgradeLevels;
  final BigInt highestNumber;
  final int progressScore;
  final DateTime updatedAt;

  const PlayerProgress({
    required this.userId,
    required this.number,
    required this.clickPower,
    required this.autoClickRate,
    required this.prestigeCurrency,
    required this.prestigeMultiplier,
    required this.prestigeCount,
    required this.upgradeLevels,
    required this.highestNumber,
    required this.progressScore,
    required this.updatedAt,
  });

  int get totalUpgradeLevels =>
      upgradeLevels.values.fold<int>(0, (sum, level) => sum + level);

  BigInt get normalizedHighestNumber =>
      highestNumber > number ? highestNumber : number;

  static int calculateProgressScore({
    required BigInt number,
    required int prestigeCount,
    required double prestigeCurrency,
    required Map<String, int> upgradeLevels,
  }) {
    final numberDigits = number == BigInt.zero ? 1 : number.toString().length;
    final upgradesTotal =
        upgradeLevels.values.fold<int>(0, (sum, level) => sum + level);
    final prestigeCurrencyScaled = (prestigeCurrency * 1000).floor();
    final logScore = (math.log(numberDigits + 1) / math.ln10 * 1000).floor();

    // Bounded deterministic score that fits PostgreSQL bigint.
    return (prestigeCount * 100000000).clamp(0, 9000000000000000000).toInt() +
        (prestigeCurrencyScaled * 10000) +
        (upgradesTotal * 10) +
        logScore;
  }

  PlayerProgress copyWith({
    BigInt? number,
    BigInt? clickPower,
    double? autoClickRate,
    double? prestigeCurrency,
    double? prestigeMultiplier,
    int? prestigeCount,
    Map<String, int>? upgradeLevels,
    BigInt? highestNumber,
    int? progressScore,
    DateTime? updatedAt,
  }) {
    return PlayerProgress(
      userId: userId,
      number: number ?? this.number,
      clickPower: clickPower ?? this.clickPower,
      autoClickRate: autoClickRate ?? this.autoClickRate,
      prestigeCurrency: prestigeCurrency ?? this.prestigeCurrency,
      prestigeMultiplier: prestigeMultiplier ?? this.prestigeMultiplier,
      prestigeCount: prestigeCount ?? this.prestigeCount,
      upgradeLevels: upgradeLevels ?? this.upgradeLevels,
      highestNumber: highestNumber ?? this.highestNumber,
      progressScore: progressScore ?? this.progressScore,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'user_id': userId,
      'number_numeric': number.toString(),
      'click_power_numeric': clickPower.toString(),
      'auto_click_rate': autoClickRate,
      'prestige_currency': prestigeCurrency,
      'prestige_multiplier': prestigeMultiplier,
      'prestige_count': prestigeCount,
      'upgrade_levels': upgradeLevels,
      'highest_number_numeric': normalizedHighestNumber.toString(),
      'progress_score': progressScore,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory PlayerProgress.fromDatabase(Map<String, dynamic> row) {
    final levelsRaw = row['upgrade_levels'] as Map<String, dynamic>? ?? {};
    final upgradeLevels = levelsRaw.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );

    final parsedNumber =
        BigInt.tryParse(row['number_numeric'] as String? ?? '');
    final parsedHighest =
        BigInt.tryParse(row['highest_number_numeric'] as String? ?? '');

    return PlayerProgress(
      userId: row['user_id'] as String,
      number: parsedNumber ?? BigInt.zero,
      clickPower:
          BigInt.tryParse(row['click_power_numeric'] as String? ?? '') ??
              BigInt.from(50),
      autoClickRate: (row['auto_click_rate'] as num?)?.toDouble() ?? 0.0,
      prestigeCurrency: (row['prestige_currency'] as num?)?.toDouble() ?? 0.0,
      prestigeMultiplier:
          (row['prestige_multiplier'] as num?)?.toDouble() ?? 1.0,
      prestigeCount: (row['prestige_count'] as num?)?.toInt() ?? 0,
      upgradeLevels: upgradeLevels,
      highestNumber: parsedHighest ?? parsedNumber ?? BigInt.zero,
      progressScore: (row['progress_score'] as num?)?.toInt() ??
          calculateProgressScore(
            number: parsedNumber ?? BigInt.zero,
            prestigeCount: (row['prestige_count'] as num?)?.toInt() ?? 0,
            prestigeCurrency:
                (row['prestige_currency'] as num?)?.toDouble() ?? 0.0,
            upgradeLevels: upgradeLevels,
          ),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
