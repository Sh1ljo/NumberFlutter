import 'package:flutter/material.dart';
import '../models/research_node.dart';

abstract class NexusData {
  static List<ResearchNode> allNodes() => [
        // ── TIER I ──────────────────────────────────────────────────────────

        ResearchNode(
          id: 'opt_protocol',
          name: 'Optimization Protocol',
          description: 'Reduces all upgrade costs by 1% per level.',
          icon: Icons.tune,
          tier: 1,
          effectType: ResearchEffect.costReduction,
          effectPerLevel: 0.01,
          maxLevel: 10,
          baseCostPerLevel: 1.0,
          costsScale: true,
        ),

        ResearchNode(
          id: 'surge_protocol',
          name: 'Surge Protocol',
          description:
              'After each prestige, gain 0.5% of your pre-prestige net worth per level.',
          icon: Icons.electric_bolt,
          tier: 1,
          effectType: ResearchEffect.surgeSeconds,
          effectPerLevel: 30.0,
          maxLevel: 5,
          baseCostPerLevel: 2.0,
          costsScale: true,
        ),

        ResearchNode(
          id: 'enhanced_extraction',
          name: 'Enhanced Extraction',
          description:
              'Increases the prestige multiplier gained per prestige by 10% per level.',
          icon: Icons.auto_awesome,
          tier: 1,
          effectType: ResearchEffect.prestigeDeltaMult,
          effectPerLevel: 0.10,
          maxLevel: 5,
          baseCostPerLevel: 2.0,
          costsScale: true,
        ),

        // ── TIER II ─────────────────────────────────────────────────────────

        ResearchNode(
          id: 'idle_foundation',
          name: 'Idle Foundation',
          description:
              'Permanently adds 1.0/sec to your base idle rate per level. Survives prestige.',
          icon: Icons.cached,
          tier: 2,
          prereqLevels: {'opt_protocol': 3},
          effectType: ResearchEffect.idleBonus,
          effectPerLevel: 1.0,
          maxLevel: 10,
          baseCostPerLevel: 2.0,
          costsScale: true,
        ),

        ResearchNode(
          id: 'quick_resume',
          name: 'Quick Resume',
          description:
              'Multiplies offline gains by an additional 10% per level.',
          icon: Icons.fast_forward,
          tier: 2,
          prereqLevels: {'opt_protocol': 5},
          effectType: ResearchEffect.offlineMult,
          effectPerLevel: 0.10,
          maxLevel: 5,
          baseCostPerLevel: 3.0,
          costsScale: true,
        ),

        ResearchNode(
          id: 'kinetic_surge',
          name: 'Kinetic Surge',
          description:
              'Increases the maximum momentum multiplier cap by 0.1x per level.',
          icon: Icons.flash_on,
          tier: 2,
          prereqLevels: {'surge_protocol': 3},
          effectType: ResearchEffect.momentumCap,
          effectPerLevel: 0.1,
          maxLevel: 3,
          baseCostPerLevel: 3.0,
          costsScale: true,
        ),

        // ── TIER III ────────────────────────────────────────────────────────

        ResearchNode(
          id: 'resonance_core',
          name: 'Resonance Core',
          description:
              'Multiplies your effective idle rate by an additional ×1.05 per level.',
          icon: Icons.graphic_eq,
          tier: 3,
          prereqLevels: {'idle_foundation': 5},
          effectType: ResearchEffect.idleMult,
          effectPerLevel: 0.05,
          maxLevel: 5,
          baseCostPerLevel: 5.0,
          costsScale: true,
        ),

        ResearchNode(
          id: 'echo_protocol',
          name: 'Echo Protocol',
          description:
              'Earn 10% more prestige points per level on each prestige.',
          icon: Icons.all_inclusive,
          tier: 3,
          prereqLevels: {'enhanced_extraction': 3},
          effectType: ResearchEffect.prestigePointsMult,
          effectPerLevel: 0.10,
          maxLevel: 5,
          baseCostPerLevel: 4.0,
          costsScale: true,
        ),

        // ── TIER IV ─────────────────────────────────────────────────────────

        ResearchNode(
          id: 'neural_genesis',
          name: 'Neural Genesis',
          description:
              'Awakens the Neural Network. Unlocks a new system where you can grow and tune neurons.',
          icon: Icons.psychology,
          tier: 4,
          prereqLevels: {'resonance_core': 5, 'echo_protocol': 5},
          effectType: ResearchEffect.neuralUnlock,
          effectPerLevel: 1.0,
          maxLevel: 1,
          baseCostPerLevel: 50.0,
          costsScale: false,
        ),
      ];
}
