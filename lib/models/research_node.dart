import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResearchNode {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final int tier;
  final Map<String, int> prereqLevels; // nodeId -> minimum level required
  final int maxLevel;
  final double baseCostPerLevel;
  /// If true, cost grows geometrically: base * [costGrowth] ^ level.
  ///
  /// It used to be linear ((level + 1) * base), which put PP on a linear curve
  /// against an exponential number economy — the whole 1,469 PP tree got
  /// bought out within a few prestiges of unlocking and PP had no sink after.
  final bool costsScale;
  final String effectType;
  final double effectPerLevel;
  int level;

  ResearchNode({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.tier,
    required this.effectType,
    required this.effectPerLevel,
    this.prereqLevels = const {},
    this.maxLevel = 10,
    this.baseCostPerLevel = 1.0,
    this.costsScale = false,
    this.level = 0,
  });

  bool get isMaxed => level >= maxLevel;

  /// Per-level cost growth for nodes with [costsScale] set.
  static const double costGrowth = 1.6;

  double get costForNextLevel => costsScale
      ? baseCostPerLevel * math.pow(costGrowth, level)
      : baseCostPerLevel;

  bool prereqsMet(List<ResearchNode> allNodes) {
    for (final entry in prereqLevels.entries) {
      final node = allNodes.where((n) => n.id == entry.key).firstOrNull;
      if (node == null || node.level < entry.value) return false;
    }
    return true;
  }

  String prereqDescription(List<ResearchNode> allNodes) {
    if (prereqLevels.isEmpty) return '';
    final parts = <String>[];
    for (final entry in prereqLevels.entries) {
      final node = allNodes.where((n) => n.id == entry.key).firstOrNull;
      final name = node?.name ?? entry.key;
      parts.add('$name Lv ${entry.value}');
    }
    return parts.join(', ');
  }
}

// Effect type constants
abstract class ResearchEffect {
  static const String costReduction = 'cost_reduction';
  static const String surgeSeconds = 'surge_seconds';
  static const String prestigeDeltaMult = 'prestige_delta_mult';
  static const String idleBonus = 'idle_bonus';
  static const String offlineMult = 'offline_mult';
  static const String momentumCap = 'momentum_cap';
  static const String idleMult = 'idle_mult';
  static const String prestigePointsMult = 'prestige_points_mult';
  static const String neuralUnlock = 'neural_unlock';
}
