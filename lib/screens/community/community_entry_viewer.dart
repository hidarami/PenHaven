import 'dart:async';
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
import '../editor/editor_canvas.dart';
import '../../widgets/shared_widgets.dart';

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
  bool _barVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _scheduleHide();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (_commentsLoading) return;
    setState(() => _commentsLoading = true);
    final comments = await context.read<CommunityState>().getComments(_entry.id);
    if (mounted) setState(() { _comments = comments; _commentsLoading = false; });
  }

  void _toggleComments() {
    setState(() => _commentsOpen = !_commentsOpen);
    if (_commentsOpen && _comments.isEmpty) _loadComments();
  }

  Future<void> _submitComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _submittingComment) return;

    if (!SupabaseService.instance.isAuthenticated) {
      _showAuthRequired();
      return;
    }

    setState(() => _submittingComment = true);
    final prefs = await _getDisplayName();
    final ok = await context.read<CommunityState>().addComment(
      entryId: _entry.id,
      body: body,
      isAnonymous: _commentAnon,
      displayName: prefs,
    );

    if (ok && mounted) {
      _commentCtrl.clear();
      _entry.commentCount++;
      await _loadComments();
    }
    if (mounted) setState(() => _submittingComment = false);
  }

  Future<String?> _getDisplayName() async {
    final prefs = await _getStoredDisplayName();
    return prefs;
  }

  Future<String?> _getStoredDisplayName() async {
    // Could use SharedPreferences here; for simplicity, use email prefix
    final email = SupabaseService.instance.userEmail;
    if (email == null) return null;
    return email.split('@').first;
  }

  void _showAuthRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to interact with the community.')),
    );
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _barVisible = false);
    });
  }

  void _onTapScreen() {
    if (!_barVisible) {
      setState(() => _barVisible = true);
      _scheduleHide();
    }
  }

  void _dismissBar() {
    _hideTimer?.cancel();
    setState(() => _barVisible = false);
  }

  void _handleClap() {
    if (!SupabaseService.instance.isAuthenticated) {
      _showAuthRequired();
      return;
    }
    HapticFeedback.lightImpact();
    context.read<CommunityState>().toggleClap(_entry.id);
    setState(() {
      final wasClapped = _entry.hasClapped;
      _entry.hasClapped = !wasClapped;
      _entry.clapCount = (_entry.clapCount + (wasClapped ? -1 : 1)).clamp(0, 999999);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = context.watch<AtmosphereState>().backgroundFor(dark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final fontName = context.watch<AppState>().preferredFont;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
        },
        onTap: _onTapScreen,
        child: Stack(
          children: [
            // ── Scrollable content ──────────────────────────────────────
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left_rounded,
                                size: 28, color: mutedColor),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        _AvatarCircle(name: _entry.authorLabel, size: 32),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_entry.authorLabel,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textColor)),
                            Text(_formatDate(_entry.createdAt),
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: mutedColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Text(
                      _entry.title.isEmpty ? 'Untitled' : _entry.title,
                      style: GoogleFonts.crimsonPro(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.15),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(
                        color: dark
                            ? AppColors.dividerDark
                            : AppColors.dividerLight,
                        thickness: 0.5),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        24, 16, 24, bottomPad + 100),
                    child: _buildBody(dark, fontName, textColor),
                  ),
                ),
                if (_commentsOpen)
                  SliverToBoxAdapter(
                    child: _CommentsSection(
                      comments: _comments,
                      loading: _commentsLoading,
                      controller: _commentCtrl,
                      isAnon: _commentAnon,
                      submitting: _submittingComment,
                      isDark: dark,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onAnonChanged: (v) =>
                          setState(() => _commentAnon = v),
                      onSubmit: _submitComment,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),

            // ── Floating glassmorphic pill ───────────────────────────────
            Positioned(
              bottom: bottomPad + 24,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _barVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  child: IgnorePointer(
                    ignoring: !_barVisible,
                    child: _GlassPill(
                      entry: _entry,
                      commentsOpen: _commentsOpen,
                      onClap: _handleClap,
                      onComment: _toggleComments,
                      onDismiss: _dismissBar,
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

  Widget _buildBody(bool dark, String fontName, Color textColor) {
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

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(dt);
  }
}

// ── Glassmorphic pill ─────────────────────────────────────────────────────────

class _GlassPill extends StatelessWidget {
  final PublishedEntry entry;
  final bool commentsOpen;
  final VoidCallback onClap;
  final VoidCallback onComment;
  final VoidCallback onDismiss;

  const _GlassPill({
    required this.entry,
    required this.commentsOpen,
    required this.onClap,
    required this.onComment,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Ghost white — not dynamic, works on any background
    const ghostColor = Color(0xDDFFFFFF);
    const ghostMuted = Color(0x99FFFFFF);

    return GestureDetector(
      onTap: onDismiss,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Clap ──────────────────────────────────────────────
                GestureDetector(
                  onTap: onClap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        entry.hasClapped
                            ? Icons.volunteer_activism_rounded
                            : Icons.volunteer_activism_outlined,
                        size: 20,
                        color: ghostColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${entry.clapCount}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ghostColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Hairline divider ───────────────────────────────────
                Container(
                  width: 0.5,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: ghostMuted,
                ),

                // ── Comments ───────────────────────────────────────────
                GestureDetector(
                  onTap: onComment,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        commentsOpen
                            ? Icons.chat_bubble_rounded
                            : Icons.chat_bubble_outline_rounded,
                        size: 18,
                        color: ghostColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${entry.commentCount}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ghostColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.03);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: divColor, thickness: 0.5),
          const SizedBox(height: 16),
          Text(
            'Comments',
            style: GoogleFonts.crimsonPro(
              fontSize: 22, fontWeight: FontWeight.w700, color: textColor,
            ),
          ),
          const SizedBox(height: 16),

          // Comment input
          Container(
            decoration: BoxDecoration(
              color: cardBg, borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 3,
                  minLines: 1,
                  style: GoogleFonts.inter(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Add a comment...',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: mutedColor),
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => onAnonChanged(!isAnon),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 16, height: 16,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: isAnon ? AppColors.aqua : Colors.transparent,
                              border: Border.all(
                                color: isAnon ? AppColors.aqua : mutedColor,
                                width: 1.5,
                              ),
                            ),
                            child: isAnon
                                ? const Icon(Icons.check, size: 11, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Post anonymously',
                            style: GoogleFonts.inter(fontSize: 12, color: mutedColor),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: submitting ? null : onSubmit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: submitting
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 1.5),
                              )
                            : Text(
                                'Post',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
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

          const SizedBox(height: 16),

          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No comments yet. Start the conversation.',
                style: GoogleFonts.crimsonPro(
                  fontSize: 16, fontStyle: FontStyle.italic, color: mutedColor,
                ),
              ),
            )
          else
            ...comments.map((c) => _CommentTile(
                  comment: c,
                  isDark: isDark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                )),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommunityComment comment;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;

  const _CommentTile({
    required this.comment,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(comment.createdAt);
    String ago;
    if (diff.inMinutes < 60) {
      ago = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      ago = '${diff.inHours}h ago';
    } else {
      ago = '${diff.inDays}d ago';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarCircle(name: comment.authorLabel, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600, color: textColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ago,
                      style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.body,
                  style: GoogleFonts.inter(fontSize: 14, color: textColor, height: 1.5),
                ),
              ],
            ),
          ),
        ],
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
      Color(0xFF7BA591), Color(0xFF5B8DB8), Color(0xFFD4820A),
      Color(0xFF9472D4), Color(0xFFE87FA0), Color(0xFFD44A28),
      Color(0xFF5A8A5C), Color(0xFF1B9B8D),
    ];
    final hash = n.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _color(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: size * 0.45,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}