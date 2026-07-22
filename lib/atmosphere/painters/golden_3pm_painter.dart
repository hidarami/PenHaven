import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GOLDEN 3PM PAINTER
// Realistic window light projection — like sunlight through a window with
// venetian blinds. Neutral white light columns, shadow mullions, blind slats.
// Reference: cool neutral light through a window on a cream wall.
//
// Light Mode: vertical white-light columns with fine horizontal blind lines
// Dark Mode:  warm amber glow seeping around curtains (no streaks)
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
    const double angle = 12.0 * math.pi / 180.0;
    final double shiftY = size.height * math.tan(angle);

    // Window frame layout: 3 vertical light columns + mullion gaps between
    // Positioned on the left-to-center portion (light source from right/above)
    final double totalW = size.width * 0.80;
    final double mullionW = size.width * 0.028;
    final double colW = (totalW - mullionW * 2) / 3;
    final double startX = size.width * 0.04;

    final columns = [
      _ColSpec(startX, colW, 0.23),
      _ColSpec(startX + colW + mullionW, colW, 0.20),
      _ColSpec(startX + (colW + mullionW) * 2, colW, 0.17),
    ];

    // Draw each light column
    for (final col in columns) {
      _drawLightColumn(canvas, size, col.x, col.w, shiftY, col.opacity);
    }

    // Draw horizontal blind shadow lines across all light columns
    _paintBlindLines(canvas, size, angle,
        startX - shiftY - 20, startX + totalW - shiftY + 20);

    // Very subtle warm glow from upper right (light source direction)
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(1.3, -1.1),
          radius: 1.2,
          colors: [
            const Color(0xFFFFF8F2).withOpacity(0.10),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  void _drawLightColumn(Canvas canvas, Size size, double x, double colW,
      double shiftY, double opacity) {
    final path = Path()
      ..moveTo(x, 0)
      ..lineTo(x + colW, 0)
      ..lineTo(x + colW - shiftY, size.height)
      ..lineTo(x - shiftY, size.height)
      ..close();

    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    // Light fill — pure neutral white (no yellow tint)
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(opacity),
          Colors.white.withOpacity(opacity * 0.80),
          Colors.white.withOpacity(opacity * 0.55),
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(path.getBounds())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _paintBlindLines(Canvas canvas, Size size, double angle,
      double xStart, double xEnd) {
    // Fine horizontal shadow bands — venetian blind slat effect
    const int numLines = 14;
    final double spacing = size.height / numLines;

    // Thicker slat shadow
    final slatPaint = Paint()
      ..color = const Color(0xFF6A5E52).withOpacity(0.058)
      ..strokeWidth = spacing * 0.30
      ..strokeCap = StrokeCap.square;

    // Thin bright highlight between slats
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.square;

    for (int i = 0; i <= numLines; i++) {
      final double y = i * spacing;
      final double xOff = -y * math.tan(angle);
      canvas.drawLine(
        Offset(xStart + xOff, y),
        Offset(xEnd + xOff, y),
        slatPaint,
      );
      if (i < numLines) {
        final double yH = y + spacing * 0.15;
        final double xOffH = -yH * math.tan(angle);
        canvas.drawLine(
          Offset(xStart + xOffH, yH),
          Offset(xEnd + xOffH, yH),
          highlightPaint,
        );
      }
    }
  }

  // ── Dark Mode ──────────────────────────────────────────────────────────────

  void _paintDark(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

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

class _ColSpec {
  final double x, w, opacity;
  const _ColSpec(this.x, this.w, this.opacity);
}