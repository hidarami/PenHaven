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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.story.title);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) {
        _saveTitle();
      }
    });
  }

  @override
  void didUpdateWidget(StoryHeader old) {
    super.didUpdateWidget(old);
    if (!_editing && old.story.title != widget.story.title) {
      _controller.text = widget.story.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  void _saveTitle() {
    final newTitle = _controller.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.story.title) {
      try {
        context.read<AppState>().updateStory(
              widget.story.copyWith(title: newTitle),
            );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update title: $e')),
        );
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
              ? TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: AppTypography.storyTitle(textColor),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveTitle(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    fillColor: Colors.transparent,
                    filled: true,
                    hintText: 'Story title',
                    hintStyle: AppTypography.storyTitle(mutedColor),
                  ),
                  maxLines: 1,
                )
              : Text(
                  widget.story.title,
                  style: AppTypography.storyTitle(textColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ),

        // ── Description ───────────────────────────────────────────────────
        if (widget.story.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.story.description,
            style: AppTypography.storyDescription(mutedColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
