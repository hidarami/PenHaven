import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/shared_widgets.dart';
import 'library_empty_state.dart';
import 'story_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LIBRARY PANEL — Panel 0
// Leftmost panel. Create and browse stories.
// Access: swipe right from Story Panel OR via Menu.
//
// CRITICAL RULES (from Master Specification §3):
//   - NO IMAGES anywhere on this panel
//   - Tapping a story does NOT navigate — stories are selected via Menu
//   - When empty: large centered + button
//   - When populated: small "+ Add New Story" at top, then scrollable list
// ─────────────────────────────────────────────────────────────────────────────

class LibraryPanel extends StatelessWidget {
  const LibraryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final stories = appState.stories;
        final topPadding = MediaQuery.of(context).padding.top;
        final dark = appState.isDarkMode;
        final textColor = dark ? AppColors.textDark : AppColors.textLight;
        final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────
                SizedBox(height: topPadding > 0 ? 60 : 80),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Library',
                      style: AppTypography.panelHeader(textColor),
                    ),
                    if (stories.isNotEmpty)
                      Text(
                        '${stories.length} ${stories.length == 1 ? 'story' : 'stories'}',
                        style: AppTypography.entryCount(mutedColor),
                      ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Body: empty state OR story list ───────────────────────
                Expanded(
                  child: stories.isEmpty
                      ? LibraryEmptyState(
                          onCreateStory: () => _createStory(context))
                      : _PopulatedLibrary(
                          onCreateStory: () => _createStory(context),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createStory(BuildContext context) async {
    print('Library: _createStory called');
    try {
      final result = await StoryCreateDialog.show(context);
      print('Library: StoryCreateDialog result: $result');
      if (result == null || !context.mounted) return;
      await context.read<AppState>().createStory(
            title: result.title,
            description: result.description,
          );
      print('Library: Story created successfully');
    } catch (e) {
      print('Library: Error creating story: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create story: $e')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POPULATED LIBRARY
// Shows "+ Add New Story" button at top, then scrollable story cards.
// ─────────────────────────────────────────────────────────────────────────────

class _PopulatedLibrary extends StatelessWidget {
  final VoidCallback onCreateStory;

  const _PopulatedLibrary({required this.onCreateStory});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final stories = appState.stories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Small "+ Add New Story" button
        GestureDetector(
          onTap: onCreateStory,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 16, color: AppColors.teal),
              const SizedBox(width: 6),
              Text(
                'Add New Story',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Story list
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: stories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return StoryCard(
                story: stories[index],
                isActive: appState.activeStory?.id == stories[index].id,
              );
            },
          ),
        ),
      ],
    );
  }
}
