import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:number_flutter/logic/leaderboard_ranking.dart';

void main() {
  group('highestNumberSortKey', () {
    test('never decreases as the number grows', () {
      final random = math.Random(42);
      final values = <BigInt>[
        BigInt.zero,
        BigInt.one,
        BigInt.from(9),
        BigInt.from(10),
        BigInt.from(99),
        BigInt.from(100),
        BigInt.parse('9' * 15),
        BigInt.parse('1${'0' * 15}'),
        BigInt.parse('9' * 40),
        BigInt.parse('1${'0' * 40}'),
        BigInt.from(10).pow(500) + BigInt.one,
        BigInt.from(10).pow(500) * BigInt.two,
        for (var i = 0; i < 300; i++)
          BigInt.parse(
            '${random.nextInt(9) + 1}'
            '${List.generate(random.nextInt(60), (_) => random.nextInt(10)).join()}',
          ),
      ]..sort();

      for (var i = 1; i < values.length; i++) {
        expect(
          highestNumberSortKey(values[i]),
          greaterThanOrEqualTo(highestNumberSortKey(values[i - 1])),
          reason: '${values[i - 1]} < ${values[i]}',
        );
      }
    });

    test('separates different magnitudes', () {
      expect(highestNumberSortKey(BigInt.from(100)),
          greaterThan(highestNumberSortKey(BigInt.from(99))));
      expect(highestNumberSortKey(BigInt.from(10).pow(500)),
          closeTo(500, 1e-9));
      expect(highestNumberSortKey(BigInt.zero),
          lessThan(highestNumberSortKey(BigInt.one)));
    });
  });

  test('withDenseRank gives ties the same rank without gaps', () {
    final rows = [
      {'v': 9},
      {'v': 9},
      {'v': 7},
      {'v': 5},
      {'v': 5},
      {'v': 1},
    ];
    final ranks = withDenseRank(rows, (row) => row['v'])
        .map((row) => row['rank'])
        .toList();
    expect(ranks, [1, 1, 2, 3, 3, 4]);
  });
}
