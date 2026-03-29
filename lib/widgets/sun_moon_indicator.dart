import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/atmosphere_state.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SUN/MOON INDICATOR
// Always visible in top-left corner across all panels and screens.
// Drawn entirely in code — no emoji, no icon library.
// Sun: thin-stroke circle + 8 irregular radiating lines
// Moon: two overlapping circles creating a crescent
// Color shifts with atmosphere and time of day.
// ─────────────────────────────────────────────────────────────────────────────

class SunMoonIndicator extends StatelessWidget {
  const SunMoonIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AtmosphereState, AppState>(
      builder: (context, atmo, app, _) {
        final color = atmo.sunMoonColor();
        final isDay = atmo.isDay;

        return AnimatedSwitcher(
          duration: const Duration(seconds: 3),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: SizedBox(
            key: ValueKey(isDay),
            width: 32,
            height: 32,
            child: CustomPaint(
              painter: isDay
                  ? _SunPainter(color: color)
                  : _MoonPainter(color: color),
            ),
          ),
        );
      },
    );
  }
}

// ── Sun Painter ───────────────────────────────────────────────────────────────

class _SunPainter extends CustomPainter {
  final Color color;
  const _SunPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Central circle
    canvas.drawCircle(center, 5.5, paint);

    // 8 radiating lines at 45° intervals, slightly irregular lengths
    final lengths = [5.5, 4.8, 5.5, 4.5, 5.5, 5.0, 5.5, 4.7];
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final innerR = 7.5;
      final outerR = innerR + lengths[i];
      canvas.drawLine(
        Offset(center.dx + innerR * math.cos(angle),
            center.dy + innerR * math.sin(angle)),
        Offset(center.dx + outerR * math.cos(angle),
            center.dy + outerR * math.sin(angle)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.color != color;
}

// ── Moon Painter ──────────────────────────────────────────────────────────────

class _MoonPainter extends CustomPainter {
  final Color color;
  const _MoonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw crescent: main circle minus offset mask circle
    final path = Path();

    // Main circle
    path.addOval(Rect.fromCircle(center: center, radius: 8.0));

    // Cut out the mask circle (offset right to create crescent)
    final maskCenter = Offset(center.dx + 5.0, center.dy - 1.5);
    final maskPath = Path()
      ..addOval(Rect.fromCircle(center: maskCenter, radius: 7.0));

    final crescent = Path.combine(PathOperation.difference, path, maskPath);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(crescent, paint);
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.color != color;
}
