import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/story.dart';
import 'package:intl/intl.dart';

import 'dart:io';
import '../../models/reflection.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../providers/community_state.dart';
import '../../theme/app_colors.dart';
import '../community/reflection_viewer.dart' show ReflectionViewer;
import '../../theme/app_typography.dart';
import '../../widgets/shared_widgets.dart';
import 'library_empty_state.dart';
import 'story_card.dart';

enum _SortBy { lastEdited, alphabetical }

class LibraryPanel extends StatefulWidget {
  const LibraryPanel({super.key});

  @override
  State<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends State<LibraryPanel>
    with TickerProviderStateMixin {
  _SortBy _sortBy = _SortBy.lastEdited;
  late final TabController _mainTab;
  late final TabController _wbTab;
  bool _wbLoaded = false;

  @override
  void initState() {
    super.initState();
    _mainTab = TabController(length: 2, vsync: this);
    _mainTab.addListener(() {
      if (_mainTab.index == 1 && !_wbLoaded && mounted) {
        _wbLoaded = true;
        context.read<CommunityState>().loadReceivedWriteBacks();
      }
    });
  }

  @override
  void dispose() {
    _mainTab.dispose();
    super.dispose();
  }

  List<Story> _sorted(List<Story> stories) {
    final list = List<Story>.of(stories);
    if (_sortBy == _SortBy.alphabetical) {
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final stories = _sorted(appState.stories);
        final communityState = context.watch<CommunityState>();
        final topPadding = MediaQuery.of(context).padding.top;
        final dark = appState.isDarkMode;
        final textColor = dark ? AppColors.textDark : AppColors.textLight;
        final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
        final accent = context.watch<AtmosphereState>().accentColor;
        final divColor =
            dark ? AppColors.dividerDark : AppColors.dividerLight;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: topPadding > 0 ? 60 : 80),

                // ── Header ─────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Library',
                              style: AppTypography.panelHeader(textColor)),
                          const SizedBox(height: 4),
                          Text(
                            'Your writing collections.',
                            style: GoogleFonts.crimsonPro(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Add story button — only on Stories tab
                    AnimatedBuilder(
                      animation: _mainTab,
                      builder: (_, __) {
                        if (_mainTab.index != 0 || stories.isEmpty) {
                          return const SizedBox(width: 0);
                        }
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _createStory(context),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dark
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.06),
                                ),
                                child: Icon(Icons.add,
                                    size: 18, color: accent),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Main tabs: Stories | Write Backs ───────────────
                TabBar(
                  controller: _mainTab,
                  tabs: const [
                    Tab(text: 'Stories'),
                    Tab(text: 'Reflections'),
                  ],
                  labelColor: accent,
                  unselectedLabelColor: mutedColor,
                  indicatorColor: accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w400),
                ),

                Divider(color: divColor, thickness: 0.5, height: 8),

                // ── Tab content ────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _mainTab,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Stories tab
                      Column(
                        children: [
                          if (stories.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.menu_book_outlined,
                                    size: 15,
                                    color: accent.withOpacity(0.8)),
                                const SizedBox(width: 6),
                                Text(
                                  '${stories.length} ${stories.length == 1 ? "story" : "stories"}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: mutedColor,
                                  ),
                                ),
                                const Spacer(),
                                _SortDropdown(
                                  current: _sortBy,
                                  onChanged: (v) =>
                                      setState(() => _sortBy = v),
                                  mutedColor: mutedColor,
                                  textColor: textColor,
                                  dark: dark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          Expanded(
                            child: stories.isEmpty
                                ? LibraryEmptyState(
                                    onCreateStory: () =>
                                        _createStory(context))
                                : _sortBy == _SortBy.alphabetical
                                    ? ListView.builder(
                                        physics:
                                            const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.only(
                                            bottom: 100),
                                        itemCount: stories.length,
                                        itemBuilder: (context, i) =>
                                            StoryCard(
                                          key: ValueKey(stories[i].id),
                                          story: stories[i],
                                          isActive:
                                              appState.activeStory?.id ==
                                                  stories[i].id,
                                        ),
                                      )
                                    : ReorderableListView.builder(
                                        buildDefaultDragHandles: false,
                                        physics:
                                            const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.only(
                                            bottom: 100),
                                        itemCount: stories.length,
                                        onReorder: (oldIndex, newIndex) {
                                          context
                                              .read<AppState>()
                                              .reorderStories(
                                                  oldIndex, newIndex);
                                        },
                                        itemBuilder: (context, i) =>
                                            ReorderableDelayedDragStartListener(
                                          key: ValueKey(stories[i].id),
                                          index: i,
                                          child: StoryCard(
                                            story: stories[i],
                                            isActive: appState
                                                    .activeStory?.id ==
                                                stories[i].id,
                                          ),
                                        ),
                                      ),
                          ),
                        ],
                      ),

                      // Reflections tab — reflections received on user's published entries
                      _ReflectionsTab(
                        communityState: communityState,
                        dark: dark,
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createStory(BuildContext context) async {
    try {
      final result = await StoryCreateDialog.show(context);
      if (result == null || !context.mounted) return;
      await context.read<AppState>().createStory(
            title: result.title,
            description: result.description,
            coverImage: result.coverImage,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create story: $e')),
      );
    }
  }
}

// ── Sort dropdown ─────────────────────────────────────────────────────────────

class _SortDropdown extends StatelessWidget {
  final _SortBy current;
  final ValueChanged<_SortBy> onChanged;
  final Color mutedColor;
  final Color textColor;
  final bool dark;

  const _SortDropdown({
    required this.current,
    required this.onChanged,
    required this.mutedColor,
    required this.textColor,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        current == _SortBy.lastEdited ? 'Last edited' : 'A–Z';
    return PopupMenuButton<_SortBy>(
      onSelected: onChanged,
      color: dark ? AppColors.warmDark : AppColors.warmWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sort by: $label',
              style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: mutedColor),
        ],
      ),
      itemBuilder: (_) => [
        _menuItem(_SortBy.lastEdited, 'Last edited'),
        _menuItem(_SortBy.alphabetical, 'A–Z'),
      ],
    );
  }

  PopupMenuItem<_SortBy> _menuItem(_SortBy val, String label) =>
      PopupMenuItem(
        value: val,
        child: Row(
          children: [
            if (current == val) ...[
              const Icon(Icons.check_rounded, size: 14, color: AppColors.aqua),
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 22),
            Text(label,
                style: GoogleFonts.inter(fontSize: 14, color: textColor)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// REFLECTIONS TAB
// Shows reflections received on the user's published entries.
// ─────────────────────────────────────────────────────────────────────────────

class _ReflectionsTab extends StatelessWidget {
  final CommunityState communityState;
  final bool dark;
  final Color textColor;
  final Color mutedColor;

  const _ReflectionsTab({
    required this.communityState,
    required this.dark,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final items = communityState.receivedWriteBacks;
    final loading = communityState.writeBacksLoading;
    final divColor = dark ? AppColors.dividerDark : AppColors.dividerLight;

    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No reflections received yet.\nPublish entries to Sanctuary so others can reflect on them.',
            textAlign: TextAlign.center,
            style: GoogleFonts.crimsonPro(
              fontSize: 17,
              fontStyle: FontStyle.italic,
              color: mutedColor.withOpacity(0.65),
              height: 1.6,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          Divider(color: divColor, thickness: 0.5, height: 0),
      itemBuilder: (ctx, i) => _ReceivedReflectionCard(
        key: ValueKey(items[i].hashCode),
        item: items[i],
        dark: dark,
        textColor: textColor,
        mutedColor: mutedColor,
      ),
    );
  }
}

class _ReceivedReflectionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool dark;
  final Color textColor;
  final Color mutedColor;

  const _ReceivedReflectionCard({
    required super.key,
    required this.item,
    required this.dark,
    required this.textColor,
    required this.mutedColor,
  });

  String _relTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? '';
    final content = item['content'] as String? ?? '';
    final originTitle = item['origin_title'] as String? ?? '';
    final isAnon = item['is_anonymous'] as bool? ?? false;
    final displayName = item['display_name'] as String?;
    final author =
        isAnon ? 'Anonymous' : (displayName?.isNotEmpty == true ? displayName! : 'A Writer');
    final headerImage = (item['header_image'] as String?)?.isNotEmpty == true
        ? item['header_image'] as String
        : (item['origin_header_image'] as String?) ?? '';
    final hasImage = headerImage.isNotEmpty && File(headerImage).existsSync();
    final preview = content.length > 90 ? '${content.substring(0, 90)}…' : content;

    return GestureDetector(
      onTap: () {
        try {
          final reflection = Reflection.fromMap(item);
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => ReflectionViewer(reflection: reflection)),
          );
        } catch (e) {
          debugPrint('[ReflectionCard] parse error: $e');
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: hasImage
                  ? Image.file(File(headerImage), fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFF180A28), Color(0xFF301550)]),
                      ),
                      child: const Icon(Icons.auto_stories_outlined,
                          color: Colors.white24, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (originTitle.isNotEmpty)
                Text(
                  'On "$originTitle"',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: mutedColor, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),
              Text(
                title.isEmpty ? (preview.isEmpty ? 'Untitled' : preview) : title,
                style: GoogleFonts.crimsonPro(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (title.isNotEmpty && preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(preview,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: mutedColor, height: 1.45),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 7),
              Row(children: [
                _LibraryAvatarCircle(name: author, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$author  ·  ${_relTime(item['created_at'] as String?)}',
                    style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Author avatar for received reflection cards ───────────────────────────────

class _LibraryAvatarCircle extends StatelessWidget {
  final String name;
  final double size;
  const _LibraryAvatarCircle({required this.name, required this.size});

  Color _color(String n) {
    const colors = [
      Color(0xFF7BA591), Color(0xFF5B8DB8), Color(0xFFD4820A),
      Color(0xFF9472D4), Color(0xFFE87FA0), Color(0xFFD44A28),
      Color(0xFF5A8A5C), Color(0xFF1B9B8D),
    ];
    return colors[n.codeUnits.fold(0, (a, b) => a + b) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
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
}