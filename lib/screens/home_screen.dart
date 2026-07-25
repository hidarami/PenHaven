import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../atmosphere/atmosphere_overlay.dart';
import '../atmosphere/atmosphere_image_layer.dart';
import '../atmosphere/painters/dust_mote_painter.dart';
import '../models/entry.dart';
import '../providers/atmosphere_state.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import 'community/community_search_screen.dart';
import 'editor/editor_screen.dart';
import 'library/library_panel.dart';
import 'search/search_screen.dart';
import 'story/story_panel.dart';
import 'community/community_panel.dart';
import 'menu/menu_panel.dart';
import 'home_persistent_ui.dart';
import 'lock_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN
// Root of the app after splash. Contains the 3-panel horizontal PageView.
// Panel order: Library (0) | Story/Home (1) | Work Desk (2)
// App opens to Panel 1 (Story Panel) per Master Specification §2.
//
// Persistent UI (Sun/Moon top-left, Glass menu top-right) is overlaid
// via HomePersistentUI which sits above the PageView in a Stack.
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final PageController _pageController;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    // CRITICAL: initialPage: 1 — opens to Story Panel, NOT Library
    _pageController = PageController(initialPage: 1);
    WidgetsBinding.instance.addObserver(this);

    // Run mercy archive on app open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().runMercyArchive();
      _checkPendingLock();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkPendingLock() async {
    // Check if app was backgrounded for more than 1 minute
    final prefs = await SharedPreferences.getInstance();
    final backgroundedAt = prefs.getInt('appBackgroundedAt');
    if (backgroundedAt != null) {
      final backgroundedTime =
          DateTime.fromMillisecondsSinceEpoch(backgroundedAt);
      final elapsed = DateTime.now().difference(backgroundedTime);
      if (elapsed.inMinutes >= 5) {
        final appState = context.read<AppState>();
        if (appState.isLockEnabled && !appState.isLocked) {
          appState.lockApp();
        }
      }
      // Clear the timestamp
      await prefs.remove('appBackgroundedAt');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // App going to background - start timer and store timestamp
      _lockTimer?.cancel();
      _lockTimer = Timer(const Duration(minutes: 5), () async {
        final appState = context.read<AppState>();
        if (appState.isLockEnabled && !appState.isLocked) {
          appState.lockApp();
        }
      });
      // Store timestamp for handling app termination
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(
            'appBackgroundedAt', DateTime.now().millisecondsSinceEpoch);
      });
    } else if (state == AppLifecycleState.resumed) {
      // App returned - cancel timer and clear timestamp
      _lockTimer?.cancel();
      _lockTimer = null;
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('appBackgroundedAt');
      });
    }
  }

  void _openMenu() async {
    await MenuPanel.show(
      context,
      onNavigateToLibrary: () {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      },
      onCreateEntry: _createNewEntry,
    );
  }

  Future<void> _createNewEntry() async {
    final appState = context.read<AppState>();
    if (!appState.hasStories || appState.activeStory == null) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Create a story first in your Library.')),
      );
      return;
    }
    try {
      final entry = await appState.createEntry();
      if (!mounted) return;
      final result = await Navigator.of(context).push<Entry>(
        MaterialPageRoute(builder: (_) => EditorScreen(entry: entry)),
      );
      if (result != null && mounted) appState.refreshEntries();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create entry: $e')),
      );
    }
  }

  void _openSearch() {
    final dark = context.read<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Search',
                  style: GoogleFonts.crimsonPro(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
              const SizedBox(height: 2),
              Text('Where would you like to search?',
                  style:
                      GoogleFonts.inter(fontSize: 13, color: mutedColor)),
              const SizedBox(height: 18),

              // My Entries
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SearchScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: mutedColor.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.aqua.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.book_outlined,
                            color: AppColors.aqua, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('My Entries',
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textColor)),
                            Text('Search within your journal',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: mutedColor)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: mutedColor.withOpacity(0.5), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Community
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CommunitySearchScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: mutedColor.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.aqua.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people_outline_rounded,
                            color: AppColors.aqua, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Community',
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textColor)),
                            Text(
                                'Search all published entries from writers',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: mutedColor)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: mutedColor.withOpacity(0.5), size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dark = appState.isDarkMode;
    final atmo = context.watch<AtmosphereState>();

    // Lock screen overlay — shown when user locks via menu
    if (appState.isLocked) {
      return const LockScreen();
    }

    return Scaffold(
      backgroundColor: atmo.backgroundFor(dark),
      body: AtmosphereBackground(
        child: Stack(
          children: [
            // ── Three-panel PageView ────────────────────────────────────────
            PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              children: [
                const LibraryPanel(), // Panel 0 — leftmost
                const StoryPanel(), // Panel 1 — HOME (default)
                const CommunityPanel(), // Panel 2 — rightmost
              ],
            ),

            // ── Atmosphere visual overlay (glow painters) ──────────────────
            const AtmosphereOverlay(),

            // ── Atmosphere image layer (PNG window/shadow overlays) ─────────
            const AtmosphereImageLayer(),

            // ── 3PM dust mote easter egg ───────────────────────────────────
            const DustMoteOverlay(),

            // ── Persistent UI: Sun/Moon + Search + Menu button ─────────────
            HomePersistentUI(
                onMenuTap: _openMenu, onSearchTap: _openSearch),
          ],
        ),
      ),
    );
  }
}
