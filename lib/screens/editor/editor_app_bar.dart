import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/entry.dart';
import '../../providers/app_state.dart';
import '../../providers/editor_state.dart';
import '../../services/export_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR APP BAR
// Custom top bar for the editor. NOT a Material AppBar.
//
// Left:  "<" back chevron — returns to Read-Only (NOT to Story Panel)
// Center: (empty — title is in the editor body)
// Right: "..." overflow menu
//
// CRITICAL: Back chevron goes to Read-Only, not all the way to Story Panel.
// ─────────────────────────────────────────────────────────────────────────────

class EditorAppBar extends StatelessWidget {
  final Entry entry;
  final VoidCallback onBack;
  final ValueChanged<Entry> onEntryChanged;

  const EditorAppBar({
    super.key,
    required this.entry,
    required this.onBack,
    required this.onEntryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final topPadding = MediaQuery.of(context).padding.top;
    final editorState = context.watch<EditorState>();

    return Container(
      padding: EdgeInsets.fromLTRB(8, topPadding + 4, 8, 4),
      child: Row(
        children: [
          // ── Back chevron — to Read-Only ──────────────────────────────────
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, size: 28, color: mutedColor),
            onPressed: onBack,
            tooltip: 'Back to read view',
          ),

          const Spacer(),

          // ── Word count (live) ─────────────────────────────────────────────
          Text(
            '${editorState.wordCount} words',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: mutedColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(width: 8),

          // ── Overflow menu ─────────────────────────────────────────────────
          IconButton(
            icon: Icon(Icons.more_horiz, size: 22, color: mutedColor),
            onPressed: () => _showOverflowMenu(context),
          ),
        ],
      ),
    );
  }

  void _showOverflowMenu(BuildContext context) {
    final appState = context.read<AppState>();

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),

            // Export options
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Export as TXT'),
              onTap: () {
                Navigator.pop(ctx);
                ExportService.instance.exportAsTxt(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(ctx);
                ExportService.instance.exportAsPdf(entry);
              },
            ),

            const Divider(height: 1),

            // Session log
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Session log'),
              subtitle: Text(
                entry.formattedTimeSpent.isNotEmpty
                    ? 'Total: ${entry.formattedTimeSpent}'
                    : 'No time logged yet',
              ),
              onTap: () => Navigator.pop(ctx),
            ),

            // Delete header image
            if (entry.hasHeaderImage)
              ListTile(
                leading: const Icon(Icons.image_not_supported_outlined),
                title: const Text('Remove header image'),
                onTap: () {
                  Navigator.pop(ctx);
                  onEntryChanged(entry.copyWith(clearHeaderImage: true));
                },
              ),

            const Divider(height: 1),

            // Delete entry
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
              ),
              title: const Text(
                'Delete entry',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, appState);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState appState) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This entry will be moved to the Bin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              await appState.deleteEntry(entry.id);
              if (context.mounted) {
                // Pop editor AND read-only to return to Story Panel
                Navigator.of(context)
                  ..pop() // Pop editor
                  ..pop(); // Pop read-only
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
