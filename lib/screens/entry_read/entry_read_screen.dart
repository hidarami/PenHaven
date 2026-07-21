import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/entry.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../editor/editor_screen.dart';
import 'entry_header_image.dart';
import 'entry_content.dart';
import 'entry_footer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY READ SCREEN
// Pure reading experience. Magazine-quality rendering.
//
// CRITICAL rules (Master Specification §4):
//   - Swipe left-to-right → Navigator.pop() back to Story Panel
//   - Double-tap ANYWHERE on screen → opens Editor
//   - Header image appears FIRST (before title) if it exists
//   - NO visible UI chrome — no buttons, no labels, pure content
//   - Read-Only fully renders markdown (no raw syntax visible)
//   - [openEditorImmediately] = true when coming from "Add Entry" button
// ─────────────────────────────────────────────────────────────────────────────

class EntryReadScreen extends StatefulWidget {
  final Entry entry;
  final bool openEditorImmediately;

  const EntryReadScreen({
    super.key,
    required this.entry,
    this.openEditorImmediately = false,
  });

  @override
  State<EntryReadScreen> createState() => _EntryReadScreenState();
}

class _EntryReadScreenState extends State<EntryReadScreen> {
  late Entry _entry;

  // Swipe tracking
  double _dragStartX = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;

    // If called from "Add Entry", jump straight to editor
    if (widget.openEditorImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openEditor());
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Called when editor closes — refreshes entry data in case it was edited.
  Future<void> _openEditor() async {
    final appState = context.read<AppState>();
    final result = await Navigator.of(context).push<Entry>(
      MaterialPageRoute(
        builder: (_) => EditorScreen(entry: _entry),
      ),
    );
    // Editor returns the updated entry on pop
    if (result != null && mounted) {
      setState(() => _entry = result);
      // Also refresh the story panel list
      appState.refreshEntries();
    }
  }

  void _handleSwipeExit(DragEndDetails details) {
    // Positive velocity = right swipe = exit to Story Panel
    if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
      Navigator.of(context).pop();
    }
    setState(() => _isDragging = false);
  }

  // ── Double-tap ─────────────────────────────────────────────────────────────

  void _handleDoubleTap() => _openEditor();

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = context.watch<AppState>().isDarkMode
        ? AppColors.warmDark
        : AppColors.warmWhite;

    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        // ── Swipe left-to-right to exit ──────────────────────────────────
        onHorizontalDragStart: (d) {
          _dragStartX = d.globalPosition.dx;
          _isDragging = true;
        },
        onHorizontalDragEnd: _handleSwipeExit,

        // ── Double-tap anywhere to edit ───────────────────────────────────
        onDoubleTap: _handleDoubleTap,

        behavior: HitTestBehavior.translucent,
        child: _ReadContent(entry: _entry, isDark: dark),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ CONTENT
// Assembles the full reading layout:
//   [Header Image] → Title → Date → Body → Footer
// Each piece is its own widget for isolated editing.
// ─────────────────────────────────────────────────────────────────────────────

class _ReadContent extends StatelessWidget {
  final Entry entry;
  final bool isDark;

  const _ReadContent({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Status bar spacer ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: SizedBox(height: topPadding + 24),
        ),

        // ── Header image FIRST (before title) — CRITICAL ─────────────────
        if (entry.hasHeaderImage)
          SliverToBoxAdapter(
            child: EntryHeaderImage(path: entry.headerImage!),
          ),

        // ── Title + date + body ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: EntryContent(entry: entry, isDark: isDark),
        ),

        // ── Footer: time spent + last updated ────────────────────────────
        SliverToBoxAdapter(
          child: EntryFooter(entry: entry, isDark: isDark),
        ),

        // Bottom safe area
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.of(context).padding.bottom + 48,
          ),
        ),
      ],
    );
  }
}
