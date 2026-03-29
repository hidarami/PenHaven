import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY FOOTER
// Appears at the bottom of the Read-Only entry view.
// Shows: session time spent (Proof of Work) + last updated date.
// 11pt, 50% opacity — small, muted, unobtrusive.
// Only rendered if at least one piece of metadata exists.
// ─────────────────────────────────────────────────────────────────────────────

class EntryFooter extends StatelessWidget {
  final Entry entry;
  final bool isDark;

  const EntryFooter({super.key, required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hasTimeSpent = entry.formattedTimeSpent.isNotEmpty;
    final updatedStr = _updatedLabel();

    // Nothing to show
    if (!hasTimeSpent && updatedStr == null) return const SizedBox.shrink();

    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thin divider before footer
          Divider(
            color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
                .withOpacity(0.5),
            thickness: 0.5,
            height: 24,
          ),

          // Metadata row
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (hasTimeSpent)
                _FooterItem(
                  icon: Icons.timer_outlined,
                  label: entry.formattedTimeSpent,
                  color: mutedColor,
                ),
              if (updatedStr != null)
                _FooterItem(
                  icon: Icons.edit_outlined,
                  label: updatedStr,
                  color: mutedColor,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns "Updated Mar 2" if updatedAt differs from createdAt by >1 min.
  String? _updatedLabel() {
    final diff = entry.updatedAt.difference(entry.createdAt);
    if (diff.inMinutes < 1) return null;
    return 'Updated ${DateFormat('MMM d').format(entry.updatedAt)}';
  }
}

class _FooterItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FooterItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.metaSmall(color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color.withOpacity(0.5)),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }
}
