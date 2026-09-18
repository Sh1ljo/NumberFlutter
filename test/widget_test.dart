// Basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:number_flutter/main.dart';

void main() {
  testWidgets('app starts without requiring sign-in screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NumberApp());
    await tester.pump();
    expect(find.text('SIGN IN REQUIRED'), findsNothing);
    expect(find.text('CLOUD ACCOUNT'), findsNothing);
    // Firebase can't start in tests, so boot waits out the cloud timeout
    // and then opens the game offline.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
