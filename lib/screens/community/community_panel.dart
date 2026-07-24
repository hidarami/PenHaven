import 'dart:io';
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
import '../../services/image_service.dart';
import '../../services/permission_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import 'community_entry_viewer.dart';

// ── Category constants ────────────────────────────────────────────────────────

const _kCategories = [
  'All',
  'Faith',
  'Identity',
  'Philosophy',
  'Dreams',
  'Society',
  'Personal',
  'Reflections',
];

const _kCategoryIcons = <String, IconData>{
  'All': Icons.apps_rounded,
  'Faith': Icons.nightlight_round,
  'Identity': Icons.person_outline_rounded,
  'Philosophy': Icons.auto_stories_outlined,
  'Dreams': Icons.cloud_outlined,
  'Society': Icons.people_outline_rounded,
  'Personal': Icons.favorite_border_rounded,
  'Reflections': Icons.self_improvement_outlined,
};

Color _categoryColor(String? cat) {
  switch ((cat ?? '').toLowerCase()) {
    case 'faith':
    case 'religion':
      return const Color(0xFF4A8A70);
    case 'identity':
      return const Color(0xFF5B8DB8);
    case 'philosophy':
      return const Color(0xFFD4820A);
    case 'dreams':
      return const Color(0xFF6A5AB8);
    case 'society':
      return const Color(0xFFD44A28);
    case 'personal':
      return const Color(0xFFE87FA0);
    case 'reflections':
      return const Color(0xFF9472D4);
    default:
      return AppColors.aqua;
  }
}

List<Color> _entryGradient(PublishedEntry entry) {
  final cat = (entry.category ?? '').toLowerCase();
  switch (cat) {
    case 'faith':
    case 'religion':
      return [const Color(0xFF0D2415), const Color(0xFF1A4028)];
    case 'identity':
      return [const Color(0xFF0D1530), const Color(0xFF1A2550)];
    case 'philosophy':
      return [const Color(0xFF2A1508), const Color(0xFF503018)];
    case 'dreams':
      return [const Color(0xFF080D20), const Color(0xFF121A40)];
    case 'society':
      return [const Color(0xFF280A08), const Color(0xFF501510)];
    case 'personal':
      return [const Color(0xFF280A18), const Color(0xFF501530)];
    case 'reflections':
      return [const Color(0xFF180A28), const Color(0xFF301550)];
    default:
      final gradients = [
        [const Color(0xFF0D1A28), const Color(0xFF1A3045)],
        [const Color(0xFF1A0D28), const Color(0xFF351A45)],
        [const Color(0xFF0D2018), const Color(0xFF1A3A28)],
        [const Color(0xFF201A0D), const Color(0xFF403520)],
      ];
      final idx =
          (entry.title.length + entry.authorLabel.length) % gradients.length;
      return [gradients[idx][0], gradients[idx][1]];
  }
}

String _readTime(String content) {
  if (content.isEmpty) return '1 min read';
  final words =
      content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  return '${(words / 200).ceil().clamp(1, 99)} min read';
}

String _greetingText() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 21) return 'Good evening';
  return 'Good night';
}

String _relativeDate(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return 'Just now';
  if (diff.inHours < 24) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(dt);
}

