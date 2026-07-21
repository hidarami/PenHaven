import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/entry.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neumorphic_widgets.dart';
import '../editor/editor_screen.dart';
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
//
// Adding an entry:
//   - Click the "Add Entry" button below the list
//   - OR scroll down past the last item — a fresh blank page slides in
//     with a blinking cursor, ready to type (like Pencake).
//   - Double-tap / long-press on the story panel no longer creates entries.
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

class _StoryPanelContent extends StatefulWidget {
  final AppState appState;

  const _StoryPanelContent({required this.appState});

  @override
  State<_StoryPanelContent> createState() => _StoryPanelContentState();
}

class _StoryPanelContentState extends State<_StoryPanelContent> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Pull-to-refresh handler — creates a new entry instead of refreshing.
  Future<void> _onRefresh() async {
    await _addEntry(context);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final dark = widget.appState.isDarkMode;
    final entries = widget.appState.currentEntries;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPadding > 0 ? 60 : 80),

          // ── Story header: title, description, entry count ────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: StoryHeader(story: widget.appState.activeStory!),
          ),

          const SizedBox(height: 24),

          // ── Divider ───────────────────────────────────────────────────────
          Divider(
            color: dark ? AppColors.dividerDark : AppColors.dividerLight,
            thickness: 0.5,
            height: 0,
          ),

          // ── Entry list or empty state ─────────────────────────────────────
          // NOTE: No GestureDetector wrapper — double-tap/long-press removed.
          // Use the "Add Entry" button or pull down to create.
          Expanded(
            child: entries.isEmpty
                ? _EmptyEntryState(onAddEntry: () => _addEntry(context))
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: EntryList(
                      entries: entries,
                      scrollController: _scrollController,
                      onTapEntry: (entry) => _openEntry(context, entry),
                      onAddEntry: () => _addEntry(context),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Creates a new entry and opens the Editor directly (not EntryReadScreen).
  /// A fresh blank page slides in with a blinking cursor, ready to type.
  Future<void> _addEntry(BuildContext context) async {
    print('Story: _addEntry called');
    final appState = context.read<AppState>();
    try {
      final entry = await appState.createEntry();
      print('Story: Entry created: ${entry.id}');
      if (!context.mounted) return;

      // Push EditorScreen directly — fresh blank page with blinking cursor
      final result = await Navigator.of(context).push<Entry>(
        MaterialPageRoute(
          builder: (_) => EditorScreen(entry: entry),
        ),
      );

      // If the editor returned an updated entry, refresh the list
      if (result != null && context.mounted) {
        appState.refreshEntries();
      }
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