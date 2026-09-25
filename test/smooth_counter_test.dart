import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:number_flutter/ui/widgets/ambient_gradient_background.dart';
import 'package:number_flutter/ui/widgets/floating_tap_text.dart';
import 'package:number_flutter/ui/widgets/pulse_number.dart';
import 'package:number_flutter/ui/widgets/tap_ripple_effect.dart';
import 'package:number_flutter/utils/number_formatter.dart';

const _family = 'SpaceGroteskUnderTest';

double _width(String text, {required bool tabular}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: _family,
        fontSize: 57,
        letterSpacing: -2,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  setUpAll(() async {
    final bytes =
        File('assets/google_fonts/SpaceGrotesk-Bold.ttf').readAsBytesSync();
    final loader = FontLoader(_family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  // Consecutive ticks of a counter just past the first prestige (100M).
  final ticks = [
    for (var n = 100000000; n < 112000000; n += 1234567) BigInt.from(n),
  ];

  test('old formatting made the big counter change width between ticks', () {
    final widths = {
      for (final n in ticks)
        _width(NumberFormatter.format(n), tabular: false).round(),
    };
    expect(widths.length, greaterThan(1));
  });

  test('fixed decimals + tabular figures keep the counter width constant', () {
    final widths = {
      for (final n in ticks)
        _width(NumberFormatter.format(n, fixedDecimals: true), tabular: true)
            .toStringAsFixed(3),
    };
    expect(widths, hasLength(1));
  });

  testWidgets('a long counter shrinks to fit instead of wrapping',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            child: PulseNumber(
              value: BigInt.parse('123456789012345678901234567890'),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PulseNumber)).width,
        lessThanOrEqualTo(200));
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 1);
  });

  testWidgets('ripples and the ambient backdrop animate without errors',
      (tester) async {
    final rippleKey = GlobalKey<TapRippleLayerState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const Positioned.fill(child: AmbientGradientBackground()),
            Positioned.fill(child: TapRippleLayer(key: rippleKey)),
          ],
        ),
      ),
    );
    rippleKey.currentState!.add(const Offset(100, 100));
    rippleKey.currentState!.add(const Offset(150, 220));
    await tester.pump();
    expect(find.byType(TapRippleEffect), findsNWidgets(2));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Ripples remove themselves when their 420ms animation completes.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TapRippleEffect), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap numbers, strikes included, rise and clear themselves',
      (tester) async {
    final layerKey = GlobalKey<FloatingTapTextLayerState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(child: FloatingTapTextLayer(key: layerKey)),
          ],
        ),
      ),
    );
    final layer = layerKey.currentState!;
    layer.add(
        text: '+12', isProbabilityStrike: false, position: const Offset(80, 300));
    layer.add(
        text: '+120', isProbabilityStrike: true, position: const Offset(160, 300));
    await tester.pump();
    expect(layer.activeCount, 2);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // The plain one (680ms) and the strike (760ms) are both gone after 800ms.
    await tester.pump(const Duration(milliseconds: 400));
    expect(layer.activeCount, 0);
    expect(tester.takeException(), isNull);
  });
}
