import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MIDNIGHT INK PAINTER
// 1 AM – 4 AM. Protective, intimate late-night cocoon.
//
// Light Mode: Cool blue-white glow at top — well-lit indoor space at night.
// Dark Mode:  Moonlight radial glow through a skylight. Very subtle.
// ─────────────────────────────────────────────────────────────────────────────

class MidnightInkPainter extends CustomPainter {
  final bool isDark;

  const MidnightInkPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (isDark) {
      // Cool moonlight from top-center — 15% opacity max
      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -1.2),
          radius: 0.9,
          colors: [
            const Color(0xFFB8C8E8).withOpacity(0.14),
            const Color(0xFF8899CC).withOpacity(0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect);

      canvas.drawRect(rect, paint);
    } else {
      // Light mode: cool-blue tint glow from top — indoor lamp / city light
      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -1.0),
          radius: 1.1,
          colors: [
            const Color(0xFFD8E4F8).withOpacity(0.18),
            const Color(0xFFE8EFF8).withOpacity(0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(MidnightInkPainter old) => old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
// SUNDAY MORNING PAINTER
// 7 AM – 10 AM on Sundays. Quiet, reflective, parchment-warm.
//
// Light Mode: Faint warm parchment radial glow from top-center.
// Dark Mode:  Very faint cool-blue top glow — soft dawn light.
// ─────────────────────────────────────────────────────────────────────────────

class SundayMorningPainter extends CustomPainter {
  final bool isDark;

  const SundayMorningPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (isDark) {
      // Dawn light just starting to appear — cool-blue, very subtle
      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -1.0),
          radius: 1.0,
          colors: [
            const Color(0xFFCCD8EE).withOpacity(0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(rect);

      canvas.drawRect(rect, paint);
    } else {
      // Parchment warmth — gentle, like paper-filtered light
      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.9),
          radius: 1.1,
          colors: [
            const Color(0xFFEEE0C0).withOpacity(0.16),
            const Color(0xFFF5EED8).withOpacity(0.07),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);

      canvas.drawRect(rect, paint);

      // Subtle texture suggestion — horizontal very faint lines
      _paintParchmentLines(canvas, size);
    }
  }

  void _paintParchmentLines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFD4C090).withOpacity(0.04)
      ..strokeWidth = 1.0;

    // Sparse, irregular horizontal lines suggesting paper grain
    final linePositions = [0.08, 0.21, 0.35, 0.51, 0.67, 0.82, 0.94];
    for (final pct in linePositions) {
      final y = size.height * pct;
      canvas.drawLine(
        Offset(size.width * 0.05, y),
        Offset(size.width * 0.95, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(SundayMorningPainter old) => old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
// GOLDEN HOUR PAINTER
// 5:50 – 6:10 AM and 4:50 – 5:10 PM.
// Softer than 3PM — more white than gold.
//
// Light Mode: Faint diagonal streak from upper-left (gentle, not 3PM intense).
// Dark Mode:  Faint cool-blue top glow — dawn light starting to appear.
// ─────────────────────────────────────────────────────────────────────────────

class GoldenHourPainter extends CustomPainter {
  final bool isDark;

  const GoldenHourPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (isDark) {
      // Dawn / dusk seeping — cool-blue from top, very faint
      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -1.0),
          radius: 1.0,
          colors: [
            const Color(0xFFB8C8E0).withOpacity(0.10),
            Colors.transparent,
          ],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    } else {
      // Softer diagonal streak — upper-left origin
      _paintSoftStreak(canvas, size);
      // Radial warmth
      final glowPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.7, -0.8),
          radius: 1.0,
          colors: [
            const Color(0xFFFFEECC).withOpacity(0.15),
            Colors.transparent,
          ],
        ).createShader(rect);
      canvas.drawRect(rect, glowPaint);
    }
  }

  void _paintSoftStreak(Canvas canvas, Size size) {
    const double angle = 30.0 * math.pi / 180.0;
    final double streakWidth = size.width * 0.45;
    final shiftY = size.height * math.tan(angle);

    final path = Path()
      ..moveTo(-size.width * 0.1, 0)
      ..lineTo(-size.width * 0.1 + streakWidth, 0)
      ..lineTo(-size.width * 0.1 + streakWidth - shiftY, size.height)
      ..lineTo(-size.width * 0.1 - shiftY, size.height)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFF5E0).withOpacity(0.12),
          Colors.transparent,
        ],
      ).createShader(path.getBounds())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(GoldenHourPainter old) => old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
// RAINY / FOGGY / SNOWY PAINTER
// Weather-triggered. Single painter handles all three via [condition] flag.
//
// Rainy: Blue-tinted cool overlay, subtle streaks suggestion
// Foggy: Soft grey-white radial diffusion
// Snowy: Cool blue-white top glow
// ─────────────────────────────────────────────────────────────────────────────

class RainyPainter extends CustomPainter {
  final bool isDark;
  final String condition; // 'Rainy' | 'Foggy' | 'Snowy'

  const RainyPainter({required this.isDark, required this.condition});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    switch (condition) {
      case 'Rainy':
        _paintRainy(canvas, size, rect);
      case 'Foggy':
        _paintFoggy(canvas, size, rect);
      case 'Snowy':
        _paintSnowy(canvas, size, rect);
      case 'Stormy':
        _paintStormy(canvas, size, rect);
      case 'Cloudy':
        _paintCloudy(canvas, size, rect);
    }
  }

  void _paintRainy(Canvas canvas, Size size, Rect rect) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8899BB).withOpacity(isDark ? 0.12 : 0.09),
          const Color(0xFF6677AA).withOpacity(isDark ? 0.06 : 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintStormy(Canvas canvas, Size size, Rect rect) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3A4560).withOpacity(isDark ? 0.22 : 0.16),
          const Color(0xFF252E48).withOpacity(isDark ? 0.12 : 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintCloudy(Canvas canvas, Size size, Rect rect) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.8),
        radius: 1.1,
        colors: [
          (isDark ? const Color(0xFF8888AA) : const Color(0xFFBBBBCC))
              .withOpacity(isDark ? 0.08 : 0.10),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintFoggy(Canvas canvas, Size size, Rect rect) {
    // Soft diffused white-grey from all edges
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          Colors.transparent,
          isDark
              ? const Color(0xFF888888).withOpacity(0.08)
              : const Color(0xFFDDDDDD).withOpacity(0.15),
        ],
        stops: const [0.4, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintSnowy(Canvas canvas, Size size, Rect rect) {
    // Cool blue-white from top
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -1.0),
        radius: 1.1,
        colors: [
          const Color(0xFFCCDDFF).withOpacity(isDark ? 0.10 : 0.12),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(RainyPainter old) =>
      old.isDark != isDark || old.condition != condition;
}
