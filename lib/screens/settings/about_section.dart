import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';

/// The "About" section at the bottom of Settings.
/// Communicates the app's philosophy and credits. Warm, human, no bullet points.
class AboutSection extends StatelessWidget {
  final bool isDark;
  final Color bg;

  const AboutSection({super.key, required this.isDark, required this.bg});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final accentColor = AppColors.teal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'ABOUT',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: mutedColor,
                letterSpacing: 2.0,
              ),
            ),
          ),

          // About card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App name + version
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Flow',
                      style: GoogleFonts.crimsonPro(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'v1.0',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Philosophy quote
                Text(
                  '"A quiet space for your words.\n'
                  'No streaks. No guilt. No judgment.\n'
                  'Just you, and the time of day."',
                  style: GoogleFonts.crimsonPro(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    color: textColor.withOpacity(0.75),
                    height: 1.65,
                    letterSpacing: 0.1,
                  ),
                ),

                const SizedBox(height: 24),

                // Divider
                Container(
                  height: 0.5,
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
                ),

                const SizedBox(height: 20),

                // Design principles (brief)
                _PrincipleRow(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Atmosphere over decoration',
                  mutedColor: mutedColor,
                  textColor: textColor,
                ),
                const SizedBox(height: 10),
                _PrincipleRow(
                  icon: Icons.swipe_outlined,
                  label: 'Gesture over buttons',
                  mutedColor: mutedColor,
                  textColor: textColor,
                ),
                const SizedBox(height: 10),
                _PrincipleRow(
                  icon: Icons.favorite_border_rounded,
                  label: 'Mercy over judgment',
                  mutedColor: mutedColor,
                  textColor: textColor,
                ),
                const SizedBox(height: 10),
                _PrincipleRow(
                  icon: Icons.auto_stories_outlined,
                  label: 'Editorial over utility',
                  mutedColor: mutedColor,
                  textColor: textColor,
                ),

                const SizedBox(height: 24),

                // Divider
                Container(
                  height: 0.5,
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
                ),

                const SizedBox(height: 20),

                // Crafted with love note
                Row(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 13,
                      color: accentColor.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Crafted for neurodivergent minds.\n'
                        'Built for the 3PM light you almost missed.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: mutedColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Principle row ────────────────────────────────────────────────────────────

class _PrincipleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color mutedColor;
  final Color textColor;

  const _PrincipleRow({
    required this.icon,
    required this.label,
    required this.mutedColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: mutedColor.withOpacity(0.7)),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: textColor.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
