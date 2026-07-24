import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../atmosphere/atmosphere_overlay.dart';
import '../atmosphere/atmosphere_image_layer.dart';
import '../atmosphere/painters/dust_mote_painter.dart';
import '../providers/atmosphere_state.dart';
import '../providers/app_state.dart';
import 'library/library_panel.dart';
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
      if (elapsed.inMinutes >= 1) {
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
      _lockTimer = Timer(const Duration(minutes: 1), () async {
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
    await MenuPanel.show(context);
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

            // ── Persistent UI: Sun/Moon + Menu button ──────────────────────
            HomePersistentUI(onMenuTap: _openMenu),
          ],
        ),
      ),
    );
  }
}
