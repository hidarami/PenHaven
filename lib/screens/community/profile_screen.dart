import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/entry_dao.dart';
import '../../models/story.dart';
import '../../models/published_entry.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../providers/community_state.dart';
import '../../services/image_service.dart';
import '../../services/permission_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../story_cover.dart';
import 'community_entry_viewer.dart';

class _BannerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - 28);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 28,
      0,
      size.height - 28,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    final state = context.read<CommunityState>();
    await state.loadProfile();
    await state.loadBookmarks();
    if (SupabaseService.instance.isAuthenticated) {
      await state.loadMyPosts();
      if (state.feed.isEmpty) await state.loadFeed();
    }
    if (mounted) setState(() {});
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
    }
  }

  Future<void> _pickBannerImage() async {
    final ok = await PermissionService.instance.ensurePhotos(context);
    if (!ok || !mounted) return;
    final path = await ImageService.instance.pickAndSave(
      context: context,
      allowCrop: true,
      cropAspectRatioX: 16,
      cropAspectRatioY: 9,
    );
    if (path != null && mounted) {
      await context.read<CommunityState>().saveProfile(bannerPath: path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = context.watch<AtmosphereState>().backgroundFor(dark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final accentColor = context.watch<AtmosphereState>().accentColor;
    final communityState = context.watch<CommunityState>();
    final appState = context.watch<AppState>();
    final topPad = MediaQuery.of(context).padding.top;
    final divColor = dark ? AppColors.dividerDark : AppColors.dividerLight;

    final displayName = communityState.profileDisplayName ??
        (SupabaseService.instance.userEmail?.split('@').first ?? 'You');
    final email = SupabaseService.instance.userEmail ?? '';
    final rawHandle = email.isNotEmpty ? email.split('@').first : displayName;
    final handle =
        '@${rawHandle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '')}';
    final imagePath = communityState.profileImagePath;
    final hasImage = imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync();
    final bannerPath = communityState.profileBannerPath;
    final hasBanner = bannerPath != null &&
        bannerPath.isNotEmpty &&
        File(bannerPath).existsSync();
    final stories = appState.stories.where((s) => !s.isDeleted).toList();
    final publications = communityState.myPosts;
    final pubCount = publications.length;
    final appreciationsTotal =
        publications.fold<int>(0, (sum, p) => sum + p.clapCount);

    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
        },
        child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // ── Cover + Avatar ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Banner with curved bottom
                ClipPath(
                  clipper: _BannerClipper(),
                  child: GestureDetector(
                    onTap: _pickBannerImage,
                    child: SizedBox(
                      height: 190 + topPad,
                      width: double.infinity,
                      child: hasBanner
                          ? SizedBox(
                              width: double.infinity,
                              height: 190 + topPad,
                              child: Image.file(File(bannerPath!),
                                  fit: BoxFit.cover),
                            )
                          : hasImage
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ImageFiltered(
                                      imageFilter: ImageFilter.blur(
                                          sigmaX: 44, sigmaY: 44),
                                      child: Image.file(
                                        File(imagePath!),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    ),
                                    Container(
                                        color: Colors.black.withOpacity(0.42)),
                                  ],
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: dark
                                          ? [
                                              const Color(0xFF0D1A28),
                                              const Color(0xFF1A3045)
                                            ]
                                          : [
                                              const Color(0xFFB8CDE0),
                                              const Color(0xFFD8E8F0)
                                            ],
                                    ),
                                  ),
                                ),
                    ),
                  ),
                ),


                // Avatar — centered, overlapping bottom of banner
                Positioned(
                  bottom: -48,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _pickProfileImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: dark ? AppColors.warmDark : Colors.white,
                                width: 4,
                              ),
                            ),
                            child: ClipOval(
                              child: hasImage
                                  ? Image.file(File(imagePath!),
                                      width: 96, height: 96, fit: BoxFit.cover)
                                  : Container(
                                      color: accentColor.withOpacity(0.18),
                                      child: Center(
                                        child: Text(
                                          displayName.isNotEmpty
                                              ? displayName[0].toUpperCase()
                                              : '?',
                                          style: GoogleFonts.crimsonPro(
                                            fontSize: 38,
                                            fontWeight: FontWeight.w700,
                                            color: accentColor,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Spacer for avatar overlap
          const SliverToBoxAdapter(child: SizedBox(height: 62)),

          // ── Name, Handle, Stats ──────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.crimsonPro(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  handle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 22),

                // Stats row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Expanded(
                          child: _StatItem(
                              count: pubCount,
                              label: 'Publications',
                              textColor: textColor,
                              mutedColor: mutedColor)),
                      Container(width: 0.5, height: 36, color: divColor),
                      Expanded(
                          child: _StatItem(
                              count: appreciationsTotal,
                              label: 'Appreciations',
                              textColor: textColor,
                              mutedColor: mutedColor)),
                      Container(width: 0.5, height: 36, color: divColor),
                      Expanded(
                          child: _StatItem(
                              count: 0,
                              label: 'Followers',
                              textColor: textColor,
                              mutedColor: mutedColor)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: divColor, thickness: 0.5),
                ),
              ],
            ),
          ),

          // ── Stories ──────────────────────────────────────────────
          if (stories.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                child: Row(
                  children: [
                    Text('Stories',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor)),
                    const Spacer(),
                    Text('View all',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: accentColor,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 170,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: stories.length,
                  itemBuilder: (ctx, i) => _ProfileStoryCard(
                    story: stories[i],
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ),
              ),
            ),
          ],

          // ── Recent Publications ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
              child: Text('Recent Publications',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
            ),
          ),

          if (!SupabaseService.instance.isAuthenticated)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text('Sign in to view your publications.',
                    style: GoogleFonts.crimsonPro(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: mutedColor)),
              ),
            )
          else if (publications.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text("You haven't published anything yet.",
                    style: GoogleFonts.crimsonPro(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: mutedColor)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _PublicationTile(
                  entry: publications[i],
                  isDark: dark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            CommunityEntryViewer(entry: publications[i])),
                  ),
                ),
                childCount: publications.length,
              ),
            ),

          // ── Bookmarked Entries ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
              child: Row(
                children: [
                  Icon(Icons.bookmark_rounded, size: 16, color: accentColor),
                  const SizedBox(width: 8),
                  Text('Bookmarked',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                ],
              ),
            ),
          ),

          Builder(builder: (context) {
            final bookmarked = communityState.bookmarkedEntries;
            if (bookmarked.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Text(
                    'Nothing bookmarked yet. Tap the bookmark icon on any entry.',
                    style: GoogleFonts.crimsonPro(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: mutedColor),
                  ),
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _PublicationTile(
                  entry: bookmarked[i],
                  isDark: dark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            CommunityEntryViewer(entry: bookmarked[i])),
                  ),
                ),
                childCount: bookmarked.length,
              ),
            );
          }),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      ),
    );
  }
}

