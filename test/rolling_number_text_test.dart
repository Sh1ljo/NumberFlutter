import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:number_flutter/ui/widgets/rolling_number_text.dart';

BigInt _parseShown(WidgetTester tester) {
  // "123.45M" -> 123450000, good enough to check ordering within one suffix.
  final text = tester.widget<Text>(find.byType(Text)).data!;
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return BigInt.parse(digits);
}

Widget _host(BigInt value) => MaterialApp(
      home: Center(child: RollingNumberText(value: value)),
    );

void main() {
  final start = BigInt.from(100000000); // 100.00M
  final end = BigInt.from(101000000); // 101.00M

  testWidgets('rolls up through intermediate values and lands exactly',
      (tester) async {
    await tester.pumpWidget(_host(start));
    expect(find.text('100.00M'), findsOneWidget);

    await tester.pumpWidget(_host(end));
    final seen = <BigInt>[];
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      seen.add(_parseShown(tester));
    }
    // Monotonic, never past the real value, and at least one in-between
    // frame instead of a single jump.
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i] >= seen[i - 1], isTrue);
    }
    expect(seen.every((v) => v <= BigInt.from(10100)), isTrue);
    expect(seen.any((v) => v > BigInt.from(10000) && v < BigInt.from(10100)),
        isTrue);
    expect(find.text('101.00M'), findsOneWidget);
    // Frame callbacks stop once the roll is done.
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a new tick mid-roll continues from what is on screen',
      (tester) async {
    await tester.pumpWidget(_host(start));
    await tester.pumpWidget(_host(end));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 48));
    final before = _parseShown(tester);

    await tester.pumpWidget(_host(BigInt.from(102000000)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_parseShown(tester) >= before, isTrue);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('102.00M'), findsOneWidget);
  });

  testWidgets('spending snaps down immediately', (tester) async {
    await tester.pumpWidget(_host(end));
    await tester.pumpWidget(_host(start));
    expect(find.text('100.00M'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion snaps instead of rolling', (tester) async {
    Widget host(BigInt v) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(child: RollingNumberText(value: v)),
          ),
        );
    await tester.pumpWidget(host(start));
    await tester.pumpWidget(host(end));
    expect(find.text('101.00M'), findsOneWidget);
  });
}
