import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neumorphic_widgets.dart';
import '../entry_read/entry_read_screen.dart';
import 'story_header.dart';
import 'story_first_time.dart';
import 'entry_list.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STORY PANEL — Panel 1 (HOME)
// Middle panel. Shows entries for the active story.
// App opens here by default (PageController initialPage: 1).
//
// States:
//   - No active story: StoryFirstTime (inline story creation)
//   - Active story, no entries: Header + empty state + Add Entry button
//   - Active story, has entries: Header + EntryList + Add Entry button
// ─────────────────────────────────────────────────────────────────────────────

class StoryPanel extends StatelessWidget {
  const StoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        // No stories at all — first time experience
        if (!appState.hasStories) {
          return const StoryFirstTime();
        }

        return _StoryPanelContent(appState: appState);
      },
    );
  }
}

class _StoryPanelContent extends StatelessWidget {
  final AppState appState;

  const _StoryPanelContent({required this.appState});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final dark = appState.isDarkMode;
    final entries = appState.currentEntries;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPadding > 0 ? 60 : 80),

          // ── Story header: title, description, entry count ────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: StoryHeader(story: appState.activeStory!),
          ),

          const SizedBox(height: 24),

          // ── Divider ───────────────────────────────────────────────────────
          Divider(
            color: dark ? AppColors.dividerDark : AppColors.dividerLight,
            thickness: 0.5,
            height: 0,
          ),

          // ── Entry list or empty state ─────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onDoubleTap: () => _addEntry(context),
              onLongPress: () => _addEntry(context),
              child: entries.isEmpty
                  ? _EmptyEntryState(onAddEntry: () => _addEntry(context))
                  : EntryList(
                      entries: entries,
                      onTapEntry: (entry) => _openEntry(context, entry),
                      onAddEntry: () => _addEntry(context),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addEntry(BuildContext context) async {
    print('Story: _addEntry called');
    final appState = context.read<AppState>();
    try {
      final entry = await appState.createEntry();
      print('Story: Entry created: ${entry.id}');
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EntryReadScreen(
            entry: entry,
            openEditorImmediately: true,
          ),
        ),
      );
    } catch (e) {
      print('Story: Error adding entry: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add entry: $e')),
      );
    }
  }

  void _openEntry(BuildContext context, entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntryReadScreen(entry: entry),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY ENTRY STATE
// Shown when a story exists but has no entries yet.
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyEntryState extends StatelessWidget {
  final VoidCallback onAddEntry;

  const _EmptyEntryState({required this.onAddEntry});

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No entries yet.',
            style: TextStyle(
              color: mutedColor,
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          NeumorphicButton(
            onTap: onAddEntry,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 16, color: AppColors.teal),
                const SizedBox(width: 6),
                Text(
                  'Add Entry',
                  style: TextStyle(
                    color: AppColors.teal,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
