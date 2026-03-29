import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/atmosphere_state.dart';
import '../../providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DUST MOTE PAINTER
// Easter egg: golden dust particles floating in afternoon light.
// Active window: 2:55 PM – 3:10 PM only.
// 5–8 particles max, very slow drift, warm golden color.
// IgnorePointer is applied by the parent — particles don't block input.
// ─────────────────────────────────────────────────────────────────────────────

class DustMoteOverlay extends StatefulWidget {
  const DustMoteOverlay({super.key});

  @override
  State<DustMoteOverlay> createState() => _DustMoteOverlayState();
}

class _DustMoteOverlayState extends State<DustMoteOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(DateTime.now().millisecondsSinceEpoch);
    // 6 motes with staggered lifetimes
    _motes = List.generate(6, (i) => _Mote.random(rng, i));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(); // Drives continuous updates via listener
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AtmosphereState, AppState>(
      builder: (context, atmo, app, _) {
        // Only show during active window and when NOT dark mode
        // (Dark mode 3PM has no dust motes — they imply bright light)
        if (!atmo.isDustMoteActive || app.isDarkMode) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _DustMotePainter(
                    motes: _motes,
                    time: DateTime.now().millisecondsSinceEpoch / 1000.0,
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

// ── Mote data ─────────────────────────────────────────────────────────────────

class _Mote {
  final double baseX;     // 0.0–1.0 normalized
  final double baseY;     // 0.0–1.0 normalized
  final double size;      // Radius in logical pixels
  final double driftSpeed;  // Pixels per second
  final double driftAngle;  // Direction in radians
  final double phaseOffset; // Animation phase offset

  const _Mote({
    required this.baseX,
    required this.baseY,
    required this.size,
    required this.driftSpeed,
    required this.driftAngle,
    required this.phaseOffset,
  });

  factory _Mote.random(math.Random rng, int index) {
    return _Mote(
      baseX: rng.nextDouble(),
      baseY: rng.nextDouble() * 0.7, // Keep mostly in upper 70% of screen
      size: 1.5 + rng.nextDouble() * 2.5, // 1.5–4px radius
      driftSpeed: 8.0 + rng.nextDouble() * 12.0, // Very slow
      driftAngle: (rng.nextDouble() * 2 - 1) * math.pi / 6, // ±30°
      phaseOffset: rng.nextDouble() * math.pi * 2,
    );
  }

  /// Current position at [time] seconds on a [size] canvas.
  Offset positionAt(double time, Size canvasSize) {
    // Slow sinusoidal drift — organic, not mechanical
    final drift = math.sin(time * 0.3 + phaseOffset) * 12.0;
    final px = (baseX * canvasSize.width) +
        math.cos(driftAngle) * driftSpeed * (time % 60) +
        math.sin(time * 0.4 + phaseOffset) * 6.0;
    final py = (baseY * canvasSize.height) +
        math.sin(driftAngle) * driftSpeed * (time % 60) * 0.3 +
        drift;

    // Wrap around screen edges
    return Offset(
      px % canvasSize.width,
      py.clamp(0, canvasSize.height),
    );
  }

  /// Opacity pulses gently — in and out.
  double opacityAt(double time) {
    final pulse = (math.sin(time * 0.6 + phaseOffset) + 1) / 2; // 0.0–1.0
    return 0.12 + pulse * 0.25; // 0.12–0.37 range — subtle
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _DustMotePainter extends CustomPainter {
  final List<_Mote> motes;
  final double time;

  const _DustMotePainter({required this.motes, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final mote in motes) {
      final pos = mote.positionAt(time, size);
      final opacity = mote.opacityAt(time);

      // Warm golden particle with soft blur halo
      final haloPaint = Paint()
        ..color = const Color(0xFFFFD700).withOpacity(opacity * 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, mote.size * 2);
      canvas.drawCircle(pos, mote.size * 2, haloPaint);

      // Core dot
      final dotPaint = Paint()
        ..color = const Color(0xFFFFF0B0).withOpacity(opacity);
      canvas.drawCircle(pos, mote.size, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_DustMotePainter old) =>
      old.time != time;
}
