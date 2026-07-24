import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/story.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STORY HEADER
// Shows: story title (large, bold, editable), description, entry count.
// Title is editable via double-tap OR long-press — transitions to TextField.
// Pressing Enter or tapping away saves the new title.
// ─────────────────────────────────────────────────────────────────────────────

class StoryHeader extends StatefulWidget {
  final Story story;

  const StoryHeader({super.key, required this.story});

  @override
  State<StoryHeader> createState() => _StoryHeaderState();
}

class _StoryHeaderState extends State<StoryHeader> {
  bool _editing = false;
  late TextEditingController _controller;
  late TextEditingController _descController;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _descFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.story.title);
    _descController = TextEditingController(text: widget.story.description);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) {
        // Microtask: don't save if focus moved to description field
        Future.microtask(() {
          if (mounted && _editing && !_descFocusNode.hasFocus) _save();
        });
      }
    });
    _descFocusNode.addListener(() {
      if (!_descFocusNode.hasFocus && _editing) _save();
    });
  }

  @override
  void didUpdateWidget(StoryHeader old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      if (old.story.title != widget.story.title) {
        _controller.text = widget.story.title;
      }
      if (old.story.description != widget.story.description) {
        _descController.text = widget.story.description;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _descController.dispose();
    _focusNode.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    _descController.text = widget.story.description;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  void _save() {
    final newTitle = _controller.text.trim();
    final newDesc = _descController.text.trim();
    if (newTitle.isNotEmpty) {
      final changed =
          newTitle != widget.story.title || newDesc != widget.story.description;
      if (changed) {
        try {
          context.read<AppState>().updateStory(
                widget.story.copyWith(title: newTitle, description: newDesc),
              );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update: $e')),
          );
        }
      }
    } else {
      _controller.text = widget.story.title;
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dark = appState.isDarkMode;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final entryCount = appState.entryCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title ──────────────────────────────────────────────────────────
        GestureDetector(
          onDoubleTap: _startEditing,
          onLongPress: _startEditing,
          child: _editing
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: AppTypography.storyTitle(textColor),
                      textInputAction: TextInputAction.next,
                      maxLines: 1,
                      onSubmitted: (_) => _descFocusNode.requestFocus(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        fillColor: Colors.transparent,
                        filled: true,
                        hintText: 'Story title',
                        hintStyle: AppTypography.storyTitle(mutedColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descController,
                      focusNode: _descFocusNode,
                      style: AppTypography.storyDescription(mutedColor),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Description (optional)',
                        hintStyle: AppTypography.storyDescription(
                            mutedColor.withOpacity(0.5)),
                      ),
                    ),
                  ],
                )
              : Text(
                  widget.story.title,
                  style: AppTypography.storyTitle(textColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ),

        // ── Description ───────────────────────────────────────────────────
        if (!_editing) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onLongPress: _startEditing,
            onDoubleTap: _startEditing,
            child: widget.story.description.isNotEmpty
                ? Text(
                    widget.story.description,
                    style: AppTypography.storyDescription(mutedColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    'Add a description…',
                    style: AppTypography.storyDescription(
                        mutedColor.withOpacity(0.4)),
                  ),
          ),
        ],

        // ── Entry count ───────────────────────────────────────────────────
        const SizedBox(height: 8),
        Text(
          entryCount == 0
              ? 'no entries'
              : '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
          style: AppTypography.entryCount(mutedColor),
        ),
      ],
    );
  }
}
