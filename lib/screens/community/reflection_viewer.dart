import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/reflection.dart';
import '../../models/published_entry.dart';
import '../../models/community_comment.dart';
import '../../models/editor_block.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../providers/community_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/action_pill.dart';
import '../editor/editor_canvas.dart';
import 'community_entry_viewer.dart'
    show SanctuaryShareSheet, CommunityEntryViewer;
import 'reflection_editor_screen.dart';
import 'write_back_sheet.dart';
import '../../models/reflection.dart';
import 'public_profile_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REFLECTION VIEWER
// Displays a published Reflection with "Reflection on" card above content.
// Actions: Appreciate | Respond | Write Back | Share
// Respond = short reply thread (similar to community comments)
// Write Back = create a new reflection on the same origin
// ─────────────────────────────────────────────────────────────────────────────

class ReflectionViewer extends StatefulWidget {
  final Reflection reflection;
  final PublishedEntry? originEntry; // pre-loaded origin, optional

  const ReflectionViewer({
    super.key,
    required this.reflection,
    this.originEntry,
  });

  /// Shared navigation helper — fetches a reflection by id and pushes its
  /// viewer. Used by every "Inspired by" tap across the app so every entry
  /// point lands on the exact same viewer/record instead of a re-built copy.
  static Future<void> openById(
      BuildContext context, String reflectionId) async {
    final wb = await SupabaseService.instance.getWriteBackById(reflectionId);
    if (wb == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('This reflection may have been removed or is private.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final reflection = Reflection.fromMap(wb);
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ReflectionViewer(reflection: reflection)),
    );
  }

  @override
  State<ReflectionViewer> createState() => _ReflectionViewerState();
}

class _ReflectionViewerState extends State<ReflectionViewer> {
  late Reflection _reflection;
  bool _respondOpen = false;
  List<CommunityComment> _replies = [];
  bool _repliesLoading = false;
  final _replyCtrl = TextEditingController();
  bool _replyAnon = false;
  bool _submittingReply = false;
  bool _pillVisible = true;
  Timer? _hideTimer;
  final _scrollCtrl = ScrollController();
  double _readProgress = 0;
  bool _hasClapped = false;
  int _clapCount = 0;
  int _replyCount = 0;

  @override
  void initState() {
    super.initState();
    _reflection = widget.reflection;
    _hasClapped = _reflection.hasClapped;
    _clapCount = _reflection.clapCount;
    _replyCount = _reflection.replyCount;
    _schedulePillHide();
    _scrollCtrl.addListener(_onScroll);
    _loadClapState();
  }

  // Reflection.hasClapped is never populated from the server when a
  // Reflection is built via Reflection.fromMap() — it always defaults to
  // false. This re-hydrates the real clapped state from reflection_claps
  // so the appreciate button doesn't visually "reset" every time you revisit.
  Future<void> _loadClapState() async {
    final clapped = await SupabaseService.instance
        .getClappedReflectionIds([_reflection.id]);
    if (mounted) {
      setState(() => _hasClapped = clapped.contains(_reflection.id));
    }
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _hideTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.hasClients && _scrollCtrl.position.maxScrollExtent > 0) {
      final progress =
          (_scrollCtrl.offset / _scrollCtrl.position.maxScrollExtent)
              .clamp(0.0, 1.0);
      if ((progress - _readProgress).abs() > 0.01) {
        setState(() => _readProgress = progress);
      }
    }
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

  void _handleClap() {
    HapticFeedback.lightImpact();
    final was = _hasClapped;
    setState(() {
      _hasClapped = !was;
      _clapCount = (_clapCount + (was ? -1 : 1)).clamp(0, 999999);
    });
    context.read<CommunityState>().toggleReflectionClap(_reflection.id, was);
  }

  void _toggleRespond() {
    setState(() => _respondOpen = !_respondOpen);
    if (_respondOpen && _replies.isEmpty) _loadReplies();
  }

  Future<void> _loadReplies() async {
    setState(() => _repliesLoading = true);
    final replies =
        await SupabaseService.instance.getReflectionReplies(_reflection.id);
    if (mounted) {
      setState(() {
        _replies = replies;
        _repliesLoading = false;
      });
    }
  }

