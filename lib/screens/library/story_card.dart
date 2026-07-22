import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/story.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neumorphic_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STORY CARD
// Neumorphic card showing story title + 2-line description.
// Tapping selects the story as active (switches which entries appear
// in the Story Panel). Stories are NOT navigated into from here.
// Active story gets a aqua left accent border.
// ─────────────────────────────────────────────────────────────────────────────

class StoryCard extends StatelessWidget {
  final Story story;
  final bool isActive;

  const StoryCard({
    super.key,
    required this.story,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return NeumorphicCard(
      padding: EdgeInsets.zero,
      onTap: () => context.read<AppState>().selectStory(story),
      onLongPress: () => _showOptions(context),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Active story accent bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 4,
              decoration: BoxDecoration(
                color: isActive ? AppColors.aqua : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),

            // Story content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      story.title,
                      style: GoogleFonts.crimsonPro(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Description (if any)
                    if (story.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        story.description,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: mutedColor,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Lock icon if story is locked
            if (story.isLocked)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: mutedColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final appState = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, appState);
              },
            ),
            ListTile(
              leading: Icon(
                story.isLocked ? Icons.lock_open_outlined : Icons.lock_outline,
              ),
              title: Text(story.isLocked ? 'Unlock story' : 'Lock story'),
              onTap: () {
                Navigator.pop(ctx);
                appState.updateStory(
                  story.copyWith(isLocked: !story.isLocked),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text(
                'Delete story',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, appState);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, AppState appState) {
    final controller = TextEditingController(text: story.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Story'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Story title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                appState.updateStory(story.copyWith(title: newTitle));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState appState) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Story?'),
        content: const Text(
          'This will delete all entries in this story. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.deleteStory(story.id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
