import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/community_comment.dart';
import '../../models/published_entry.dart';
import '../../models/editor_block.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../providers/community_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../editor/editor_canvas.dart';
import '../../widgets/shared_widgets.dart';
import 'public_profile_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COMMUNITY ENTRY VIEWER — Medium-inspired editorial layout
// Large title · Author row · Full reading body · Glassmorphic action pill
// ─────────────────────────────────────────────────────────────────────────────

class CommunityEntryViewer extends StatefulWidget {
  final PublishedEntry entry;
  const CommunityEntryViewer({super.key, required this.entry});

  @override
  State<CommunityEntryViewer> createState() => _CommunityEntryViewerState();
}

class _CommunityEntryViewerState extends State<CommunityEntryViewer> {
  late PublishedEntry _entry;
  List<CommunityComment> _comments = [];
  bool _commentsLoading = false;
  bool _commentsOpen = false;
  final _commentCtrl = TextEditingController();
  bool _commentAnon = false;
  bool _submittingComment = false;
  bool _pillVisible = true;
  Timer? _hideTimer;
  final ScrollController _scrollCtrl = ScrollController();
  double _readProgress = 0;
  bool _hasClapped = false;
  String? _viewerFontName;
  double _imageBrightness = 1.0;
  bool _isBookmarked = false;
  bool _showBrightnessSlider = false;
  int _clapCount = 0;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _hasClapped = _entry.hasClapped;
    _clapCount = _entry.clapCount;
    _commentCount = _entry.commentCount;
    _schedulePillHide();
    _scrollCtrl.addListener(_onScroll);
    _loadBookmark();
    // Record unique view (silently — table must exist in Supabase)
    SupabaseService.instance.recordView(_entry.id);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _hideTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

// Loads persisted bookmark state for this entry
  Future<void> _loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() =>
          _isBookmarked = prefs.getBool('bookmark_${_entry.id}') ?? false);
    }
  }

  void _onScroll() {
    // Update reading progress
    if (_scrollCtrl.hasClients && _scrollCtrl.position.maxScrollExtent > 0) {
      final progress =
          (_scrollCtrl.offset / _scrollCtrl.position.maxScrollExtent)
              .clamp(0.0, 1.0);
      if ((progress - _readProgress).abs() > 0.01) {
        setState(() => _readProgress = progress);
      }
    }
    // Show pill on scroll
    if (!_pillVisible) {
      setState(() => _pillVisible = true);
      _schedulePillHide();
    }
  }

  void _schedulePillHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _pillVisible = false);
    });
  }

  Future<void> _loadComments() async {
    if (_commentsLoading) return;
    setState(() => _commentsLoading = true);
    final comments =
        await context.read<CommunityState>().getComments(_entry.id);
    if (mounted) {
      setState(() {
        _comments = comments;
        _commentsLoading = false;
      });
    }
  }

  void _toggleComments() {
    setState(() => _commentsOpen = !_commentsOpen);
    if (_commentsOpen && _comments.isEmpty) _loadComments();
    // Scroll to bottom when opening
    if (_commentsOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _submitComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _submittingComment) return;

    if (!SupabaseService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to comment.')),
      );
      return;
    }

    setState(() => _submittingComment = true);
    final communityState = context.read<CommunityState>();
    final email = SupabaseService.instance.userEmail;
    final displayName = communityState.profileDisplayName ?? email?.split('@').first;

    final ok = await context.read<CommunityState>().addComment(
          entryId: _entry.id,
          body: body,
          isAnonymous: _commentAnon,
          displayName: _commentAnon ? null : displayName,
        );

    if (ok && mounted) {
      _commentCtrl.clear();
      setState(() => _commentCount++);
      await _loadComments();
    }
    if (mounted) setState(() => _submittingComment = false);
  }

  Future<void> _deleteComment(String commentId) async {
    final ok = await context.read<CommunityState>().deleteComment(
      commentId: commentId,
      entryId: _entry.id,
    );
    if (ok && mounted) {
      setState(() {
        _comments.removeWhere((c) => c.id == commentId);
        _commentCount = (_commentCount - 1).clamp(0, 999999);
      });
    }
  }

  void _handleClap() {
    if (!SupabaseService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to clap.')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    final was = _hasClapped;
    setState(() {
      _hasClapped = !was;
      _clapCount = (_clapCount + (was ? -1 : 1)).clamp(0, 999999);
    });
    context.read<CommunityState>().toggleClap(_entry.id);
  }

  Future<void> _handleBookmark() async {
    final newVal = !_isBookmarked;
    setState(() => _isBookmarked = newVal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bookmark_${_entry.id}', newVal);
  }

  void _handleShare() {
    HapticFeedback.lightImpact();
    _showShareSheet(context);
  }

  void _showShareSheet(BuildContext ctx) {
    final dark = ctx.read<AppState>().isDarkMode;
    final profileImagePath = ctx.read<CommunityState>().profileImagePath;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SanctuaryShareSheet(
          entry: _entry, isDark: dark, profileImagePath: profileImagePath),
    );
  }

  void _showFontPicker(BuildContext ctx) {
    final dark = ctx.read<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final fonts = AppTypography.fontDisplayNames.entries.toList();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                child: Text('Reading Font',
                    style: GoogleFonts.crimsonPro(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: fonts.length,
                  itemBuilder: (_, i) {
                    final key = fonts[i].key;
                    final name = fonts[i].value;
                    final current =
                        _viewerFontName ?? ctx.read<AppState>().preferredFont;
                    return ListTile(
                      title: Text(name,
                          style: AppTypography.bodyTextFor(key, textColor,
                              size: 16, height: 1.5)),
                      trailing: current == key
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.aqua)
                          : null,
                      onTap: () {
                        setState(() => _viewerFontName = key);
                        Navigator.pop(_);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showMoreMenu(BuildContext ctx) {
    final dark = ctx.read<AppState>().isDarkMode;
    final communityState = ctx.read<CommunityState>();
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    // Check if this entry has a local header image
    final localImageExists = _entry.headerImage != null &&
        _entry.headerImage!.isNotEmpty &&
        File(_entry.headerImage!).existsSync();

    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Delete (owner only)
            if (_entry.isOwner)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Delete from Sanctuary',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () async {
                  Navigator.pop(_);
                  await ctx.read<CommunityState>().deletePost(_entry.id);
                  if (mounted) Navigator.of(ctx).pop();
                },
              ),

            ListTile(
              leading: Icon(Icons.share_outlined, color: mutedColor),
              title:
                  Text('Share this entry', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(_);
                _handleShare();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Duration picker for featuring an entry.
  void _showFeatureDurationPicker(
      BuildContext ctx, CommunityState communityState) {
    final dark = ctx.read<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feature for how long?',
                style: GoogleFonts.crimsonPro(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pins this entry to the "Featured Reflection" card.',
                style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
              ),
              const SizedBox(height: 14),
              for (final opt in [
                (label: '24 hours', duration: const Duration(hours: 24)),
                (label: '3 days', duration: const Duration(days: 3)),
                (label: '7 days', duration: const Duration(days: 7)),
                (label: '30 days', duration: const Duration(days: 30)),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 20),
                  title: Text(opt.label,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: textColor)),
                  onTap: () {
                    Navigator.pop(_);
                    communityState.setFeatured(_entry.id,
                        duration: opt.duration);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Featured for ${opt.label} ✓')),
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Estimates reading time in minutes.
  String _readTime(String content) {
    final words = content.trim().split(RegExp(r'\s+')).length;
    final minutes = (words / 200).ceil().clamp(1, 999);
    return '$minutes min read';
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays < 1) return 'Today';
    if (diff.inDays < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('MMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = context.watch<AtmosphereState>().backgroundFor(dark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final fontName = _viewerFontName ?? context.watch<AppState>().preferredFont;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;
    final divColor = dark ? AppColors.dividerDark : AppColors.dividerLight;
    final hasHeaderImage = _entry.headerImage != null &&
        _entry.headerImage!.isNotEmpty &&
        File(_entry.headerImage!).existsSync();
    const imageH = 280.0;

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        // Right swipe to go back — no visible back button in this view
        if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            // ── Reading progress bar ──────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                height: 2.5,
                width: MediaQuery.of(context).size.width * _readProgress,
                color: AppColors.aqua.withOpacity(0.7),
              ),
            ),

            // ── Main content (header image lives INSIDE the scroll) ───────────
            SingleChildScrollView(
              controller: _scrollCtrl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header image — full-bleed at top of scroll ──────────────
                  if (hasHeaderImage)
                    Builder(builder: (_) {
                      final file = File(_entry.headerImage!);
                      if (!file.existsSync()) {
                        return SizedBox(height: topPad + 64);
                      }
                      // ColorFiltered lets the brightness slider affect the image
                      return ColorFiltered(
                        colorFilter: ColorFilter.matrix([
                          _imageBrightness,
                          0,
                          0,
                          0,
                          0,
                          0,
                          _imageBrightness,
                          0,
                          0,
                          0,
                          0,
                          0,
                          _imageBrightness,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                        child: Image.file(
                          file,
                          width: double.infinity,
                          height: 260,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              SizedBox(height: topPad + 64),
                        ),
                      );
                    })
                  else
                    // Status-bar spacer when there is no header image
                    SizedBox(height: topPad + 60),

                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Text(
                      _entry.title.isEmpty ? 'Untitled' : _entry.title,
                      style: GoogleFonts.crimsonPro(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),

                  // Author row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                    child: GestureDetector(
                      onTap: (!_entry.isOwner && !_entry.isAnonymous)
                          ? () => PublicProfileModal.show(
                                context,
                                userId: _entry.userId,
                                displayName: _entry.authorLabel,
                              )
                          : null,
                      child: Row(
                      children: [
                        _AvatarCircle(
                          name: _entry.isOwner
                              ? (context
                                      .watch<CommunityState>()
                                      .profileDisplayName ??
                                  _entry.authorLabel)
                              : _entry.authorLabel,
                          size: 38,
                          imagePath: _entry.isOwner
                              ? context.read<CommunityState>().profileImagePath
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _entry.isOwner
                                    ? (context
                                            .watch<CommunityState>()
                                            .profileDisplayName ??
                                        _entry.authorLabel)
                                    : _entry.authorLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_readTime(_entry.content)}  ·  ${_formatDate(_entry.createdAt)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: mutedColor,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),

                  // Thin divider
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Container(height: 0.5, color: divColor),
                  ),

                  // Body content
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 100),
                    child: _buildBody(dark, fontName),
                  ),

                  // Comments section
                  if (_commentsOpen)
                    _CommentsSection(
                      comments: _comments,
                      loading: _commentsLoading,
                      isEntryOwner: _entry.isOwner,
                      onDeleteComment: _deleteComment,
                      controller: _commentCtrl,
                      isAnon: _commentAnon,
                      submitting: _submittingComment,
                      isDark: dark,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onAnonChanged: (v) => setState(() => _commentAnon = v),
                      onSubmit: _submitComment,
                    ),

                  SizedBox(height: bottomPad + 80),
                ],
              ),
            ),

            // ── Glassmorphic nav row — top-right only (swipe right to go back) ──
            Positioned(
              top: topPad + 8,
              right: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavIconButton(
                    icon: _isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    active: _isBookmarked,
                    onTap: _handleBookmark,
                  ),
                  const SizedBox(width: 8),
                  _NavIconButton(
                    icon: Icons.text_fields_rounded,
                    onTap: () => _showFontPicker(context),
                  ),
                  const SizedBox(width: 8),
                  _NavIconButton(
                    icon: Icons.more_horiz,
                    onTap: () => _showMoreMenu(context),
                  ),
                ],
              ),
            ),

            // ── Glassmorphic action pill ──────────────────────────────────
            Positioned(
              bottom: bottomPad + 28,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _pillVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: !_pillVisible,
                  child: Center(
                    child: _ActionPill(
                      entry: _entry,
                      hasClapped: _hasClapped,
                      clapCount: _clapCount,
                      commentCount: _commentCount,
                      commentsOpen: _commentsOpen,
                      onClap: _handleClap,
                      onComment: _toggleComments,
                      onShare: _handleShare,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool dark, String fontName) {
    if (_entry.blocksJson != null && _entry.blocksJson!.isNotEmpty) {
      return BlocksReadView(
        blocks: deserializeBlocks(_entry.blocksJson!),
        isDark: dark,
        textAlignment: 'left',
        fontName: fontName,
      );
    }
    if (_entry.content.isNotEmpty) {
      return FlowMarkdownBody(data: _entry.content, selectable: true);
    }
    return const SizedBox.shrink();
  }
}

// ── Action pill — glassmorphic ────────────────────────────────────────────────

class _ActionPill extends StatelessWidget {
  final PublishedEntry entry;
  final bool hasClapped;
  final int clapCount;
  final int commentCount;
  final bool commentsOpen;
  final VoidCallback onClap;
  final VoidCallback onComment;
  final VoidCallback? onShare;

  const _ActionPill({
    required this.entry,
    required this.hasClapped,
    required this.clapCount,
    required this.commentCount,
    required this.commentsOpen,
    required this.onClap,
    required this.onComment,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(36),
            border:
                Border.all(color: Colors.white.withOpacity(0.25), width: 0.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Appreciate ─────────────────────────────────────────────
              GestureDetector(
                onTap: onClap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: hasClapped
                        ? const Color(0xFFE87FA0).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          hasClapped
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          key: ValueKey(hasClapped),
                          size: 18,
                          color: hasClapped
                              ? const Color(0xFFE87FA0)
                              : Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        hasClapped ? 'Appreciated' : 'Appreciate',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasClapped
                              ? const Color(0xFFE87FA0)
                              : Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Divider
              Container(
                  width: 0.5, height: 22, color: Colors.white.withOpacity(0.3)),

              // ── Comments ────────────────────────────────────────────────
              GestureDetector(
                onTap: onComment,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        commentsOpen
                            ? Icons.chat_bubble_rounded
                            : Icons.chat_bubble_outline_rounded,
                        size: 17,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$commentCount',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Divider
              Container(
                  width: 0.5, height: 22, color: Colors.white.withOpacity(0.3)),

              // ── Share ───────────────────────────────────────────────────
              GestureDetector(
                onTap: onShare,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Icon(Icons.ios_share_outlined,
                      size: 17, color: Colors.white.withOpacity(0.9)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Glassmorphic nav icon button — swipe right to go back, no back button ──────

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _NavIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    // Active state uses theme accent; inactive uses white over blurred bg
    final accentColor = context.watch<AtmosphereState>().accentColor;
    final iconColor = active ? accentColor : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.28),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
                width: 0.5,
              ),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
        ),
      ),
    );
  }
}

// ── Avatar circle ─────────────────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  final String name;
  final double size;
  final String? imagePath;
  const _AvatarCircle({required this.name, required this.size, this.imagePath});

  Color _color(String n) {
    const colors = [
      Color(0xFF7BA591),
      Color(0xFF5B8DB8),
      Color(0xFFD4820A),
      Color(0xFF9472D4),
      Color(0xFFE87FA0),
      Color(0xFFD44A28),
      Color(0xFF5A8A5C),
      Color(0xFF1B9B8D),
    ];
    final hash = n.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync()) {
      return ClipOval(
        child: Image.file(File(imagePath!),
            width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _color(name), shape: BoxShape.circle),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Comments section ──────────────────────────────────────────────────────────

class _CommentsSection extends StatelessWidget {
  final List<CommunityComment> comments;
  final bool loading;
  final TextEditingController controller;
  final bool isAnon;
  final bool submitting;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<bool> onAnonChanged;
  final VoidCallback onSubmit;
  final bool isEntryOwner;
  final Future<void> Function(String)? onDeleteComment;

  const _CommentsSection({
    required this.comments,
    required this.loading,
    required this.controller,
    required this.isAnon,
    required this.submitting,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onAnonChanged,
    required this.onSubmit,
    this.isEntryOwner = false,
    this.onDeleteComment,
  });

  @override
  Widget build(BuildContext context) {
    final divColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final cardBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: divColor, thickness: 0.5),
          const SizedBox(height: 20),
          Text(
            'Responses',
            style: GoogleFonts.crimsonPro(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),

          // ── Comment input card ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: divColor.withOpacity(0.5)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 3,
                  minLines: 1,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: textColor, height: 1.5),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'What did this make you feel?',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: mutedColor,
                        fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => onAnonChanged(!isAnon),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color:
                                  isAnon ? AppColors.aqua : Colors.transparent,
                              border: Border.all(
                                color: isAnon
                                    ? AppColors.aqua
                                    : mutedColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: isAnon
                                ? const Icon(Icons.check,
                                    size: 11, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text('Post anonymously',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: mutedColor)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: submitting ? null : onSubmit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.aqua.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.aqua.withOpacity(0.4)),
                        ),
                        child: submitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: AppColors.aqua),
                              )
                            : Text(
                                'Respond',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.aqua,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Comment list ──────────────────────────────────────────────
          if (loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator()))
          else if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No responses yet.\nBe the first to share your thoughts.',
                style: GoogleFonts.crimsonPro(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: mutedColor,
                  height: 1.6,
                ),
              ),
            )
          else
            ...comments.map((c) {
              final currentUserId = SupabaseService.instance.userId;
              final canDelete = c.userId == currentUserId || isEntryOwner;
              final isCurrentUser = c.userId == currentUserId;
              return _CommentCard(
                comment: c,
                isDark: isDark,
                textColor: textColor,
                mutedColor: mutedColor,
                canDelete: canDelete,
                currentUserImagePath: isCurrentUser
                    ? context.read<CommunityState>().profileImagePath
                    : null,
                onDelete: canDelete
                    ? () => onDeleteComment?.call(c.id)
                    : null,
              );
            }),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final CommunityComment comment;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final bool canDelete;
  final VoidCallback? onDelete;
  final String? currentUserImagePath;

  const _CommentCard({
    required this.comment,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    this.canDelete = false,
    this.onDelete,
    this.currentUserImagePath,
  });

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: canDelete
          ? () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete comment?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete?.call();
                      },
                      child: const Text('Delete',
                          style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvatarCircle(
              name: comment.authorLabel,
              size: 30,
              imagePath: currentUserImagePath ?? comment.profileImagePath,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.authorLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _ago(comment.createdAt),
                        style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                      ),
                      if (canDelete) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete comment?'),
                              content: const Text('This cannot be undone.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    onDelete?.call();
                                  },
                                  child: const Text('Delete',
                                      style: TextStyle(color: AppColors.danger)),
                                ),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: mutedColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.body,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: textColor.withOpacity(0.85),
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SANCTUARY SHARE SHEET — generates editorial card formats for social sharing
// Matches the design board: Editorial, Magazine, Quote Story, Paper
// ─────────────────────────────────────────────────────────────────────────────

class SanctuaryShareSheet extends StatefulWidget {
  final PublishedEntry entry;
  final bool isDark;
  final String? profileImagePath;
  const SanctuaryShareSheet(
      {super.key, required this.entry, required this.isDark, this.profileImagePath});

  @override
  State<SanctuaryShareSheet> createState() => _SanctuaryShareSheetState();
}

class _SanctuaryShareSheetState extends State<SanctuaryShareSheet> {
  int _selected = 0; // 0=Editorial, 1=Magazine, 2=Quote, 3=Paper
  bool _sharing = false;
  final _previewKey = GlobalKey();
  late TextEditingController _quoteTextCtrl;
  int _quoteAspect = 0; // 0 = 1:1 square, 1 = 3:4 portrait

  @override
  void initState() {
    super.initState();
    _quoteTextCtrl = TextEditingController(text: widget.entry.preview(300));
  }

  @override
  void dispose() {
    _quoteTextCtrl.dispose();
    super.dispose();
  }

  Widget _buildCard() {
    switch (_selected) {
      case 0:
        return _EditorialShareCard(
            entry: widget.entry, profileImagePath: widget.profileImagePath);
      case 1:
        return _MagazineShareCard(
            entry: widget.entry, profileImagePath: widget.profileImagePath);
      case 2:
        return _QuoteShareCard(
            entry: widget.entry,
            profileImagePath: widget.profileImagePath,
            customText: _quoteTextCtrl.text,
            isSquare: _quoteAspect == 0);
      default:
        return _PaperShareCard(
            entry: widget.entry,
            profileImagePath: widget.profileImagePath,
            customText: _quoteTextCtrl.text);
    }
  }

  Future<void> _shareCard() async {
    setState(() => _sharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      final boundary = _previewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) { setState(() => _sharing = false); return; }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) { setState(() => _sharing = false); return; }

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/sanctuary_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.pop(context);

      // Try to build a proper OG share link via Supabase Storage + Edge Function
      final imageUrl = await SupabaseService.instance.uploadShareCard(
          file.path, widget.entry.id);

      if (imageUrl != null) {
        final projectUrl = 'https://vjmzileqdrhxiklxqftv.supabase.co';
        final isPublished = widget.entry.userId.isNotEmpty; // has a user_id = was published
        final shareUrl = Uri.parse(
          '$projectUrl/functions/v1/share'
          '?entry_id=${Uri.encodeComponent(widget.entry.id)}'
          '&img=${Uri.encodeComponent(imageUrl)}'
          '&pub=$isPublished',
        ).toString();
        await Share.share(
          shareUrl,
          subject: widget.entry.title.isEmpty ? 'Sanctuary' : widget.entry.title,
        );
      } else {
        // Fallback: share the raw image file
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
          subject: widget.entry.title.isEmpty ? 'Sanctuary' : widget.entry.title,
        );
      }
    } catch (e) {
      debugPrint('[SanctuaryShare] $e');
    }
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor =
        widget.isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final cardW = MediaQuery.of(context).size.width - 40;
    // Dynamic card height per format and sub-option
    final double cardH;
    if (_selected == 2) {
      // Quote Story: 1:1 or 3:4
      cardH = _quoteAspect == 0 ? cardW : cardW * 4.0 / 3.0;
    } else if (_selected == 3) {
      // Paper: 2:3 portrait
      cardH = cardW * 3.0 / 2.0;
    } else {
      cardH = 200.0;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──────────────────────────────────────
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mutedColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('Share beautifully',
                    style: GoogleFonts.crimsonPro(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                child: Text('Choose a card format.',
                    style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
              ),

              // ── Format tabs ──────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  _ShareTab(
                    label: 'Editorial',
                    icon: Icons.auto_stories_outlined,
                    selected: _selected == 0,
                    onTap: () => setState(() => _selected = 0),
                  ),
                  _ShareTab(
                    label: 'Magazine',
                    icon: Icons.photo_library_outlined,
                    selected: _selected == 1,
                    onTap: () => setState(() => _selected = 1),
                  ),
                  _ShareTab(
                    label: 'Quote Story',
                    icon: Icons.format_quote_rounded,
                    selected: _selected == 2,
                    onTap: () => setState(() => _selected = 2),
                  ),
                  _ShareTab(
                    label: 'Paper',
                    icon: Icons.article_outlined,
                    selected: _selected == 3,
                    onTap: () => setState(() => _selected = 3),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Aspect ratio picker for Quote Story ──────────────
              if (_selected == 2) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ASPECT RATIO',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Row(children: [
                        _SizeChip(
                          label: '1 : 1  Square',
                          selected: _quoteAspect == 0,
                          onTap: () => setState(() => _quoteAspect = 0),
                          mutedColor: mutedColor,
                        ),
                        const SizedBox(width: 10),
                        _SizeChip(
                          label: '3 : 4  Portrait',
                          selected: _quoteAspect == 1,
                          onTap: () => setState(() => _quoteAspect = 1),
                          mutedColor: mutedColor,
                        ),
                      ]),
                    ],
                  ),
                ),
              ],

              // ── Custom text editor for Quote / Paper formats ──────
              if (_selected == 2 || _selected == 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EDIT QUOTE TEXT',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: mutedColor,
                            letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: widget.isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.08)),
                        ),
                        child: TextField(
                          controller: _quoteTextCtrl,
                          maxLines: 4,
                          minLines: 2,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.crimsonPro(
                              fontSize: 14, color: textColor, height: 1.6),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(12),
                            hintText: 'Enter quote text for the card...',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 13,
                                color: mutedColor,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Card preview (also the capture target) ───────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RepaintBoundary(
                    key: _previewKey,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      height: cardH,
                      child: _buildCard(),
                    ),
                  ),
                ),
              ),

              // ── Format hint ──────────────────────────────────────
              if (_selected == 2 || _selected == 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Text(
                    _selected == 2
                        ? 'Great for Instagram & TikTok Stories'
                        : 'Great for portrait sharing · 2:3 ratio',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: mutedColor,
                        fontStyle: FontStyle.italic)),
                ),
              const SizedBox(height: 16),

              // ── Share button ─────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad + 12),
                child: GestureDetector(
                  onTap: _sharing ? null : _shareCard,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.aqua.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AppColors.aqua.withOpacity(0.5)),
                    ),
                    child: Center(
                      child: _sharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: AppColors.aqua))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.ios_share_outlined,
                                  size: 16, color: AppColors.aqua),
                              const SizedBox(width: 8),
                              Text('Share this card',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.aqua)),
                            ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Format tab pill ───────────────────────────────────────────────────────────

