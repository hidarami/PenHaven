import 'dart:io';
import 'package:flutter/material.dart';

/// Returns the display height for a full-width header image given the
/// stored crop ratio string. Shared by every viewer so the chosen crop
/// ratio is honored consistently (local read, editor, community, reflection).
/// Returns the display height for a full-width header image given the
/// stored crop ratio string. Returns null for 'full' — that ratio means
/// "use the image's own aspect ratio, uncropped" rather than a locked box.
double? headerHeightForRatio(double width, String? ratio) {
  switch (ratio) {
    case '16:9':
      return width / (16 / 9);
    case '4:3':
      return width / (4 / 3);
    case '3:1':
      return width / 3;
    case '1:1':
      return width;
    case 'full':
      return null;
    default:
      return width / (16 / 9);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY HEADER IMAGE
// Full-width, 240px height banner image. Edge-to-edge (no horizontal padding).
// Appears as the FIRST element in Read-Only — before title, before date.
//
// CRITICAL per Master Specification §4:
//   Order: [Header Image] → Title → Date → Body
//   NOT after title. NOT in middle of content.
//
// Subtle gradient overlay at bottom to help text legibility if needed.
// Sharp edges — no border radius.
// ─────────────────────────────────────────────────────────────────────────────

class EntryHeaderImage extends StatelessWidget {
  final String path;
  final String? ratio;
  final Color? backgroundColor;

  const EntryHeaderImage({
    super.key,
    required this.path,
    this.ratio,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(path);

    if (!file.existsSync()) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = _getHeight(constraints.maxWidth);
          // 'full' ratio (height == null): show the image at its own
          // aspect ratio, uncropped — no fixed box, no BoxFit.cover.
          if (height == null) {
            return Image.file(
              file,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) =>
                  _placeholder(constraints.maxWidth / 2),
            );
          }
          // Sharp bottom edge — no gradient fade overlay.
          return Image.file(
            file,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(height),
          );
        },
      ),
    );
  }

  double? _getHeight(double width) {
    return headerHeightForRatio(width, ratio);
  }

  Widget _placeholder(double height) {
    return Container(
      width: double.infinity,
      height: height,
      color: const Color(0xFFE0D8CE),
      child: const Icon(
        Icons.image_outlined,
        size: 48,
        color: Color(0xFFB0A898),
      ),
    );
  }
}
