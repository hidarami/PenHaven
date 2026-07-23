import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/entry.dart';
import '../../models/published_entry.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../providers/community_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import 'community_entry_viewer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COMMUNITY PANEL — Panel 3
// Browse and share entries with the world.
// Panel 0: Library | Panel 1: Story | Panel 2: WorkDesk | Panel 3: Community
// ─────────────────────────────────────────────────────────────────────────────

class CommunityPanel extends StatefulWidget {
  const CommunityPanel({super.key});

  @override
  State<CommunityPanel> createState() => _CommunityPanelState();
}

class _CommunityPanelState extends State<CommunityPanel>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _initialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    final state = context.read<CommunityState>();
    await state.loadFeed();
    if (SupabaseService.instance.isAuthenticated) {
      await state.loadMyPosts();
    }
  }

  void _openPublishSheet() {
    if (!SupabaseService.instance.isAuthenticated) {
      _showAuthSheet();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PublishSheet(
        entries: context.read<AppState>().currentEntries,
        onPublish: (entry, isAnon, displayName) async {
          Navigator.pop(context);
          final ok = await context.read<CommunityState>().publishEntry(
            entry: entry,
            isAnonymous: isAnon,
            displayName: displayName,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? 'Published to community.' : 'Failed to publish.'),
            ));
            if (ok) _tabController.animateTo(1);
          }
        },
      ),
    );
  }

  void _showAuthSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AuthSheet(
        onSuccess: () {
          Navigator.pop(context);
          context.read<CommunityState>().loadMyPosts();
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dark = context.watch<AppState>().isDarkMode;
    final bg = context.watch<AtmosphereState>().backgroundFor(dark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final divColor = dark ? AppColors.dividerDark : AppColors.dividerLight;
    final topPadding = MediaQuery.of(context).padding.top;
    final isAuth = SupabaseService.instance.isAuthenticated;
    final isConfigured = SupabaseService.instance.isSupabaseConfigured;

    if (!isConfigured) {
      return _SetupRequired(isDark: dark, mutedColor: mutedColor, textColor: textColor);
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPadding > 0 ? 60 : 80),

          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community',
                        style: GoogleFonts.crimsonPro(
                          fontSize: 28, fontWeight: FontWeight.w700, color: textColor,
                        ),
                      ),
                      Text(
                        'Words from the sanctuary.',
                        style: GoogleFonts.inter(
                          fontSize: 13, color: mutedColor, fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                // Auth / Profile button
                GestureDetector(
                  onTap: isAuth ? _showProfileOptions : _showAuthSheet,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: isAuth ? AppColors.aqua.withOpacity(0.15) : (dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAuth ? Icons.person_rounded : Icons.person_outline_rounded,
                      size: 18,
                      color: isAuth ? AppColors.aqua : mutedColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Publish button
                GestureDetector(
                  onTap: _openPublishSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.aqua.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.aqua.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.upload_rounded, size: 14, color: AppColors.aqua),
                        const SizedBox(width: 5),
                        Text(
                          'Publish',
                          style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.aqua,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Tabs ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tabController,
              tabs: const [Tab(text: 'Feed'), Tab(text: 'Mine')],
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
              labelColor: AppColors.aqua,
              unselectedLabelColor: mutedColor,
              indicatorColor: AppColors.aqua,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
            ),
          ),

          Divider(color: divColor, thickness: 0.5, height: 0),

          // ── Content ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FeedTab(isDark: dark, textColor: textColor, mutedColor: mutedColor),
                _MyPostsTab(isDark: dark, textColor: textColor, mutedColor: mutedColor, onAuthRequired: _showAuthSheet),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileOptions() {
    final dark = context.read<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = AppColors.readableText(bg);
    final email = SupabaseService.instance.userEmail ?? 'Signed in';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, color: AppColors.aqua, size: 20),
                  const SizedBox(width: 12),
                  Text(email, style: GoogleFonts.inter(fontSize: 14, color: textColor)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: Text('Sign Out', style: GoogleFonts.inter(fontSize: 14, color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                await SupabaseService.instance.signOut();
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Feed tab ──────────────────────────────────────────────────────────────────

class _FeedTab extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color mutedColor;

  const _FeedTab({required this.isDark, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CommunityState>();

    if (state.feedLoading && state.feed.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.feed.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 52, color: mutedColor.withOpacity(0.3)),
            const SizedBox(height: 14),
            Text(
              'Nothing here yet.\nBe the first to share.',
              textAlign: TextAlign.center,
              style: GoogleFonts.crimsonPro(
                fontSize: 18, fontStyle: FontStyle.italic, color: mutedColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<CommunityState>().loadFeed(refresh: true),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
        itemCount: state.feed.length + (state.hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == state.feed.length) {
            // Load more trigger
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<CommunityState>().loadFeed();
            });
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _EntryCard(
            entry: state.feed[i],
            isDark: isDark,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
              builder: (_) => CommunityEntryViewer(entry: state.feed[i]),
            )),
            onClap: () => context.read<CommunityState>().toggleClap(state.feed[i].id),
          );
        },
      ),
    );
  }
}

// ── My posts tab ──────────────────────────────────────────────────────────────

class _MyPostsTab extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onAuthRequired;

  const _MyPostsTab({
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onAuthRequired,
  });

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.instance.isAuthenticated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 48, color: mutedColor.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'Sign in to view\nyour published entries.',
                textAlign: TextAlign.center,
                style: GoogleFonts.crimsonPro(
                  fontSize: 18, fontStyle: FontStyle.italic, color: mutedColor,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onAuthRequired,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.aqua.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.aqua.withOpacity(0.4)),
                  ),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.aqua,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final state = context.watch<CommunityState>();

    if (state.myPostsLoading && state.myPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.myPosts.isEmpty) {
      return Center(
        child: Text(
          "You haven't published anything yet.",
          style: GoogleFonts.crimsonPro(
            fontSize: 16, fontStyle: FontStyle.italic, color: mutedColor,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<CommunityState>().loadMyPosts(),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
        itemCount: state.myPosts.length,
        itemBuilder: (ctx, i) => _EntryCard(
          entry: state.myPosts[i],
          isDark: isDark,
          textColor: textColor,
          mutedColor: mutedColor,
          showDelete: true,
          onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
            builder: (_) => CommunityEntryViewer(entry: state.myPosts[i]),
          )),
          onClap: () {},
          onDelete: () => _confirmDelete(ctx, context.read<CommunityState>(), state.myPosts[i].id),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, CommunityState state, String entryId) {
    showDialog<void>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Remove from community?'),
        content: const Text('This will unpublish your entry. Your local copy is unaffected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              state.deletePost(entryId);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Entry card ────────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  final PublishedEntry entry;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;
  final VoidCallback onClap;
  final VoidCallback? onDelete;
  final bool showDelete;

  const _EntryCard({
    required this.entry,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
    required this.onClap,
    this.onDelete,
    this.showDelete = false,
  });

  Color _avatarColor(String n) {
    const colors = [
      Color(0xFF7BA591), Color(0xFF5B8DB8), Color(0xFFD4820A),
      Color(0xFF9472D4), Color(0xFFE87FA0), Color(0xFFD44A28),
      Color(0xFF5A8A5C),
    ];
    final hash = n.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final divColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final initial = entry.authorLabel.isNotEmpty ? entry.authorLabel[0].toUpperCase() : '?';
    final avatarColor = _avatarColor(entry.authorLabel);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.authorLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w500, color: textColor,
                        ),
                      ),
                    ),
                    Text(
                      _relativeDate(entry.createdAt),
                      style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                    ),
                    if (showDelete && onDelete != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(Icons.close_rounded, size: 16, color: mutedColor.withOpacity(0.5)),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // Title
                Text(
                  entry.title.isEmpty ? 'Untitled' : entry.title,
                  style: GoogleFonts.crimsonPro(
                    fontSize: 20, fontWeight: FontWeight.w700, color: textColor, height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Preview
                if (entry.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.preview(),
                    style: GoogleFonts.inter(
                      fontSize: 13, color: mutedColor, height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Clap + comment row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onClap();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.hasClapped
                                ? Icons.volunteer_activism_rounded
                                : Icons.volunteer_activism_outlined,
                            size: 16,
                            color: entry.hasClapped ? AppColors.aqua : mutedColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.clapCount}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: entry.hasClapped ? AppColors.aqua : mutedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 14, color: mutedColor),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.commentCount}',
                          style: GoogleFonts.inter(fontSize: 12, color: mutedColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: divColor, thickness: 0.5, height: 0, indent: 24, endIndent: 24),
        ],
      ),
    );
  }
}

// ── Publish sheet ─────────────────────────────────────────────────────────────

class _PublishSheet extends StatefulWidget {
  final List<Entry> entries;
  final void Function(Entry, bool isAnon, String? displayName) onPublish;

  const _PublishSheet({required this.entries, required this.onPublish});

  @override
  State<_PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends State<_PublishSheet> {
  Entry? _selected;
  bool _isAnon = false;
  late TextEditingController _nameCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
    _nameCtrl = TextEditingController();
  }

  Future<void> _loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('communityDisplayName');
    if (stored != null && mounted) {
      _nameCtrl.text = stored;
    } else {
      final email = SupabaseService.instance.userEmail;
      if (email != null && mounted) {
        _nameCtrl.text = email.split('@').first;
      }
    }
  }

  Future<void> _saveDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('communityDisplayName', name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final divColor = dark ? AppColors.dividerDark : AppColors.dividerLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, sc) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: mutedColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Publish to Community',
                style: GoogleFonts.crimsonPro(
                  fontSize: 24, fontWeight: FontWeight.w700, color: textColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Text(
                'Choose an entry from your current story to share.',
                style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
              ),
            ),
            Divider(color: divColor, thickness: 0.5, height: 0),

            // Entry list
            Expanded(
              child: widget.entries.isEmpty
                  ? Center(
                      child: Text(
                        'No entries in current story.',
                        style: GoogleFonts.crimsonPro(
                          fontSize: 16, fontStyle: FontStyle.italic, color: mutedColor,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: sc,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: widget.entries.length,
                      itemBuilder: (_, i) {
                        final e = widget.entries[i];
                        final sel = _selected?.id == e.id;
                        return GestureDetector(
                          onTap: () => setState(() => _selected = e),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.aqua.withOpacity(0.1)
                                  : (dark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel ? AppColors.aqua : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.title.isEmpty ? 'Untitled' : e.title,
                                        style: GoogleFonts.crimsonPro(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: sel ? AppColors.aqua : textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        e.preview(80),
                                        style: GoogleFonts.inter(fontSize: 12, color: mutedColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (sel)
                                  const Icon(Icons.check_circle_rounded, color: AppColors.aqua, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Options + publish button
            Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: divColor, thickness: 0.5),
                  const SizedBox(height: 12),

                  // Display name
                  if (!_isAnon) ...[
                    Text('Your name', style: GoogleFonts.inter(fontSize: 11, color: mutedColor, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _nameCtrl,
                        style: GoogleFonts.inter(fontSize: 14, color: textColor),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          hintText: 'Display name...',
                          hintStyle: GoogleFonts.inter(fontSize: 14, color: mutedColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Anonymous toggle
                  GestureDetector(
                    onTap: () => setState(() => _isAnon = !_isAnon),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: _isAnon ? AppColors.aqua : Colors.transparent,
                            border: Border.all(color: _isAnon ? AppColors.aqua : mutedColor, width: 1.5),
                          ),
                          child: _isAnon
                              ? const Icon(Icons.check, size: 13, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Publish anonymously',
                          style: GoogleFonts.inter(fontSize: 14, color: textColor),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Publish button
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: (_selected == null || _loading)
                          ? null
                          : () async {
                              setState(() => _loading = true);
                              final name = _nameCtrl.text.trim();
                              if (!_isAnon && name.isNotEmpty) {
                                await _saveDisplayName(name);
                              }
                              widget.onPublish(
                                _selected!,
                                _isAnon,
                                _isAnon ? null : name.isEmpty ? null : name,
                              );
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _selected != null
                              ? AppColors.aqua.withOpacity(0.12)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selected != null
                                ? AppColors.aqua.withOpacity(0.5)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.aqua),
                                )
                              : Text(
                                  _selected == null ? 'Select an entry first' : 'Publish to Community',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _selected != null ? AppColors.aqua : mutedColor,
                                  ),
                                ),
                        ),
                      ),
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

// ── Auth sheet ────────────────────────────────────────────────────────────────

class _AuthSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const _AuthSheet({required this.onSuccess});

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    String? err;
    if (_tab.index == 0) {
      err = await SupabaseService.instance.signInWithEmail(email, pass);
    } else {
      err = await SupabaseService.instance.signUpWithEmail(email, pass);
    }

    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _loading = false; });
    } else {
      setState(() => _loading = false);
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: mutedColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 20),
            Text(
              'Join the community',
              style: GoogleFonts.crimsonPro(
                fontSize: 26, fontWeight: FontWeight.w700, color: textColor,
              ),
            ),
            Text(
              'Sign in to publish, clap, and comment.',
              style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
            ),
            const SizedBox(height: 20),
            TabBar(
              controller: _tab,
              tabs: const [Tab(text: 'Sign In'), Tab(text: 'Sign Up')],
              labelColor: AppColors.aqua,
              unselectedLabelColor: mutedColor,
              indicatorColor: AppColors.aqua,
              dividerColor: Colors.transparent,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
            ),
            const SizedBox(height: 16),
            _InputField(controller: _emailCtrl, hint: 'Email', isDark: dark, textColor: textColor, mutedColor: mutedColor),
            const SizedBox(height: 10),
            _InputField(controller: _passCtrl, hint: 'Password', isDark: dark, textColor: textColor, mutedColor: mutedColor, obscure: true),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _loading ? null : _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.aqua.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.aqua.withOpacity(0.5)),
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.aqua),
                          )
                        : Text(
                            'Continue',
                            style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.aqua,
                            ),
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
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final bool obscure;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.inter(fontSize: 14, color: textColor),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 14, color: mutedColor),
        ),
      ),
    );
  }
}

// ── Setup required ────────────────────────────────────────────────────────────

class _SetupRequired extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color mutedColor;

  const _SetupRequired({required this.isDark, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, topPadding + 80, 32, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community',
              style: GoogleFonts.crimsonPro(
                fontSize: 28, fontWeight: FontWeight.w700, color: textColor,
              ),
            ),
            const SizedBox(height: 32),
            Icon(Icons.cloud_off_rounded, size: 48, color: mutedColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'Supabase not configured.',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Set your Supabase URL and anon key in\nlib/services/supabase_service.dart\nto enable community features.',
              style: GoogleFonts.inter(fontSize: 13, color: mutedColor, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}