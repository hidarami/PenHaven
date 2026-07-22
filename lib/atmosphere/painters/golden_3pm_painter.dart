import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GOLDEN 3PM PAINTER — v3 (Glow-only, image overlay handles structure)
//
// The PNG asset (window_plant_shadow.png / window_light_projection.png) is
// rendered as a separate AtmosphereImageLayer on top of this painter.
// This painter provides ONLY the warm ambient glow — no structural elements.
//
// Light Mode: Warm golden radial glow from upper-right (afternoon sun direction)
//             + ambient depth shadow on the left (wall opposite the window)
// Dark Mode:  Amber light seeping around curtain edges from corners
//             + faint central warmth (sky glow through fabric)
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
  // Simulates: you are in a bright room, window is to your upper-right.
  // Warm golden light floods in. The opposite wall (left) is slightly cooler.

  void _paintLight(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Primary: golden light flooding from upper-right (window direction)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.9, -1.0),
          radius: 1.5,
          colors: [
            const Color(0xFFFFD580).withOpacity(0.26),
            const Color(0xFFFFBF47).withOpacity(0.12),
            const Color(0xFFFFA500).withOpacity(0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.30, 0.55, 1.0],
        ).createShader(rect),
    );

    // Secondary: softer sky-light from top-center (open sky brightness)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.2, -1.3),
          radius: 1.1,
          colors: [
            const Color(0xFFFFF5CC).withOpacity(0.15),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // Left ambient shadow: wall opposite the window is ever so slightly dimmer.
    // This creates subtle depth — light comes from right, left feels cooler.
    final leftRect =
        Rect.fromLTWH(0, 0, size.width * 0.35, size.height);
    canvas.drawRect(
      leftRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF8B7040).withOpacity(0.055),
            Colors.transparent,
          ],
        ).createShader(leftRect),
    );

    // Bottom warmth: warm dust / reflected light from the floor
    final bottomRect = Rect.fromLTWH(
        0, size.height * 0.78, size.width, size.height * 0.22);
    canvas.drawRect(
      bottomRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFFD4A017).withOpacity(0.038),
          ],
        ).createShader(bottomRect),
    );
  }

  // ── Dark Mode ─────────────────────────────────────────────────────────────
  // Simulates: dark room, curtains drawn, afternoon sunlight seeps around edges.
  // Warm amber bleeding from corners — you can feel the golden outside.

  void _paintDark(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Main amber glow — upper-right corner (curtain edge closest to sun)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(1.05, -1.05),
          radius: 1.15,
          colors: [
            const Color(0xFFFFB347).withOpacity(0.20),
            const Color(0xFFFF8C00).withOpacity(0.10),
            const Color(0xFFFF6600).withOpacity(0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.6, 1.0],
        ).createShader(rect),
    );

    // Upper-left secondary glow (reflected ambient warmth)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.85, -1.05),
          radius: 0.88,
          colors: [
            const Color(0xFFFFAA33).withOpacity(0.11),
            const Color(0xFFFF8800).withOpacity(0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    // Center-top faint warmth (sky glow diffusing through curtain fabric)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.1, -1.4),
          radius: 0.85,
          colors: [
            const Color(0xFFFFCC66).withOpacity(0.065),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(Golden3pmPainter old) => old.isDark != isDark;
}