import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../settings/settings_screen.dart';
import '../search/search_screen.dart';
import '../period/period_tracker_screen.dart';
import 'archived_tasks_sheet.dart';

/// Bottom action rows inside the menu panel.
/// Covers: Archived Tasks, Deleted Entries (Bin), Settings, Lock app.
class MenuActions extends StatelessWidget {
  final bool isDark;
  final Color bg;

  const MenuActions({super.key, required this.isDark, required this.bg});

  @override
  Widget build(BuildContext context) {
    final mutedColor = AppColors.readableMuted(bg);
    final textColor = AppColors.readableText(bg);
    final appState = context.watch<AppState>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Text(
              'MORE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: mutedColor,
                letterSpacing: 2.0,
              ),
            ),
          ),

          // Search
          _ActionTile(
            icon: Icons.search_rounded,
            label: 'Search',
            isDark: isDark,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () async {
              Navigator.of(context).pop();
              await Future.delayed(const Duration(milliseconds: 150));
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              }
            },
          ),

          // Period tracker (only when enabled)
          if (appState.isPeriodTrackerEnabled)
            _ActionTile(
              icon: Icons.favorite_border_rounded,
              label: 'Period Tracker',
              isDark: isDark,
              textColor: textColor,
              mutedColor: mutedColor,
              onTap: () async {
                Navigator.of(context).pop();
                await Future.delayed(const Duration(milliseconds: 150));
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PeriodTrackerScreen()),
                  );
                }
              },
            ),

          // Archived tasks
          _ActionTile(
            icon: Icons.inventory_2_outlined,
            label: 'Archived Tasks',
            isDark: isDark,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () async {
              Navigator.of(context).pop();
              await Future.delayed(const Duration(milliseconds: 150));
              if (context.mounted) {
                ArchivedTasksSheet.show(context);
              }
            },
          ),

          // Deleted entries bin
          _ActionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Deleted Entries',
            isDark: isDark,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () {
              Navigator.of(context).pop();
              _showDeletedEntriesSheet(context, appState, isDark, bg);
            },
          ),

          // Settings
          _ActionTile(
            icon: Icons.tune_rounded,
            label: 'Settings',
            isDark: isDark,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () async {
              Navigator.of(context).pop();
              await Future.delayed(const Duration(milliseconds: 150));
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              }
            },
          ),

          // Lock (visible only when PIN is set)
          if (appState.isLockEnabled)
            _ActionTile(
              icon: Icons.lock_outline_rounded,
              label: 'Lock Flow',
              isDark: isDark,
              textColor: textColor,
              mutedColor: mutedColor,
              onTap: () {
                Navigator.of(context).pop();
                appState.lockApp();
              },
            ),
        ],
      ),
    );
  }

  void _showDeletedEntriesSheet(
    BuildContext context,
    AppState appState,
    bool isDark,
    Color bg,
  ) {
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final sheetBg = isDark ? AppColors.warmDark : AppColors.warmWhite;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        // Use Consumer so the sheet rebuilds when entries are restored/deleted
        return Consumer<AppState>(
          builder: (context, appState, _) {
            final deleted = appState.allEntries.where((e) => e.isDeleted).toList();
            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Text(
                      'Deleted Entries',
                      style: GoogleFonts.crimsonPro(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (deleted.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Nothing deleted.',
                          style: GoogleFonts.crimsonPro(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: mutedColor,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: deleted.length,
                        itemBuilder: (_, i) {
                          final entry = deleted[i];
                          return ListTile(
                            title: Text(
                              entry.title.isEmpty ? 'Untitled' : entry.title,
                              style: GoogleFonts.crimsonPro(
                                fontSize: 17,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              entry.preview(60),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: mutedColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Restore
                                IconButton(
                                  icon: const Icon(
                                    Icons.restore_rounded,
                                    color: AppColors.aqua,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    appState.restoreEntry(entry.id);
                                    // Don't pop — let Consumer rebuild the list
                                  },
                                ),
                                // Permanent delete
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_forever_rounded,
                                    color: Colors.redAccent.withOpacity(0.75),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    appState.permanentlyDeleteEntry(entry.id);
                                    // Don't pop — let Consumer rebuild the list
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Single action tile ──────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: mutedColor,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
