import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/atmosphere_state.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SUN/MOON INDICATOR — Animated, weather-aware
// Drawn entirely in code — no emoji, no icon library.
// Animates: sun rays rotate slowly, moon has glow pulse.
// Weather states: rain drops, snowflake, fog waves, cloud.
// ─────────────────────────────────────────────────────────────────────────────

class SunMoonIndicator extends StatefulWidget {
  const SunMoonIndicator({super.key});

  @override
  State<SunMoonIndicator> createState() => _SunMoonIndicatorState();
}

class _SunMoonIndicatorState extends State<SunMoonIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _rainCtrl;

  @override
  void initState() {
    super.initState();
    // Sun ray rotation: imperceptibly slow (120s per revolution)
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();

    // Glow / breathing pulse (3s cycle)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Rain/snow animation (2s cycle)
    _rainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _pulseCtrl.dispose();
    _rainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AtmosphereState, AppState>(
      builder: (context, atmo, app, _) {
        final color = atmo.sunMoonColor();
        final isDay = atmo.isDay;
        final atmosphere = atmo.current;

        return AnimatedSwitcher(
          duration: const Duration(seconds: 3),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: SizedBox(
            key: ValueKey('${atmosphere}_$isDay'),
            width: 32,
            height: 32,
            child: AnimatedBuilder(
              animation: Listenable.merge([_rotationCtrl, _pulseCtrl, _rainCtrl]),
              builder: (context, _) {
                final rotation = _rotationCtrl.value * math.pi * 2;
                final pulse = _pulseCtrl.value;
                final rainProgress = _rainCtrl.value;

                return CustomPaint(
                  painter: _selectPainter(
                    atmosphere: atmosphere,
                    isDay: isDay,
                    color: color,
                    rotation: rotation,
                    pulse: pulse,
                    rainProgress: rainProgress,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  CustomPainter _selectPainter({
    required String atmosphere,
    required bool isDay,
    required Color color,
    required double rotation,
    required double pulse,
    required double rainProgress,
  }) {
    switch (atmosphere) {
      case 'Rainy':
        return _RainPainter(color: color, progress: rainProgress);
      case 'Snowy':
        return _SnowPainter(color: color, rotation: rotation * 0.25);
      case 'Foggy':
        return _FogPainter(color: color, pulse: pulse);
      case 'GoldenHour':
        return _GoldenHourPainter(color: color, pulse: pulse);
      default:
        if (isDay) {
          return _SunPainter(color: color, rotation: rotation, pulse: pulse);
        } else {
          return _MoonPainter(color: color, pulse: pulse);
        }
    }
  }
}

// ── Sun Painter ───────────────────────────────────────────────────────────────

class _SunPainter extends CustomPainter {
  final Color color;
  final double rotation;
  final double pulse;

  const _SunPainter({
    required this.color,
    required this.rotation,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Glow pulse
    canvas.drawCircle(
      center,
      13,
      Paint()
        ..color = color.withOpacity(0.20 + pulse * 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // Central circle
    canvas.drawCircle(center, 5.5, paint);

    // 8 rotating rays with slightly irregular lengths
    final lengths = [5.5, 4.5, 5.8, 4.2, 5.5, 4.7, 5.3, 4.4];
    for (int i = 0; i < 8; i++) {
      final angle = rotation + i * math.pi / 4;
      const innerR = 7.8;
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
  bool shouldRepaint(_SunPainter old) =>
      old.rotation != rotation || old.pulse != pulse || old.color != color;
}

// ── Moon Painter ──────────────────────────────────────────────────────────────

class _MoonPainter extends CustomPainter {
  final Color color;
  final double pulse;

  const _MoonPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Glow pulse
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..color = color.withOpacity(0.18 + pulse * 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
    );

    // Crescent: main circle minus offset mask
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: 8.5));
    final maskCenter = Offset(center.dx + 5.5, center.dy - 1.5);
    final maskPath = Path()
      ..addOval(Rect.fromCircle(center: maskCenter, radius: 7.5));
    final crescent = Path.combine(PathOperation.difference, path, maskPath);

    canvas.drawPath(crescent, Paint()..color = color..style = PaintingStyle.fill);

    // Star near moon
    final starPos = Offset(center.dx + 9, center.dy - 8);
    final starPaint = Paint()
      ..color = color.withOpacity(0.65 + pulse * 0.35)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const sR = 2.0;
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawLine(
        Offset(starPos.dx + sR * 0.4 * math.cos(a), starPos.dy + sR * 0.4 * math.sin(a)),
        Offset(starPos.dx + sR * math.cos(a), starPos.dy + sR * math.sin(a)),
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.pulse != pulse || old.color != color;
}

// ── Rain Painter ──────────────────────────────────────────────────────────────

class _RainPainter extends CustomPainter {
  final Color color;
  final double progress; // 0 to 1 looping

  const _RainPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Cloud shape
    final cloudPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final cloudPath = Path();
    cloudPath.moveTo(center.dx - 9, center.dy - 2);
    cloudPath.arcToPoint(Offset(center.dx - 5, center.dy - 7),
        radius: const Radius.circular(5));
    cloudPath.arcToPoint(Offset(center.dx + 1, center.dy - 8),
        radius: const Radius.circular(4));
    cloudPath.arcToPoint(Offset(center.dx + 9, center.dy - 3),
        radius: const Radius.circular(5));
    cloudPath.arcToPoint(Offset(center.dx - 9, center.dy - 2),
        radius: const Radius.circular(8), clockwise: false);
    canvas.drawPath(cloudPath, cloudPaint);

    // 3 animated rain drops
    final dropPaint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const dropOffsets = [-6.0, 0.0, 6.0];
    const dropDelays = [0.0, 0.33, 0.66];

    for (int i = 0; i < 3; i++) {
      final phase = (progress + dropDelays[i]) % 1.0;
      final y = center.dy + 2 + phase * 12;
      final opacity = (1.0 - phase).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(center.dx + dropOffsets[i] - 1, y),
        Offset(center.dx + dropOffsets[i] + 1, y + 4),
        dropPaint..color = color.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Snow Painter ──────────────────────────────────────────────────────────────

class _SnowPainter extends CustomPainter {
  final Color color;
  final double rotation;

  const _SnowPainter({required this.color, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 6 arms of snowflake, rotating
    for (int i = 0; i < 6; i++) {
      final angle = rotation + i * math.pi / 3;
      final armEnd = Offset(
        center.dx + 10 * math.cos(angle),
        center.dy + 10 * math.sin(angle),
      );
      canvas.drawLine(center, armEnd, paint);

      // Small branches on each arm
      for (final t in [0.4, 0.7]) {
        final branchBase = Offset(
          center.dx + 10 * t * math.cos(angle),
          center.dy + 10 * t * math.sin(angle),
        );
        for (final branchAngle in [-math.pi / 4, math.pi / 4]) {
          canvas.drawLine(
            branchBase,
            Offset(
              branchBase.dx + 3.5 * math.cos(angle + branchAngle),
              branchBase.dy + 3.5 * math.sin(angle + branchAngle),
            ),
            paint,
          );
        }
      }
    }

    // Center dot
    canvas.drawCircle(center, 1.5, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_SnowPainter old) =>
      old.rotation != rotation || old.color != color;
}

// ── Fog Painter ───────────────────────────────────────────────────────────────

class _FogPainter extends CustomPainter {
  final Color color;
  final double pulse;

  const _FogPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 4 horizontal wavy lines of decreasing width
    final lineSpecs = [
      (0.0, 14.0, 0.9),
      (-5.0, 12.0, 0.7),
      (5.0, 10.0, 0.55),
      (0.0, 7.0, 0.35),
    ];

    for (int i = 0; i < lineSpecs.length; i++) {
      final (yOff, halfW, opacityMult) = lineSpecs[i];
      final waveAmt = 1.5 * math.sin(pulse * math.pi + i * 1.5);
      final y = center.dy - 6 + i * 4.5 + yOff + waveAmt;
      paint
        ..color = color.withOpacity(opacityMult * (0.7 + pulse * 0.3))
        ..strokeWidth = 1.5;

      // Draw slightly curved line
      final path = Path()
        ..moveTo(center.dx - halfW, y)
        ..cubicTo(
          center.dx - halfW / 2, y - 1.5,
          center.dx + halfW / 2, y + 1.5,
          center.dx + halfW, y,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_FogPainter old) =>
      old.pulse != pulse || old.color != color;
}

// ── Golden Hour Painter ───────────────────────────────────────────────────────

class _GoldenHourPainter extends CustomPainter {
  final Color color;
  final double pulse;

  const _GoldenHourPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 3;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // Horizon line
    canvas.drawLine(Offset(cx - 12, cy + 1), Offset(cx + 12, cy + 1), paint);

    // Half sun above horizon
    final sunRect = Rect.fromCenter(center: Offset(cx, cy), width: 14, height: 14);
    canvas.drawArc(sunRect, math.pi, math.pi, false, paint);

    // Radiating lines above horizon (sunrise/sunset rays)
    final glowPaint = Paint()
      ..color = color.withOpacity(0.15 + pulse * 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(Offset(cx, cy), 9, glowPaint);

    for (int i = 0; i < 5; i++) {
      final angle = math.pi * 1.1 + i * (math.pi * 0.8 / 4);
      const innerR = 10.0;
      const outerR = 14.5;
      canvas.drawLine(
        Offset(cx + innerR * math.cos(angle), cy + innerR * math.sin(angle)),
        Offset(cx + outerR * math.cos(angle), cy + outerR * math.sin(angle)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GoldenHourPainter old) =>
      old.pulse != pulse || old.color != color;
}