class _ShareTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ShareTab(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.aqua.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppColors.aqua.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: selected ? AppColors.aqua : Colors.grey),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.aqua : Colors.grey)),
        ]),
      ),
    );
  }
}

// ── Sanctuary watermark ───────────────────────────────────────────────────────

class _SanctuaryMark extends StatelessWidget {
  final bool light;
  const _SanctuaryMark({this.light = false});

  @override
  Widget build(BuildContext context) {
    final color =
        light ? Colors.white.withOpacity(0.55) : const Color(0xFF8A8178);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.nightlight_rounded, size: 9, color: color),
      const SizedBox(width: 4),
      Text('Sanctuary',
          style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 1.4)),
    ]);
  }
}

// ── Card 1: Editorial — text left, image right ────────────────────────────────

class _EditorialShareCard extends StatelessWidget {
  final PublishedEntry entry;
  final String? profileImagePath;
  const _EditorialShareCard({required this.entry, this.profileImagePath});

  @override
  Widget build(BuildContext context) {
    final hasImage = entry.headerImage != null &&
        entry.headerImage!.isNotEmpty &&
        File(entry.headerImage!).existsSync();
    final catColor = const Color(0xFF4A7A6A);
    final authorInitial =
        entry.authorLabel.isNotEmpty ? entry.authorLabel[0].toUpperCase() : 'A';
    final hasProfileImage = profileImagePath != null &&
        profileImagePath!.isNotEmpty &&
        File(profileImagePath!).existsSync();

    return Container(
      color: const Color(0xFFF7F3EE), // warm cream
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: all text content
          Expanded(
            flex: 55,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.category != null && entry.category!.isNotEmpty) ...[
                    Text(
                      entry.category!.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          color: catColor,
                          letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    entry.title.isEmpty ? 'Untitled' : entry.title,
                    style: GoogleFonts.crimsonPro(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1410),
                        height: 1.2),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      entry.preview(100),
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          color: const Color(0xFF8A8178),
                          height: 1.55),
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Author row
                  Row(children: [
                    ClipOval(
                      child: hasProfileImage
                          ? Image.file(File(profileImagePath!),
                              width: 16, height: 16, fit: BoxFit.cover)
                          : Container(
                              width: 16,
                              height: 16,
                              color: const Color(0xFF7BA591),
                              child: Center(
                                  child: Text(authorInitial,
                                      style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)))),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                        child: Text(entry.authorLabel,
                            style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1410)),
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 6),
                  const _SanctuaryMark(),
                ],
              ),
            ),
          ),
          // Right: header image or gradient
          Expanded(
            flex: 45,
            child: hasImage
                ? Image.file(File(entry.headerImage!), fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D2415), Color(0xFF1A4028)],
                      ),
                    ),
                    child: Center(
                        child: Icon(Icons.nightlight_rounded,
                            size: 32, color: Colors.white.withOpacity(0.15))),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Card 2: Magazine — full-bleed image with gradient overlay ─────────────────

