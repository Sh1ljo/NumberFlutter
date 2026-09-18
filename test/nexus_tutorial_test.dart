import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/tutorial_step.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameState gameState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    gameState = GameState();
    await gameState.ready;
  });

  tearDown(() {
    gameState.dispose();
  });

  test(
      'purchasing opt_protocol during nexusResearchOptProtocol advances to '
      'nexusGoal', () {
    gameState.debugSetTutorialStep(TutorialStep.nexusResearchOptProtocol);
    gameState.prestigeCurrency = 3.0; // exactly opt_protocol's L0->1 cost

    gameState.purchaseResearch('opt_protocol');

    expect(gameState.tutorialStep, TutorialStep.nexusGoal);
    expect(
      gameState.researchNodes.firstWhere((n) => n.id == 'opt_protocol').level,
      1,
    );
  });

  test(
      'purchasing a different node during nexusResearchOptProtocol does not '
      'advance', () {
    gameState.debugSetTutorialStep(TutorialStep.nexusResearchOptProtocol);
    gameState.prestigeCurrency = 6.0;

    gameState.purchaseResearch('surge_protocol');

    expect(gameState.tutorialStep, TutorialStep.nexusResearchOptProtocol);
  });
}
