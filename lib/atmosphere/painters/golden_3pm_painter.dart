import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GOLDEN 3PM PAINTER
// The star atmosphere. Simulates afternoon window light on a wall.
//
// Light Mode:
//   - Diagonal window light streaks (30-45° angle, grid of parallelograms)
//   - Warm radial glow from upper-right
//   - BlendMode.screen for realistic light layering
//
// Dark Mode:
//   - NO streaks (light implies brightness)
//   - Soft warm amber radial glow from upper corners only
//   - Like afternoon light seeping around curtains
// ─────────────────────────────────────────────────────────────────────────────

class Golden3pmPainter extends CustomPainter {
  final bool isDark;

  const Golden3pmPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) {
      _paintDark(canvas, size);
    } else {
      _paintLight(canvas, size);
    }
  }

  // ── Light Mode ─────────────────────────────────────────────────────────────

  void _paintLight(Canvas canvas, Size size) {
    // 1. Warm radial glow from upper-right corner
    _paintUpperRightGlow(canvas, size);

    // 2. Window light streak grid
    _paintWindowStreaks(canvas, size);
  }

  void _paintUpperRightGlow(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, -0.8),
        radius: 0.9,
        colors: [
          const Color(0xFFFFEBB5).withOpacity(0.22), // Warm golden
          const Color(0xFFFFF3C4).withOpacity(0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..blendMode = BlendMode.screen;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _paintWindowStreaks(Canvas canvas, Size size) {
    // Window light: 2×3 grid of parallelogram patches
    // Diagonal at ~35 degrees, divided by thin shadow "mullion" lines
    const double angle = 35.0 * math.pi / 180.0;
    final double streakWidth = size.width * 0.18;
    final double gapWidth = size.width * 0.055; // Mullion shadow

    final paint = Paint()..blendMode = BlendMode.screen;

    // Start streaks from left edge, sweep right
    double x = -size.width * 0.3;
    int streakIndex = 0;
    while (x < size.width * 1.4) {
      if (streakIndex % 3 != 1) {
        // Skip every 3rd to create mullion gap variation
        _paintStreak(
          canvas,
          size,
          paint,
          startX: x,
          width: streakWidth,
          angle: angle,
          opacity: streakIndex.isEven ? 0.18 : 0.13,
        );
      }
      x += streakWidth + gapWidth;
      streakIndex++;
    }
  }

  void _paintStreak(
    Canvas canvas,
    Size size,
    Paint basePaint,
    {
    required double startX,
    required double width,
    required double angle,
    required double opacity,
  }) {
    final shiftY = size.height * math.tan(angle);

    final path = Path()
      ..moveTo(startX, 0)
      ..lineTo(startX + width, 0)
      ..lineTo(startX + width - shiftY, size.height)
      ..lineTo(startX - shiftY, size.height)
      ..close();

    final rect = path.getBounds();
    final paint = basePaint
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFF0D2).withOpacity(opacity),
          const Color(0xFFFFEBB5).withOpacity(opacity * 0.6),
          const Color(0xFFFFF0D2).withOpacity(opacity * 0.3),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    // Feathered edges via MaskFilter
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
    canvas.drawPath(path, paint);

    // Soften edges
    final featherPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..color = Colors.transparent;
    canvas.drawPath(path, featherPaint);

    canvas.restore();
  }

  // ── Dark Mode ──────────────────────────────────────────────────────────────

  void _paintDark(Canvas canvas, Size size) {
    // Soft warm amber glow seeping from upper-left and upper-right corners
    // Like afternoon light around dark curtains — max 14% opacity
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Upper-right amber
    final rightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(1.0, -1.0),
        radius: 1.2,
        colors: [
          const Color(0xFFFFB347).withOpacity(0.13),
          const Color(0xFFFF8C00).withOpacity(0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, rightPaint);

    // Upper-left warm echo
    final leftPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-1.0, -1.0),
        radius: 0.9,
        colors: [
          const Color(0xFFFFB347).withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, leftPaint);
  }

  @override
  bool shouldRepaint(Golden3pmPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