  Future<void> _submitReply() async {
    final body = _replyCtrl.text.trim();
    if (body.isEmpty || _submittingReply) return;
    setState(() => _submittingReply = true);
    final communityState = context.read<CommunityState>();
    final email = SupabaseService.instance.userEmail;
    final displayName = _replyAnon
        ? null
        : (communityState.profileDisplayName ?? email?.split('@').first);
    final ok = await SupabaseService.instance.addReflectionReply(
      reflectionId: _reflection.id,
      body: body,
      isAnonymous: _replyAnon,
      displayName: displayName,
      profileImageUrl: context.read<CommunityState>().profileImageUrl,
    );
    if (ok && mounted) {
      _replyCtrl.clear();
      setState(() => _replyCount++);
      await _loadReplies();
    }
    if (mounted) setState(() => _submittingReply = false);
  }

  void _showShareSheetForReflection(BuildContext context) {
    final origin = widget.originEntry ??
        PublishedEntry(
          id: _reflection.originEntryId,
          userId: '',
          title: _reflection.originTitle ?? '',
          content: _reflection.originExcerpt ?? '',
          displayName: _reflection.originAuthor,
          headerImage: _reflection.originHeaderImage,
        );
    final dark = context.read<AppState>().isDarkMode;
    final profileImagePath = context.read<CommunityState>().profileImagePath;
    final asPublished = PublishedEntry(
      id: _reflection.id,
      userId: _reflection.userId,
      title: _reflection.title,
      content: _reflection.content,
      blocksJson: _reflection.blocksJson,
      isAnonymous: _reflection.isAnonymous,
      displayName: _reflection.displayName,
      headerImage: _reflection.headerImage,
      category: _reflection.category,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SanctuaryShareSheet(
          entry: asPublished, isDark: dark, profileImagePath: profileImagePath),
    );
  }

