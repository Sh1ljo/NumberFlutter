import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../logic/game_state.dart';
import '../../../models/neural_network.dart';
import '../../../models/neural_skill.dart';
import '../../../utils/number_formatter.dart';

/// Tutorial targets on the Tapping card, owned by MainLayout.
class SkillTutorialKeys {
  final GlobalKey train;
  final GlobalKey mastery;
  final GlobalKey fit;
  final GlobalKey helper;

  const SkillTutorialKeys({
    required this.train,
    required this.mastery,
    required this.fit,
    required this.helper,
  });
}

/// The SKILLS tab on the Neural screen: a locked preview until the pyramid
/// is complete, then one card per Skill.
class SkillsView extends StatelessWidget {
  final SkillTutorialKeys? tutorialKeys;

  const SkillsView({super.key, this.tutorialKeys});

  @override
  Widget build(BuildContext context) {
    // Everything on this tab moves slowly (Mastery in 0.1% steps, the
    // prestige ETA in seconds), so rebuild on a coarse signature instead of
    // on every 100ms tick.
    context.select<GameState, int>((gs) => gs.skillsViewSignature);
    final gs = context.read<GameState>();
    final bottom = MediaQuery.of(context).padding.bottom;
    if (!gs.skillsUnlocked) return _LockedSkills(bottomPadding: bottom);

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
      children: [
        const _SkillsIntro(),
        const SizedBox(height: 16),
        for (final def in NeuralSkills.all) ...[
          _SkillCard(
            def: def,
            keys: def.id == SkillId.tapping ? tutorialKeys : null,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ── Shared styles ────────────────────────────────────────────────────────

TextStyle? _label(BuildContext context, {Color? color}) =>
    Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.6,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color ?? Theme.of(context).colorScheme.outline,
        );

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

String _activationLabel(String fn) => fn.toUpperCase();

// ── Locked ───────────────────────────────────────────────────────────────

class _LockedSkills extends StatelessWidget {
  final double bottomPadding;

  const _LockedSkills({required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gs = context.read<GameState>();
    final built = gs.pyramidLayersBuilt;
    const target = NeuralNetwork.pyramidLayerCount;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 28, 20, 24 + bottomPadding),
      children: [
        Center(child: Icon(Icons.lock_outline, color: cs.outline, size: 36)),
        const SizedBox(height: 16),
        Text(
          'SKILLS',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayMedium?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Teach your network jobs — and it does them for you.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: cs.outline),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(2),
            color: cs.surfaceContainerLow.withValues(alpha: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('UNLOCK', style: _label(context))),
                  Text(
                    '$built / $target LAYERS',
                    style: _label(context, color: cs.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Bar(value: built / target),
              const SizedBox(height: 10),
              Text(
                gs.neuralNetworkUnlocked
                    ? 'Grow the neural pyramid to all $target layers by '
                        'branching neurons on the NETWORK tab.'
                    : 'Awaken the Neural Network in the Nexus, then grow its '
                        'pyramid to all $target layers.',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('WHAT YOUR NETWORK WILL LEARN', style: _label(context)),
        const SizedBox(height: 10),
        for (final def in NeuralSkills.all) ...[
          _LockedSkillRow(def: def),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _LockedSkillRow extends StatelessWidget {
  final SkillDef def;

  const _LockedSkillRow({required this.def});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.6),
        border: Border(left: BorderSide(color: cs.outlineVariant, width: 2)),
      ),
      child: Row(
        children: [
          Icon(def.icon, size: 20, color: cs.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.name, style: _label(context, color: cs.onSurface)),
                const SizedBox(height: 3),
                Text(
                  def.promise,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                ),
                if (def.gate != SkillGate.none) ...[
                  const SizedBox(height: 3),
                  Text('THEN: ${def.gateHint.toUpperCase()}',
                      style: _label(context, color: cs.outlineVariant)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.lock_outline, size: 14, color: cs.outlineVariant),
        ],
      ),
    );
  }
}

// ── Unlocked ─────────────────────────────────────────────────────────────

class _SkillsIntro extends StatelessWidget {
  const _SkillsIntro();

  void _explain(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('HOW SKILLS WORK'),
        content: const SingleChildScrollView(
          child: Text(
            'TRAIN — Your network studies one Skill at a time. In real AI the '
            'examples a network studies are called a dataset; each Skill is '
            'one.\n\n'
            'MASTERY — How well the network knows the job. It rises while '
            'the Skill trains, even while you are away, and is never lost '
            'when you switch.\n\n'
            'FIT — Each Skill learns fastest with one kind of neuron. The '
            'more of your neurons use that activation, the faster it learns '
            '(up to 4× faster than a bad fit). Change activations on the '
            'NETWORK tab.\n\n'
            'HELPER — Switch it on and the network does the job for you. '
            'The higher the Mastery, the better it does it.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Pick a Skill to TRAIN. Its Mastery rises over time — switch on '
            'its helper and the network does that job for you.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
        ),
        IconButton(
          tooltip: 'How Skills work',
          visualDensity: VisualDensity.compact,
          onPressed: () => _explain(context),
          icon: Icon(Icons.help_outline, size: 20, color: cs.outline),
        ),
      ],
    );
  }
}

class _SkillCard extends StatelessWidget {
  final SkillDef def;
  final SkillTutorialKeys? keys;

  const _SkillCard({required this.def, this.keys});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gs = context.read<GameState>();
    final id = def.id;

    if (!gs.isSkillAvailable(id)) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow.withValues(alpha: 0.4),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(def.icon, size: 22, color: cs.outlineVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.name, style: _label(context, color: cs.outline)),
                  const SizedBox(height: 4),
                  Text(
                    def.promise,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outlineVariant),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 12, color: cs.outlineVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'UNLOCK: ${def.gateHint.toUpperCase()}',
                          style: _label(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final training = gs.skills.training == id;
    final mastery = gs.skillMastery(id);
    final (matching, total) = skillFitCounts(gs.neuralNetwork, id);
    final fitMult = NeuralSkills.fitMultiplier(gs.skillFitFor(id));
    final eta = training ? _nextMilestoneEta(gs, id, mastery) : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.7),
        border: Border.all(
          color: training ? cs.primary : cs.outlineVariant,
          width: training ? 1.2 : 1,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title + TRAIN
          Row(
            children: [
              Icon(def.icon, size: 22, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  def.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 15,
                  ),
                ),
              ),
              KeyedSubtree(
                key: keys?.train,
                child: training
                    ? _TrainingBadge()
                    : OutlinedButton(
                        onPressed: () => gs.trainSkill(id),
                        style: _smallButton(cs),
                        child: const Text('TRAIN'),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            def.promise,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: 12),

          // Mastery
          KeyedSubtree(
            key: keys?.mastery,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('MASTERY', style: _label(context)),
                    const SizedBox(width: 8),
                    Text(_pct(mastery),
                        style: _label(context, color: cs.onSurface)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        eta ?? '',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: _label(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _Bar(value: mastery),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Fit
          KeyedSubtree(
            key: keys?.fit,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('FIT', style: _label(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$matching / $total neurons use '
                        '${_activationLabel(def.preferredActivation)}',
                        style: _label(context, color: cs.onSurface),
                      ),
                    ),
                    Text('${fitMult.toStringAsFixed(2)}× speed',
                        style: _label(context)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  def.fitReason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.outlineVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 10),

          // Helper
          _HelperSection(def: def, helperKey: keys?.helper),
        ],
      ),
    );
  }

  /// "50% in 12m 30s" toward the next of 50 / 90 / 99%.
  String? _nextMilestoneEta(GameState gs, SkillId id, double mastery) {
    for (final target in const [0.5, 0.9, 0.99]) {
      if (mastery >= target) continue;
      final seconds = gs.skillSecondsTo(id, target);
      if (seconds == null) return null;
      return '${(target * 100).round()}% IN '
          '${NumberFormatter.formatDuration(seconds).toUpperCase()}';
    }
    return null;
  }
}

ButtonStyle _smallButton(ColorScheme cs) => OutlinedButton.styleFrom(
      foregroundColor: cs.primary,
      side: BorderSide(color: cs.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        fontSize: 11,
      ),
    );

class _TrainingBadge extends StatefulWidget {
  @override
  State<_TrainingBadge> createState() => _TrainingBadgeState();
}

class _TrainingBadgeState extends State<_TrainingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 0.25, end: 1.0).animate(_ctrl),
          child: Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 6),
        Text('TRAINING', style: _label(context, color: cs.primary)),
      ],
    );
  }
}

class _HelperSection extends StatelessWidget {
  final SkillDef def;
  final GlobalKey? helperKey;

  const _HelperSection({required this.def, this.helperKey});

  Future<void> _toggle(BuildContext context, bool on) async {
    final gs = context.read<GameState>();
    if (on &&
        def.id == SkillId.prestigePlanning &&
        !gs.skills.autoPrestigeConfirmed) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('TURN ON AUTO-PRESTIGE?'),
          content: const Text(
            'Whenever your next prestige is ready, the network will prestige '
            'for you — your number and upgrades reset, exactly as if you had '
            'pressed the button yourself.\n\n'
            'It only acts while the game is open, never during a tutorial, '
            'and you can switch it off at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('TURN ON'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      gs.confirmAutoPrestige();
    }
    gs.setSkillHelper(def.id, on);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gs = context.read<GameState>();
    final id = def.id;
    final mastery = gs.skillMastery(id);
    final on = gs.skills.isHelperOn(id);
    final lockedByMastery = id == SkillId.prestigePlanning &&
        mastery < NeuralSkills.autoPrestigeMastery;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (id == SkillId.prestigePlanning) ...[
          _PrestigeForecast(),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.helperName.toUpperCase(),
                      style: _label(context, color: cs.onSurface)),
                  const SizedBox(height: 3),
                  Text(
                    _effectText(mastery, gs),
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            ),
            KeyedSubtree(
              key: helperKey,
              child: Switch(
                value: on && !lockedByMastery,
                onChanged: lockedByMastery ? null : (v) => _toggle(context, v),
              ),
            ),
          ],
        ),
        if (id == SkillId.shopping) ...[
          const SizedBox(height: 8),
          _SpendLimitPicker(current: gs.skills.spendLimit),
        ],
      ],
    );
  }

  String _effectText(double mastery, GameState gs) {
    switch (def.id) {
      case SkillId.tapping:
        final rate = NeuralSkills.tapsPerSecond(mastery).toStringAsFixed(1);
        return mastery >= NeuralSkills.rhythmMastery
            ? '$rate taps/sec · keeps Momentum & Overclock streaks'
            : '$rate taps/sec · builds streaks from '
                '${(NeuralSkills.rhythmMastery * 100).round()}% Mastery';
      case SkillId.shopping:
        final every = NeuralSkills.shoppingIntervalSeconds(mastery);
        return 'Buys every ${every.toStringAsFixed(every < 10 ? 1 : 0)}s · '
            'never touches the real-money shop';
      case SkillId.sparkHunting:
        final bonus = (NeuralSkills.sparkSpawnRateBonus(mastery) - 1) * 100;
        return 'Catches ${_pct(NeuralSkills.sparkCatchChance(mastery))} of '
            'sparks · +${bonus.toStringAsFixed(0)}% more sparks · on '
            'GENERATORS';
      case SkillId.prestigePlanning:
        if (mastery < NeuralSkills.autoPrestigeMastery) {
          return 'Unlocks at '
              '${(NeuralSkills.autoPrestigeMastery * 100).round()}% Mastery';
        }
        final reaction = NeuralSkills.prestigeReactionSeconds(mastery);
        return 'Prestiges ${reaction < 1 ? 'instantly' : 'within ${NumberFormatter.formatDuration(reaction)}'} '
            'of being ready';
    }
  }
}

