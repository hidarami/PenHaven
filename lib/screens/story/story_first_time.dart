import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STORY FIRST TIME
// Shown when the user has NO stories yet.
// Displays editable "Story" text at the top with a subtle hint.
// Double-tap or long-press activates inline TextField.
// Pressing Enter creates the story and returns to normal StoryPanel.
//
// CRITICAL per Master Specification §3:
//   - User creates first story RIGHT HERE — not forced to Library panel
//   - "Story" text is inline editable, not a dialog
// ─────────────────────────────────────────────────────────────────────────────

class StoryFirstTime extends StatefulWidget {
  const StoryFirstTime({super.key});

  @override
  State<StoryFirstTime> createState() => _StoryFirstTimeState();
}

class _StoryFirstTimeState extends State<StoryFirstTime> {
  bool _editing = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) {
        _tryCreate();
      }
    });
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
    });
  }

  Future<void> _tryCreate() async {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _editing = false);
      return;
    }
    try {
      await context.read<AppState>().createStory(title: title);
      // AppState.hasStories will now be true, StoryPanel re-renders automatically
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create story: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final topPadding = MediaQuery.of(context).padding.top;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: topPadding > 0 ? 60 : 80),

            // ── Editable "Story" title ────────────────────────────────────
            GestureDetector(
              onDoubleTap: _startEditing,
              onLongPress: _startEditing,
              child: _editing
                  ? TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: AppTypography.storyTitle(textColor),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _tryCreate(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Name your story...',
                        hintStyle: AppTypography.storyTitle(mutedColor),
                      ),
                    )
                  : Text(
                      'Story',
                      style: AppTypography.storyTitle(textColor),
                    ),
            ),

            const SizedBox(height: 12),

            // ── Hint text ─────────────────────────────────────────────────
            if (!_editing)
              Text(
                'Double-tap or long-press to begin',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: mutedColor,
                  fontStyle: FontStyle.italic,
                ),
              ),

            const Spacer(),

            // ── Centered guide prompt ─────────────────────────────────────
            if (!_editing)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Text(
                    'Your sanctuary awaits.',
                    style: GoogleFonts.crimsonPro(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: mutedColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
