import 'package:flutter/material.dart';
import '../../../../utils/number_formatter.dart';
import '../prestige_constants.dart';

class PrestigeOverlay extends StatelessWidget {
  final double progress;
  final ThemeData theme;
  final double pointsEarned;

  const PrestigeOverlay({
    super.key,
    required this.progress,
    required this.theme,
    required this.pointsEarned,
  });

  static const _labelIn = Interval(0.18, 0.42, curve: Curves.easeIn);
  static const _labelOut = Interval(0.60, 0.72, curve: Curves.easeOut);
  static const _scan = Interval(0.14, 0.70, curve: Curves.easeInOut);

  @override
  Widget build(BuildContext context) {
    final isReveal = progress >= kPrestigeFirePoint;

    final labelOpacity = isReveal
        ? 0.0
        : (_labelIn.transform(progress) *
                (1.0 - _labelOut.transform(progress)))
            .clamp(0.0, 1.0);

    final scanProgress = isReveal ? 1.0 : _scan.transform(progress);

    return CustomPaint(
      painter: _PrestigePainter(progress: progress),
      child: SizedBox.expand(
        child: Center(
          child: Opacity(
            opacity: labelOpacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'RESETTING SEQUENCE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.black87,
                      letterSpacing: 5.0,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 128,
                    child: LinearProgressIndicator(
                      value: scanProgress,
                      backgroundColor: Colors.black.withValues(alpha: 0.08),
                      color: Colors.black87,
                      minHeight: 2,
                    ),
                  ),
                  if (pointsEarned > 0.0) ...[
                    const SizedBox(height: 22),
                    Text(
                      '+${NumberFormatter.formatDouble(pointsEarned)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'PRESTIGE POINTS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter — two phases:
//   Phase 1 (0 → kPrestigeFirePoint): dark overlay → scan sweep → flash
//   Phase 2 (kPrestigeFirePoint → 1): white fades out revealing reset screen
class _PrestigePainter extends CustomPainter {
  final double progress;

  const _PrestigePainter({required this.progress});

  static const _overlayIn =
      Interval(0.00, 0.14, curve: Curves.easeIn);
  static const _scan =
      Interval(0.14, 0.66, curve: Curves.easeInOut);
  static const _flashIn =
      Interval(0.64, kPrestigeFirePoint, curve: Curves.easeIn);
  static const _reveal =
      Interval(kPrestigeFirePoint, 1.00, curve: Curves.easeInOut);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < kPrestigeFirePoint) {
      // 1. Dark overlay
      final overlayOpacity = _overlayIn.transform(progress);
      if (overlayOpacity > 0) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color =
                Colors.black.withValues(alpha: 0.88 * overlayOpacity),
        );
      }

      // 2. White scan sweep
      final scanProgress = _scan.transform(progress);
      if (scanProgress > 0) {
        final scanY = size.height * scanProgress;

        // Solid white region above the scan line
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, scanY),
          Paint()..color = Colors.white.withValues(alpha: 0.97),
        );

        // Glowing leading edge
        const glowH = 60.0;
        final glowRect =
            Rect.fromLTWH(0, scanY - glowH / 2, size.width, glowH);
        canvas.drawRect(
          glowRect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.55),
                Colors.white,
                Colors.white.withValues(alpha: 0.55),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ).createShader(glowRect),
        );
      }

      // 3. Flash in
      final flashOpacity = _flashIn.transform(progress);
      if (flashOpacity > 0) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = Colors.white.withValues(alpha: flashOpacity),
        );
      }
    } else {
      // Reverse scan (bottom → top) reveals reset screen
      final revealProgress = _reveal.transform(progress);
      final bottomWhiteY = size.height * (1.0 - revealProgress);

      // Solid white above the reverse scan line
      if (bottomWhiteY > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, bottomWhiteY),
          Paint()..color = Colors.white.withValues(alpha: 0.97),
        );
      }

      // Glowing trailing edge
      const glowH = 60.0;
      final glowRect =
          Rect.fromLTWH(0, bottomWhiteY - glowH / 2, size.width, glowH);
      canvas.drawRect(
        glowRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.55),
              Colors.white,
              Colors.white.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
          ).createShader(glowRect),
      );
    }
  }

  @override
  bool shouldRepaint(_PrestigePainter old) => old.progress != progress;
}
