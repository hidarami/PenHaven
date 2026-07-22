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
// - Inline images are embedded at cursor position using WidgetSpan
//   so they appear exactly where the user inserted them
// - Each inline image has an '×' remove button (editor only — not viewer)
// ─────────────────────────────────────────────────────────────────────────────

// Unicode marker for inline image positions in the text.
// Using Object Replacement Character (U+FFFC) — a standard placeholder.
const String _imageMarker = '\uFFFC';

class EditorBodyField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Entry entry;
  final ValueChanged<String>? onImageRemoved;

  const EditorBodyField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.entry,
    this.onImageRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final editorState = context.read<EditorState>();
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return _EditorBodyContent(
      controller: controller,
      focusNode: focusNode,
      entry: entry,
      editorState: editorState,
      onImageRemoved: onImageRemoved,
      textColor: textColor,
      mutedColor: mutedColor,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR BODY CONTENT
// Uses a custom TextEditingController that overrides buildTextSpan()
// to render WidgetSpan placeholders for images at their cursor positions.
// ─────────────────────────────────────────────────────────────────────────────

class _EditorBodyContent extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Entry entry;
  final EditorState editorState;
  final ValueChanged<String>? onImageRemoved;
  final Color textColor;
  final Color mutedColor;

  const _EditorBodyContent({
    required this.controller,
    required this.focusNode,
    required this.entry,
    required this.editorState,
    this.onImageRemoved,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  State<_EditorBodyContent> createState() => _EditorBodyContentState();
}

class _EditorBodyContentState extends State<_EditorBodyContent> {
  late _ImageAwareTextController _imageController;

  @override
  void initState() {
    super.initState();
    _imageController = _ImageAwareTextController(
      baseController: widget.controller,
      entry: widget.entry,
      textColor: widget.textColor,
      onImageRemove: widget.onImageRemoved,
    );
  }

  @override
  void didUpdateWidget(_EditorBodyContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _imageController.updateEntry(widget.entry);
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _imageController,
      focusNode: widget.focusNode,
      style: AppTypography.entryBody(widget.textColor),
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      onChanged: (text) {
        // Sync the text back to the original controller for saving
        widget.controller.text = text;
        widget.editorState.onContentChanged(text);
      },
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: 'Begin writing...',
        hintStyle: AppTypography.entryBody(widget.mutedColor).copyWith(
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE-AWARE TEXT CONTROLLER
// Custom TextEditingController that overrides buildTextSpan()
// to render WidgetSpan widgets at positions marked by U+FFFC.
// ─────────────────────────────────────────────────────────────────────────────

class _ImageAwareTextController extends TextEditingController {
  final TextEditingController baseController;
  Entry _entry;
  final Color _textColor;
  final ValueChanged<String>? onImageRemove;

  _ImageAwareTextController({
    required this.baseController,
    required Entry entry,
    required Color textColor,
    this.onImageRemove,
  })  : _textColor = textColor,
        _entry = entry,
        super(text: baseController.text);

  void updateEntry(Entry entry) {
    _entry = entry;
    // Rebuild the visual spans when images change
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Build the base text spans first
    final base = super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );

    // If no images, return plain text
    if (_entry.images.isEmpty) return base;

    // We need to replace each U+FFFC marker with a WidgetSpan
    // Flutter doesn't let us modify children after creation,
    // so we build our own list
    final textValue = text;
    final segments = <InlineSpan>[];
    int cursor = 0;

    // Sort images by position ascending
    final images = List.of(_entry.images)
      ..sort((a, b) => a.position.compareTo(b.position));

    for (final image in images) {
      // Find the marker closest to this image's position
      final markerPos = textValue.indexOf(_imageMarker, cursor);
      if (markerPos == -1) break;

      // Text before this marker
      if (markerPos > cursor) {
        segments.add(TextSpan(
          text: textValue.substring(cursor, markerPos),
          style: style,
        ));
      }

      // Image widget span
      final file = File(image.path);
      if (file.existsSync()) {
        segments.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _InlineImageSpan(
              path: image.path,
              textColor: _textColor,
              onRemove: () => onImageRemove?.call(image.path),
            ),
          ),
        );
      }

      cursor = markerPos + 1; // +1 for the marker character
    }

    // Remaining text after last marker
    if (cursor < textValue.length) {
      segments.add(TextSpan(
        text: textValue.substring(cursor),
        style: style,
      ));
    }

    return TextSpan(style: style, children: segments);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE IMAGE SPAN
// A small inline widget that displays the image with an '×' remove button.
// Sized to fit within text line height (about 3 lines tall).
// ─────────────────────────────────────────────────────────────────────────────

class _InlineImageSpan extends StatelessWidget {
  final String path;
  final Color textColor;
  final VoidCallback? onRemove;

  const _InlineImageSpan({
    required this.path,
    required this.textColor,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) return const SizedBox(width: 16, height: 16);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: 200,
        height: 100,
        child: Stack(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

            // Remove button — top-right
            if (onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
