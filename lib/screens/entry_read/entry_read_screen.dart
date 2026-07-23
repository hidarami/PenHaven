import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/entry.dart';
import '../../atmosphere/atmosphere_overlay.dart';
import '../../atmosphere/atmosphere_image_layer.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_colors.dart';
import '../editor/editor_screen.dart';
import '../community/community_entry_viewer.dart';
import '../../services/supabase_service.dart';
import '../../models/published_entry.dart';
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

  // Swipe exit is velocity-based — no tracking state needed

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
  }

  // ── Long-press to open editor ────────────────────────────────────────────

  void _handleLongPress() => _openEditor();

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = context.watch<AtmosphereState>().backgroundFor(dark);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          GestureDetector(
              onHorizontalDragEnd: _handleSwipeExit,
              onLongPress: _handleLongPress,
              behavior: HitTestBehavior.translucent,
              child: _ReadContent(entry: _entry, isDark: dark),
            ),
          // ── Atmosphere visual overlay (glow painters) ──────────────────
          const AtmosphereOverlay(),
          // ── Atmosphere image layer (PNG window/shadow overlays) ─────────
          const AtmosphereImageLayer(),
          // ── Glassmorphic community stats pill (shows if published) ───────
          _PublishedStatsPill(entryId: _entry.id),
        ],
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
            child: EntryHeaderImage(
              path: entry.headerImage!,
              ratio: entry.headerImageRatio,
            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// PUBLISHED STATS PILL
// Shows clap + comment count for entries the user has published.
// Appears as a floating glassmorphic pill at the bottom of the read view.
// Tapping navigates to the community entry viewer.
// ─────────────────────────────────────────────────────────────────────────────

class _PublishedStatsPill extends StatefulWidget {
  final String entryId;
  const _PublishedStatsPill({required this.entryId});

  @override
  State<_PublishedStatsPill> createState() => _PublishedStatsPillState();
}

class _PublishedStatsPillState extends State<_PublishedStatsPill> {
  PublishedEntry? _pub;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!SupabaseService.instance.isAuthenticated) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final pub = await SupabaseService.instance.getPublishedEntry(widget.entryId);
    if (mounted) setState(() { _pub = pub; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    // Only show if loaded and published by current user
    if (!_loaded || _pub == null) return const SizedBox.shrink();

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPad + 28,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CommunityEntryViewer(entry: _pub!)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Clap count
                    Icon(
                      _pub!.hasClapped
                          ? Icons.volunteer_activism_rounded
                          : Icons.volunteer_activism_outlined,
                      size: 17,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_pub!.clapCount}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    // Divider
                    Container(
                      width: 0.5, height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: Colors.white.withOpacity(0.35),
                    ),
                    // Comment count
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 15, color: Colors.white.withOpacity(0.9)),
                    const SizedBox(width: 5),
                    Text(
                      '${_pub!.commentCount}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    // Published label
                    Container(
                      width: 0.5, height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: Colors.white.withOpacity(0.35),
                    ),
                    Icon(Icons.public_rounded,
                        size: 13, color: Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      'Published',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}