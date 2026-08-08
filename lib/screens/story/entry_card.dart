import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/editor_block.dart';
import '../../models/entry.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';

class EntryCard extends StatelessWidget {
  final Entry entry;
  final int index;
  final VoidCallback onTap;

  const EntryCard({
    super.key,
    required this.entry,
    required this.index,
    required this.onTap,
  });

  String _readTime() {
    String text = entry.content;
    if (entry.blocksJson != null && entry.blocksJson!.isNotEmpty) {
      try {
        text = plainTextFromBlocks(deserializeBlocks(entry.blocksJson!));
      } catch (_) {}
    }
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (words < 15) return '';
    return '${(words / 200).ceil().clamp(1, 99)} min';
  }

  String _entryDate() {
    final diff = DateTime.now().difference(entry.createdAt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(entry.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final divColor =
        dark ? AppColors.dividerDark : AppColors.dividerLight;
    final readTime = _readTime();

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Content ───────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title.isEmpty ? 'Untitled' : entry.title,
                        style: GoogleFonts.crimsonPro(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (entry.preview().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.preview(90),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: mutedColor,
                            height: 1.45,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Text(
                            _entryDate(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: mutedColor.withOpacity(0.7),
                            ),
                          ),
                          if (readTime.isNotEmpty)
                            Text(
                              '  ·  $readTime',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: mutedColor.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: divColor,
            thickness: 0.5,
            height: 0,
            indent: 20,
            endIndent: 20,
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final appState = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Delete entry',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                appState.deleteEntry(entry.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}