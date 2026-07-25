import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/lock_service.dart';
import '../lock/pin_setup_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_colors.dart';
import 'about_section.dart';
import 'settings_section.dart';
import 'settings_tile.dart';

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

    return GestureDetector(
      // Swipe left-to-right to go back (no back button — spec rule)
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
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

              // ── PRIVACY ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'PRIVACY',
                  isDark: isDark,
                  bg: bg,
                  children: [
                    SettingsNavTile(
                      icon: Icons.lock_outline_rounded,
                      label:
                          appState.isLockEnabled ? 'App Lock · On' : 'App Lock',
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

              // ── HELP ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SettingsSection(
                  label: 'HELP',
                  isDark: isDark,
                  bg: bg,
                  children: [
                    SettingsNavTile(
                      icon: Icons.play_circle_outline_rounded,
                      label: 'View Tutorial Again',
                      description: 'Restart the onboarding walkthrough.',
                      isDark: isDark,
                      bg: bg,
                      onTap: () async {
                        await context.read<AppState>().resetOnboarding();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const OnboardingScreen()),
                          (route) => false,
                        );
                      },
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
                  style:
                      GoogleFonts.inter(fontSize: 15, color: AppColors.danger),
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
        content: const Text(
            'Your PIN will be deleted and Flow will open without protection.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await LockService.instance.removePin();
      appState.setLockEnabled(false);
    }
  }
}
