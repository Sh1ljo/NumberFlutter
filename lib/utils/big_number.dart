/// Whole part of a non-negative production amount, exact for any size.
///
/// `BigInt.from(x.floor())` goes through a 64-bit int, which silently caps
/// at ~9.22e18: past that, taps, ticks and bursts stopped growing no matter
/// how strong the player got. `BigInt.from(double)` converts directly.
/// Infinity (a production rate past ~1.8e308) is clamped instead of
/// throwing inside the game loop.
BigInt wholeBigInt(double value) {
  if (value.isNaN || value < 1) return BigInt.zero;
  return BigInt.from(value.isFinite ? value : double.maxFinite);
}
