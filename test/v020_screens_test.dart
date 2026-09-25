import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/data/achievement_data.dart';
import 'package:number_flutter/data/artifact_data.dart';
import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/ui/screens/achievements_screen.dart';
import 'package:number_flutter/ui/screens/prestige/artifacts_view.dart';
import 'package:number_flutter/ui/screens/prestige/prestige_screen.dart';

Widget _host(GameState gs, Widget child) => ChangeNotifierProvider.value(
      value: gs,
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Built outside testWidgets' fake clock so the game ticker doesn't count
  // as a pending timer.
  late GameState gs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    gs = GameState();
    await gs.ready;
  });
  tearDown(() => gs.dispose());

  testWidgets('achievements screen renders locked, unlocked and hidden',
      (tester) async {
    gs.highestNumber = BigInt.from(5000);
    gs.number = BigInt.from(5000);
    gs.setSelectedUpgradeCategory(GameState.idleCategory);
    gs.buyUpgrade(GameState.autoClickerId);

    await tester.pumpWidget(_host(gs, const AchievementsScreen()));
    expect(tester.takeException(), isNull);
    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    expect(find.textContaining('UNLOCKED'), findsOneWidget);
    expect(find.text('FIRST STEPS'), findsOneWidget);

    await tester.scrollUntilVisible(find.textContaining('SECRET ·'), 300);
    expect(find.text('???'), findsWidgets);
  });

  testWidgets('opening from a notice scrolls to and highlights the achievement',
      (tester) async {
    // The last achievement in the list sits well below the fold.
    final target = Achievements.all.lastWhere((a) => !a.hidden);

    await tester.pumpWidget(_host(
      gs,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              AchievementsScreen.open(context, highlightIds: {target.id}),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final tile = find.text(target.title.toUpperCase());
    expect(tile, findsOneWidget);
    final screen = tester.getRect(find.byType(CustomScrollView));
    expect(screen.contains(tester.getCenter(tile)), isTrue,
        reason: 'the highlighted tile should have been scrolled into view');
  });

  testWidgets('artifacts tab shows an offer, then the owned card',
      (tester) async {
    gs.prestigeCount = 1;
    gs.prestigeCurrency = 1000;

    await tester.pumpWidget(_host(gs, const ArtifactsView()));
    expect(tester.takeException(), isNull);
    expect(find.text('CHOOSE AN ARTIFACT'), findsOneWidget);
    expect(find.text('CLAIM'), findsNWidgets(3));

    final offered = gs.currentArtifactOffer!.first;
    await tester.tap(find.text('CLAIM').first);
    await tester.pump();
    expect(gs.artifactState.levelOf(offered), 1);
    expect(find.text('CLAIM'), findsNothing);
    expect(
        find.text(Artifacts.byId(offered)!.name.toUpperCase()), findsOneWidget);

    await tester.tap(find.textContaining('EMPOWER'));
    await tester.pump();
    expect(gs.artifactState.levelOf(offered), 2);
    expect(find.text('LV 2'), findsOneWidget);
    // Flush the debounced save the purchase scheduled.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('artifact choice sheet claims and closes', (tester) async {
    gs.prestigeCount = 5;

    await tester.pumpWidget(_host(
      gs,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => ArtifactChoiceSheet.show(context),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('PRESTIGE 1 MILESTONE'), findsOneWidget);

    await tester.tap(find.text('CLAIM').first);
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE AN ARTIFACT'), findsNothing);
    expect(gs.pendingArtifactChoices, 1,
        reason: 'the Prestige 5 milestone is still waiting');
  });

  testWidgets('prestige tab strip fits the artifact badge on a 320dp screen',
      (tester) async {
    gs.prestigeCount = 1;
    expect(gs.pendingArtifactChoices, 1,
        reason: 'the ARTIFACTS badge has to be lit for this to mean anything');

    // A 320dp bar splits into three 106.7px tabs; with the default
    // kTabLabelPadding that left ~75px for the ~90px "ARTIFACTS" + dot row,
    // so the strip reported a RenderFlex overflow until the pick was made.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(gs, const PrestigeScreen()));
    await tester.pump();

    expect(find.text('NEXUS'), findsOneWidget);
    expect(find.text('ARTIFACTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Flush the debounced save the prestige-count setter scheduled.
    await tester.pump(const Duration(seconds: 1));
  });
}
