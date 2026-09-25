import '../logic/game_state.dart';
import '../logic/tutorial_step.dart';

/// One page of the in-game Guide.
///
/// Entries unlock alongside the systems they describe. A locked entry still
/// shows up — as a teaser of what is coming — with its [lockedHint] in place
/// of the body, and a [secret] one hides its title too.
class GuideEntry {
  final String title;
  final String body;
  final bool Function(GameState gs) isUnlocked;
  final String lockedHint;
  final bool secret;

  const GuideEntry({
    required this.title,
    required this.body,
    required this.isUnlocked,
    this.lockedHint = '',
    this.secret = false,
  });
}

class GuideSection {
  final String name;
  final List<GuideEntry> entries;

  const GuideSection({required this.name, required this.entries});
}

bool _always(GameState gs) => true;
bool _prestiged(GameState gs) => gs.prestigeCount >= 1;
bool _neural(GameState gs) => gs.neuralNetworkUnlocked;

/// Unlocked once its tip has been shown, or the upgrade was bought anyway.
bool Function(GameState) _upgradeMet(String upgradeId) => (gs) {
      final tip = upgradeTipSteps[upgradeId];
      if (tip != null && gs.hasSeenTutorialBeat(tip)) return true;
      return gs.upgrades.any((u) => u.id == upgradeId && u.level > 0);
    };

