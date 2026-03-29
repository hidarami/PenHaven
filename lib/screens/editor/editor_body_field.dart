import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/entry.dart';
import '../../providers/app_state.dart';
import '../../providers/editor_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR BODY FIELD
// The main writing area of the editor.
// - Multiline TextField in Crimson Pro 18pt, line-height 1.8
// - Notifies EditorState on every change (word count + comfort engine)
// - Inline images are displayed above the text field at their positions
//   (simplified: shown as a scrollable row above the text until proper
//   cursor-position insertion is implemented in the toolbar)
// ─────────────────────────────────────────────────────────────────────────────

class EditorBodyField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Entry entry;

  const EditorBodyField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final editorState = context.read<EditorState>();
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Inline images (sorted by position) ───────────────────────────
        if (entry.images.isNotEmpty)
          _InlineImagesPreview(entry: entry),

        // ── Main body TextField ───────────────────────────────────────────
        TextField(
          controller: controller,
          focusNode: focusNode,
          style: AppTypography.entryBody(textColor),
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          onChanged: editorState.onContentChanged,
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: 'Begin writing...',
            hintStyle: AppTypography.entryBody(mutedColor).copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE IMAGES PREVIEW
// Shows inline images sorted by their content position.
// Full-width, rounded corners, 16px vertical margin.
// ─────────────────────────────────────────────────────────────────────────────

class _InlineImagesPreview extends StatelessWidget {
  final Entry entry;

  const _InlineImagesPreview({required this.entry});

  @override
  Widget build(BuildContext context) {
    final images = List.of(entry.images)
      ..sort((a, b) => a.position.compareTo(b.position));

    return Column(
      children: images.map((img) {
        final file = File(img.path);
        if (!file.existsSync()) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        );
      }).toList(),
    );
  }
}
