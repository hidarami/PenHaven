import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/image_service.dart';
import '../../services/permission_service.dart';

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
  bool _creating = false; // prevents double-creation
  final _controller = TextEditingController();
  final _descController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // No focus listener — prevents duplicate creation when keyboard dismisses
  }

  @override
  void dispose() {
    _controller.dispose();
    _descController.dispose();
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
    if (_creating) return;
    final title = _controller.text.trim();
    if (title.isEmpty) {
      if (mounted) setState(() => _editing = false);
      return;
    }

    // Prompt for optional cover before creating — skipped entirely in
    // Minimalist Mode, which never asks for cover/header art up front.
    String? coverPath;
    final isMinimal = context.read<AppState>().isMinimalistMode;
    if (mounted && !isMinimal) coverPath = await _showCoverPrompt();
    if (!mounted) return;

    setState(() => _creating = true);
    try {
      await context.read<AppState>().createStory(
            title: title,
            description: _descController.text.trim(),
            coverImage: coverPath,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create story: $e')),
      );
    }
  }

  Future<String?> _showCoverPrompt() async {
    final dark = context.read<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    final pick = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: mutedColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Add a cover image?',
                  style: GoogleFonts.crimsonPro(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
              const SizedBox(height: 4),
              Text(
                'Your story will look beautiful either way.',
                style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(_, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: mutedColor.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('Skip',
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: mutedColor)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(_, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.aqua.withOpacity(0.1),
                          border: Border.all(
                              color: AppColors.aqua.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('Add Cover',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.aqua)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (pick != true || !mounted) return null;
    final ok = await PermissionService.instance.ensurePhotos(context);
    if (!ok || !mounted) return null;
    return ImageService.instance.pickAndSave(
      context: context,
      allowCrop: true,
      cropAspectRatioX: 3,
      cropAspectRatioY: 2,
    );
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
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: AppTypography.storyTitle(textColor),
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Name your story...',
                            hintStyle: AppTypography.storyTitle(mutedColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descController,
                          style: GoogleFonts.crimsonPro(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: mutedColor,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _tryCreate(),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'A short description (optional)',
                            hintStyle: GoogleFonts.crimsonPro(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: mutedColor.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
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
