import 'dart:io';
import 'package:flutter/material.dart';

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
// Rounded corners (16px).
// ─────────────────────────────────────────────────────────────────────────────

class EntryHeaderImage extends StatelessWidget {
  final String path;

  const EntryHeaderImage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);

    if (!file.existsSync()) return const SizedBox.shrink();

    return Padding(
      // Slight horizontal inset so rounded corners are visible
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Stack(
        children: [
          // ── Image ────────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Image.file(
              file,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            ),
          ),

          // ── Gradient overlay (bottom fade) ────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 240,
      color: const Color(0xFFE0D8CE),
      child: const Icon(
        Icons.image_outlined,
        size: 48,
        color: Color(0xFFB0A898),
      ),
    );
  }
}
