import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _hideTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
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
    final email = SupabaseService.instance.userEmail;
    final displayName = email?.split('@').first;

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

  void _handleBookmark() => setState(() => _isBookmarked = !_isBookmarked);

  void _handleShare() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Share link copied — deep-link not yet wired.')),
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
    final isFeatured = communityState.featuredEntryId == _entry.id;
    final featuredLabel = communityState.featuredUntilLabel;
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

            // Feature / Unfeature
            ListTile(
              leading: Icon(
                isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFeatured ? Colors.amber : mutedColor,
              ),
              title: Text(
                isFeatured ? 'Remove from Featured' : 'Feature this entry',
                style: TextStyle(color: textColor),
              ),
              subtitle: isFeatured && featuredLabel != null
                  ? Text(featuredLabel,
                      style: TextStyle(color: mutedColor, fontSize: 12))
                  : Text('Pin to "Featured Reflection" section',
                      style: TextStyle(color: mutedColor, fontSize: 12)),
              onTap: () {
                Navigator.pop(_);
                if (isFeatured) {
                  communityState.clearFeatured();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Featured entry cleared.')),
                  );
                } else {
                  _showFeatureDurationPicker(ctx, communityState);
                }
              },
            ),

            // Brightness (only when local image present)
            if (localImageExists)
              ListTile(
                leading:
                    Icon(Icons.brightness_medium_outlined, color: mutedColor),
                title: Text('Adjust image brightness',
                    style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(_);
                  setState(
                      () => _showBrightnessSlider = !_showBrightnessSlider);
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
                    child: Row(
                      children: [
                        _AvatarCircle(name: _entry.authorLabel, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _entry.authorLabel,
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

            // ── Brightness slider ─────────────────────────────────────────
            if (_showBrightnessSlider && hasHeaderImage)
              Positioned(
                top: topPad + 50,
                left: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.brightness_low_rounded,
                          size: 16, color: Colors.white70),
                      Expanded(
                        child: Slider(
                          value: _imageBrightness,
                          min: 0.3,
                          max: 1.7,
                          onChanged: (v) =>
                              setState(() => _imageBrightness = v),
                          activeColor: Colors.white,
                          inactiveColor: Colors.white30,
                        ),
                      ),
                      const Icon(Icons.brightness_high_rounded,
                          size: 16, color: Colors.white70),
                    ],
                  ),
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
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
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
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
  const _AvatarCircle({required this.name, required this.size});

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
            ...comments.map((c) => _CommentCard(
                  comment: c,
                  isDark: isDark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                )),

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

  const _CommentCard({
    required this.comment,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarCircle(name: comment.authorLabel, size: 30),
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
    );
  }
}