// ── Stat item ──────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  final Color textColor;
  final Color mutedColor;

  const _StatItem({
    required this.count,
    required this.label,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
            textAlign: TextAlign.center),
      ],
    );
  }
}

// ── Profile story card (horizontal) ───────────────────────────────────────

class _ProfileStoryCard extends StatelessWidget {
  final Story story;
  final Color textColor;
  final Color mutedColor;

  const _ProfileStoryCard({
    required this.story,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: StoryCoverWidget(
              storyTitle: story.title,
              imagePath: story.coverImage,
              width: 118,
              height: 118,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            story.title,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          FutureBuilder<int>(
            future: EntryDao.instance.countByStory(story.id),
            builder: (ctx, snap) {
              final count = snap.data ?? 0;
              return Text(
                '$count ${count == 1 ? "entry" : "entries"}',
                style: GoogleFonts.inter(fontSize: 10, color: mutedColor),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Publication tile ──────────────────────────────────────────────────────

class _PublicationTile extends StatelessWidget {
  final PublishedEntry entry;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _PublicationTile({
    required this.entry,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  String _readTime(String content) {
    if (content.isEmpty) return '1 min read';
    final words =
        content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return '${(words / 200).ceil().clamp(1, 99)} min read';
  }

  String _relDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  Color _catColor(String? cat) {
    switch ((cat ?? '').toLowerCase()) {
      case 'faith':
        return const Color(0xFF4A8A70);
      case 'identity':
        return const Color(0xFF5B8DB8);
      case 'philosophy':
        return const Color(0xFFD4820A);
      case 'reflections':
        return const Color(0xFF9472D4);
      case 'personal':
        return const Color(0xFFE87FA0);
      case 'love':
        return const Color(0xFFD45880);
      case 'growth':
        return const Color(0xFF3E9E5F);
      default:
        return AppColors.aqua;
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _catColor(entry.category);
    final divColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final hasImage = entry.headerImage != null &&
        entry.headerImage!.isNotEmpty &&
        File(entry.headerImage!).existsSync();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: hasImage
                        ? Image.file(File(entry.headerImage!),
                            fit: BoxFit.cover)
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  catColor.withOpacity(0.6),
                                  catColor.withOpacity(0.3)
                                ],
                              ),
                            ),
                            child: Icon(Icons.auto_stories_outlined,
                                color: catColor, size: 22),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.category != null && entry.category!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            entry.category!.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: catColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      Text(
                        entry.title.isEmpty ? 'Untitled' : entry.title,
                        style: GoogleFonts.crimsonPro(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_readTime(entry.content)}  ·  ${_relDate(entry.createdAt)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: mutedColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
              color: divColor,
              thickness: 0.5,
              height: 0,
              indent: 20,
              endIndent: 20),
        ],
      ),
    );
  }
}
