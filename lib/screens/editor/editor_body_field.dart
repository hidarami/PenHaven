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
// - Inline images are interleaved at their cursor positions within the text
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

    return _InterleavedEditorBody(
      controller: controller,
      focusNode: focusNode,
      entry: entry,
      editorState: editorState,
      textColor: textColor,
      mutedColor: mutedColor,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERLEAVED EDITOR BODY
// Splits entry content at each inline image position and renders:
//   [TextField segment] → [image] → [TextField segment] → [image] → ...
// Since we need a single editable TextField, this is a simplified version
// that shows images at their approximate positions within the text flow.
// ─────────────────────────────────────────────────────────────────────────────

class _InterleavedEditorBody extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Entry entry;
  final EditorState editorState;
  final Color textColor;
  final Color mutedColor;

  const _InterleavedEditorBody({
    required this.controller,
    required this.focusNode,
    required this.entry,
    required this.editorState,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    // No images — just render the TextField
    if (entry.images.isEmpty) {
      return TextField(
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
      );
    }

    // Sort images by position ascending
    final images = List.of(entry.images)
      ..sort((a, b) => a.position.compareTo(b.position));

    final segments = <Widget>[];
    final content = controller.text;
    int cursor = 0;

    for (final image in images) {
      final pos = image.position.clamp(0, content.length);

      // Text before this image - show as read-only for now
      // (complex to maintain cursor positions across multiple TextFields)
      if (pos > cursor) {
        final segment = content.substring(cursor, pos);
        if (segment.trim().isNotEmpty) {
          segments.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                segment,
                style: AppTypography.entryBody(textColor),
              ),
            ),
          );
        }
      }

      // The image itself
      final file = File(image.path);
      if (file.existsSync()) {
        segments.add(
          Padding(
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
          ),
        );
      }

      cursor = pos;
    }

    // Remaining text - editable TextField
    if (cursor < content.length) {
      final remaining = content.substring(cursor);
      segments.add(
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
            hintText: cursor == 0 ? 'Begin writing...' : '',
            hintStyle: AppTypography.entryBody(mutedColor).copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments,
    );
  }
}
