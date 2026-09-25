import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/tutorial_step.dart';

Future<GameState> _game() async {
  SharedPreferences.setMockInitialValues({});
  final gs = GameState();
  await gs.ready;
  return gs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'crossing the first artifact milestone starts the tutorial once the '
      'prestige animation finishes, not during prestige() itself', () async {
    final gs = await _game();
    addTearDown(gs.dispose);
    gs.debugSetTutorialStep(TutorialStep.done);

    gs.number = gs.prestigeRequirement;
    await gs.prestige();
    // The reveal animation is still "playing" at this point in real usage —
    // the tutorial must not have started yet.
    expect(gs.tutorialStep, TutorialStep.done);

    gs.setPrestigeAnimating(false);
    expect(gs.tutorialStep, TutorialStep.artifactsIntro);
  });

  test('tapping through the artifacts tutorial completes it', () async {
    final gs = await _game();
    addTearDown(gs.dispose);
    gs.debugSetTutorialStep(TutorialStep.done);

    gs.number = gs.prestigeRequirement;
    await gs.prestige();
    gs.setPrestigeAnimating(false);
    expect(gs.tutorialStep, TutorialStep.artifactsIntro);

    gs.onTutorialTapToContinue();
    expect(gs.tutorialStep, TutorialStep.artifactsEmpower);

    // Ends on a teaser for the Nexus, two prestiges away.
    gs.onTutorialTapToContinue();
    expect(gs.tutorialStep, TutorialStep.nexusWhisper);

    gs.onTutorialTapToContinue();
    expect(gs.tutorialStep, TutorialStep.done);
    expect(gs.artifactTutorialSeen, isTrue);
  });

  test('SKIP mid-tutorial completes it the same as tapping through', () async {
    final gs = await _game();
    addTearDown(gs.dispose);
    gs.debugSetTutorialStep(TutorialStep.done);

    gs.number = gs.prestigeRequirement;
    await gs.prestige();
    gs.setPrestigeAnimating(false);
    expect(gs.tutorialStep, TutorialStep.artifactsIntro);

    gs.skipTutorial();
    expect(gs.tutorialStep, TutorialStep.done);
    expect(gs.artifactTutorialSeen, isTrue);
  });

  test('does not fire again on a later prestige once already seen', () async {
    final gs = await _game();
    addTearDown(gs.dispose);
    gs.debugSetTutorialStep(TutorialStep.done);

    gs.number = gs.prestigeRequirement;
    await gs.prestige();
    gs.setPrestigeAnimating(false);
    gs.skipTutorial();
    expect(gs.artifactTutorialSeen, isTrue);

    gs.number = gs.prestigeRequirement;
    await gs.prestige();
    gs.setPrestigeAnimating(false);
    // Prestige 2 brings the Nexus teaser instead.
    expect(gs.tutorialStep, isNot(TutorialStep.artifactsIntro));
    expect(gs.tutorialStep, TutorialStep.nexusSignal);
  });
}
