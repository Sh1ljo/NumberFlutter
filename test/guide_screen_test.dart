import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/data/guide_data.dart';
import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/ui/screens/guide_screen.dart';

void main() {
  late GameState gameState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    gameState = GameState();
    await gameState.ready;
  });

  tearDown(() => gameState.dispose());

  Future<void> pumpGuide(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<GameState>.value(
      value: gameState,
      child: MaterialApp(theme: ThemeData.dark(), home: const GuideScreen()),
    ));
    await tester.pump();
  }

  test('every entry has a title, a body and something to show while locked',
      () {
    for (final section in GuideData.sections) {
      for (final entry in section.entries) {
        expect(entry.title, isNotEmpty);
        expect(entry.body, isNotEmpty);
        final alwaysOpen = entry.isUnlocked(gameState);
        if (!alwaysOpen) {
          expect(entry.lockedHint, isNotEmpty, reason: entry.title);
        }
      }
    }
  });

  testWidgets('a new player sees the basics, and what is ahead stays hidden',
      (tester) async {
    await pumpGuide(tester);

    expect(find.text('TAPPING'), findsOneWidget);
    expect(find.text('IDLE INCOME'), findsOneWidget);
    // Coming up: named, but not explained yet.
    expect(find.text('THE NEXUS'), findsWidgets);
    expect(find.text('Reach 3 prestiges.'), findsOneWidget);
    // Further out: not even named.
    expect(find.text('THE NETWORK'), findsNothing);
    expect(find.text('???'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prestiging unlocks its entries', (tester) async {
    gameState.prestigeCount = 3;
    await pumpGuide(tester);

    expect(find.text('Reach 3 prestiges.'), findsNothing);
    expect(find.text('NEURAL GENESIS'), findsOneWidget);
    expect(find.text('THE NETWORK'), findsNothing);
  });
}
