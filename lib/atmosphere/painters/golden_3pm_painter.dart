import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GOLDEN 3PM PAINTER — v2 (Shadow-based approach)
//
// PREVIOUS PROBLEM: Painting semi-transparent white on Color(0xFFF1EDE7)
// yellow base = result looked yellow/golden, not like real window light.
//
// NEW APPROACH: Base is near-white Color(0xFFF8F6F3). We paint SHADOW
// elements (mullions + venetian blind bands) on it. This matches how
// real window projections work — it's the shadows that define the pattern,
// not painted light.
//
// Light Mode: shadow mullions + blind shadow bands on near-white wall
// Dark Mode:  warm amber glow from corners (unchanged — was always correct)
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
    // Slight diagonal — window light falls at ~10° from vertical
    const double angleDeg = 10.0;
    const double angle = angleDeg * math.pi / 180.0;
    final double shiftAtBottom = size.height * math.tan(angle);

    // Window layout: 4 panes across nearly full width
    const double leftFrac = 0.02;
    const double rightFrac = 0.98;
    final double mullionW = size.width * 0.022; // narrow shadow strip per divider
    final double usableW = size.width * (rightFrac - leftFrac);
    final double paneW = (usableW - mullionW * 3) / 4;
    final double startX = size.width * leftFrac;

    // Step 1: Draw 3 shadow mullions between the 4 panes
    _paintMullions(canvas, size, startX, paneW, mullionW, shiftAtBottom);

    // Step 2: Draw horizontal venetian blind shadow bands across full window
    _paintBlindBands(
        canvas, size, angle, startX, size.width * rightFrac, shiftAtBottom);

    // Step 3: Right-edge frame shadow (window frame / wall boundary)
    _paintFrameEdge(canvas, size, shiftAtBottom);

    // Step 4: Subtle brightening at top — closer to light source
    _paintLightSourceHint(canvas, size);
  }

  void _paintMullions(
    Canvas canvas,
    Size size,
    double startX,
    double paneW,
    double mullionW,
    double shiftAtBottom,
  ) {
    // Each mullion: a parallelogram shadow strip between adjacent panes
    // Soft blur gives realistic soft-edged shadow feel
    final softPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..color = const Color(0xFF5A5040).withOpacity(0.22);

    final hardPaint = Paint()
      ..color = const Color(0xFF5A5040).withOpacity(0.13);

    for (int i = 0; i < 3; i++) {
      // Left edge of this mullion
      final double xLeft = startX + (i + 1) * paneW + i * mullionW;

      // Parallelogram path (diagonal due to projection angle)
      final path = Path()
        ..moveTo(xLeft, 0)
        ..lineTo(xLeft + mullionW, 0)
        ..lineTo(xLeft + mullionW - shiftAtBottom, size.height)
        ..lineTo(xLeft - shiftAtBottom, size.height)
        ..close();

      // Outer soft shadow first, then harder core on top
      canvas.drawPath(path, softPaint);
      canvas.drawPath(path, hardPaint);
    }
  }

  void _paintBlindBands(
    Canvas canvas,
    Size size,
    double angle,
    double xStart,
    double xEnd,
    double shiftAtBottom,
  ) {
    // 30+ horizontal bands give the venetian blind slat pattern
    const int numBands = 32;
    final double spacing = size.height / numBands;

    // Extra horizontal extent so bands aren't clipped at edges after diagonal shift
    final double extra = shiftAtBottom + 10;

    // Shadow band — slightly darker than the near-white base
    final shadowPaint = Paint()
      ..color = const Color(0xFF5A5040).withOpacity(0.075)
      ..strokeWidth = spacing * 0.42
      ..strokeCap = StrokeCap.square;

    // Bright edge line between bands — simulates light reflecting off slat edge
    final brightPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i <= numBands; i++) {
      final double y = i * spacing;
      // Diagonal offset: all lines shift left as they go down
      final double xOff = -y * math.tan(angle);

      // Shadow band
      canvas.drawLine(
        Offset(xStart + xOff - extra, y),
        Offset(xEnd + xOff + extra, y),
        shadowPaint,
      );

      // Bright edge just below the shadow (subtle highlight between slats)
      if (i < numBands) {
        final double yB = y + spacing * 0.10;
        final double xOffB = -yB * math.tan(angle);
        canvas.drawLine(
          Offset(xStart + xOffB - extra, yB),
          Offset(xEnd + xOffB + extra, yB),
          brightPaint,
        );
      }
    }
  }

  void _paintFrameEdge(Canvas canvas, Size size, double shiftAtBottom) {
    // Window frame shadow on the right side — wall beyond the window is darker
    final framePaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
      ..color = const Color(0xFF5A5040).withOpacity(0.17);

    // Diagonal parallelogram along right edge
    final rightPath = Path()
      ..moveTo(size.width * 0.88, 0)
      ..lineTo(size.width * 1.05, 0) // extend past edge
      ..lineTo(size.width * 1.05 - shiftAtBottom, size.height)
      ..lineTo(size.width * 0.88 - shiftAtBottom, size.height)
      ..close();

    canvas.drawPath(rightPath, framePaint);

    // Bottom fade — wall below window gets progressively less light
    final bottomFade = Rect.fromLTWH(
        0, size.height * 0.72, size.width, size.height * 0.28);
    canvas.drawRect(
      bottomFade,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF5A5040).withOpacity(0.06),
          ],
        ).createShader(bottomFade),
    );
  }

  void _paintLightSourceHint(Canvas canvas, Size size) {
    // Very faint brightening at top — the window is above, so the upper wall
    // receives slightly more light. Keeps the scene from feeling flat.
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -1.4),
          radius: 1.3,
          colors: [
            Colors.white.withOpacity(0.07),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  // ── Dark Mode — unchanged from v1 ─────────────────────────────────────────
  // Warm amber glow seeping around curtains. No streak in dark mode.

  void _paintDark(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Main glow from upper-right corner
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(1.0, -1.0),
          radius: 1.2,
          colors: [
            const Color(0xFFFFB347).withOpacity(0.13),
            const Color(0xFFFF8C00).withOpacity(0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(rect),
    );

    // Secondary glow from upper-left — fills corners warmly
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-1.0, -1.0),
          radius: 0.9,
          colors: [
            const Color(0xFFFFB347).withOpacity(0.08),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(Golden3pmPainter old) => old.isDark != isDark;
}