class _MagazineShareCard extends StatelessWidget {
  final PublishedEntry entry;
  final String? profileImagePath;
  const _MagazineShareCard({required this.entry, this.profileImagePath});

  @override
  Widget build(BuildContext context) {
    final hasImage = entry.headerImage != null &&
        entry.headerImage!.isNotEmpty &&
        File(entry.headerImage!).existsSync();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        hasImage
            ? Image.file(File(entry.headerImage!), fit: BoxFit.cover)
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF050A14), Color(0xFF0D1A2E)],
                  ),
                ),
              ),
        // Scrim
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.90)],
              stops: const [0.25, 1.0],
            ),
          ),
        ),
        // Text content anchored at bottom
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.category != null && entry.category!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFF7BA591),
                      borderRadius: BorderRadius.circular(3)),
                  child: Text(
                    entry.category!.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.0),
                  ),
                ),
              Text(
                entry.title.isEmpty ? 'Untitled' : entry.title,
                style: GoogleFonts.crimsonPro(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(children: [
                Text(entry.authorLabel,
                    style: GoogleFonts.inter(
                        fontSize: 8,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                const _SanctuaryMark(light: true),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Auto-fit text: reduces font size until text fits the given constraints ────

class _AutoFitText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final BoxConstraints constraints;

  const _AutoFitText({
    required this.text,
    required this.baseStyle,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    if (constraints.maxHeight.isInfinite || constraints.maxWidth.isInfinite) {
      return Text(text, style: baseStyle);
    }
    double fontSize = baseStyle.fontSize ?? 14.0;
    const double minFontSize = 7.0;
    TextStyle style = baseStyle;
    while (fontSize > minFontSize) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: constraints.maxWidth);
      if (tp.height <= constraints.maxHeight) break;
      fontSize -= 0.5;
      style = baseStyle.copyWith(fontSize: fontSize);
    }
    return Text(text, style: style);
  }
}

// ── Size chip for aspect ratio selector ───────────────────────────────────────

class _SizeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color mutedColor;

  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.aqua.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.aqua.withOpacity(0.5)
                : mutedColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.aqua : mutedColor,
          ),
        ),
      ),
    );
  }
}

