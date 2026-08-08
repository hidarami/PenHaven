import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/atmosphere_state.dart';
import '../../providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STARFIELD OVERLAY
// Active only during Midnight Ink, dark mode, and clear (cloudless) weather.
// A quiet scattering of twinkling stars with an occasional, brief shooting
// star — deliberately subtle so it never competes with the writing.
// ─────────────────────────────────────────────────────────────────────────────

class StarfieldOverlay extends StatefulWidget {
  const StarfieldOverlay({super.key});

  @override
  State<StarfieldOverlay> createState() => _StarfieldOverlayState();
}

class _StarfieldOverlayState extends State<StarfieldOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _twinkleCtrl;
  late final AnimationController _shootCtrl;
  late final List<_Star> _stars;
  final math.Random _rng = math.Random();

  double _prevShootValue = 0;
  double _shootTrigger = 0.85;
  Offset _shootOrigin = const Offset(0.2, 0.12);
  double _shootAngle = 0.7;
  double _shootLength = 0.18;

  @override
  void initState() {
    super.initState();
    _stars = List.generate(28, (i) => _Star.random(math.Random(i * 3391)));

    _twinkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // One slow loop (~14s) decides whether a shooting star fires that cycle.
    _shootCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _rollNextShootingStar();
  }

  void _rollNextShootingStar() {
    _shootTrigger = 0.75 + _rng.nextDouble() * 0.24;
    _shootOrigin = Offset(
      0.05 + _rng.nextDouble() * 0.5,
      0.05 + _rng.nextDouble() * 0.25,
    );
    _shootAngle = (35 + _rng.nextDouble() * 20) * math.pi / 180;
    _shootLength = 0.14 + _rng.nextDouble() * 0.10;
  }

  @override
  void dispose() {
    _twinkleCtrl.dispose();
    _shootCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AtmosphereState, AppState>(
      builder: (context, atmo, app, _) {
        final isClearMidnight = atmo.isDynamicTheme &&
            app.isDarkMode &&
            atmo.current == Atmosphere.midnightInk &&
            (atmo.weather == null || atmo.weather!.condition == 'clear');

        if (!isClearMidnight) return const SizedBox.shrink();

        return Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_twinkleCtrl, _shootCtrl]),
              builder: (context, _) {
                if (_shootCtrl.value < 0.02 && _prevShootValue > 0.9) {
                  _rollNextShootingStar();
                }
                _prevShootValue = _shootCtrl.value;

                double shootProgress = -1;
                if (_shootCtrl.value >= _shootTrigger) {
                  shootProgress =
                      (_shootCtrl.value - _shootTrigger) / (1 - _shootTrigger);
                }

                return CustomPaint(
                  painter: _StarfieldPainter(
                    stars: _stars,
                    twinkle: _twinkleCtrl.value,
                    shootProgress: shootProgress,
                    shootOrigin: _shootOrigin,
                    shootAngle: _shootAngle,
                    shootLength: _shootLength,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Star {
  final double x, y, size, phase, speed;
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
  });

  factory _Star.random(math.Random r) => _Star(
        x: r.nextDouble(),
        y: r.nextDouble() * 0.7,
        size: 0.6 + r.nextDouble() * 1.4,
        phase: r.nextDouble() * math.pi * 2,
        speed: 0.5 + r.nextDouble() * 1.0,
      );
}

class _StarfieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double twinkle;
  final double shootProgress;
  final Offset shootOrigin;
  final double shootAngle;
  final double shootLength;

  const _StarfieldPainter({
    required this.stars,
    required this.twinkle,
    required this.shootProgress,
    required this.shootOrigin,
    required this.shootAngle,
    required this.shootLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final t =
          (math.sin(twinkle * math.pi * 2 * star.speed + star.phase) + 1) / 2;
      final opacity = (0.12 + t * 0.35).clamp(0.0, 0.55);
      final pos = Offset(star.x * size.width, star.y * size.height);
      canvas.drawCircle(
        pos,
        star.size,
        Paint()..color = const Color(0xFFEAF0FF).withOpacity(opacity),
      );
    }

    if (shootProgress >= 0 && shootProgress <= 1) {
      _paintShootingStar(canvas, size);
    }
  }

  void _paintShootingStar(Canvas canvas, Size size) {
    final fade = shootProgress < 0.15
        ? shootProgress / 0.15
        : (1 - ((shootProgress - 0.15) / 0.85)).clamp(0.0, 1.0);

    final origin =
        Offset(shootOrigin.dx * size.width, shootOrigin.dy * size.height);
    final totalLen = shootLength * size.width;
    final dir = Offset(math.cos(shootAngle), math.sin(shootAngle));

    final headDist = totalLen * shootProgress;
    final head = origin + dir * headDist;
    final tail = origin + dir * (headDist - totalLen * 0.4).clamp(0, totalLen);

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFFEAF0FF).withOpacity(0.75 * fade),
        ],
      ).createShader(Rect.fromPoints(tail, head))
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(tail, head, paint);

    canvas.drawCircle(
      head,
      1.4,
      Paint()..color = const Color(0xFFF5F8FF).withOpacity(0.85 * fade),
    );
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) =>
      old.twinkle != twinkle || old.shootProgress != shootProgress;
}