import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/story.dart';
import 'package:intl/intl.dart';

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
    _wbTab = TabController(length: 2, vsync: this);
    _mainTab.addListener(() {
      if (_mainTab.index == 1 && !_wbLoaded && mounted) {
        _wbLoaded = true;
        final cs = context.read<CommunityState>();
        cs.loadMyWriteBacks();
        cs.loadReceivedWriteBacks();
      }
    });
  }

  @override
  void dispose() {
    _mainTab.dispose();
    _wbTab.dispose();
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
                    Tab(text: 'Write Backs'),
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

                      // Write Backs tab
                      _WriteBacksTab(
                        communityState: communityState,
                        wbTab: _wbTab,
                        dark: dark,
                        textColor: textColor,
                        mutedColor: mutedColor,
                        accent: accent,
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
// WRITE BACKS TAB
// Shows Made and Received write backs in a nested tab structure.
// ─────────────────────────────────────────────────────────────────────────────

class _WriteBacksTab extends StatelessWidget {
  final CommunityState communityState;
  final TabController wbTab;
  final bool dark;
  final Color textColor;
  final Color mutedColor;
  final Color accent;

  const _WriteBacksTab({
    required this.communityState,
    required this.wbTab,
    required this.dark,
    required this.textColor,
    required this.mutedColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final divColor = dark ? AppColors.dividerDark : AppColors.dividerLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: wbTab,
          tabs: const [
            Tab(text: 'Made'),
            Tab(text: 'Received'),
          ],
          labelColor: accent,
          unselectedLabelColor: mutedColor,
          indicatorColor: accent,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
        ),
        Divider(color: divColor, thickness: 0.5, height: 0),
        Expanded(
          child: TabBarView(
            controller: wbTab,
            children: [
              _WriteBacksList(
                items: communityState.myWriteBacks,
                loading: communityState.writeBacksLoading,
                emptyMessage:
                    'No write backs yet.\nTap "Write Back" on any Sanctuary entry to start.',
                dark: dark,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              _WriteBacksList(
                items: communityState.receivedWriteBacks,
                loading: communityState.writeBacksLoading,
                emptyMessage:
                    'No write backs received yet.\nPublish entries to the Sanctuary to invite responses.',
                dark: dark,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WriteBacksList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool loading;
  final String emptyMessage;
  final bool dark;
  final Color textColor;
  final Color mutedColor;

  const _WriteBacksList({
    required this.items,
    required this.loading,
    required this.emptyMessage,
    required this.dark,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyMessage,
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
      separatorBuilder: (_, __) => Divider(
        color: dark ? AppColors.dividerDark : AppColors.dividerLight,
        thickness: 0.5,
        height: 0,
      ),
      itemBuilder: (ctx, i) => _WriteBackCard(
        item: items[i],
        dark: dark,
        textColor: textColor,
        mutedColor: mutedColor,
      ),
    );
  }
}

class _WriteBackCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool dark;
  final Color textColor;
  final Color mutedColor;

  const _WriteBackCard({
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

  void _open(BuildContext context) {
    final isPrivate = item['is_private'] as bool? ?? true;
    if (!isPrivate) {
      try {
        final reflection = Reflection.fromMap(item);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReflectionViewer(reflection: reflection),
          ),
        );
        return;
      } catch (_) {}
    }
    // Private or parse error — show detail sheet
    _showDetail(context);
  }

  void _showDetail(BuildContext context) {
    final title = item['title'] as String? ?? '';
    final content = item['content'] as String? ?? '';
    final originTitle = item['origin_title'] as String? ?? '';
    final isPrivate = item['is_private'] as bool? ?? true;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, sc) => Column(
          children: [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPrivate
                          ? Colors.grey.withOpacity(0.1)
                          : AppColors.aqua.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: isPrivate
                              ? Colors.grey.withOpacity(0.3)
                              : AppColors.aqua.withOpacity(0.3)),
                    ),
                    child: Text(
                      isPrivate ? 'Private' : 'Published',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPrivate ? mutedColor : AppColors.aqua,
                      ),
                    ),
                  ),
                  if (originTitle.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'On: $originTitle',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: mutedColor,
                            fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: sc,
                padding:
                    const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty) ...[
                      Text(
                        title,
                        style: GoogleFonts.crimsonPro(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      content,
                      style: GoogleFonts.crimsonPro(
                        fontSize: 18,
                        color: textColor,
                        height: 1.75,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? '';
    final content = item['content'] as String? ?? '';
    final isPrivate = item['is_private'] as bool? ?? true;
    final originTitle = item['origin_title'] as String? ?? '';
    final originAuthor = item['origin_author'] as String? ?? '';
    final createdAt = item['created_at'] as String?;
    final clapCount = (item['clap_count'] as int?) ?? 0;
    final replyCount = (item['reply_count'] as int?) ?? 0;

    final preview = content.length > 90
        ? '${content.substring(0, 90)}…'
        : content;

    return GestureDetector(
      onTap: () => _open(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Origin reference
            if (originTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_right_rounded,
                        size: 12, color: mutedColor.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'On "$originTitle"'
                        '${originAuthor.isNotEmpty ? ' by $originAuthor' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: mutedColor,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Title or preview
            Text(
              title.isEmpty
                  ? (preview.isEmpty ? 'Untitled' : preview)
                  : title,
              style: GoogleFonts.crimsonPro(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            if (title.isNotEmpty && preview.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                preview,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: mutedColor,
                  height: 1.45,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 8),

            // Footer
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPrivate
                        ? Colors.grey.withOpacity(0.08)
                        : AppColors.aqua.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isPrivate
                          ? Colors.grey.withOpacity(0.25)
                          : AppColors.aqua.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    isPrivate ? 'Private' : 'Published',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isPrivate ? mutedColor : AppColors.aqua,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _relTime(createdAt),
                  style:
                      GoogleFonts.inter(fontSize: 11, color: mutedColor),
                ),
                const Spacer(),
                if (!isPrivate) ...[
                  Icon(Icons.favorite_border_rounded,
                      size: 13, color: mutedColor.withOpacity(0.5)),
                  const SizedBox(width: 3),
                  Text('$clapCount',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: mutedColor.withOpacity(0.7))),
                  const SizedBox(width: 10),
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 12, color: mutedColor.withOpacity(0.5)),
                  const SizedBox(width: 3),
                  Text('$replyCount',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: mutedColor.withOpacity(0.7))),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}