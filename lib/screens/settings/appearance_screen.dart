import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'fonts_screen.dart';
import 'settings_section.dart';
import 'settings_tile.dart';
import 'themes_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APPEARANCE SCREEN
// All visual/display settings: dark mode, atmosphere, theme, reading font.
// Migrated from Settings so menu > Appearance is the canonical home.
// ─────────────────────────────────────────────────────────────────────────────

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final atmo = context.watch<AtmosphereState>();
    final isDark = appState.isDarkMode;
    final bg = atmo.backgroundFor(isDark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(Icons.chevron_left_rounded,
                            size: 28, color: mutedColor),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appearance',
                              style: GoogleFonts.crimsonPro(
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Customize how PenHaven looks and feels.',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: mutedColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── DISPLAY ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'DISPLAY',
                  isDark: isDark,
                  bg: bg,
                  children: [
                    SettingsToggleTile(
                      icon: Icons.dark_mode_outlined,
                      label: 'Dark Mode',
                      description: 'Switch between warm light and warm dark.',
                      value: isDark,
                      isDark: isDark,
                      bg: bg,
                      onChanged: (v) => appState.setDarkMode(v),
                    ),
                    SettingsToggleTile(
                      icon: Icons.wb_twilight_rounded,
                      label: 'Dynamic Atmosphere',
                      description:
                          'App breathes with time of day and weather. Turn off for a static look.',
                      value: atmo.isDynamicTheme,
                      isDark: isDark,
                      bg: bg,
                      onChanged: (v) => atmo.setDynamicTheme(v),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── SIMPLICITY ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'SIMPLICITY',
                  isDark: isDark,
                  bg: bg,
                  children: [
                    SettingsToggleTile(
                      icon: Icons.crop_free_rounded,
                      label: appState.isMinimalistMode
                          ? 'Minimalist Mode · On'
                          : 'Minimalist Mode',
                      description: appState.isMinimalistMode
                          ? 'A simpler toolbar, no cover art, Sanctuary hidden. '
                              'Turn off anytime — nothing you added is deleted.'
                          : 'Hide Sanctuary, cover art, and extra toolbar buttons '
                              'for a calmer, distraction-free writing space.',
                      value: appState.isMinimalistMode,
                      isDark: isDark,
                      bg: bg,
                      onChanged: (v) => appState.setMinimalistMode(v),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── THEME ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'THEME',
                  isDark: isDark,
                  bg: bg,
                  children: [
                    SettingsNavTile(
                      icon: Icons.palette_outlined,
                      label: _themeLabel(atmo),
                      description:
                          'Manual themes override the atmosphere background.',
                      isDark: isDark,
                      bg: bg,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ThemesScreen()),
                      ),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── READING FONT ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'READING FONT',
                  isDark: isDark,
                  bg: bg,
                  children: [
                    SettingsNavTile(
                      icon: Icons.font_download_outlined,
                      label: AppTypography
                              .fontDisplayNames[appState.preferredFont] ??
                          'Crimson Pro',
                      description:
                          'Choose how your journal entries feel to read.',
                      isDark: isDark,
                      bg: bg,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FontsScreen()),
                      ),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
        ),
      ),
    );
  }

  String _themeLabel(AtmosphereState atmo) {
    if (atmo.manualTheme == null) return 'Dynamic (Auto)';
    for (final t in AppColors.manualThemes) {
      if (t.key == atmo.manualTheme) return t.name;
    }
    return 'Dynamic (Auto)';
  }
}
