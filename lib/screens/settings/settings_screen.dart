import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/lock_service.dart';
import '../lock/pin_setup_screen.dart';
import '../period/period_tracker_screen.dart';
import '../../theme/app_typography.dart';
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
                    SettingsToggleTile(
                      icon: Icons.wb_twilight_rounded,
                      label: 'Dynamic Atmosphere',
                      description:
                          'App breathes with time of day and weather. Turn off for a static look.',
                      value: atmosphereState.isDynamicTheme,
                      isDark: isDark,
                      bg: bg,
                      onChanged: (v) => atmosphereState.setDynamicTheme(v),
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

              // ── APPEARANCE — FONT ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 10),
                        child: Text('READING FONT', style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w600, color: mutedColor, letterSpacing: 2.0,
                        )),
                      ),
                      SizedBox(
                        height: 46,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: AppTypography.fontDisplayNames.entries.map((entry) {
                            final isSelected = appState.preferredFont == entry.key;
                            return GestureDetector(
                              onTap: () => appState.setPreferredFont(entry.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.aqua.withOpacity(0.12) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: isSelected ? Border.all(color: AppColors.aqua.withOpacity(0.5)) : null,
                                ),
                                child: Text(
                                  entry.value,
                                  style: AppTypography.bodyTextFor(entry.key, isSelected ? AppColors.aqua : mutedColor, size: 14, height: 1),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── HEALTH TRACKING ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'HEALTH',
                  isDark: isDark,
                  bg: bg,
                  children: [
                    SettingsToggleTile(
                      icon: Icons.favorite_border_rounded,
                      label: 'Period Tracker',
                      description: 'Enable discreet cycle tracking in your journal.',
                      value: appState.isPeriodTrackerEnabled,
                      isDark: isDark,
                      bg: bg,
                      onChanged: (v) => appState.setPeriodTracker(v),
                    ),
                    if (appState.isPeriodTrackerEnabled)
                      SettingsNavTile(
                        icon: Icons.calendar_month_outlined,
                        label: 'Open Period Tracker',
                        description: 'View your cycle, history, and predictions.',
                        isDark: isDark,
                        bg: bg,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PeriodTrackerScreen()),
                        ),
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

  void _showLockOptions(BuildContext context, AppState appState) async {
    final isDark = appState.isDarkMode;
    final bg = isDark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    // Pre-fetch bio state before showing the sheet
    final bioAvailable = await LockService.instance.isBiometricAvailable();
    bool bioEnabled = await LockService.instance.isBiometricEnabled();
    if (!context.mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),

              // Change PIN
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

              // Biometric toggle — only shown when hardware is present
              if (bioAvailable)
                ListTile(
                  leading: Icon(
                    Icons.fingerprint_rounded,
                    color: bioEnabled ? AppColors.aqua : mutedColor,
                  ),
                  title: Text(
                    'Biometric Unlock',
                    style: GoogleFonts.inter(fontSize: 15, color: textColor),
                  ),
                  subtitle: Text(
                    bioEnabled
                        ? 'Fingerprint / Face ID active'
                        : 'Enable fingerprint or Face ID',
                    style: GoogleFonts.inter(fontSize: 12, color: mutedColor),
                  ),
                  trailing: Switch.adaptive(
                    value: bioEnabled,
                    onChanged: (v) async {
                      await LockService.instance.setBiometricEnabled(v);
                      setSheetState(() => bioEnabled = v);
                    },
                    activeThumbColor: AppColors.aqua,
                    activeTrackColor: AppColors.aqua,
                  ),
                ),

              // Remove lock
              ListTile(
                leading: const Icon(
                  Icons.lock_open_outlined,
                  color: AppColors.danger,
                ),
                title: Text(
                  'Remove App Lock',
                  style: GoogleFonts.inter(
                      fontSize: 15, color: AppColors.danger),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _confirmRemoveLock(context, appState);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
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
