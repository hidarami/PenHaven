import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/story.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/shared_widgets.dart';
import 'library_empty_state.dart';
import 'story_card.dart';

enum _SortBy { lastEdited, alphabetical }

class LibraryPanel extends StatefulWidget {
  const LibraryPanel({super.key});

  @override
  State<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends State<LibraryPanel> {
  _SortBy _sortBy = _SortBy.lastEdited;

  List<Story> _sorted(List<Story> stories) {
    final list = List<Story>.of(stories);
    if (_sortBy == _SortBy.alphabetical) {
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final stories = _sorted(appState.stories);
        final topPadding = MediaQuery.of(context).padding.top;
        final dark = appState.isDarkMode;
        final textColor = dark ? AppColors.textDark : AppColors.textLight;
        final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
        final accent = context.watch<AtmosphereState>().accentColor;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: topPadding > 0 ? 60 : 80),

                // ── Header ──────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Library',
                              style: AppTypography.panelHeader(textColor)),
                          const SizedBox(height: 4),
                          Text(
                            'Your writing collections.',
                            style: GoogleFonts.crimsonPro(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (stories.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _createStory(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.06),
                          ),
                          child: Icon(Icons.add, size: 18, color: accent),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // ── Stats + Sort ─────────────────────────────────────────
                if (stories.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 15, color: accent.withOpacity(0.8)),
                      const SizedBox(width: 6),
                      Text(
                        '${stories.length} ${stories.length == 1 ? "story" : "stories"}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: mutedColor,
                        ),
                      ),
                      const Spacer(),
                      _SortDropdown(
                        current: _sortBy,
                        onChanged: (v) => setState(() => _sortBy = v),
                        mutedColor: mutedColor,
                        textColor: textColor,
                        dark: dark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Body ────────────────────────────────────────────────
                Expanded(
                  child: stories.isEmpty
                      ? LibraryEmptyState(
                          onCreateStory: () => _createStory(context))
                      : _sortBy == _SortBy.alphabetical
                          ? ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: stories.length,
                              itemBuilder: (context, i) => StoryCard(
                                key: ValueKey(stories[i].id),
                                story: stories[i],
                                isActive: appState.activeStory?.id == stories[i].id,
                              ),
                            )
                          : ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: stories.length,
                              onReorder: (oldIndex, newIndex) {
                                context.read<AppState>().reorderStories(oldIndex, newIndex);
                              },
                              itemBuilder: (context, i) =>
                                  ReorderableDelayedDragStartListener(
                                key: ValueKey(stories[i].id),
                                index: i,
                                child: StoryCard(
                                  story: stories[i],
                                  isActive: appState.activeStory?.id == stories[i].id,
                                ),
                              ),
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
    try {
      final result = await StoryCreateDialog.show(context);
      if (result == null || !context.mounted) return;
      await context.read<AppState>().createStory(
            title: result.title,
            description: result.description,
            coverImage: result.coverImage,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create story: $e')),
      );
    }
  }
}

// ── Sort dropdown ─────────────────────────────────────────────────────────────

class _SortDropdown extends StatelessWidget {
  final _SortBy current;
  final ValueChanged<_SortBy> onChanged;
  final Color mutedColor;
  final Color textColor;
  final bool dark;

  const _SortDropdown({
    required this.current,
    required this.onChanged,
    required this.mutedColor,
    required this.textColor,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        current == _SortBy.lastEdited ? 'Last edited' : 'A–Z';
    return PopupMenuButton<_SortBy>(
      onSelected: onChanged,
      color: dark ? AppColors.warmDark : AppColors.warmWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sort by: $label',
              style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: mutedColor),
        ],
      ),
      itemBuilder: (_) => [
        _menuItem(_SortBy.lastEdited, 'Last edited'),
        _menuItem(_SortBy.alphabetical, 'A–Z'),
      ],
    );
  }

  PopupMenuItem<_SortBy> _menuItem(_SortBy val, String label) =>
      PopupMenuItem(
        value: val,
        child: Row(
          children: [
            if (current == val) ...[
              const Icon(Icons.check_rounded, size: 14, color: AppColors.aqua),
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 22),
            Text(label,
                style: GoogleFonts.inter(fontSize: 14, color: textColor)),
          ],
        ),
      );
}