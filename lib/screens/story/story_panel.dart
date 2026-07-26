import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/entry.dart';
import '../../models/story.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../services/image_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_colors.dart';
import '../editor/editor_screen.dart';
import '../entry_read/entry_read_screen.dart';
import '../story_cover.dart';
import 'entry_card.dart';
import 'story_first_time.dart';

class StoryPanel extends StatelessWidget {
  const StoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (!appState.hasStories) return const StoryFirstTime();
        return _StoryPanelContent(appState: appState);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StoryPanelContent extends StatefulWidget {
  final AppState appState;
  const _StoryPanelContent({required this.appState});

  @override
  State<_StoryPanelContent> createState() => _StoryPanelContentState();
}

class _StoryPanelContentState extends State<_StoryPanelContent> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _addEntry(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      final entry = await appState.createEntry();
      if (!context.mounted) return;
      final result = await Navigator.of(context).push<Entry>(
        MaterialPageRoute(builder: (_) => EditorScreen(entry: entry)),
      );
      if (result != null && context.mounted) appState.refreshEntries();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to add entry: $e')));
    }
  }

  void _openEntry(BuildContext context, Entry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EntryReadScreen(entry: entry)),
    );
  }

  void _showStoryOptions(BuildContext context, Story story) {
    final appState = context.read<AppState>();
    final dark = appState.isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: mutedColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(story.title,
                    style: GoogleFonts.crimsonPro(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: mutedColor),
              title: Text('Rename Story',
                  style: GoogleFonts.inter(fontSize: 15, color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                _showRename(context, story, appState);
              },
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, color: mutedColor),
              title: Text(
                story.coverImage != null ? 'Change Cover' : 'Add Cover Image',
                style: GoogleFonts.inter(fontSize: 15, color: textColor),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _changeCover(context, story, appState);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRename(BuildContext context, Story story, AppState appState) {
    final titleCtrl = TextEditingController(text: story.title);
    final descCtrl = TextEditingController(text: story.description);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Story',
            style: GoogleFonts.crimsonPro(
                fontSize: 22, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Story title')),
            const SizedBox(height: 12),
            TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(hintText: 'Description (optional)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final t = titleCtrl.text.trim();
              if (t.isNotEmpty) {
                appState.updateStory(story.copyWith(
                    title: t, description: descCtrl.text.trim()));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeCover(
      BuildContext context, Story story, AppState appState) async {
    final ok = await PermissionService.instance.ensurePhotos(context);
    if (!ok || !context.mounted) return;
    final path = await ImageService.instance.pickAndSave(
      context: context,
      allowCrop: true,
      cropAspectRatioX: 3,
      cropAspectRatioY: 2,
    );
    if (path != null) appState.updateStory(story.copyWith(coverImage: path));
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;
    final dark = widget.appState.isDarkMode;
    final entries = widget.appState.currentEntries;
    final story = widget.appState.activeStory!;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;

    // Button always visible
    final buttonVisible = true;

    return Stack(
      children: [
        // ── Main scrollable content ────────────────────────────────────
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: topPad + 60),
            ),

            // ── Hero Card ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _HeroCard(
                  story: story,
                  dark: dark,
                  onTap: () => _showStoryOptions(context, story),
                ),
              ),
            ),

            // ── Section header ─────────────────────────────────────
            if (entries.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        'Recent Entries',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${entries.length} ${entries.length == 1 ? "entry" : "entries"}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: mutedColor.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Entry list or empty ────────────────────────────────
            if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(mutedColor: mutedColor),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _StaggeredEntry(
                    delay: Duration(milliseconds: i * 55),
                    child: EntryCard(
                      entry: entries[i],
                      index: i,
                      onTap: () => _openEntry(context, entries[i]),
                    ),
                  ),
                  childCount: entries.length,
                ),
              ),

            SliverToBoxAdapter(child: SizedBox(height: botPad + 110)),
          ],
        ),

        // ── Floating "+ New Entry" button ──────────────────────────────
        Positioned(
          bottom: botPad + 20,
          left: 32,
          right: 32,
          child: AnimatedOpacity(
            opacity: buttonVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: !buttonVisible,
              child: _FloatingAddButton(onTap: () => _addEntry(context)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final Story story;
  final bool dark;
  final VoidCallback onTap;

  const _HeroCard({
    required this.story,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 224,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background cover
              StoryCoverWidget(
                storyTitle: story.title,
                imagePath: story.coverImage,
                width: double.infinity,
                height: 224,
              ),

              // Bottom gradient overlay
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x4D000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.18, 0.52, 1.0],
                  ),
                ),
              ),

              // Text content
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      story.title,
                      style: GoogleFonts.crimsonPro(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                        shadows: [
                          Shadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 10)
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (story.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        story.description,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.78),
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

// ── Floating Add Button ───────────────────────────────────────────────────────

class _FloatingAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FloatingAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AtmosphereState>().accentColor;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: Colors.white.withOpacity(0.30), width: 0.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: accent),
                const SizedBox(width: 8),
                Text(
                  'New Entry',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.95),
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

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Color mutedColor;
  const _EmptyState({required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note_rounded,
              size: 48, color: mutedColor.withOpacity(0.28)),
          const SizedBox(height: 16),
          Text(
            'No entries yet.',
            style: GoogleFonts.crimsonPro(
              fontSize: 20,
              fontStyle: FontStyle.italic,
              color: mutedColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the button below to start writing.',
            style: GoogleFonts.inter(
                fontSize: 13, color: mutedColor.withOpacity(0.4)),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Staggered entrance ────────────────────────────────────────────────────────

class _StaggeredEntry extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _StaggeredEntry({required this.child, required this.delay});

  @override
  State<_StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<_StaggeredEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
