import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/lock_service.dart';
import '../lock/pin_setup_screen.dart';
import '../../data/backup_service.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
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
    final surfaceBg = atmosphereState.backgroundFor(isDark);

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
                    SettingsNavTile(
                      icon: Icons.lock_outline_rounded,
                      label: appState.isLockEnabled
                          ? 'App Lock · On'
                          : 'App Lock',
                      description: appState.isLockEnabled
                          ? 'PIN lock is active. Tap to change or remove.'
                          : 'Set a PIN to protect your sanctuary.',
                      isDark: isDark,
                      bg: bg,
                      onTap: () => appState.isLockEnabled
                          ? _showLockOptions(context, appState)
                          : _setupLock(context),
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

              // ── DATA ─────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'DATA',
                  isDark: isDark,
                  bg: bg,
                  children: [
                    SettingsNavTile(
                      icon: Icons.backup_outlined,
                      label: 'Full Backup (JSON)',
                      description:
                          'Export all data as a restorable JSON file.',
                      isDark: isDark,
                      bg: bg,
                      onTap: () =>
                          BackupService.instance.exportBackup(context),
                    ),
                    SettingsNavTile(
                      icon: Icons.download_outlined,
                      label: 'Export Entries as JSON',
                      description:
                          'Export all journal entries as a readable JSON file.',
                      isDark: isDark,
                      bg: bg,
                      onTap: () =>
                          BackupService.instance.exportEntriesAsJson(context),
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
void _setupLock(BuildContext context) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
  }

  void _showLockOptions(BuildContext context, AppState appState) {
    final isDark = appState.isDarkMode;
    final bg = isDark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: mutedColor),
              title: Text('Change PIN',
                  style: GoogleFonts.inter(fontSize: 15, color: textColor)),
              onTap: () async {
                Navigator.pop(ctx);
                await Future.delayed(const Duration(milliseconds: 150));
                if (context.mounted) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const PinSetupScreen(mode: PinSetupMode.change),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_open_outlined,
                  color: AppColors.danger),
              title: Text('Remove App Lock',
                  style: GoogleFonts.inter(
                      fontSize: 15, color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                await _confirmRemoveLock(context, appState);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveLock(
      BuildContext context, AppState appState) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove App Lock?'),
        content:
            const Text('Your PIN will be deleted and Flow will open without protection.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await LockService.instance.removePin();
      appState.setLockEnabled(false);
    }
  }

  // ── Handlers ─────────────────────────────────────────────────────────────

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
              style: GoogleFonts.inter(color: AppColors.aqua),
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