  void _openWriteBack() {
    // Build a synthetic PublishedEntry for the origin
    final origin = widget.originEntry ??
        PublishedEntry(
          id: _reflection.originEntryId,
          userId: '',
          title: _reflection.originTitle ?? '',
          content: _reflection.originExcerpt ?? '',
          displayName: _reflection.originAuthor,
          headerImage: _reflection.originHeaderImage,
        );
    WriteBackSheet.show(
      context,
      entry: origin,
      inspirationReflection: _reflection,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = context.watch<AtmosphereState>().backgroundFor(dark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final fontName = context.watch<AppState>().preferredFont;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            // Progress bar
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                height: 2.5,
                width: MediaQuery.of(context).size.width * _readProgress,
                color: AppColors.teal.withOpacity(0.7),
              ),
            ),

            SingleChildScrollView(
              controller: _scrollCtrl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (_) {
                    final hasHeader = _reflection.headerImage != null &&
                        _reflection.headerImage!.isNotEmpty &&
                        File(_reflection.headerImage!).existsSync();
                    if (hasHeader) {
                      return Stack(
                        children: [
                          Image.file(
                            File(_reflection.headerImage!),
                            width: double.infinity,
                            height: 260,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                SizedBox(height: topPad + 60),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 120,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      bg.withOpacity(0.0),
                                      bg.withOpacity(0.55),
                                      bg,
                                    ],
                                    stops: const [0.0, 0.65, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return SizedBox(height: topPad + 60);
                  }),

                  const SizedBox(height: 8),

                  // ── Title ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _reflection.title.isEmpty
                          ? 'Untitled'
                          : _reflection.title,
                      style: GoogleFonts.crimsonPro(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.15,
                          letterSpacing: -0.3),
                    ),
                  ),

                  // ── Author row ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: GestureDetector(
                      onTap: !_reflection.isAnonymous
                          ? () => PublicProfileModal.show(
                                context,
                                userId: _reflection.userId,
                                displayName: _reflection.authorLabel,
                                imageUrl: _reflection.authorImageUrl,
                              )
                          : null,
                      child: Row(
                        children: [
                          _AvatarCircle(
                            name: _reflection.authorLabel,
                            size: 36,
                            imagePath: (_reflection.userId ==
                                    SupabaseService.instance.userId)
                                ? context
                                    .watch<CommunityState>()
                                    .profileImagePath
                                : null,
                            imageUrl: (_reflection.userId ==
                                    SupabaseService.instance.userId)
                                ? null
                                : _reflection.authorImageUrl,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_reflection.authorLabel,
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textColor)),
                                Text(
                                  '${_readTime(_reflection.content)}  ·  ${_formatDate(_reflection.createdAt)}',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: mutedColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Reflection on card — below title/author, never above ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ReflectionOnCard(
                      originEntry: widget.originEntry ??
                          PublishedEntry(
                            id: _reflection.originEntryId,
                            userId: '',
                            title: _reflection.originTitle ?? '',
                            content: _reflection.originExcerpt ?? '',
                            displayName: _reflection.originAuthor,
                            headerImage: _reflection.originHeaderImage,
                          ),
                      inspirationId: _reflection.inspirationId,
                      inspirationAuthor: _reflection.inspirationAuthor,
                      inspirationTitle: _reflection.inspirationTitle,
                      onTapInspiration: (id) =>
                          ReflectionViewer.openById(context, id),
                      dark: dark,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTapOrigin: () async {
                        if (widget.originEntry != null) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CommunityEntryViewer(
                                entry: widget.originEntry!),
                          ));
                        } else {
                          final orig = await SupabaseService.instance
                              .getPublishedEntry(_reflection.originEntryId);
                          if (!mounted) return;
                          if (orig != null) {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => CommunityEntryViewer(entry: orig),
                            ));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'This entry may have been removed by its author.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),

                  // Private reflection notice
                  if (_reflection.isPrivate)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.teal.withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 14, color: AppColors.teal.withOpacity(0.8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Private reflection — only you and the author of '
                              'the original entry can see this. They can appreciate '
                              'and respond, but cannot edit or delete it.',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.teal.withOpacity(0.85),
                                  height: 1.4),
                            ),
                          ),
                        ]),
                      ),
                    ),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                    child: Container(
                      height: 0.5,
                      color:
                          dark ? AppColors.dividerDark : AppColors.dividerLight,
                    ),
                  ),

                  // ── Body ───────────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, botPad + 100),
                    child: _buildBody(dark, fontName, textColor),
                  ),

                  // ── Respond section ─────────────────────────────────
                  if (_respondOpen)
                    _RespondSection(
                      replies: _replies,
                      loading: _repliesLoading,
                      controller: _replyCtrl,
                      isAnon: _replyAnon,
                      submitting: _submittingReply,
                      isDark: dark,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onAnonChanged: (v) => setState(() => _replyAnon = v),
                      onSubmit: _submitReply,
                    ),

                  SizedBox(height: botPad + 80),
                ],
              ),
            ),

            // ── Action pill ─────────────────────────────────────────
            Positioned(
              bottom: botPad + 28,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _pillVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: IgnorePointer(
                  ignoring: !_pillVisible,
                  child: Center(
                    child: ActionPill(
                      hasClapped: _hasClapped,
                      onClap: _handleClap,
                      onRespond: _toggleRespond,
                      respondActive: _respondOpen,
                      onWriteBack:
                          _reflection.isPrivate ? null : _openWriteBack,
                      onShare: _reflection.isPrivate
                          ? null
                          : () => _showShareSheetForReflection(context),
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
    if (_reflection.blocksJson != null && _reflection.blocksJson!.isNotEmpty) {
      // ReflectionHeaderBlock is already rendered as ReflectionOnCard above —
      // filter it from blocks to prevent the double "Reflection on" card.
      final blocks = deserializeBlocks(_reflection.blocksJson!)
          .where((b) => b is! ReflectionHeaderBlock)
          .toList();
      return BlocksReadView(
        blocks: blocks,
        isDark: dark,
        textAlignment: 'left',
        fontName: fontName,
        onTapInspirationReflection: (id) =>
            ReflectionViewer.openById(context, id),
      );
    }
    if (_reflection.content.isNotEmpty) {
      return PenHavenMarkdownBody(data: _reflection.content, selectable: true);
    }
    return const SizedBox.shrink();
  }

  String _readTime(String c) {
    final w = c.trim().split(RegExp(r'\s+')).length;
    return '${(w / 200).ceil().clamp(1, 99)} min read';
  }

  String _formatDate(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays < 1) return 'Today';
    if (d.inDays < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('MMM d, yyyy').format(dt);
  }
}

// ── Respond section (short replies only, inside reflections) ──────────────────

class _RespondSection extends StatelessWidget {
  final List<CommunityComment> replies;
  final bool loading;
  final TextEditingController controller;
  final bool isAnon;
  final bool submitting;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<bool> onAnonChanged;
  final VoidCallback onSubmit;

  const _RespondSection({
    required this.replies,
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Divider(color: divColor, thickness: 0.5),
        const SizedBox(height: 16),
        Text('Responses',
            style: GoogleFonts.crimsonPro(
                fontSize: 22, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 12),
        // Reply input
        Container(
          decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: divColor.withOpacity(0.5))),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: controller,
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
            const SizedBox(height: 6),
            Row(children: [
              GestureDetector(
                onTap: () => onAnonChanged(!isAnon),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isAnon ? AppColors.aqua : Colors.transparent,
                      border: Border.all(
                          color: isAnon
                              ? AppColors.aqua
                              : mutedColor.withOpacity(0.5),
                          width: 1.5),
                    ),
                    child: isAnon
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 5),
                  Text('Anonymous',
                      style:
                          GoogleFonts.inter(fontSize: 11, color: mutedColor)),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: submitting ? null : onSubmit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.aqua.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: AppColors.aqua.withOpacity(0.4))),
                  child: submitting
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.aqua))
                      : Text('Reply',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.aqua)),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (replies.isEmpty)
          Text('No responses yet.',
              style: GoogleFonts.crimsonPro(
                  fontSize: 15, fontStyle: FontStyle.italic, color: mutedColor))
        else
          ...replies.map((r) => _ReplyCard(
              reply: r, textColor: textColor, mutedColor: mutedColor)),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  final CommunityComment reply;
  final Color textColor;
  final Color mutedColor;

  const _ReplyCard(
      {required this.reply, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final isSelf = reply.userId == SupabaseService.instance.userId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => PublicProfileModal.show(
            context,
            userId: reply.userId,
            displayName: reply.authorLabel,
            imageUrl: reply.profileImagePath,
          ),
          child: _AvatarCircle(
            name: reply.authorLabel,
            size: 28,
            imagePath: isSelf
                ? context.watch<CommunityState>().profileImagePath
                : null,
            imageUrl: isSelf ? null : reply.profileImagePath,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(reply.authorLabel,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              const SizedBox(width: 6),
              Text(_ago(reply.createdAt),
                  style: GoogleFonts.inter(fontSize: 11, color: mutedColor)),
            ]),
            const SizedBox(height: 3),
            Text(reply.body,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: textColor.withOpacity(0.85),
                    height: 1.5)),
          ]),
        ),
      ]),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

class _AvatarCircle extends StatelessWidget {
  final String name;
  final double size;
  final String? imagePath;
  final String? imageUrl;

  const _AvatarCircle(
      {required this.name, required this.size, this.imagePath, this.imageUrl});

  Color _color(String n) {
    const colors = [
      Color(0xFF7BA591),
      Color(0xFF5B8DB8),
      Color(0xFFD4820A),
      Color(0xFF9472D4),
      Color(0xFFE87FA0),
      Color(0xFFD44A28),
    ];
    return colors[n.codeUnits.fold(0, (a, b) => a + b) % colors.length];
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
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(imageUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(initial)),
      );
    }
    return _fallback(initial);
  }

  Widget _fallback(String initial) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: _color(name), shape: BoxShape.circle),
        child: Center(
          child: Text(initial,
              style: GoogleFonts.inter(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      );
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
              border:
                  Border.all(color: Colors.white.withOpacity(0.22), width: 0.5),
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
