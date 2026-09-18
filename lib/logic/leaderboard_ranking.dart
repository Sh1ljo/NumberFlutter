import 'dart:math' as math;

/// Firestore can't order BigInt strings numerically, so the leaderboard
/// stores this key instead: the number's log10 as a double.
///
/// `digits - 1` gives the magnitude and the leading 15 digits give the
/// fraction, so the key never decreases as the number grows (a < b implies
/// key(a) <= key(b)) and has no length limit. Numbers that agree in their
/// first ~15 digits can tie, which only makes them share a rank.
double highestNumberSortKey(BigInt value) {
  if (value <= BigInt.zero) return -1.0;
  final digits = value.toString();
  final leadLength = math.min(15, digits.length);
  final lead = double.parse(digits.substring(0, leadLength));
  final fraction = math.log(lead) / math.ln10 - (leadLength - 1);
  // Guard float rounding at the top of a magnitude (e.g. 999...9 -> 1.0).
  return (digits.length - 1) + fraction.clamp(0.0, 1.0);
}

/// Dense ranking over rows that are already sorted best-first: equal values
/// share a rank and the next distinct value gets the next rank, matching the
/// old Postgres `dense_rank()`.
List<Map<String, dynamic>> withDenseRank(
  List<Map<String, dynamic>> sortedRows,
  Object? Function(Map<String, dynamic> row) valueOf,
) {
  var rank = 0;
  Object? previous;
  final ranked = <Map<String, dynamic>>[];
  for (var i = 0; i < sortedRows.length; i++) {
    final value = valueOf(sortedRows[i]);
    if (i == 0 || value != previous) rank++;
    previous = value;
    ranked.add({...sortedRows[i], 'rank': rank});
  }
  return ranked;
}