Color _avatarColor(String n) {
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

// ─────────────────────────────────────────────────────────────────────────────
// COMMUNITY PANEL
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
  String _selectedCategory = 'All';
  String? _displayName;
  String? _profileImagePath;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _displayName = prefs.getString('communityDisplayName');
        _profileImagePath = prefs.getString('communityProfileImage');
      });
    }
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    final state = context.read<CommunityState>();
    await state.loadProfile();
    await state.loadFeatured(); // Load pinned featured entry state
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
        onPublish: (entry, isAnon, displayName, category) async {
          Navigator.pop(context);
          final ok = await context.read<CommunityState>().publishEntry(
                entry: entry,
                isAnonymous: isAnon,
                displayName: displayName,
                category: category,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(ok ? 'Published to community.' : 'Failed to publish.'),
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
          _loadProfile();
          context.read<CommunityState>().loadMyPosts();
          setState(() {});
        },
      ),
    );
  }

  void _showProfileSheet() {
    final dark = context.read<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProfileSheet(
        email: SupabaseService.instance.userEmail ?? '',
        isDark: dark,
        currentName: _displayName,
        currentImagePath: _profileImagePath,
        onSignOut: () async {
          Navigator.pop(context);
          await SupabaseService.instance.signOut();
          setState(() {});
        },
        onProfileUpdated: () {
          Navigator.pop(context);
          context.read<CommunityState>().loadProfile();
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
    final communityState = context.watch<CommunityState>();
    final displayName = communityState.profileDisplayName;
    final profileImagePath = communityState.profileImagePath;
    final isAuth = SupabaseService.instance.isAuthenticated;

    if (!SupabaseService.instance.isSupabaseConfigured) {
      return _SetupRequired(
          isDark: dark, mutedColor: mutedColor, textColor: textColor);
    }

    final username = displayName ??
        (SupabaseService.instance.userEmail?.split('@').first ?? 'there');

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPadding > 0 ? 60 : 80),

          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sanctuary',
                        style: GoogleFonts.crimsonPro(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_greetingText()}, $username.',
                        style:
                            GoogleFonts.inter(fontSize: 13, color: mutedColor),
                      ),
                      Text(
                        'What would you like to read today?',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: mutedColor.withOpacity(0.65)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Publish + profile row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _openPublishSheet,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: dark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.black.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit_outlined,
                            size: 16, color: mutedColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: isAuth ? _showProfileSheet : _showAuthSheet,
                      child: _ProfileAvatar(
                        imagePath: profileImagePath,
                        name: username,
                        size: 38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Tabs ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'For You'),
                Tab(text: 'Recent'),
                Tab(text: 'Mine')
              ],
              labelStyle:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
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
                _ForYouTab(
                  isDark: dark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  selectedCategory: _selectedCategory,
                  onCategoryChanged: (cat) =>
                      setState(() => _selectedCategory = cat),
                  onViewAll: () => _tabController.animateTo(1),
                  onPublish: _openPublishSheet,
                ),
                _RecentTab(
                  isDark: dark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onPublish: _openPublishSheet,
                ),
                _MyPostsTab(
                  isDark: dark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onAuthRequired: _showAuthSheet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE AVATAR — properly loads and displays image
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  final String? imagePath;
  final String name;
  final double size;

  const _ProfileAvatar({
    required this.imagePath,
    required this.name,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _avatarColor(name);

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
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.45), width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOR YOU TAB — Sanctuary-style home
// ─────────────────────────────────────────────────────────────────────────────

class _ForYouTab extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onViewAll;
  final VoidCallback onPublish;

  const _ForYouTab({
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onViewAll,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CommunityState>();
    final feed = state.feed;

    if (state.feedLoading && feed.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = selectedCategory == 'All'
        ? feed
        : feed
            .where((e) =>
                (e.category ?? '').toLowerCase() ==
                selectedCategory.toLowerCase())
            .toList();

    // Use pinned featured entry if still valid; otherwise fall back to first
    final featuredId = state.featuredEntryId;
    PublishedEntry? featured;
    List<PublishedEntry> recentItems;
    if (featuredId != null) {
      try {
        featured = filtered.firstWhere((e) => e.id == featuredId);
        recentItems =
            filtered.where((e) => e.id != featuredId).take(8).toList();
      } catch (_) {
        featured = filtered.isNotEmpty ? filtered.first : null;
        recentItems = filtered.length > 1
            ? filtered.skip(1).take(8).toList()
            : <PublishedEntry>[];
      }
    } else {
      featured = filtered.isNotEmpty ? filtered.first : null;
      recentItems = filtered.length > 1
          ? filtered.skip(1).take(8).toList()
          : <PublishedEntry>[];
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Category chips
        SliverToBoxAdapter(
          child: _CategoryChipsRow(
            selectedCategory: selectedCategory,
            onCategoryChanged: onCategoryChanged,
            isDark: isDark,
            mutedColor: mutedColor,
          ),
        ),

        if (feed.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_outlined,
                      size: 52, color: mutedColor.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No entries yet.\nBe the first to share.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.crimsonPro(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: mutedColor.withOpacity(0.6),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: onPublish,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.aqua.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.aqua.withOpacity(0.4)),
                      ),
                      child: Text('Share Something',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.aqua)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // "Featured Reflection" label
          if (featured != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Text('Featured Reflection',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
              ),
            ),

          // Featured card
          if (featured != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _FeaturedCard(
                  entry: featured,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => CommunityEntryViewer(entry: featured!)),
                  ),
                ),
              ),
            ),

          // "Recently Shared" header
          if (recentItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recently Shared',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor)),
                    GestureDetector(
                      onTap: onViewAll,
                      child: Text('View all',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.aqua,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),

          // Recently shared list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final entry = recentItems[i];
                return _CompactEntryCard(
                  entry: entry,
                  isDark: isDark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onTap: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                        builder: (_) => CommunityEntryViewer(entry: entry)),
                  ),
                  onAppreciate: () =>
                      ctx.read<CommunityState>().toggleClap(entry.id),
                );
              },
              childCount: recentItems.length,
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY CHIPS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChipsRow extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final bool isDark;
  final Color mutedColor;

  const _CategoryChipsRow({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.isDark,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
        itemCount: _kCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _kCategories[i];
          final isSelected = cat == selectedCategory;
          final icon = _kCategoryIcons[cat] ?? Icons.label_outline;
          final color = cat == 'All' ? AppColors.aqua : _categoryColor(cat);

          return GestureDetector(
            onTap: () => onCategoryChanged(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.14)
                    : (isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.black.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isSelected ? color.withOpacity(0.5) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: isSelected ? color : mutedColor),
                  const SizedBox(width: 5),
                  Text(
                    cat,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? color : mutedColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURED CARD — large card with image/gradient overlay
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final PublishedEntry entry;
  final VoidCallback onTap;

  const _FeaturedCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = entry.headerImage != null &&
        entry.headerImage!.isNotEmpty &&
        File(entry.headerImage!).existsSync();
    final gradient = _entryGradient(entry);
    final catColor = _categoryColor(entry.category);
    final author = entry.authorLabel;
    final authorColor = _avatarColor(author);
    final authorInitial = author.isNotEmpty ? author[0].toUpperCase() : '?';

    final cardH = ((MediaQuery.of(context).size.width - 48) * 11 / 16)
        .clamp(220.0, 340.0);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: cardH,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              // Background
              hasImage
                  ? Image.file(File(entry.headerImage!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _GradientBox(gradient: gradient))
                  : _GradientBox(gradient: gradient),

              // Gradient overlay — dark at bottom
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.82),
                    ],
                    stops: const [0.0, 0.38, 1.0],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Category badge
                    if (entry.category != null && entry.category!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: catColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.category!.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ),

                    // Title
                    Text(
                      entry.title.isEmpty ? 'Untitled' : entry.title,
                      style: GoogleFonts.crimsonPro(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Preview
                    if (entry.content.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.preview(90),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.72),
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Author + Read button
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: authorColor, shape: BoxShape.circle),
                          child: Center(
                            child: Text(authorInitial,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(author,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                              Text(_readTime(entry.content),
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.6))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text('Read',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientBox extends StatelessWidget {
  final List<Color> gradient;
  const _GradientBox({required this.gradient});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPACT ENTRY CARD — Recently Shared style (image left, text right)
// ─────────────────────────────────────────────────────────────────────────────

class _CompactEntryCard extends StatelessWidget {
  final PublishedEntry entry;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;
  final VoidCallback onAppreciate;

  const _CompactEntryCard({
    required this.entry,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
    required this.onAppreciate,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = entry.headerImage != null &&
        entry.headerImage!.isNotEmpty &&
        File(entry.headerImage!).existsSync();
    final gradient = _entryGradient(entry);
    final catColor = _categoryColor(entry.category);
    final author = entry.authorLabel;
    final authorColor = _avatarColor(author);
    final authorInitial = author.isNotEmpty ? author[0].toUpperCase() : '?';
    final divColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 86,
                    height: 86,
                    child: hasImage
                        ? Image.file(File(entry.headerImage!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _GradientBox(gradient: gradient))
                        : _GradientBox(gradient: gradient),
                  ),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (entry.category != null &&
                              entry.category!.isNotEmpty)
                            Text(
                              entry.category!.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: catColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          const Spacer(),
                          Text(_relativeDate(entry.createdAt),
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: mutedColor)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.title.isEmpty ? 'Untitled' : entry.title,
                        style: GoogleFonts.crimsonPro(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.content.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          entry.preview(65),
                          style: GoogleFonts.inter(
                              fontSize: 12, color: mutedColor, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                                color: authorColor, shape: BoxShape.circle),
                            child: Center(
                              child: Text(authorInitial,
                                  style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(author,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: mutedColor)),
                          const SizedBox(width: 5),
                          Text(_readTime(entry.content),
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: mutedColor.withOpacity(0.6))),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onAppreciate();
                            },
                            child: Icon(
                              entry.hasClapped
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 15,
                              color: entry.hasClapped
                                  ? const Color(0xFFE87FA0)
                                  : mutedColor.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.bookmark_border_rounded,
                              size: 15, color: mutedColor.withOpacity(0.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(
            color: divColor,
            thickness: 0.5,
            height: 0,
            indent: 24,
            endIndent: 24),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT TAB — Community feed (middle panel style)
// ─────────────────────────────────────────────────────────────────────────────

class _RecentTab extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onPublish;

  const _RecentTab({
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onPublish,
  });

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
            Icon(Icons.auto_stories_outlined,
                size: 52, color: mutedColor.withOpacity(0.3)),
            const SizedBox(height: 14),
            Text(
              'Nothing shared yet.\nBe the first.',
              textAlign: TextAlign.center,
              style: GoogleFonts.crimsonPro(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: mutedColor.withOpacity(0.6),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onPublish,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.aqua.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.aqua.withOpacity(0.4)),
                ),
                child: Text('Publish Something',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.aqua)),
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<CommunityState>().loadFeed();
            });
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _FeedEntryCard(
            entry: state.feed[i],
            isDark: isDark,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () => Navigator.of(ctx).push(
              MaterialPageRoute(
                  builder: (_) => CommunityEntryViewer(entry: state.feed[i])),
            ),
            onAppreciate: () =>
                context.read<CommunityState>().toggleClap(state.feed[i].id),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEED ENTRY CARD — middle panel card style
// ─────────────────────────────────────────────────────────────────────────────

class _FeedEntryCard extends StatelessWidget {
  final PublishedEntry entry;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;
  final VoidCallback onAppreciate;

  const _FeedEntryCard({
    required this.entry,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
    required this.onAppreciate,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = entry.headerImage != null &&
        entry.headerImage!.isNotEmpty &&
        File(entry.headerImage!).existsSync();
    final gradient = _entryGradient(entry);
    final catColor = _categoryColor(entry.category);
    final author = entry.authorLabel;
    final authorColor = _avatarColor(author);
    final authorInitial = author.isNotEmpty ? author[0].toUpperCase() : '?';
    final divColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 98,
                        height: 108,
                        child: hasImage
                            ? Image.file(File(entry.headerImage!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _GradientBox(gradient: gradient))
                            : _GradientBox(gradient: gradient),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (entry.category != null &&
                                  entry.category!.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    entry.category!.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: catColor,
                                      letterSpacing: 0.8,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const Spacer(),
                              Text(_relativeDate(entry.createdAt),
                                  style: GoogleFonts.inter(
                                      fontSize: 10, color: mutedColor)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            entry.title.isEmpty ? 'Untitled' : entry.title,
                            style: GoogleFonts.crimsonPro(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              height: 1.2,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.preview(80),
                            style: GoogleFonts.inter(
                                fontSize: 12, color: mutedColor, height: 1.45),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                          color: authorColor, shape: BoxShape.circle),
                      child: Center(
                        child: Text(authorInitial,
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(author,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textColor)),
                    const SizedBox(width: 6),
                    Text(_readTime(entry.content),
                        style:
                            GoogleFonts.inter(fontSize: 11, color: mutedColor)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onAppreciate();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.hasClapped
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 16,
                            color: entry.hasClapped
                                ? const Color(0xFFE87FA0)
                                : mutedColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Appreciate',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: entry.hasClapped
                                  ? const Color(0xFFE87FA0)
                                  : mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 14, color: mutedColor),
                        const SizedBox(width: 3),
                        Text('${entry.commentCount}',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: mutedColor)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.bookmark_border_rounded,
                        size: 16, color: mutedColor.withOpacity(0.55)),
                  ],
                ),
              ],
            ),
          ),
          Divider(
              color: divColor,
              thickness: 0.5,
              height: 0,
              indent: 24,
              endIndent: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MY POSTS TAB
// ─────────────────────────────────────────────────────────────────────────────

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
              Icon(Icons.lock_outline_rounded,
                  size: 48, color: mutedColor.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'Sign in to view\nyour published entries.',
                textAlign: TextAlign.center,
                style: GoogleFonts.crimsonPro(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: mutedColor),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onAuthRequired,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.aqua.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.aqua.withOpacity(0.4)),
                  ),
                  child: Text('Sign In',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.aqua)),
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
        child: Text("You haven't published anything yet.",
            style: GoogleFonts.crimsonPro(
                fontSize: 16, fontStyle: FontStyle.italic, color: mutedColor)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<CommunityState>().loadMyPosts(),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
        itemCount: state.myPosts.length,
        itemBuilder: (ctx, i) {
          final entry = state.myPosts[i];
          return _FeedEntryCard(
            entry: entry,
            isDark: isDark,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () => Navigator.of(ctx).push(
              MaterialPageRoute(
                  builder: (_) => CommunityEntryViewer(entry: entry)),
            ),
            onAppreciate: () {},
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLISH SHEET — with category picker
// ─────────────────────────────────────────────────────────────────────────────

class _PublishSheet extends StatefulWidget {
  final List<Entry> entries;
  final void Function(
          Entry entry, bool isAnon, String? displayName, String? category)
      onPublish;

  const _PublishSheet({required this.entries, required this.onPublish});

  @override
  State<_PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends State<_PublishSheet> {
  Entry? _selected;
  bool _isAnon = false;
  String? _selectedCategory;
  late TextEditingController _nameCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('communityDisplayName');
    if (stored != null && mounted) {
      _nameCtrl.text = stored;
    } else {
      final email = SupabaseService.instance.userEmail;
      if (email != null && mounted) _nameCtrl.text = email.split('@').first;
    }
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
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, sc) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: mutedColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Share to Sanctuary',
                  style: GoogleFonts.crimsonPro(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
              child: Text(
                  'Choose an entry and a category to give readers context.',
                  style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
            ),
            Divider(color: divColor, thickness: 0.5, height: 0),

            Expanded(
              child: widget.entries.isEmpty
                  ? Center(
                      child: Text('No entries in current story.',
                          style: GoogleFonts.crimsonPro(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: mutedColor)))
                  : ListView.builder(
                      controller: sc,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                                  : (dark
                                      ? Colors.white.withOpacity(0.04)
                                      : Colors.black.withOpacity(0.03)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: sel
                                      ? AppColors.aqua
                                      : Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          e.title.isEmpty
                                              ? 'Untitled'
                                              : e.title,
                                          style: GoogleFonts.crimsonPro(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: sel
                                                  ? AppColors.aqua
                                                  : textColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(e.preview(70),
                                          style: GoogleFonts.inter(
                                              fontSize: 12, color: mutedColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                if (sel)
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppColors.aqua, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Category + options + button
            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 12, 24, 16 + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: divColor, thickness: 0.5),
                  const SizedBox(height: 12),

                  // Category picker
                  Text('CATEGORY',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _kCategories.length - 1, // skip 'All'
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final cat = _kCategories[i + 1];
                        final isSel = _selectedCategory == cat;
                        final color = _categoryColor(cat);
                        return GestureDetector(
                          onTap: () => setState(
                              () => _selectedCategory = isSel ? null : cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? color.withOpacity(0.15)
                                  : (dark
                                      ? Colors.white.withOpacity(0.07)
                                      : Colors.black.withOpacity(0.05)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isSel
                                      ? color.withOpacity(0.5)
                                      : Colors.transparent,
                                  width: 1.5),
                            ),
                            child: Text(cat,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSel
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSel ? color : mutedColor)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Display name
                  if (!_isAnon) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _nameCtrl,
                        style:
                            GoogleFonts.inter(fontSize: 14, color: textColor),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          hintText: 'Your display name...',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 14, color: mutedColor),
                          prefixIcon: Icon(Icons.person_outline_rounded,
                              size: 16, color: mutedColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Anonymous toggle
                  GestureDetector(
                    onTap: () => setState(() => _isAnon = !_isAnon),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color:
                                _isAnon ? AppColors.aqua : Colors.transparent,
                            border: Border.all(
                                color: _isAnon ? AppColors.aqua : mutedColor,
                                width: 1.5),
                          ),
                          child: _isAnon
                              ? const Icon(Icons.check,
                                  size: 13, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text('Publish anonymously',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: textColor)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

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
                                await context
                                    .read<CommunityState>()
                                    .saveProfile(name: name);
                              }
                              widget.onPublish(
                                _selected!,
                                _isAnon,
                                _isAnon ? null : (name.isEmpty ? null : name),
                                _selectedCategory,
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
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5, color: AppColors.aqua))
                              : Text(
                                  _selected == null
                                      ? 'Select an entry first'
                                      : 'Publish to Sanctuary',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _selected != null
                                        ? AppColors.aqua
                                        : mutedColor,
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

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SHEET — with image picker, fixes avatar not showing
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileSheet extends StatefulWidget {
  final String email;
  final bool isDark;
  final String? currentName;
  final String? currentImagePath;
  final VoidCallback onSignOut;
  final VoidCallback onProfileUpdated;

  const _ProfileSheet({
    required this.email,
    required this.isDark,
    this.currentName,
    this.currentImagePath,
    required this.onSignOut,
    required this.onProfileUpdated,
  });

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late TextEditingController _nameCtrl;
  bool _saving = false;
  bool _saved = false;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.currentImagePath;
    _nameCtrl = TextEditingController(
      text: widget.currentName ?? widget.email.split('@').first,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final ok = await PermissionService.instance.ensurePhotos(context);
    if (!ok || !mounted) return;
    final path = await ImageService.instance.pickAndSave(
      context: context,
      allowCrop: true,
      cropAspectRatioX: 1,
      cropAspectRatioY: 1,
    );
    if (path != null && mounted) {
      await context.read<CommunityState>().saveProfile(imagePath: path);
      setState(() => _imagePath = path);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await context.read<CommunityState>().saveProfile(name: name);
    if (mounted)
      setState(() {
        _saving = false;
        _saved = true;
      });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _saved = false);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor =
        widget.isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final divColor =
        widget.isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final cardBg = widget.isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
          const SizedBox(height: 20),

          // Profile image
          Center(
            child: GestureDetector(
              onTap: _pickProfileImage,
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cardBg,
                      border: Border.all(
                          color: AppColors.aqua.withOpacity(0.4), width: 2),
                    ),
                    child: _imagePath != null && File(_imagePath!).existsSync()
                        ? ClipOval(
                            child: Image.file(File(_imagePath!),
                                width: 80, height: 80, fit: BoxFit.cover))
                        : Center(
                            child: Icon(Icons.person_rounded,
                                size: 38, color: mutedColor)),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                          color: AppColors.aqua, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('Tap to change photo',
              style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
          const SizedBox(height: 20),

          // Email
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: cardBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, size: 16, color: mutedColor),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          widget.email.isEmpty ? 'Signed in' : widget.email,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: textColor))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.aqua.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Verified',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.aqua)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Display name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: divColor.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      style: GoogleFonts.inter(fontSize: 15, color: textColor),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        hintText: 'Display name',
                        hintStyle:
                            GoogleFonts.inter(fontSize: 15, color: mutedColor),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _saving ? null : _save,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _saved
                            ? Colors.green.withOpacity(0.15)
                            : AppColors.aqua.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _saved
                                ? Colors.green.withOpacity(0.4)
                                : AppColors.aqua.withOpacity(0.4)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: AppColors.aqua))
                          : Text(_saved ? 'Saved ✓' : 'Save',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _saved ? Colors.green : AppColors.aqua)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: divColor, thickness: 0.5),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onSignOut,
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded,
                          size: 18, color: AppColors.danger),
                      const SizedBox(width: 10),
                      Text('Sign Out',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.danger)),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onProfileUpdated,
                  child: Text('Done',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.aqua)),
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _AuthSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const _AuthSheet({required this.onSuccess});

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet>
    with SingleTickerProviderStateMixin {
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
    setState(() {
      _loading = true;
      _error = null;
    });
    String? err;
    if (_tab.index == 0) {
      err = await SupabaseService.instance.signInWithEmail(email, pass);
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _error = err;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        widget.onSuccess();
      }
    } else {
      err = await SupabaseService.instance.signUpWithEmail(email, pass);
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _error = err;
          _loading = false;
        });
      } else if (SupabaseService.instance.isAuthenticated) {
        setState(() => _loading = false);
        widget.onSuccess();
      } else {
        setState(() {
          _error = 'Check your email ($email) to confirm your account.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: mutedColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Join the Sanctuary',
                style: GoogleFonts.crimsonPro(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
            Text('Sign in to publish, appreciate, and reflect.',
                style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
            const SizedBox(height: 20),
            TabBar(
              controller: _tab,
              tabs: const [Tab(text: 'Sign In'), Tab(text: 'Sign Up')],
              labelColor: AppColors.aqua,
              unselectedLabelColor: mutedColor,
              indicatorColor: AppColors.aqua,
              dividerColor: Colors.transparent,
              labelStyle:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
            ),
            const SizedBox(height: 16),
            _InputField(
                controller: _emailCtrl,
                hint: 'Email',
                isDark: dark,
                textColor: textColor,
                mutedColor: mutedColor),
            const SizedBox(height: 10),
            _InputField(
                controller: _passCtrl,
                hint: 'Password',
                isDark: dark,
                textColor: textColor,
                mutedColor: mutedColor,
                obscure: true),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
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
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppColors.aqua))
                        : Text('Continue',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.aqua)),
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
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.inter(fontSize: 14, color: textColor),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 14, color: mutedColor),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETUP REQUIRED
// ─────────────────────────────────────────────────────────────────────────────

class _SetupRequired extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color mutedColor;

  const _SetupRequired(
      {required this.isDark,
      required this.textColor,
      required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, topPadding + 80, 32, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sanctuary',
                style: GoogleFonts.crimsonPro(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
            const SizedBox(height: 32),
            Icon(Icons.cloud_off_rounded,
                size: 48, color: mutedColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Supabase not configured.',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor)),
            const SizedBox(height: 8),
            Text(
                'Set your Supabase URL and anon key in\nlib/services/supabase_service.dart\nto enable community features.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: mutedColor, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