abstract class GuideData {
  static const List<GuideSection> sections = [
    GuideSection(name: 'BASICS', entries: [
      GuideEntry(
        title: 'Tapping',
        body:
            'Every tap on the GENERATORS field adds your click power to the '
            'number. Click upgrades make each tap worth more.',
        isUnlocked: _always,
      ),
      GuideEntry(
        title: 'Idle income',
        body:
            'Idle upgrades earn every second without you — even with the app '
            'closed. When you come back you get a report of what was earned '
            'while you were away (up to 12 hours to start with).',
        isUnlocked: _always,
      ),
      GuideEntry(
        title: 'Level milestones',
        body:
            'Every upgrade doubles its effect at levels 25, 50, 100, 250, 500 '
            'and 1000. The NEXT buy option takes you straight to the next '
            'milestone.',
        isUnlocked: _always,
      ),
      GuideEntry(
        title: 'The advisor',
        body:
            'The RECOMMENDED card on UPGRADES points at the purchase that pays '
            'for itself fastest, weighted by how much you actually tap. BUY '
            'on the card buys exactly the amount it suggests.',
        isUnlocked: _always,
      ),
      GuideEntry(
        title: 'Neural Sparks',
        body:
            'Glowing sparks appear on the play field every so often. Catch '
            'one before it fades and your taps are doubled for 10 seconds.',
        isUnlocked: _always,
      ),
      GuideEntry(
        title: 'Achievements',
        body:
            'Every achievement adds +1% to all production, permanently. Some '
            'are secret. Find them under MORE › ACHIEVEMENTS.',
        isUnlocked: _always,
      ),
    ]),
    GuideSection(name: 'SPECIAL UPGRADES', entries: [
      GuideEntry(
        title: 'Probability Strike',
        body:
            'Each tap has a 5% chance to strike for ×10. Every level after '
            'the first makes strikes hit harder.',
        isUnlocked: _probabilityStrikeMet,
        lockedHint: 'Keep growing your number.',
      ),
      GuideEntry(
        title: 'Momentum',
        body:
            'Tap without stopping to fill the momentum bar; the fuller it is, '
            'the more every tap is multiplied. Stop tapping and it drains. '
            'Levels raise the cap and slow the drain.',
        isUnlocked: _momentumMet,
        lockedHint: 'Keep growing your number.',
      ),
      GuideEntry(
        title: 'Kinetic Synergy',
        body:
            'Each level adds 1% of your idle income per second to every tap, '
            'so idle and tapping grow together.',
        isUnlocked: _kineticMet,
        lockedHint: 'Keep growing your number.',
      ),
      GuideEntry(
        title: 'Overclock',
        body:
            'An unbroken tapping streak triggers Overclock: idle income is '
            'doubled for 30 seconds. Levels shorten the streak and make the '
            'surge longer and stronger.',
        isUnlocked: _overclockMet,
        lockedHint: 'Keep growing your number.',
      ),
      GuideEntry(
        title: 'Temporal Collapse',
        body:
            'An active ability. Once bought, a button on GENERATORS collapses '
            '60 seconds of idle into one burst and doubles your prestige '
            'multiplier for a short time, then recharges.',
        isUnlocked: _collapseMet,
        lockedHint: 'Unlocks at prestige 8.',
      ),
    ]),
    GuideSection(name: 'PRESTIGE', entries: [
      GuideEntry(
        title: 'Prestige',
        body:
            'Reach the requirement and you can reset your number and upgrades '
            'in exchange for a permanent multiplier on everything plus '
            'Prestige Points (PP). The requirement and the reward both grow '
            'with every prestige.',
        isUnlocked: _prestigeMet,
        lockedHint: 'Reach 100M.',
      ),
      GuideEntry(
        title: 'Prestige-only upgrades',
        body:
            'Some upgrades only exist after enough prestiges — Dimensional '
            'Tap at 1, more at 2, 3, 4, 5, 6, 7, 8 and 10. Each one announces '
            'itself when it unlocks.',
        isUnlocked: _prestiged,
        lockedHint: 'Prestige once.',
      ),
      GuideEntry(
        title: 'Artifacts',
        body:
            'Prestige milestones (1, 5, 10, 15, 20, 30, 40, 50) each let you '
            'pick one of three permanent relics. Level them with PP under '
            'PRESTIGE › ARTIFACTS; there is no level cap.',
        isUnlocked: _prestiged,
        lockedHint: 'Prestige once.',
      ),
    ]),
    GuideSection(name: 'THE NEXUS', entries: [
      GuideEntry(
        title: 'The Nexus',
        body:
            'A research tree that survives every reset. Spend PP on nodes; '
            'levelling a tier opens the next. Find it under PRESTIGE › NEXUS.',
        isUnlocked: _nexusMet,
        lockedHint: 'Reach 3 prestiges.',
      ),
      GuideEntry(
        title: 'Neural Genesis',
        body:
            'The node at the root of the tree. It needs Resonance Core and '
            'Echo Protocol at level 5, and it awakens the Neural Network.',
        isUnlocked: _nexusMet,
        lockedHint: 'Something waits at the bottom of the Nexus.',
        secret: true,
      ),
    ]),
    GuideSection(name: 'NEURAL NETWORK', entries: [
      GuideEntry(
        title: 'The network',
        body:
            'Your network trains on its own, even offline. As accuracy rises '
            'the MULT multiplier on all production rises with it. Accuracy '
            'gets closer to 100% but never reaches it.',
        isUnlocked: _neural,
        lockedHint: 'Not yet.',
        secret: true,
      ),
      GuideEntry(
        title: 'Neurons',
        body:
            'Tap a neuron to upgrade its gradient (faster training), change '
            'its activation function (each layer prefers one, which trains '
            '10% faster), or branch it to grow the next layer.',
        isUnlocked: _neural,
        lockedHint: 'Not yet.',
        secret: true,
      ),
      GuideEntry(
        title: 'Epochs',
        body:
            'Once the network converges below 1% loss you can start an Epoch: '
            'training and gradients reset, every neuron stays, and each Epoch '
            'adds +10% to all production permanently — at the cost of '
            'training a little slower.',
        isUnlocked: _neural,
        lockedHint: 'Not yet.',
        secret: true,
      ),
      GuideEntry(
        title: 'Deep layers',
        body:
            'Prestiges 18, 22, 26 and 30 each open one layer deeper than the '
            'pyramid. Deep neurons cost more and raise the multiplier '
            'ceiling.',
        isUnlocked: _neural,
        lockedHint: 'Not yet.',
        secret: true,
      ),
    ]),
  ];

  static bool _probabilityStrikeMet(GameState gs) =>
      _upgradeMet(GameState.probabilityStrikeId)(gs);
  static bool _momentumMet(GameState gs) =>
      _upgradeMet(GameState.momentumId)(gs);
  static bool _kineticMet(GameState gs) =>
      _upgradeMet(GameState.kineticSynergyId)(gs);
  static bool _overclockMet(GameState gs) =>
      _upgradeMet(GameState.overclockId)(gs);
  static bool _collapseMet(GameState gs) =>
      gs.prestigeCount >= gs.minPrestigeForUpgrade(GameState.temporalCollapseId);
  static bool _prestigeMet(GameState gs) =>
      gs.prestigeCount >= 1 ||
      gs.hasSeenTutorialBeat(TutorialStep.prestigeReady);
  static bool _nexusMet(GameState gs) =>
      gs.nexusStabilized ||
      gs.prestigeCount >= GameState.nexusPrestigeRequirement;
}
