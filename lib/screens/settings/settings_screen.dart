import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import 'settings_section.dart';
import 'settings_tile.dart';
import 'about_section.dart';

/// Settings screen — full-screen push, no back button (swipe left-to-right).
/// Covers: Appearance, Privacy, Tracking, About.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final atmosphereState = context.watch<AtmosphereState>();
    final isDark = appState.isDarkMode;
    final bg = atmosphereState.backgroundFor(isDark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final surfaceBg = isDark ? AppColors.warmDark : AppColors.warmWhite;

    return GestureDetector(
      // Swipe left-to-right to go back (no back button — spec rule)
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: surfaceBg,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: GoogleFonts.crimsonPro(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Make Flow yours.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: mutedColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── APPEARANCE ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'APPEARANCE',
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
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── PRIVACY ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'PRIVACY',
                  isDark: isDark,
                  bg: bg,
                  children: [
                    SettingsToggleTile(
                      icon: Icons.fingerprint_rounded,
                      label: 'Biometric Lock',
                      description:
                          'Require Face ID or fingerprint to open Flow.',
                      value: appState.isBiometricEnabled,
                      isDark: isDark,
                      bg: bg,
                      onChanged: (v) => appState.setBiometric(v),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── HEALTH TRACKING ──────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'HEALTH',
                  isDark: isDark,
                  bg: bg,
                  children: [
                    SettingsToggleTile(
                      icon: Icons.favorite_border_rounded,
                      label: 'Period Tracker',
                      description:
                          'Enable discreet cycle tracking in your journal.',
                      value: appState.isPeriodTrackerEnabled,
                      isDark: isDark,
                      bg: bg,
                      onChanged: (v) => appState.setPeriodTracker(v),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── DATA ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'DATA',
                  isDark: isDark,
                  bg: bg,
                  children: [
                    SettingsNavTile(
                      icon: Icons.download_outlined,
                      label: 'Export All Entries',
                      description:
                          'Download your journal as a ZIP of text files.',
                      isDark: isDark,
                      bg: bg,
                      onTap: () => _exportAll(context, appState),
                    ),
                    SettingsNavTile(
                      icon: Icons.delete_sweep_outlined,
                      label: 'Clear Deleted Entries',
                      description: 'Permanently remove everything in the bin.',
                      isDark: isDark,
                      bg: bg,
                      isDestructive: true,
                      onTap: () =>
                          _confirmClearBin(context, appState, isDark, bg),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── ABOUT ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: AboutSection(isDark: isDark, bg: bg),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Handlers ─────────────────────────────────────────────────────────────

  void _exportAll(BuildContext context, AppState appState) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export in progress…'),
        duration: Duration(seconds: 2),
      ),
    );
    appState.exportAllEntries();
  }

  void _confirmClearBin(
    BuildContext context,
    AppState appState,
    bool isDark,
    Color bg,
  ) {
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.warmDark : AppColors.warmWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear deleted entries?',
          style: GoogleFonts.crimsonPro(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        content: Text(
          'This cannot be undone. All entries in the bin will be permanently erased.',
          style: GoogleFonts.inter(fontSize: 14, color: mutedColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.teal),
            ),
          ),
          TextButton(
            onPressed: () {
              appState.clearDeletedEntries();
              Navigator.pop(context);
            },
            child: Text(
              'Clear All',
              style: GoogleFonts.inter(
                color: Colors.redAccent.withOpacity(0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
