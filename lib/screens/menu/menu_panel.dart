// ignore_for_file: non_constant_identifier_names, constant_identifier_names
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/backup_service.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../providers/community_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../settings/appearance_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/themes_screen.dart';
import '../settings/about_section.dart';
import '../community/profile_screen.dart';

class MenuPanel extends StatelessWidget {
  final BuildContext outerContext;
  final VoidCallback? onNavigateToLibrary;
  final VoidCallback? onCreateEntry;

  const MenuPanel({
    super.key,
    required this.outerContext,
    this.onNavigateToLibrary,
    this.onCreateEntry,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onNavigateToLibrary,
    VoidCallback? onCreateEntry,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      barrierColor: Colors.black.withOpacity(0.22),
      transitionDuration: const Duration(milliseconds: 290),
      pageBuilder: (ctx, anim, secAnim) => MenuPanel(
        outerContext: context,
        onNavigateToLibrary: onNavigateToLibrary,
        onCreateEntry: onCreateEntry,
      ),
      transitionBuilder: (ctx, anim, secAnim, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  void _navigate(Widget screen) {
    Navigator.of(outerContext).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final communityState = context.watch<CommunityState>();
    final isDark = appState.isDarkMode;
    final bg = isDark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final divColor =
        isDark ? AppColors.dividerDark : AppColors.dividerLight;

    final displayName = communityState.profileDisplayName ??
        (SupabaseService.instance.userEmail?.split('@').first ?? 'You');
    final imagePath = communityState.profileImagePath;
    final hasImage = imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync();

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.62,
        height: double.infinity,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              color: bg.withOpacity(0.82),
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),

              // ── Header: "Menu" + X ────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 20, 8),
                child: Row(
                  children: [
                    Text('Menu',
                        style: GoogleFonts.crimsonPro(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: -0.3,
                        )),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.black.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 17, color: mutedColor),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Profile card ──────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _navigate(const ProfileScreen());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        ClipOval(
                          child: hasImage
                              ? Image.file(File(imagePath!),
                                  width: 46, height: 46, fit: BoxFit.cover)
                              : Container(
                                  width: 46,
                                  height: 46,
                                  color: AppColors.aqua.withOpacity(0.15),
                                  child: Center(
                                    child: Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.inter(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.aqua,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'View profile',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: AppColors.aqua),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 20, color: mutedColor.withOpacity(0.5)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              Divider(
                  color: divColor,
                  thickness: 0.5,
                  indent: 24,
                  endIndent: 24),
              const SizedBox(height: 10),

              // ── Journal section ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Journal',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: mutedColor,
                        letterSpacing: 0.4,
                      )),
                ),
              ),

              _MenuItem(
                icon: Icons.menu_book_outlined,
                label: 'Library',
                subtitle: 'My stories and entries',
                isDark: isDark,
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: () {
                  Navigator.of(context).pop();
                  onNavigateToLibrary?.call();
                },
              ),

              _MenuItem(
                icon: Icons.edit_outlined,
                label: 'Write',
                subtitle: 'Create a new entry',
                isDark: isDark,
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: () {
                  Navigator.of(context).pop();
                  onCreateEntry?.call();
                },
              ),

              const SizedBox(height: 6),
              Divider(
                  color: divColor,
                  thickness: 0.5,
                  indent: 24,
                  endIndent: 24),
              const SizedBox(height: 10),

              // ── General section ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('General',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: mutedColor,
                        letterSpacing: 0.4,
                      )),
                ),
              ),

              _MenuItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                subtitle: 'Privacy, app lock & security',
                isDark: isDark,
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: () {
                  Navigator.of(context).pop();
                  _navigate(const SettingsScreen());
                },
              ),

              _MenuItem(
                icon: Icons.palette_outlined,
                label: 'Appearance',
                subtitle: 'Theme, font, dark mode & atmosphere',
                isDark: isDark,
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: () {
                  Navigator.of(context).pop();
                  _navigate(const AppearanceScreen());
                },
              ),

              _MenuItem(
                icon: Icons.download_outlined,
                label: 'Backup & Export',
                subtitle: 'Full backup, export & data management',
                isDark: isDark,
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: () {
                  Navigator.of(context).pop();
                  _showBackupSheet(isDark, bg);
                },
              ),

              _MenuItem(
                icon: Icons.info_outline_rounded,
                label: 'About Sanctuary',
                subtitle: 'Learn more about Sanctuary',
                isDark: isDark,
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: () {
                  Navigator.of(context).pop();
                  _showAbout(isDark, bg);
                },
              ),

              const SizedBox(height: 14),

              // ── Tagline card ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_stories_outlined,
                          size: 15, color: mutedColor.withOpacity(0.7)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'A space for thoughtful writings\nand meaningful connections.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: mutedColor,
                            height: 1.55,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  ),
),
),
);
  }

  void _showBackupSheet(bool isDark, Color bg) {
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    showModalBottomSheet<void>(
      context: outerContext,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
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
              const SizedBox(height: 16),
              Text('Backup & Export',
                  style: GoogleFonts.crimsonPro(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
              const SizedBox(height: 4),
              Text('Protect and export your writing.',
                  style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
              const SizedBox(height: 20),
              _BackupTile(
                icon: Icons.backup_outlined,
                label: 'Full Backup (JSON)',
                subtitle: 'Export all data as a restorable file',
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: () {
                  Navigator.pop(ctx);
                  BackupService.instance.exportBackup(outerContext);
                },
              ),
              _BackupTile(
                icon: Icons.download_outlined,
                label: 'Export Entries as JSON',
                subtitle: 'Readable export of all journal entries',
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: () {
                  Navigator.pop(ctx);
                  BackupService.instance.exportEntriesAsJson(outerContext);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout(bool isDark, Color bg) {
    showModalBottomSheet(
      context: outerContext,
      backgroundColor: bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (ctx, sc) => SingleChildScrollView(
          controller: sc,
          child: Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 40),
            child: AboutSection(isDark: isDark, bg: bg),
          ),
        ),
      ),
    );
  }
}

// ── Menu item ─────────────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: mutedColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        )),
                    Text(subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: mutedColor,
                        )),
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

// ── Backup tile ────────────────────────────────────────────────────────────

class _BackupTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _BackupTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: mutedColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor)),
                  Text(subtitle,
                      style:
                          GoogleFonts.inter(fontSize: 12, color: mutedColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: mutedColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}