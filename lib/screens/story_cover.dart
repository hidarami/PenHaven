import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STORY COVER WIDGET
// Renders either the story's cover photo or an auto-generated artistic cover.
// The auto-cover is deterministic per story title — consistent across sessions.
// Also exported: AutoCoverPainterWidget, used for entry thumbnails on the
// home screen when the entry has no header image.
// ─────────────────────────────────────────────────────────────────────────────

class StoryCoverWidget extends StatelessWidget {
  final String? imagePath;
  final String storyTitle;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const StoryCoverWidget({
    super.key,
    this.imagePath,
    required this.storyTitle,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync();

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: hasImage
            ? Image.file(
                File(imagePath!),
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    AutoCoverPainterWidget(title: storyTitle),
              )
            : AutoCoverPainterWidget(title: storyTitle),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTO COVER PAINTER WIDGET
// Standalone widget — also used for entry thumbnails on the home screen.
// ─────────────────────────────────────────────────────────────────────────────

class AutoCoverPainterWidget extends StatelessWidget {
  final String title;
  const AutoCoverPainterWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _AutoCoverPainter(title: title),
        child: const SizedBox.expand(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER
// Multi-pass: base gradient → radial bloom → counter-bloom → brushstrokes →
// vignette. Palette chosen from title hash so the same story always gets the
// same cover, but different stories look distinct.
// ─────────────────────────────────────────────────────────────────────────────

class _AutoCoverPainter extends CustomPainter {
  final String title;

  // [base, mid, accent] — dark/rich tones for a painterly feel
  static const List<List<Color>> _palettes = [
    [Color(0xFF0A0F2E), Color(0xFF1C1A55), Color(0xFF6A5FC0)], // indigo night
    [Color(0xFF0B1F10), Color(0xFF1A3018), Color(0xFF507848)], // deep forest
    [Color(0xFF2A1500), Color(0xFF4A2600), Color(0xFFA05028)], // amber ember
    [Color(0xFF031520), Color(0xFF082038), Color(0xFF2A5888)], // ocean depth
    [Color(0xFF280A18), Color(0xFF401428), Color(0xFF904858)], // rose dusk
    [Color(0xFF1A1600), Color(0xFF302400), Color(0xFF806838)], // aged gold
    [Color(0xFF050508), Color(0xFF0C0C18), Color(0xFF3030A0)], // ink night
    [Color(0xFF220A0A), Color(0xFF38100C), Color(0xFF884040)], // terracotta
  ];

  const _AutoCoverPainter({required this.title});

  List<Color> get _palette {
    final hash = title.codeUnits.fold(0, (prev, c) => prev + c);
    return _palettes[hash % _palettes.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pal = _palette;

    // 1. Base gradient (diagonal)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [pal[1], pal[0]],
        ).createShader(rect),
    );

    // 2. Upper-left radial bloom (accent light)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.6, -0.7),
          radius: 1.1,
          colors: [pal[2].withOpacity(0.52), Colors.transparent],
        ).createShader(rect),
    );

    // 3. Lower-right counter-bloom (depth)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.9, 1.0),
          radius: 0.75,
          colors: [pal[1].withOpacity(0.55), Colors.transparent],
        ).createShader(rect),
    );

    // 4. Subtle brushstroke-like curves
    final rng = math.Random(title.hashCode.abs());
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final x1 = rng.nextDouble() * size.width;
      final y1 = rng.nextDouble() * size.height;
      final x2 = x1 + (rng.nextDouble() * 0.7 - 0.15) * size.width;
      final y2 = y1 + (rng.nextDouble() * 0.4 - 0.1) * size.height;
      final path = Path()
        ..moveTo(x1, y1)
        ..cubicTo(
          x1 + (x2 - x1) * 0.33 + (rng.nextDouble() - 0.5) * 30,
          y1 + (y2 - y1) * 0.33 + (rng.nextDouble() - 0.5) * 20,
          x1 + (x2 - x1) * 0.66 + (rng.nextDouble() - 0.5) * 30,
          y1 + (y2 - y1) * 0.66 + (rng.nextDouble() - 0.5) * 20,
          x2,
          y2,
        );
      canvas.drawPath(
        path,
        strokePaint
          ..color = pal[2].withOpacity(0.09)
          ..strokeWidth = size.width * (0.025 + rng.nextDouble() * 0.04),
      );
    }

    // 5. Vignette — darken edges for depth
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [Colors.transparent, Colors.black.withOpacity(0.58)],
          stops: const [0.3, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AutoCoverPainter old) => old.title != title;
}