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
            spec.mode == TutorialMode.passthroughHint ||
            spec.mode == TutorialMode.spotlightTapToContinue) {
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

    test('each tutorial has steps', () {
      for (final scope in [
        TutorialScope.main,
        TutorialScope.prestige,
        TutorialScope.artifacts,
        TutorialScope.nexus,
        TutorialScope.neural,
        TutorialScope.tips,
        TutorialScope.lesson,
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
        TutorialTarget.idleCategory: TutorialTab.upgrades,
        TutorialTarget.advisorBanner: TutorialTab.upgrades,
        TutorialTarget.upgradeAutoClicker: TutorialTab.upgrades,
        TutorialTarget.upgradeClickPower: TutorialTab.upgrades,
        TutorialTarget.upgradeProbabilityStrike: TutorialTab.upgrades,
        TutorialTarget.upgradeMomentum: TutorialTab.upgrades,
        TutorialTarget.upgradeKineticSynergy: TutorialTab.upgrades,
        TutorialTarget.upgradeOverclock: TutorialTab.upgrades,
        TutorialTarget.upgradeDimensionalTap: TutorialTab.upgrades,
        TutorialTarget.upgradeCascadeResonator: TutorialTab.upgrades,
        TutorialTarget.upgradeTemporalCollapse: TutorialTab.upgrades,
        TutorialTarget.temporalCollapseButton: TutorialTab.generators,
        TutorialTarget.idleRate: TutorialTab.generators,
        TutorialTarget.prestigeMultiplier: TutorialTab.prestige,
        TutorialTarget.prestigeGainCard: TutorialTab.prestige,
        TutorialTarget.prestigeInitiate: TutorialTab.prestige,
        TutorialTarget.nexusStabilizeButton: TutorialTab.prestige,
        TutorialTarget.nexusOptProtocolNode: TutorialTab.prestige,
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
      const idleRows = [
        TutorialTarget.upgradeAutoClicker,
        TutorialTarget.upgradeCascadeResonator,
      ];
      const clickRows = [
        TutorialTarget.upgradeClickPower,
        TutorialTarget.upgradeProbabilityStrike,
        TutorialTarget.upgradeMomentum,
        TutorialTarget.upgradeKineticSynergy,
        TutorialTarget.upgradeOverclock,
        TutorialTarget.upgradeDimensionalTap,
        TutorialTarget.upgradeTemporalCollapse,
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

    test('the last card of chapter 1 says play starts', () {
      expect(specFor(TutorialStep.roadAhead).continueHint,
          'TAP ANYWHERE TO START PLAYING');
    });
  });

  group('chapters', () {
    test(
        'every step belongs to exactly one chapter or lesson, or is a '
        'single card', () {
      for (final step in TutorialStep.values) {
        if (step == TutorialStep.done) continue;
        final owners =
            tutorialChapters.where((c) => c.steps.contains(step)).length;
        final lessons =
            upgradeLessons.where((l) => l.steps.contains(step)).length;
        final scope = specFor(step).scope;
        if (scope == TutorialScope.tips) {
          expect(owners + lessons, 0,
              reason: '${step.name} is a tip inside a chapter or lesson');
        } else if (scope == TutorialScope.lesson) {
          expect(owners, 0, reason: '${step.name} is a lesson step in a chapter');
          expect(lessons, 1,
              reason: '${step.name} is in $lessons lessons, not exactly one');
        } else {
          expect(owners, 1,
              reason: '${step.name} is in $owners chapters, not exactly one');
        }
      }
    });

    test("a chapter's steps all share its scope", () {
      for (final chapter in tutorialChapters) {
        for (final step in chapter.steps) {
          expect(specFor(step).scope, chapter.scope,
              reason: '${step.name} is in chapter ${chapter.number}');
        }
      }
    });

    test('chapters are numbered in order', () {
      for (var i = 0; i < tutorialChapters.length; i++) {
        expect(tutorialChapters[i].number, i + 1);
      }
    });

    test('every card gets a kicker: its chapter and position, or a label',
        () {
      expect(tutorialKickerFor(TutorialStep.welcome),
          'CHAPTER 1 · FIRST STEPS · 1/12');
      expect(tutorialKickerFor(TutorialStep.doPrestige),
          'CHAPTER 2 · PRESTIGE · 6/6');
      for (final step in TutorialStep.values) {
        if (step == TutorialStep.done) continue;
        expect(tutorialKickerFor(step), isNotNull,
            reason: '${step.name} has no chapter and no kicker');
      }
    });

  });

  group('upgrade lessons', () {
    test('each goes open, buy, back, try, explain', () {
      for (final lesson in upgradeLessons) {
        final name = lesson.upgradeId;
        expect(lesson.steps, hasLength(5), reason: name);
        for (final step in lesson.steps) {
          expect(specFor(step).scope, TutorialScope.lesson, reason: step.name);
        }
        expect(specFor(lesson.open).target, TutorialTarget.navUpgrades,
            reason: name);
        expect(specFor(lesson.buy).mode, TutorialMode.spotlightAction,
            reason: name);
        expect(specFor(lesson.buy).requiredTab, TutorialTab.upgrades,
            reason: name);
        expect(specFor(lesson.back).target, TutorialTarget.navGenerators,
            reason: name);
        expect(specFor(lesson.tryIt).requiredTab, TutorialTab.generators,
            reason: name);
        expect(specFor(lesson.explain).mode, TutorialMode.tapToContinue,
            reason: name);
        expect(lesson.beat, lesson.explain, reason: name);
      }
    });

    test('covers every special upgrade, once each', () {
      final ids = upgradeLessons.map((l) => l.upgradeId).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, containsAll(<String>[
        'click_probability_strike',
        'click_momentum',
        'click_kinetic_synergy',
        'click_overclock',
        'click_dimensional_tap',
        'idle_cascade_resonator',
        'click_temporal_collapse',
      ]));
      expect(upgradeTipSteps.keys.toSet(), ids.toSet());
    });

    test('goals that count something show progress; the rest do not', () {
      for (final lesson in upgradeLessons) {
        final counts = lesson.goal == LessonGoal.combo ||
            lesson.goal == LessonGoal.taps ||
            lesson.goal == LessonGoal.streak;
        expect(specFor(lesson.tryIt).visual == TutorialVisual.lessonProgress,
            counts,
            reason: lesson.upgradeId);
        if (lesson.goal == LessonGoal.combo ||
            lesson.goal == LessonGoal.taps) {
          expect(lesson.goalCount, greaterThan(0), reason: lesson.upgradeId);
        }
      }
    });

    test('every lesson card is labelled with its position', () {
      expect(tutorialKickerFor(TutorialStep.probabilityStrikeOpen),
          'NEW UPGRADE · 1/5');
      expect(tutorialKickerFor(TutorialStep.tipTemporalCollapse),
          'NEW ABILITY · 5/5');
    });
  });

  group('prestige sub-tabs', () {
    test('a step that needs a Prestige sub-tab needs the Prestige tab', () {
      for (final step in TutorialStep.values) {
        final spec = specFor(step);
        if (spec.requiredPrestigeSubTab != null) {
          expect(spec.requiredTab, TutorialTab.prestige,
              reason: '${step.name} wants a Prestige sub-tab elsewhere');
        }
      }
    });
  });

  group('legacy step names', () {
    test('no longer exist, so an old save can be recognised', () {
      final names = TutorialStep.values.map((s) => s.name).toSet();
      for (final legacy in legacyTutorialStepNames) {
        expect(names, isNot(contains(legacy)),
            reason: '$legacy is both current and legacy');
      }
    });
  });
}
