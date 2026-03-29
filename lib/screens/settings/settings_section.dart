import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════════════════
// SETTINGS SECTION — groups tiles under a label header
// ════════════════════════════════════════════════════════════════════════════

class SettingsSection extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color bg;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.label,
    required this.isDark,
    required this.bg,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = AppColors.readableMuted(bg);
    final cardBg = isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.03);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: mutedColor,
                letterSpacing: 2.0,
              ),
            ),
          ),

          // Grouped card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: children.asMap().entries.map((entry) {
                final isLast = entry.key == children.length - 1;
                return Column(
                  children: [
                    entry.value,
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          height: 0.5,
                          color: isDark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.black.withOpacity(0.07),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SETTINGS TOGGLE TILE — on/off switch row
// ════════════════════════════════════════════════════════════════════════════

class SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final bool isDark;
  final Color bg;
  final ValueChanged<bool> onChanged;

  const SettingsToggleTile({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.isDark,
    required this.bg,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: mutedColor),
          ),
          const SizedBox(width: 14),

          // Label + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: mutedColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Toggle
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.teal,
            activeTrackColor: AppColors.teal,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SETTINGS NAV TILE — tappable row (leads to action or sub-screen)
// ════════════════════════════════════════════════════════════════════════════

class SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isDark;
  final Color bg;
  final VoidCallback onTap;
  final bool isDestructive;

  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.isDark,
    required this.bg,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final labelColor =
        isDestructive ? Colors.redAccent.withOpacity(0.85) : textColor;
    final iconColor =
        isDestructive ? Colors.redAccent.withOpacity(0.7) : mutedColor;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.07)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),

            // Label + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: mutedColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron (not shown for destructive)
            if (!isDestructive)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: mutedColor.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }
}
