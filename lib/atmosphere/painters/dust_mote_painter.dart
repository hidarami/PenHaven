import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/atmosphere_state.dart';
import '../../providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DUST MOTE OVERLAY — Enhanced
// Active: 2:55 PM – 3:45 PM, light mode only.
// 12–16 particles with varying sizes, golden glow, subtle drift.
// Includes a very faint diagonal light ray to anchor the particles.
// ─────────────────────────────────────────────────────────────────────────────

class DustMoteOverlay extends StatefulWidget {
  const DustMoteOverlay({super.key});

  @override
  State<DustMoteOverlay> createState() => _DustMoteOverlayState();
}

class _DustMoteOverlayState extends State<DustMoteOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _moteCtrl;
  late final AnimationController _rayCtrl;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(DateTime.now().millisecondsSinceEpoch);
    // 14 motes — enough to feel like sunlit dust
    _motes = List.generate(14, (i) => _Mote.random(rng, i));

    // Mote drift: continuous
    _moteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // Ray pulse: very slow breath
    _rayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _moteCtrl.dispose();
    _rayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AtmosphereState, AppState>(
      builder: (context, atmo, app, _) {
        if (!atmo.isDustMoteActive || app.isDarkMode || !atmo.isDynamicTheme) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_moteCtrl, _rayCtrl]),
              builder: (context, _) {
                final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
                return CustomPaint(
                  painter: _DustScenePainter(
                    motes: _motes,
                    time: t,
                    rayPulse: _rayCtrl.value,
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

// ── Mote ─────────────────────────────────────────────────────────────────────

class _Mote {
  final double baseX;
  final double baseY;
  final double size; // 1.0–5.0px radius
  final double driftSpeed;
  final double driftAngle;
  final double phaseOffset;
  final double glowFactor; // 0.8–2.0 — how much glow this mote has

  const _Mote({
    required this.baseX,
    required this.baseY,
    required this.size,
    required this.driftSpeed,
    required this.driftAngle,
    required this.phaseOffset,
    required this.glowFactor,
  });

  factory _Mote.random(math.Random rng, int i) {
    return _Mote(
      baseX: rng.nextDouble(),
      baseY: rng.nextDouble() * 0.75, // upper 75%
      size: 1.2 + rng.nextDouble() * 3.5,
      driftSpeed: 5.0 + rng.nextDouble() * 14.0,
      driftAngle: (rng.nextDouble() * 2 - 1) * math.pi / 5,
      phaseOffset: rng.nextDouble() * math.pi * 2,
      glowFactor: 0.8 + rng.nextDouble() * 1.2,
    );
  }

  Offset positionAt(double t, Size sz) {
    final px = (baseX * sz.width) +
        math.cos(driftAngle) * driftSpeed * (t % 120) +
        math.sin(t * 0.3 + phaseOffset) * 8;
    final py = (baseY * sz.height) +
        math.sin(driftAngle) * driftSpeed * (t % 120) * 0.25 +
        math.sin(t * 0.45 + phaseOffset) * 10;
    return Offset(px % sz.width, py.clamp(0, sz.height));
  }

  double opacityAt(double t) {
    final pulse = (math.sin(t * 0.5 + phaseOffset) + 1) / 2;
    return (0.15 + pulse * 0.45).clamp(0.0, 1.0);
  }
}

// ── Scene painter (motes + light ray) ────────────────────────────────────────

class _DustScenePainter extends CustomPainter {
  final List<_Mote> motes;
  final double time;
  final double rayPulse; // 0.0–1.0

  const _DustScenePainter({
    required this.motes,
    required this.time,
    required this.rayPulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintLightRay(canvas, size);
    _paintMotes(canvas, size);
  }

  // Very faint diagonal light shaft — upper-right to lower-left
  void _paintLightRay(Canvas canvas, Size size) {
    final opacity = 0.03 + rayPulse * 0.025; // 3–5.5% opacity max — barely felt
    const angle = 35.0 * math.pi / 180.0;
    final w = size.width * 0.28;
    final shiftY = size.height * math.tan(angle);

    final path = Path()
      ..moveTo(size.width * 0.55, 0)
      ..lineTo(size.width * 0.55 + w, 0)
      ..lineTo(size.width * 0.55 + w - shiftY, size.height)
      ..lineTo(size.width * 0.55 - shiftY, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFFFFE58A).withOpacity(opacity),
            Colors.transparent,
          ],
        ).createShader(path.getBounds())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
  }

  void _paintMotes(Canvas canvas, Size size) {
    for (final mote in motes) {
      final pos = mote.positionAt(time, size);
      final opacity = mote.opacityAt(time);
      final glowR = mote.size * 2.5 * mote.glowFactor;

      // Outer glow
      canvas.drawCircle(
        pos,
        glowR,
        Paint()
          ..color = const Color(0xFFFFD700).withOpacity(opacity * 0.28)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowR * 0.8),
      );

      // Inner warm core
      canvas.drawCircle(
        pos,
        mote.size * 0.7,
        Paint()..color = const Color(0xFFFFF3AA).withOpacity(opacity * 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_DustScenePainter old) =>
      old.time != time || old.rayPulse != rayPulse;
}
