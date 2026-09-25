import 'package:flutter_test/flutter_test.dart';

import 'package:number_flutter/utils/number_formatter.dart';

void main() {
  group('NumberFormatter.format fixedDecimals', () {
    test('keeps both decimals so a live counter never changes length', () {
      expect(NumberFormatter.format(BigInt.from(100000000), fixedDecimals: true),
          '100.00M');
      expect(NumberFormatter.format(BigInt.from(100100000), fixedDecimals: true),
          '100.10M');
      expect(NumberFormatter.format(BigInt.from(100120000), fixedDecimals: true),
          '100.12M');
      expect(NumberFormatter.format(BigInt.from(1500), fixedDecimals: true),
          '1.50K');
    });

    test('lengths only change with the magnitude', () {
      final lengths = {
        for (var n = 100000000; n < 999000000; n += 7654321)
          NumberFormatter.format(BigInt.from(n), fixedDecimals: true).length,
      };
      expect(lengths, {7});
    });

    test('below a thousand is unchanged', () {
      expect(NumberFormatter.format(BigInt.from(999), fixedDecimals: true),
          '999');
    });

    test('default output still trims zeros', () {
      expect(NumberFormatter.format(BigInt.from(100000000)), '100M');
      expect(NumberFormatter.format(BigInt.from(100100000)), '100.1M');
    });
  });
}
