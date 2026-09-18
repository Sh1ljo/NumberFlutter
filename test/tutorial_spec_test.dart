import 'package:flutter_test/flutter_test.dart';
import 'package:number_flutter/logic/tutorial_step.dart';

void main() {
  group('spec table completeness', () {
    test('every step has a spec', () {
      // This is the assertion that makes the whole original bug class
      // impossible. Behaviour used to come from three hand-maintained boolean
      // sets (isTapToContinue / isWatchIdle / isNavStep); a step missing from
      // all three, or listed in the wrong one, silently produced a broken
      // frame — no dim, no card, or no way out.
      for (final step in TutorialStep.values) {
        expect(tutorialSpecs.containsKey(step), isTrue,
            reason: '${step.name} has no TutorialStepSpec');
      }
    });

    test('has no specs for steps that no longer exist', () {
      for (final step in tutorialSpecs.keys) {
        expect(TutorialStep.values, contains(step));
      }
    });

    test('specFor never returns null for any step', () {
      for (final step in TutorialStep.values) {
        expect(specFor(step), isNotNull);
      }
    });
  });

  group('every step is renderable', () {
    test('every step except done carries copy', () {
      for (final step in TutorialStep.values) {
        if (step == TutorialStep.done) continue;
        final spec = specFor(step);
        expect(spec.hasCopy, isTrue,
            reason: '${step.name} has no title/body, so it would render an '
                'empty overlay the player cannot read or escape');
        expect(spec.title, isNotEmpty);
        expect(spec.body, isNotEmpty);
      }
    });

    test('spotlight and passthrough steps name a target', () {
      for (final step in TutorialStep.values) {
        final spec = specFor(step);
        if (spec.mode == TutorialMode.spotlightAction ||
            spec.mode == TutorialMode.passthroughHint) {
          expect(spec.target, isNotNull,
              reason: '${step.name} is a ${spec.mode.name} step with nothing '
                  'to point at');
        }
      }
    });

    test('floating and inSheet steps do not claim a spotlight target', () {
      for (final step in TutorialStep.values) {
        final spec = specFor(step);
        if (spec.mode == TutorialMode.floatingHint ||
            spec.mode == TutorialMode.inSheet) {
          expect(spec.target, isNull,
              reason: '${step.name} would never render its target');
        }
      }
    });
  });

  group('scopes', () {
    test('done is the only step outside a scope', () {
      for (final step in TutorialStep.values) {
        final spec = specFor(step);
        if (step == TutorialStep.done) {
          expect(spec.scope, TutorialScope.none);
        } else {
          expect(spec.scope, isNot(TutorialScope.none),
              reason: '${step.name} belongs to no tutorial, so SKIP cannot '
                  'know what to exit');
        }
      }
    });

    test('each of the four tutorials has steps', () {
      for (final scope in [
        TutorialScope.main,
        TutorialScope.nexus,
        TutorialScope.neural,
        TutorialScope.upgrades,
      ]) {
        final steps = tutorialSpecs.entries
            .where((e) => e.value.scope == scope)
            .toList();
        expect(steps, isNotEmpty, reason: 'no steps in ${scope.name}');
      }
    });

    test('the neural in-sheet steps are all in the neural scope', () {
      const inSheetSteps = [
        TutorialStep.neuralUpgradeGradient,
        TutorialStep.neuralChangeActivation,
        TutorialStep.neuralBranchNeuron,
      ];
      for (final step in inSheetSteps) {
        final spec = specFor(step);
        expect(spec.mode, TutorialMode.inSheet);
        expect(spec.scope, TutorialScope.neural);
        // The fallback card shown when the sheet is closed needs copy —
        // without it, dismissing the sheet left zero tutorial UI and no SKIP.
        expect(spec.hasCopy, isTrue);
      }
    });
  });

  group('tab gating', () {
    test('requiredTab is always a real tab index', () {
      const valid = [
        TutorialTab.generators,
        TutorialTab.upgrades,
        TutorialTab.prestige,
        TutorialTab.neural,
      ];
      for (final step in TutorialStep.values) {
        final tab = specFor(step).requiredTab;
        if (tab != null) {
          expect(valid, contains(tab), reason: '${step.name} wants tab $tab');
        }
      }
    });

    test('targets that live on a screen declare that screen', () {
      // A spotlight pointing at something on another tab is worse than no
      // spotlight — this is what requiredTab exists to prevent.
      const screenBoundTargets = {
        TutorialTarget.tapArea: TutorialTab.generators,
        TutorialTarget.momentumBar: TutorialTab.generators,
        TutorialTarget.idleCategory: TutorialTab.upgrades,
        TutorialTarget.upgradeAutoClicker: TutorialTab.upgrades,
        TutorialTarget.upgradeClickPower: TutorialTab.upgrades,
        TutorialTarget.upgradeProbabilityStrike: TutorialTab.upgrades,
        TutorialTarget.upgradeMomentum: TutorialTab.upgrades,
        TutorialTarget.upgradeKineticSynergy: TutorialTab.upgrades,
        TutorialTarget.upgradeOverclock: TutorialTab.upgrades,
        TutorialTarget.prestigeMultiplier: TutorialTab.prestige,
        TutorialTarget.prestigeGainCard: TutorialTab.prestige,
        TutorialTarget.neuralNeuron: TutorialTab.neural,
        TutorialTarget.neuralHud: TutorialTab.neural,
      };

      for (final entry in tutorialSpecs.entries) {
        final expectedTab = screenBoundTargets[entry.value.target];
        if (expectedTab == null) continue;
        expect(entry.value.requiredTab, expectedTab,
            reason: '${entry.key.name} targets '
                '${entry.value.target!.name} but does not require its tab');
      }
    });

    test('nav targets are not tab-gated', () {
      // The nav bar is on every screen, and these steps exist precisely to
      // get the player to another tab.
      const navTargets = [
        TutorialTarget.navGenerators,
        TutorialTarget.navUpgrades,
        TutorialTarget.navPrestige,
        TutorialTarget.navNeural,
      ];
      for (final entry in tutorialSpecs.entries) {
        if (navTargets.contains(entry.value.target)) {
          expect(entry.value.requiredTab, isNull,
              reason: '${entry.key.name} gates a nav hint behind a tab');
        }
      }
    });
  });

  group('category gating', () {
    test('requiredCategory is click or idle when set', () {
      for (final step in TutorialStep.values) {
        final category = specFor(step).requiredCategory;
        if (category != null) {
          expect(['click', 'idle'], contains(category),
              reason: '${step.name} wants category $category');
        }
      }
    });

    test('upgrade-row targets declare the category they live under', () {
      const idleRows = [TutorialTarget.upgradeAutoClicker];
      const clickRows = [
        TutorialTarget.upgradeClickPower,
        TutorialTarget.upgradeProbabilityStrike,
        TutorialTarget.upgradeMomentum,
        TutorialTarget.upgradeKineticSynergy,
        TutorialTarget.upgradeOverclock,
      ];
      for (final entry in tutorialSpecs.entries) {
        final target = entry.value.target;
        if (idleRows.contains(target)) {
          expect(entry.value.requiredCategory, 'idle',
              reason: '${entry.key.name} spotlights an idle row');
        } else if (clickRows.contains(target)) {
          expect(entry.value.requiredCategory, 'click',
              reason: '${entry.key.name} spotlights a click row');
        }
      }
    });
  });

  group('continue hints', () {
    test('only tap-to-continue steps override the continue hint', () {
      for (final step in TutorialStep.values) {
        final spec = specFor(step);
        if (spec.continueHint != null) {
          expect(spec.isTapToContinue, isTrue,
              reason: '${step.name} sets a continue hint it will never show');
        }
      }
    });

    test('learnPrestige keeps its bespoke wording', () {
      expect(specFor(TutorialStep.learnPrestige).continueHint,
          'TAP ANYWHERE TO START PLAYING');
    });
  });
}
