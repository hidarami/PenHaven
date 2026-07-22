import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../atmosphere/atmosphere_overlay.dart';
import '../atmosphere/atmosphere_image_layer.dart';
import '../atmosphere/painters/dust_mote_painter.dart';
import '../providers/atmosphere_state.dart';
import '../providers/app_state.dart';
import 'library/library_panel.dart';
import 'story/story_panel.dart';
import 'work_desk/work_desk_panel.dart';
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

  @override
  void initState() {
    super.initState();
    // CRITICAL: initialPage: 1 — opens to Story Panel, NOT Library
    _pageController = PageController(initialPage: 1);
    WidgetsBinding.instance.addObserver(this);

    // Run mercy archive on app open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().runMercyArchive();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Auto-lock when app goes to background (if biometric is enabled)
    if (state == AppLifecycleState.paused) {
      final appState = context.read<AppState>();
      if (appState.isBiometricEnabled && !appState.isLocked) {
        appState.lockApp();
      }
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
                const WorkDeskPanel(), // Panel 2 — rightmost
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