class _PrestigeForecast extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final seconds = context.read<GameState>().secondsToNextPrestige;
    final String value;
    if (seconds == null) {
      value = '—';
    } else if (seconds <= 0) {
      value = 'READY NOW';
    } else {
      value = 'IN ${NumberFormatter.formatDuration(seconds).toUpperCase()}';
    }
    return Row(
      children: [
        Text('NEXT PRESTIGE', style: _label(context)),
        const Spacer(),
        Text(value, style: _label(context, color: cs.primary)),
      ],
    );
  }
}

class _SpendLimitPicker extends StatelessWidget {
  final double current;

  const _SpendLimitPicker({required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // A Wrap, not a Row: large text sizes push the chips onto a second line
    // instead of off the card.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text('MAY SPEND', style: _label(context)),
        ),
        for (final limit in NeuralSkills.spendLimits)
          GestureDetector(
            onTap: () => context.read<GameState>().setShoppingSpendLimit(limit),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(
                  color: limit == current ? cs.primary : cs.outlineVariant,
                ),
                color: limit == current
                    ? cs.primary.withValues(alpha: 0.12)
                    : null,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '${(limit * 100).round()}%',
                style: _label(
                  context,
                  color: limit == current ? cs.primary : cs.outline,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;

  const _Bar({required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(1),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 5,
        backgroundColor: cs.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(cs.primary),
      ),
    );
  }
}
