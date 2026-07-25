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
              animation:
                  Listenable.merge([_rotationCtrl, _pulseCtrl, _rainCtrl]),
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
      case 'Cloudy':
        return isDay
            ? _CloudyPainter(color: color, pulse: pulse)
            : _CloudyNightPainter(color: color, pulse: pulse);
      case 'Stormy':
        return _ThunderstormPainter(
            color: color, progress: rainProgress, pulse: pulse);
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
    final path = Path()..addOval(Rect.fromCircle(center: center, radius: 8.5));
    final maskCenter = Offset(center.dx + 5.5, center.dy - 1.5);
    final maskPath = Path()
      ..addOval(Rect.fromCircle(center: maskCenter, radius: 7.5));
    final crescent = Path.combine(PathOperation.difference, path, maskPath);

    canvas.drawPath(
        crescent,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);

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
        Offset(starPos.dx + sR * 0.4 * math.cos(a),
            starPos.dy + sR * 0.4 * math.sin(a)),
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

    // Pulsing cloud glow
    canvas.drawCircle(
      Offset(center.dx, center.dy - 3),
      12,
      Paint()
        ..color =
            color.withOpacity(0.08 + math.sin(progress * math.pi * 2) * 0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Cloud — reliable path combine
    canvas.drawPath(
      _buildCloudPath(center.dx, center.dy - 5),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 3 rain streaks — each with own speed/length to feel like random droplets
    final streakData = [
      (xOff: -7.0, speed: 1.2, delay: 0.0, len: 5.0, width: 1.4),
      (xOff: 0.0, speed: 1.8, delay: 0.15, len: 7.0, width: 1.8),
      (xOff: 7.0, speed: 1.0, delay: 0.5, len: 4.0, width: 1.2),
    ];

    for (final s in streakData) {
      final phase = (progress * s.speed + s.delay) % 1.0;
      final y = center.dy + 2.0 + phase * 16.0;
      final opacity = math.sin(phase * math.pi).clamp(0.15, 1.0);
      canvas.drawLine(
        Offset(center.dx + s.xOff, y),
        Offset(center.dx + s.xOff + 1.5, y + s.len),
        Paint()
          ..color = color.withOpacity(opacity * 0.95)
          ..strokeWidth = s.width
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
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
    canvas.drawCircle(
        center,
        1.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
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
          center.dx - halfW / 2,
          y - 1.5,
          center.dx + halfW / 2,
          y + 1.5,
          center.dx + halfW,
          y,
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
    final sunRect =
        Rect.fromCenter(center: Offset(cx, cy), width: 14, height: 14);
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

// ── Cloud Path Helper ─────────────────────────────────────────────────────────
// Uses Path.combine (union of circles + rounded rect) for a guaranteed
// correct cloud outline — avoids arcToPoint radius constraints entirely.

Path _buildCloudPath(double cx, double cy, {double scale = 1.0}) {
  final s = scale;
  final leftBump = Path()
    ..addOval(Rect.fromCircle(
        center: Offset(cx - 5.0 * s, cy - 2.0 * s), radius: 4.5 * s));
  final centerBump = Path()
    ..addOval(Rect.fromCircle(
        center: Offset(cx + 0.5 * s, cy - 5.5 * s), radius: 6.0 * s));
  final rightBump = Path()
    ..addOval(Rect.fromCircle(
        center: Offset(cx + 6.0 * s, cy - 2.0 * s), radius: 4.5 * s));
  final body = Path()
    ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy + 2.5 * s),
            width: 21.0 * s,
            height: 8.0 * s),
        Radius.circular(4.0 * s)));
  var cloud = Path.combine(PathOperation.union, leftBump, centerBump);
  cloud = Path.combine(PathOperation.union, cloud, rightBump);
  cloud = Path.combine(PathOperation.union, cloud, body);
  return cloud;
}

// ── Cloudy Day Painter ────────────────────────────────────────────────────────

class _CloudyPainter extends CustomPainter {
  final Color color;
  final double pulse;

  const _CloudyPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 1;

    // Subtle glow
    canvas.drawCircle(
      Offset(cx, cy - 2),
      13,
      Paint()
        ..color = color.withOpacity(0.10 + pulse * 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Cloud outline using reliable path
    canvas.drawPath(
      _buildCloudPath(cx, cy),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CloudyPainter old) =>
      old.pulse != pulse || old.color != color;
}

// ── Cloudy Night Painter ──────────────────────────────────────────────────────

class _CloudyNightPainter extends CustomPainter {
  final Color color;
  final double pulse;

  const _CloudyNightPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Moon glow (peeking through cloud)
    canvas.drawCircle(
      Offset(cx + 6, cy - 5),
      11,
      Paint()
        ..color = color.withOpacity(0.11 + pulse * 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // Crescent moon — partially hidden behind cloud
    final moonC = Offset(cx + 6, cy - 5);
    final moonPath = Path()
      ..addOval(Rect.fromCircle(center: moonC, radius: 7.5));
    final maskPath = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(moonC.dx + 5, moonC.dy - 1), radius: 7.0));
    final crescent = Path.combine(PathOperation.difference, moonPath, maskPath);
    canvas.drawPath(
        crescent,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);

    // Cloud drifting over moon — reliable path combine
    final drift = math.sin(pulse * math.pi * 2) * 0.9;
    canvas.drawPath(
      _buildCloudPath(cx - 1 + drift, cy + 3, scale: 0.88),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CloudyNightPainter old) =>
      old.pulse != pulse || old.color != color;
}

// ── Thunderstorm Painter ──────────────────────────────────────────────────────

class _ThunderstormPainter extends CustomPainter {
  final Color color;
  final double progress; // rain animation 0–1
  final double pulse; // lightning flash trigger

  const _ThunderstormPainter({
    required this.color,
    required this.progress,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Storm cloud glow
    canvas.drawCircle(
      Offset(center.dx, center.dy - 4),
      14,
      Paint()
        ..color = color.withOpacity(0.11)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Heavy cloud — reliable path combine
    canvas.drawPath(
      _buildCloudPath(center.dx, center.dy - 5),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 5 heavy rain streaks — each with own speed/length for natural droplet feel
    final streakData = [
      (xOff: -8.0, speed: 1.3, delay: 0.0, len: 5.5, width: 1.5),
      (xOff: -4.0, speed: 1.9, delay: 0.1, len: 7.5, width: 2.0),
      (xOff: 0.5, speed: 1.1, delay: 0.35, len: 4.5, width: 1.3),
      (xOff: 4.5, speed: 1.6, delay: 0.55, len: 6.5, width: 1.7),
      (xOff: 8.5, speed: 0.9, delay: 0.75, len: 5.0, width: 1.4),
    ];

    for (final s in streakData) {
      final phase = (progress * s.speed + s.delay) % 1.0;
      final y = center.dy + 2.0 + phase * 15.0;
      final op = math.sin(phase * math.pi).clamp(0.1, 1.0);
      canvas.drawLine(
        Offset(center.dx + s.xOff, y),
        Offset(center.dx + s.xOff + 2.0, y + s.len),
        Paint()
          ..color = color.withOpacity(op * 0.95)
          ..strokeWidth = s.width
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    // Lightning bolt — flashes when pulse > 0.62 (~once per 3s cycle)
    if (pulse > 0.62) {
      final flash = ((pulse - 0.62) / 0.38).clamp(0.0, 1.0);
      final boltPath = Path()
        ..moveTo(center.dx + 2, center.dy - 1)
        ..lineTo(center.dx - 2, center.dy + 4)
        ..lineTo(center.dx + 1.5, center.dy + 4)
        ..lineTo(center.dx - 3, center.dy + 10);

      // Glow pass
      canvas.drawPath(
        boltPath,
        Paint()
          ..color = const Color(0xFFFFEE55).withOpacity(flash * 0.30)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      // Core bolt
      canvas.drawPath(
        boltPath,
        Paint()
          ..color = const Color(0xFFFFEE55).withOpacity(flash * 0.92)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ThunderstormPainter old) =>
      old.progress != progress || old.pulse != pulse || old.color != color;
}
