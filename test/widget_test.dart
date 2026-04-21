// Basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:number_flutter/main.dart';

void main() {
  testWidgets('app starts without requiring sign-in screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NumberApp());
    await tester.pump();
    expect(find.text('SIGN IN REQUIRED'), findsNothing);
    expect(find.text('CLOUD ACCOUNT'), findsNothing);
    // Drain AppInitializer branded delay timer so the test binding does not fail.
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
