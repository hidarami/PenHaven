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
  'Gratitude',
  'Grief & Loss',
  'Love',
  'Growth',
  'Mental Health',
  'Creativity',
  'Nature',
  'Travel',
  'Family',
  'Spirituality',
  'Work & Career',
  'Poetry',
  'Nostalgia',
  'Humor',
  'Justice',
  'Art',
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
  'Gratitude': Icons.volunteer_activism_outlined,
  'Grief & Loss': Icons.sentiment_very_dissatisfied_outlined,
  'Love': Icons.favorite_rounded,
  'Growth': Icons.trending_up_rounded,
  'Mental Health': Icons.psychology_outlined,
  'Creativity': Icons.palette_outlined,
  'Nature': Icons.eco_outlined,
  'Travel': Icons.flight_outlined,
  'Family': Icons.family_restroom_outlined,
  'Spirituality': Icons.spa_outlined,
  'Work & Career': Icons.work_outline_rounded,
  'Poetry': Icons.format_quote_rounded,
  'Nostalgia': Icons.history_rounded,
  'Humor': Icons.emoji_emotions_outlined,
  'Justice': Icons.balance_rounded,
  'Art': Icons.brush_outlined,
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
    case 'gratitude':
      return const Color(0xFF5BA86A);
    case 'grief & loss':
    case 'grief':
      return const Color(0xFF7A8299);
    case 'love':
      return const Color(0xFFD45880);
    case 'growth':
      return const Color(0xFF3E9E5F);
    case 'mental health':
      return const Color(0xFF7B9ED9);
    case 'creativity':
      return const Color(0xFFE87A40);
    case 'nature':
      return const Color(0xFF5A9A68);
    case 'travel':
      return const Color(0xFF3A85C8);
    case 'family':
      return const Color(0xFFD4A028);
    case 'spirituality':
      return const Color(0xFF9B7ED4);
    case 'work & career':
    case 'work':
      return const Color(0xFF5A7A9A);
    case 'poetry':
      return const Color(0xFFB86A9A);
    case 'nostalgia':
      return const Color(0xFFC8904A);
    case 'humor':
      return const Color(0xFFE8B840);
    case 'justice':
      return const Color(0xFF7A6ABA);
    case 'art':
      return const Color(0xFFD46A8A);
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
    case 'gratitude':
      return [const Color(0xFF0A2015), const Color(0xFF1A3A28)];
    case 'grief & loss':
    case 'grief':
      return [const Color(0xFF131520), const Color(0xFF202535)];
    case 'love':
      return [const Color(0xFF280818), const Color(0xFF501030)];
    case 'growth':
      return [const Color(0xFF0A1F10), const Color(0xFF1A3820)];
    case 'mental health':
      return [const Color(0xFF0C1828), const Color(0xFF182540)];
    case 'creativity':
      return [const Color(0xFF251208), const Color(0xFF452218)];
    case 'nature':
      return [const Color(0xFF081808), const Color(0xFF102810)];
    case 'travel':
      return [const Color(0xFF081520), const Color(0xFF102838)];
    case 'family':
      return [const Color(0xFF201800), const Color(0xFF382800)];
    case 'spirituality':
      return [const Color(0xFF170828), const Color(0xFF2A1048)];
    case 'work & career':
    case 'work':
      return [const Color(0xFF101820), const Color(0xFF1E2C38)];
    case 'poetry':
      return [const Color(0xFF200A18), const Color(0xFF381428)];
    case 'nostalgia':
      return [const Color(0xFF201808), const Color(0xFF382A10)];
    case 'humor':
      return [const Color(0xFF201A00), const Color(0xFF382E00)];
    case 'justice':
      return [const Color(0xFF100C20), const Color(0xFF201838)];
    case 'art':
      return [const Color(0xFF200810), const Color(0xFF381020)];
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
    await state.loadProfile();
    await state.loadFeatured();
    await state.loadBookmarks();
    await state.loadFeed();
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
          context.read<CommunityState>().loadProfile();
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
    final accentColor = context.watch<AtmosphereState>().accentColor;
    final communityState = context.watch<CommunityState>();
    final displayName = communityState.profileDisplayName;

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
                GestureDetector(
                  onTap: _openPublishSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.aqua.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.aqua.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 15, color: AppColors.aqua),
                        const SizedBox(width: 5),
                        Text('Publish',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.aqua)),
                      ],
                    ),
                  ),
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
              ],
              labelColor: accentColor,
              unselectedLabelColor: mutedColor,
              indicatorColor: accentColor,
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
                  accentColor: accentColor,
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
                  accentColor: accentColor,
                  isDark: dark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onPublish: _openPublishSheet,
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
// PROFILE AVATAR
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// FOR YOU TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ForYouTab extends StatelessWidget {
  final Color accentColor;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onViewAll;
  final VoidCallback onPublish;

  const _ForYouTab({
    required this.accentColor,
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
// FEATURED CARD
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
    final communityState = context.watch<CommunityState>();
    final author = entry.isOwner
        ? (communityState.profileDisplayName ?? entry.authorLabel)
        : entry.authorLabel;
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
              hasImage
                  ? Image.file(File(entry.headerImage!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _GradientBox(gradient: gradient))
                  : _GradientBox(gradient: gradient),

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

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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

                    Row(
                      children: [
                        _AuthorAvatar(
                            entry: entry,
                            size: 28,
                            authorColor: authorColor,
                            authorInitial: authorInitial),
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
// COMPACT ENTRY CARD
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
    final communityState = context.watch<CommunityState>();
    final author = entry.isOwner
        ? (communityState.profileDisplayName ?? entry.authorLabel)
        : entry.authorLabel;
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
                          _AuthorAvatar(
                              entry: entry,
                              size: 18,
                              authorColor: authorColor,
                              authorInitial: authorInitial),
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
// RECENT TAB
// ─────────────────────────────────────────────────────────────────────────────

class _RecentTab extends StatelessWidget {
  final Color accentColor;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onPublish;

  const _RecentTab({
    required this.accentColor,
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
// FEED ENTRY CARD
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
    final communityState = context.watch<CommunityState>();
    final author = entry.isOwner
        ? (communityState.profileDisplayName ?? entry.authorLabel)
        : entry.authorLabel;
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
                    _AuthorAvatar(
                        entry: entry,
                        size: 22,
                        authorColor: authorColor,
                        authorInitial: authorInitial),
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


// ─────────────────────────────────────────────────────────────────────────────
// PUBLISH SHEET
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

            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 12, 24, 16 + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: divColor, thickness: 0.5),
                  const SizedBox(height: 12),

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
                      itemCount: _kCategories.length - 1,
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
// AUTHOR AVATAR
// ─────────────────────────────────────────────────────────────────────────────

class _AuthorAvatar extends StatelessWidget {
  final PublishedEntry entry;
  final double size;
  final Color authorColor;
  final String authorInitial;

  const _AuthorAvatar({
    required this.entry,
    required this.size,
    required this.authorColor,
    required this.authorInitial,
  });

  @override
  Widget build(BuildContext context) {
    if (entry.isOwner) {
      final imagePath = context.read<CommunityState>().profileImagePath;
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          File(imagePath).existsSync()) {
        return ClipOval(
          child: Image.file(
            File(imagePath),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      }
    } else if (entry.authorImageUrl != null && entry.authorImageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          entry.authorImageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: authorColor, shape: BoxShape.circle),
            child: Center(
              child: Text(authorInitial,
                  style: GoogleFonts.inter(
                      fontSize: size * 0.40,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: authorColor, shape: BoxShape.circle),
      child: Center(
        child: Text(
          authorInitial,
          style: GoogleFonts.inter(
            fontSize: size * 0.40,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
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