// ── Card 3: Quote Story — dark, 1:1 or 3:4, auto-sizing text ─────────────────

class _QuoteShareCard extends StatelessWidget {
  final PublishedEntry entry;
  final String? profileImagePath;
  final String? customText;
  final bool isSquare; // true = 1:1, false = 3:4

  const _QuoteShareCard({
    required this.entry,
    this.profileImagePath,
    this.customText,
    this.isSquare = false,
  });

  @override
  Widget build(BuildContext context) {
    final quote = (customText?.trim().isNotEmpty == true)
        ? customText!
        : entry.preview(240);

    return Container(
      color: const Color(0xFF060C16),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sanctuary branding
          const _SanctuaryMark(light: true),
          SizedBox(height: isSquare ? 14 : 22),
          // Decorative quotation mark
          Text('"',
              style: GoogleFonts.crimsonPro(
                  fontSize: isSquare ? 48 : 64,
                  color: const Color(0xFF7BA591).withOpacity(0.35),
                  height: 0.8)),
          const SizedBox(height: 6),
          // Auto-sized quote text
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) => _AutoFitText(
                text: quote,
                baseStyle: GoogleFonts.crimsonPro(
                    fontSize: isSquare ? 15 : 17,
                    color: const Color(0xFFF0EBE3),
                    height: 1.75),
                constraints: constraints,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 0.5, color: Colors.white.withOpacity(0.12)),
          const SizedBox(height: 10),
          Text('— ${entry.authorLabel}',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF6B6058),
                  letterSpacing: 0.3)),
          if (entry.category != null && entry.category!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              entry.category!.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7BA591),
                  letterSpacing: 1.2),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Card 4: Paper — warm cream, 2:3 portrait, auto-sizing body text ───────────

class _PaperShareCard extends StatelessWidget {
  final PublishedEntry entry;
  final String? profileImagePath;
  final String? customText;

  const _PaperShareCard(
      {required this.entry, this.profileImagePath, this.customText});

  @override
  Widget build(BuildContext context) {
    final bodyText = (customText?.trim().isNotEmpty == true)
        ? customText!
        : entry.preview(200);

    return Container(
      color: const Color(0xFFFEF8EC),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.category != null && entry.category!.isNotEmpty) ...[
            Text(
              entry.category!.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: const Color(0xFF7BA591)),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            entry.title.isEmpty ? 'Untitled' : entry.title,
            style: GoogleFonts.crimsonPro(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1410),
                height: 1.2),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(height: 0.5, color: const Color(0xFFDED9D2)),
          const SizedBox(height: 12),
          // Auto-sized body text to fill remaining card space
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) => _AutoFitText(
                text: bodyText,
                baseStyle: GoogleFonts.crimsonPro(
                    fontSize: 13,
                    color: const Color(0xFF8A8178),
                    height: 1.65),
                constraints: constraints,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Text(entry.authorLabel,
                style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1410))),
            const Spacer(),
            const _SanctuaryMark(),
          ]),
        ],
      ),
    );
  }
}
