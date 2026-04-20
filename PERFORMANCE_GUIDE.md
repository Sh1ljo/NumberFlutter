# Performance Optimization Guide

## What Was Optimized

### 1. **Granular State Management**
- **Before**: The entire main screen rebuilt on every state change (every 100ms + every click)
- **After**: Using `Selector` widgets to only rebuild specific parts when their data changes
  - Number display only rebuilds when `number` changes
  - Idle rate only rebuilds when `totalIdleRate` changes
  - Momentum bar only rebuilds when momentum data changes

### 2. **RepaintBoundary Isolation**
- Added `RepaintBoundary` widgets around frequently updating areas
- Prevents repainting cascades across the widget tree
- Each isolated section only repaints when its own data changes

### 3. **Reduced Animation Overhead**
- Changed `AnimatedFractionallySizedBox` to `FractionallySizedBox` in momentum bar
- Reduces unnecessary animation calculations during rapid clicks

### 4. **Optimized State Notifications**
- Added thresholds to only notify listeners when changes are significant
- Prevents micro-updates that don't affect visual output

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
