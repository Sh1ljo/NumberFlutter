import 'dart:math' as math;

/// Number of dots in the Nexus sphere.
const int nexusSphereDotCount = 100;

/// Unit-sphere coordinates (x, y, z) of the Nexus's Fibonacci-sphere dots.
///
/// These never change, but the painters used to recompute all of them (an
/// acos plus six sin/cos each) on every frame, up to five times a frame
/// during the stabilize spin-up trail. Same formulas, computed once.
final List<(double, double, double)> nexusSpherePoints = List.unmodifiable(
  List.generate(nexusSphereDotCount, (i) {
    const goldenAngle = 2.399963229728653;
    final t = i / (nexusSphereDotCount - 1);
    final inclination = math.acos(1 - 2 * t);
    final azimuth = goldenAngle * i;
    return (
      math.sin(inclination) * math.cos(azimuth),
      math.sin(inclination) * math.sin(azimuth),
      math.cos(inclination),
    );
  }),
);
