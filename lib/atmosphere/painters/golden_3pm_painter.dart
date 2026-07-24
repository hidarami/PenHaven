import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GOLDEN 3PM PAINTER — Multi-pass physical lighting simulation
// Each pass has ONE responsibility. Max ~8% opacity per layer.
// Light source: upper-right window. Direction: upper-right → lower-left.
//
// Light mode: Scandinavian interior, cream walls, afternoon sun, NOT yellow.
// Dark mode:  Dark room, curtains drawn, golden leaking around edges.
// ─────────────────────────────────────────────────────────────────────────────

class Golden3pmPainter extends CustomPainter {
  final bool isDark;
  const Golden3pmPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) {
      _paintCurtainEdgeLeakage(canvas, size);
      _paintWarmCornerBloom(canvas, size);
      _paintFaintAmbientHaze(canvas, size);
      _paintReflectedAmber(canvas, size);
      _paintSubtleWarmCenterGlow(canvas, size);
    } else {
      _paintSkyIllumination(canvas, size);
      _paintSunBloom(canvas, size);
      _paintDirectionalSunBeam(canvas, size);
      _paintAtmosphericHaze(canvas, size);
      _paintFloorBounce(canvas, size);
      _paintCoolWallShadow(canvas, size);
      _paintExposureGradient(canvas, size);
      _paintOpticalBloom(canvas, size);
    }
  }

  // ── Light Mode Passes ──────────────────────────────────────────────────────

  /// Pass 1 — Sky Illumination
  /// The whole room is brighter because open sky exists outside the window.
  void _paintSkyIllumination(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, -1.6),
          radius: 2.6,
          colors: [
            const Color(0xFFFFF9EF).withOpacity(0.05),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  /// Pass 2 — Sun Bloom
  /// The sun illuminates from upper-right. Very soft; no visible circle.
  void _paintSunBloom(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(1.15, -1.15),
          radius: 2.5,
          colors: [
            const Color(0xFFFFE6A3).withOpacity(0.08),
            const Color(0xFFFFE6A3).withOpacity(0.04),
            const Color(0xFFFFE6A3).withOpacity(0.015),
            Colors.transparent,
          ],
          stops: const [0.0, 0.30, 0.60, 1.0],
        ).createShader(rect),
    );
  }

  /// Pass 3 — Directional Sun Beam
  /// Canvas is rotated -23° so the beam travels upper-right → lower-left.
  /// This is NOT a radial gradient — it is a physically directed beam.
  void _paintDirectionalSunBeam(Canvas canvas, Size size) {
    canvas.save();
    // Pivot from upper-right window position
    canvas.translate(size.width * 0.78, 0);
    canvas.rotate(-23.0 * math.pi / 180.0);

    final beamRect = Rect.fromCenter(
      center: Offset(0, size.height * 0.45),
      width: size.width * 2.8,
      height: size.height * 0.75,
    );

    canvas.drawOval(
      beamRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFD46A).withOpacity(0.05),
            const Color(0xFFFFC54A).withOpacity(0.025),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(beamRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );

    canvas.restore();
  }

  /// Pass 4 — Atmospheric Haze
  /// Dust particles illuminated by sunlight. Almost invisible (1.5%).
  void _paintAtmosphericHaze(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 3.0,
          colors: [
            const Color(0xFFFFF8EE).withOpacity(0.015),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  /// Pass 5 — Floor Bounce
  /// Wooden floor reflects sunlight upward. Bottom 25% of screen.
  void _paintFloorBounce(Canvas canvas, Size size) {
    final bottomRect = Rect.fromLTWH(
      0,
      size.height * 0.75,
      size.width,
      size.height * 0.25,
    );
    canvas.drawRect(
      bottomRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFF4D59A).withOpacity(0.04),
            Colors.transparent,
          ],
        ).createShader(bottomRect),
    );
  }

  /// Pass 6 — Cool Wall Shadow
  /// Left wall receives skylight, not sunlight. Cool shadow increases
  /// perceived warmth of the sunlit side (opponent contrast).
  void _paintCoolWallShadow(Canvas canvas, Size size) {
    final leftRect = Rect.fromLTWH(0, 0, size.width * 0.35, size.height);
    canvas.drawRect(
      leftRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF8A8D96).withOpacity(0.03),
            Colors.transparent,
          ],
        ).createShader(leftRect),
    );
  }

  /// Pass 7 — Exposure Gradient
  /// Camera-like exposure: top-right ~3% brighter, bottom-left normal.
  void _paintExposureGradient(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.white.withOpacity(0.03),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  /// Pass 8 — Optical Bloom
  /// Lens bloom from sun position. Below 2% opacity — no visible shape.
  void _paintOpticalBloom(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(1.2, -1.2),
          radius: 2.0,
          colors: [
            const Color(0xFFFFEECC).withOpacity(0.018),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
  }

  // ── Dark Mode Passes ───────────────────────────────────────────────────────
  // Dark room, curtains mostly drawn, brilliant golden afternoon outside.

  /// Dark 1 — Curtain Edge Leakage
  /// Golden light seeps around curtain edges, primarily upper-right.
  void _paintCurtainEdgeLeakage(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // Upper-right corner — main curtain edge closest to sun
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(1.05, -1.05),
          radius: 1.1,
          colors: [
            const Color(0xFFFFB347).withOpacity(0.18),
            const Color(0xFFFF8C00).withOpacity(0.08),
            const Color(0xFFFF6600).withOpacity(0.03),
            Colors.transparent,
          ],
          stops: const [0.0, 0.30, 0.55, 1.0],
        ).createShader(rect),
    );
    // Right edge strip — curtain gap letting in a sliver of light
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            const Color(0xFFFFAA44).withOpacity(0.10),
            const Color(0xFFFF8800).withOpacity(0.03),
            Colors.transparent,
          ],
          stops: const [0.0, 0.12, 0.35],
        ).createShader(rect),
    );
  }

  /// Dark 2 — Warm Corner Bloom
  /// Upper-left secondary glow — reflected amber from room surfaces.
  void _paintWarmCornerBloom(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.85, -1.05),
          radius: 0.80,
          colors: [
            const Color(0xFFFFAA33).withOpacity(0.09),
            const Color(0xFFFF8800).withOpacity(0.03),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
  }

  /// Dark 3 — Faint Ambient Haze
  /// Dust particles catch any light entering the room.
  void _paintFaintAmbientHaze(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.1, -0.5),
          radius: 1.8,
          colors: [
            const Color(0xFFFFBB55).withOpacity(0.022),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  /// Dark 4 — Reflected Amber
  /// Floor reflects warm exterior light upward, even in a curtained room.
  void _paintReflectedAmber(Canvas canvas, Size size) {
    final bottomRect = Rect.fromLTWH(
      0,
      size.height * 0.80,
      size.width,
      size.height * 0.20,
    );
    canvas.drawRect(
      bottomRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFCC8833).withOpacity(0.045),
            Colors.transparent,
          ],
        ).createShader(bottomRect),
    );
  }

  /// Dark 5 — Subtle Warm Center Glow
  /// Sky glow diffuses through curtain fabric — barely perceptible.
  void _paintSubtleWarmCenterGlow(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.1, -1.4),
          radius: 0.85,
          colors: [
            const Color(0xFFFFCC66).withOpacity(0.05),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(Golden3pmPainter old) => old.isDark != isDark;
}
