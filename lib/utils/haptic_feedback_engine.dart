import 'package:flutter/services.dart';

class HapticFeedbackEngine {
  static DateTime _lastPulseAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _minPulseGapMs = 22;

  static bool _canPulse({
    required bool enabled,
    required bool bypassGap,
  }) {
    if (!enabled) return false;
    if (bypassGap) return true;
    final now = DateTime.now();
    final elapsed = now.difference(_lastPulseAt).inMilliseconds;
    if (elapsed < _minPulseGapMs) return false;
    _lastPulseAt = now;
    return true;
  }

  static double _normalized(double intensity) {
    return intensity.clamp(0.0, 1.0).toDouble();
  }

  static void _markPulseNow() {
    _lastPulseAt = DateTime.now();
  }

  static Future<void> playTap({
    required bool enabled,
    required double intensity,
  }) async {
    if (!_canPulse(enabled: enabled, bypassGap: false)) return;
    _markPulseNow();
    final normalized = _normalized(intensity);

    if (normalized < 0.5) {
      await HapticFeedback.lightImpact();
      return;
    }
    if (normalized < 0.85) {
      await HapticFeedback.mediumImpact();
      return;
    }
    await HapticFeedback.heavyImpact();
  }

  static Future<void> playProbabilityStrike({
    required bool enabled,
    required double intensity,
  }) async {
    if (!_canPulse(enabled: enabled, bypassGap: true)) return;
    _markPulseNow();
    final normalized = _normalized(intensity);
    if (normalized < 0.5) {
      await HapticFeedback.mediumImpact();
      return;
    }
    await HapticFeedback.heavyImpact();
  }

  static Future<void> playPersonalBest({
    required bool enabled,
    required double intensity,
  }) async {
    if (!_canPulse(enabled: enabled, bypassGap: true)) return;
    _markPulseNow();
    final normalized = _normalized(intensity);
    if (normalized < 0.5) {
      await HapticFeedback.mediumImpact();
      return;
    }
    await HapticFeedback.heavyImpact();
  }
}
