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
// Sharp edges — no border radius.
// ─────────────────────────────────────────────────────────────────────────────

class EntryHeaderImage extends StatelessWidget {
  final String path;

  const EntryHeaderImage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);

    if (!file.existsSync()) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Stack(
        children: [
          // ── Image — 3:1 aspect ratio, sharp edges, no border radius ─────────
          LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxWidth / 3;
              return Image.file(
                file,
                width: double.infinity,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(height),
              );
            },
          ),

          // ── Gradient overlay (bottom fade) — sharp edges ──────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
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
        ],
      ),
    );
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