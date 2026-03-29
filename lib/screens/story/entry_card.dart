import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/entry.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY CARD
// Displays a single entry in the Story Panel list.
// Layout per Master Specification §3:
//   - "Entry N:" label (small, uppercase, letter-spaced)
//   - Entry title (large, bold italic, Crimson Pro 22pt)
//   - Preview text (2 lines max, ellipsis)
//   - Thumbnail image IF entry has images (120px height, edge-to-edge)
//   - Date + time spent metadata
//
// CRITICAL: NO images shown EXCEPT small thumbnails. Full images live
// only in Entry Read-Only and Editor.
//
// Long press shows context menu (delete, etc.)
// ─────────────────────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── "Entry N:" label ──────────────────────────────────────────
            Text(
              'Entry ${index + 1}:',
              style: AppTypography.entryLabel(mutedColor),
            ),
            const SizedBox(height: 4),

            // ── Entry title ───────────────────────────────────────────────
            Text(
              entry.title.isEmpty ? 'Untitled' : entry.title,
              style: AppTypography.entryCardTitle(textColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Preview text ──────────────────────────────────────────────
            if (entry.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.preview(),
                style: AppTypography.entryPreview(mutedColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Thumbnail (only if entry has images) ──────────────────────
            if (entry.hasImages || entry.hasHeaderImage) ...[
              const SizedBox(height: 10),
              _EntryThumbnail(entry: entry),
            ],

            // ── Metadata: date + time spent ───────────────────────────────
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  DateFormat('MMM d, yyyy').format(entry.createdAt),
                  style: AppTypography.metaSmall(mutedColor),
                ),
                if (entry.formattedTimeSpent.isNotEmpty) ...[
                  Text(
                    '  ·  ${entry.formattedTimeSpent}',
                    style: AppTypography.metaSmall(mutedColor),
                  ),
                ],
              ],
            ),
          ],
        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY THUMBNAIL
// 120px height preview of first available image.
// Shows header image first, then first inline image.
// Edge-to-edge (no horizontal padding), rounded corners.
// ─────────────────────────────────────────────────────────────────────────────

class _EntryThumbnail extends StatelessWidget {
  final Entry entry;

  const _EntryThumbnail({required this.entry});

  @override
  Widget build(BuildContext context) {
    // Prefer header image; fall back to first inline image
    final imagePath = entry.hasHeaderImage
        ? entry.headerImage!
        : entry.images.first.path;

    final file = File(imagePath);
    if (!file.existsSync()) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        file,
        width: double.infinity,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
