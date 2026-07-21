import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/story.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';

/// Scrollable list of all stories inside the menu.
/// Tapping a story sets it as active and closes the menu.
/// The currently active story is visually highlighted.
class MenuStorySelector extends StatelessWidget {
  final bool isDark;
  final Color bg;

  const MenuStorySelector({
    super.key,
    required this.isDark,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final stories = appState.stories.where((s) => !s.isDeleted).toList();
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
          child: Text(
            'STORIES',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: mutedColor,
              letterSpacing: 2.0,
            ),
          ),
        ),

        // Story list — scrollable
        Expanded(
          child: stories.isEmpty
              ? _EmptyStories(isDark: isDark, mutedColor: mutedColor)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: stories.length,
                  itemBuilder: (context, index) {
                    final story = stories[index];
                    final isActive = appState.activeStory?.id == story.id;
                    return _StoryTile(
                      story: story,
                      isActive: isActive,
                      isDark: isDark,
                      bg: bg,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTap: () {
                        appState.selectStory(story);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Story tile ─────────────────────────────────────────────────────────────

class _StoryTile extends StatelessWidget {
  final Story story;
  final bool isActive;
  final bool isDark;
  final Color bg;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _StoryTile({
    required this.story,
    required this.isActive,
    required this.isDark,
    required this.bg,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark
        ? Colors.white.withOpacity(isActive ? 0.09 : 0.0)
        : Colors.black.withOpacity(isActive ? 0.05 : 0.0);

    final accentColor = AppColors.teal;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(
                  color: accentColor.withOpacity(0.35),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            // Active indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3,
              height: isActive ? 28 : 0,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Story info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: GoogleFonts.crimsonPro(
                      fontSize: 18,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive ? textColor : textColor.withOpacity(0.75),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (story.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      story.description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: mutedColor,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(story.updatedAt),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: mutedColor.withOpacity(0.6),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            if (story.isLocked)
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: mutedColor,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyStories extends StatelessWidget {
  final bool isDark;
  final Color mutedColor;

  const _EmptyStories({required this.isDark, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Text(
        'No stories yet.\nSwipe right to the Library\nto create your first.',
        style: GoogleFonts.crimsonPro(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: mutedColor,
          height: 1.7,
        ),
      ),
    );
  }
}
