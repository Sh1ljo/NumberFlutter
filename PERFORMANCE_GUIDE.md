# Performance Optimization Guide

## Rules for new code

`GameState`'s ticker calls `notifyListeners()` every 100ms (10x/s), plus once
per tap. Anything that listens to the whole `GameState` rebuilds at that rate.

- **Never `context.watch<GameState>()` or `Consumer<GameState>` at a screen's
  root.** Use `context.select` / `Selector` on exactly the values you render,
  and put the per-tick bit (usually the `number` text) in its own small
  `Selector`. Records work as multi-value selector results.
- Values mutated in place (upgrade/research levels, neurons) need a value key:
  a record of the fields, `Selector(shouldRebuild: listEquals)` for lists, or
  `GameState.neuralTopologyKey` for the neural network.
- Anything that animates continuously sits under its own `RepaintBoundary`.
- `CustomPainter`s driven by a controller take it as `repaint:` instead of
  being rebuilt through `AnimatedBuilder`; don't allocate `Paint`s, shaders or
  constant geometry per frame.
- Never create `CurvedAnimation`/`Tween.animate` inside `build` or a builder:
  each one adds a listener to the controller that is never removed.
- Don't recompute in getters what only changes on purchase/prestige; see the
  memoized `prestigeRequirement`, `neuralNetworkStrength` and cost multiplier.

## What Was Optimized

### Rebuilds
- Upgrades, Prestige, Nexus tree/nodes/sheet, Settings, Profile (stats only),
  the tutorial overlay and the neuron sheet select narrow slices instead of
  rebuilding wholesale 10x/s. Upgrade rows each select their own purchase
  info; only the affordability bar follows the number.
- Tap particles live in their own layer (`FloatingTapTextLayer`), so a tap no
  longer rebuilds the game screen; particles move with a paint-time transform
  instead of re-laying out the Stack every frame.

### Game loop
- Upgrade/research lookups are O(1) id→index maps (levels still read live).
- `prestigeRequirement` (BigInt powers) is memoized per prestige count.
- Neural strength is cached against the network's revision.
- Purchase cost multipliers extend incrementally instead of looping from level
  0 on every call; `test/perf_caches_test.dart` pins them to the old maths.

### Animation
- Neural canvas: correct `TickerProviderStateMixin` (two controllers), one
  shared curve for all neurons, neuron layer behind a `RepaintBoundary`, ring
  opacity baked into colour instead of `Opacity` layers.
- Fixed a listener leak on the neural unlock screen (~120 listeners/s).
- Nexus sphere points are computed once (`sphere_points.dart`); sorting and
  paint objects reuse buffers; the ambient background repaints off its
  controller with a cached base shader.

### I/O
- Saves skip SharedPreferences keys whose value hasn't changed and run one at
  a time (no interleaved snapshots). A save is flushed when the app is
  backgrounded.
- Failed automatic cloud syncs back off (20s → 5min) instead of retrying on
  every save.
- The 1.45MB countries JSON is parsed on a background isolate.
- The leaderboard no longer refetches on unrelated rebuilds or twice per
  pull-to-refresh.
- Fonts are bundled in `assets/google_fonts/` (runtime fetching disabled).

## Running in Release Mode

**This is the MOST IMPORTANT optimization!**

Debug mode (`flutter run`) is 10-20x slower than release mode because it includes:
- Debugging symbols
- Hot reload infrastructure
- Performance profiling
- Extensive error checking

### How to Run in Release Mode

#### For Android:
```powershell
flutter run --release
```

#### For iOS:
```powershell
flutter run --release
```

#### For Windows:
```powershell
flutter run --release -d windows
```

### Building Release Builds

#### Android APK:
```powershell
flutter build apk --release
```

#### Android App Bundle (for Play Store):
```powershell
flutter build appbundle --release
```

#### iOS (requires Mac):
```powershell
flutter build ios --release
```

#### Windows:
```powershell
flutter build windows --release
```

## Performance Improvements You'll See

1. **Smooth animations** even with 100+ click upgrades
2. **No lag** during rapid clicking
3. **Consistent 60 FPS** (or 120 FPS on high-refresh displays)
4. **Lower battery consumption** on mobile devices
5. **Faster app startup**

## Additional Performance Tips

### For Development:
- Use `flutter run --profile` for performance testing with some debugging features
- Use Flutter DevTools to profile performance: `flutter pub global activate devtools`

### For Production:
- Always test your game in `--release` mode before publishing
- Use `--split-debug-info` and `--obfuscate` for smaller builds:
  ```powershell
  flutter build apk --release --split-debug-info=./debug-info --obfuscate
  ```

## What to Expect

- **Debug mode**: May lag with many upgrades, especially on lower-end devices
- **Profile mode**: Better performance, useful for testing
- **Release mode**: Buttery smooth, production-ready performance

Your game should now run smoothly even with all click upgrades purchased!
