import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/entry.dart';
import '../../atmosphere/atmosphere_overlay.dart';
import '../../atmosphere/atmosphere_image_layer.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_colors.dart';
import '../editor/editor_screen.dart';
import '../../services/supabase_service.dart';
import '../../models/published_entry.dart';
import '../community/community_entry_viewer.dart';
import '../community/public_profile_modal.dart';
import '../../widgets/user_avatar.dart';
import '../../models/community_comment.dart';
import '../../providers/community_state.dart';
import 'entry_header_image.dart';
import 'entry_content.dart';
import 'entry_footer.dart';
import '../../widgets/action_pill.dart';

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
          // ── Glassmorphic community stats pill / share pill ────────────────
      _PublishedStatsPill(entryId: _entry.id, entry: _entry),
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
              backgroundColor:
                  context.watch<AtmosphereState>().backgroundFor(isDark),
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
  final Entry entry;
  const _PublishedStatsPill({required this.entryId, required this.entry});

  @override
  State<_PublishedStatsPill> createState() => _PublishedStatsPillState();
}

class _PublishedStatsPillState extends State<_PublishedStatsPill> {
  PublishedEntry? _pub;
  bool _loaded = false;
  bool _hasClapped = false;
  int _clapCount = 0;
  int _commentCount = 0;
  Map<String, dynamic>? _writeBackData;

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
    final pub =
        await SupabaseService.instance.getPublishedEntry(widget.entryId);
    if (mounted) {
      setState(() {
        _pub = pub;
        _loaded = true;
        if (pub != null) {
          _hasClapped = pub.hasClapped;
          _clapCount = pub.clapCount;
          _commentCount = pub.commentCount;
        }
      });
    }
    if (pub != null) {
      final wb = await SupabaseService.instance.getWriteBackById(pub.id);
      if (mounted) setState(() => _writeBackData = wb);
    }
  }

  void _showReplies(BuildContext ctx) {
    if (_pub == null) return;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InlineRepliesSheet(reflectionId: _pub!.id),
    );
  }

  void _handleClap(BuildContext ctx) {
    if (!SupabaseService.instance.isAuthenticated || _pub == null) return;
    HapticFeedback.lightImpact();
    final was = _hasClapped;
    setState(() {
      _hasClapped = !was;
      _clapCount = (_clapCount + (was ? -1 : 1)).clamp(0, 999999);
    });
    ctx.read<CommunityState>().toggleClap(_pub!.id);
  }

  void _openShareSheet(BuildContext ctx) {
    HapticFeedback.lightImpact();
    final pubEntry = _pub ??
        PublishedEntry(
          userId: SupabaseService.instance.userId ?? '',
          title: widget.entry.title,
          content: widget.entry.content,
          blocksJson: widget.entry.blocksJson,
          headerImage: widget.entry.headerImage,
          displayName: ctx.read<CommunityState>().profileDisplayName,
        );
    final dark = ctx.read<AppState>().isDarkMode;
    final profileImagePath = ctx.read<CommunityState>().profileImagePath;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SanctuaryShareSheet(
        entry: pubEntry,
        isDark: dark,
        profileImagePath: profileImagePath,
      ),
    );
  }

  void _showComments(BuildContext ctx) {
    if (_pub == null) return;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InlineCommentsSheet(
        entryId: _pub!.id,
        onCommentAdded: () => setState(() => _commentCount++),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // Not published — small circular glassmorphic share button
    if (_pub == null) {
      return Positioned(
        bottom: bottomPad + 28,
        right: 20,
        child: GestureDetector(
          onTap: () => _openShareSheet(context),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.28), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.ios_share_outlined,
                    size: 20, color: Colors.white.withOpacity(0.9)),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      bottom: bottomPad + 28,
      left: 0,
      right: 0,
      child: Center(
        child: ActionPill(
          hasClapped: _hasClapped,
          onClap: () => _handleClap(context),
          onRespond: _writeBackData != null ? () => _showReplies(context) : null,
          onWriteBack: null,
          onShare: () => _openShareSheet(context),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE REPLIES SHEET
// For write-back/reflection replies (reflection_replies table) — distinct
// from regular community_comments used by _InlineCommentsSheet.
// ─────────────────────────────────────────────────────────────────────────────

class _InlineRepliesSheet extends StatefulWidget {
  final String reflectionId;
  const _InlineRepliesSheet({required this.reflectionId});

  @override
  State<_InlineRepliesSheet> createState() => _InlineRepliesSheetState();
}

class _InlineRepliesSheetState extends State<_InlineRepliesSheet> {
  List<CommunityComment> _replies = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  bool _isAnon = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final replies =
        await SupabaseService.instance.getReflectionReplies(widget.reflectionId);
    if (mounted) setState(() {
      _replies = replies;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _submitting) return;
    if (!SupabaseService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sign in to respond.')));
      return;
    }
    setState(() => _submitting = true);
    final email = SupabaseService.instance.userEmail;
    final displayName = _isAnon
        ? null
        : (context.read<CommunityState>().profileDisplayName ??
            email?.split('@').first);
    final ok = await SupabaseService.instance.addReflectionReply(
      reflectionId: widget.reflectionId,
      body: body,
      isAnonymous: _isAnon,
      displayName: displayName,
      profileImageUrl: context.read<CommunityState>().profileImageUrl,
    );
    if (ok && mounted) {
      _ctrl.clear();
      await _load();
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, sc) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: mutedColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Responses',
                  style: GoogleFonts.crimsonPro(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Container(
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _ctrl,
                      maxLines: 3,
                      minLines: 1,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: textColor, height: 1.5),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Your response...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: mutedColor,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _isAnon = !_isAnon),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: _isAnon
                                      ? AppColors.aqua
                                      : Colors.transparent,
                                  border: Border.all(
                                      color: _isAnon
                                          ? AppColors.aqua
                                          : mutedColor.withOpacity(0.5),
                                      width: 1.5)),
                              child: _isAnon
                                  ? const Icon(Icons.check,
                                      size: 10, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 5),
                            Text('Anonymous',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: mutedColor)),
                          ]),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _submitting ? null : _submit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                                color: AppColors.aqua.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.aqua.withOpacity(0.4))),
                            child: _submitting
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppColors.aqua))
                                : Text('Reply',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.aqua)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _replies.isEmpty
                      ? Center(
                          child: Text('No responses yet.',
                              style: GoogleFonts.crimsonPro(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: mutedColor)))
                      : ListView.separated(
                          controller: sc,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          itemCount: _replies.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (_, i) {
                            final r = _replies[i];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => PublicProfileModal.show(
                                    context,
                                    userId: r.userId,
                                    displayName: r.authorLabel,
                                    imageUrl: r.profileImagePath,
                                  ),
                                  child: UserAvatar(
                                    name: r.authorLabel,
                                    size: 28,
                                    userId: r.userId,
                                    remoteImageUrl: r.profileImagePath,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(r.authorLabel,
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textColor)),
                                      const SizedBox(height: 3),
                                      Text(r.body,
                                          style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color:
                                                  textColor.withOpacity(0.85),
                                              height: 1.5)),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE COMMENTS SHEET
// Bottom sheet for reading and adding comments without leaving the entry.
// ─────────────────────────────────────────────────────────────────────────────

class _InlineCommentsSheet extends StatefulWidget {
  final String entryId;
  final VoidCallback? onCommentAdded;

  const _InlineCommentsSheet({required this.entryId, this.onCommentAdded});

  @override
  State<_InlineCommentsSheet> createState() => _InlineCommentsSheetState();
}

class _InlineCommentsSheetState extends State<_InlineCommentsSheet> {
  List<CommunityComment> _comments = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  bool _isAnon = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final c =
          await SupabaseService.instance.getCommunityComments(widget.entryId);
      if (mounted)
        setState(() {
          _comments = c;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final ok = await context.read<CommunityState>().deleteComment(
      commentId: commentId,
      entryId: widget.entryId,
    );
    if (ok && mounted) {
      setState(() => _comments.removeWhere((c) => c.id == commentId));
    }
  }

  Future<void> _submit() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _submitting) return;
    if (!SupabaseService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sign in to comment.')));
      return;
    }
    setState(() => _submitting = true);
    final email = SupabaseService.instance.userEmail;
    final displayName = _isAnon
        ? null
        : (context.read<CommunityState>().profileDisplayName ??
            email?.split('@').first);
    final ok = await context.read<CommunityState>().addComment(
          entryId: widget.entryId,
          body: body,
          isAnonymous: _isAnon,
          displayName: displayName,
        );
    if (ok && mounted) {
      _ctrl.clear();
      widget.onCommentAdded?.call();
      await _loadComments();
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final divColor = dark ? AppColors.dividerDark : AppColors.dividerLight;
    final cardBg =
        dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, sc) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: mutedColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('Responses',
                      style: GoogleFonts.crimsonPro(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                  const Spacer(),
                  if (_loading)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: divColor, height: 1),
            // Input box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Container(
                decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: divColor.withOpacity(0.5))),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _ctrl,
                      maxLines: 3,
                      minLines: 1,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: textColor, height: 1.5),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Share your thoughts...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: mutedColor,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _isAnon = !_isAnon),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: _isAnon
                                      ? AppColors.aqua
                                      : Colors.transparent,
                                  border: Border.all(
                                      color: _isAnon
                                          ? AppColors.aqua
                                          : mutedColor.withOpacity(0.5),
                                      width: 1.5)),
                              child: _isAnon
                                  ? const Icon(Icons.check,
                                      size: 10, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 5),
                            Text('Anonymous',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: mutedColor)),
                          ]),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _submitting ? null : _submit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                                color: AppColors.aqua.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.aqua.withOpacity(0.4))),
                            child: _submitting
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppColors.aqua))
                                : Text('Post',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.aqua)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Divider(color: divColor, height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? Center(
                          child: Text('No responses yet.',
                              style: GoogleFonts.crimsonPro(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: mutedColor)))
                      : ListView.separated(
                          controller: sc,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          itemCount: _comments.length,
                          separatorBuilder: (_, __) => Divider(
                              color: divColor.withOpacity(0.5), height: 20),
                          itemBuilder: (_, i) {
                            final c = _comments[i];
                            final diff = DateTime.now().difference(c.createdAt);
                            final ago = diff.inMinutes < 60
                                ? '${diff.inMinutes}m ago'
                                : diff.inHours < 24
                                    ? '${diff.inHours}h ago'
                                    : diff.inDays < 7
                                        ? '${diff.inDays}d ago'
                                        : DateFormat('MMM d')
                                            .format(c.createdAt);
                            final canDelete = c.userId ==
                                SupabaseService.instance.userId;
                            return GestureDetector(
                              onLongPress: canDelete
                                  ? () => showDialog<void>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title:
                                              const Text('Delete comment?'),
                                          content: const Text(
                                              'This cannot be undone.'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child:
                                                    const Text('Cancel')),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _deleteComment(c.id);
                                              },
                                              child: const Text('Delete',
                                                  style: TextStyle(
                                                      color:
                                                          AppColors.danger)),
                                            ),
                                          ],
                                        ),
                                      )
                                  : null,
                              child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () => PublicProfileModal.show(
                                        context,
                                        userId: c.userId,
                                        displayName: c.authorLabel,
                                        imageUrl: c.profileImagePath,
                                      ),
                                      child: UserAvatar(
                                        name: c.authorLabel,
                                        size: 28,
                                        userId: c.userId,
                                        remoteImageUrl: c.profileImagePath,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Row(children: [
                                            Text(c.authorLabel,
                                                style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: textColor)),
                                            const SizedBox(width: 6),
                                            Text(ago,
                                                style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    color: mutedColor)),
                                          ]),
                                          const SizedBox(height: 3),
                                          Text(c.body,
                                              style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: textColor
                                                      .withOpacity(0.85),
                                                  height: 1.5)),
                                        ])),
                                  ]),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
