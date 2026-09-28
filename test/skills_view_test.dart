import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/tutorial_step.dart';
import 'package:number_flutter/models/neural_network.dart';
import 'package:number_flutter/models/neural_skill.dart';
import 'package:number_flutter/ui/screens/neural_network/skills_view.dart';

Future<GameState> _game({required bool pyramid}) async {
  SharedPreferences.setMockInitialValues({});
  final gs = GameState();
  await gs.ready;
  gs.debugSetTutorialStep(TutorialStep.done);
  gs.researchNodes.firstWhere((n) => n.id == 'neural_genesis').level = 1;
  gs.neuralNetwork = NeuralNetwork(
    layers: [
      NeuralLayer(index: 0, neurons: [NeuralNeuron(id: 'layer_0_neuron_0')]),
    ],
    unlocked: true,
  );
  gs.number = BigInt.from(10).pow(40);
  if (pyramid) {
    for (var guard = 0; guard < 50 && !gs.skillsUnlocked; guard++) {
      for (final l in [...gs.neuralNetwork.layers]) {
        for (final n in [...l.neurons]) {
          if (gs.canBranchNeuron(n.id)) gs.branchNeuron(n.id);
        }
      }
    }
  }
  gs.debugSetTutorialStep(TutorialStep.done);
  return gs;
}

Future<void> _pump(WidgetTester tester, GameState gs, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider<GameState>.value(
    value: gs,
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const Scaffold(body: SkillsView()),
    ),
  ));
  await tester.pump();
}

void main() {
  for (final size in const [Size(390, 780), Size(320, 568)]) {
    testWidgets('locked view previews every Skill at ${size.width}px',
        (tester) async {
      final gs = (await tester.runAsync(() => _game(pyramid: false)))!;
      addTearDown(gs.dispose);
      await _pump(tester, gs, size);
      expect(find.text('SKILLS'), findsOneWidget);
      expect(find.text('1 / 7 LAYERS'), findsOneWidget);
      for (final def in NeuralSkills.all) {
        await tester.scrollUntilVisible(find.text(def.name), 100);
        expect(find.text(def.name), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('unlocked view trains and toggles at ${size.width}px',
        (tester) async {
      final gs = (await tester.runAsync(() => _game(pyramid: true)))!;
      addTearDown(gs.dispose);
      expect(gs.skillsUnlocked, isTrue);
      await _pump(tester, gs, size);

      await tester.tap(find.text('TRAIN').first);
      await tester.pump();
      expect(gs.skills.training, SkillId.tapping);
      expect(find.text('TRAINING'), findsOneWidget);

      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      expect(gs.skills.isHelperOn(SkillId.tapping), isTrue);

      // Gated Skills show what unlocks them.
      await tester.scrollUntilVisible(
          find.textContaining('COMPLETE YOUR FIRST EPOCH'), 200);
      expect(find.textContaining('COMPLETE YOUR FIRST EPOCH'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Let the debounced save the taps above scheduled run out.
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
