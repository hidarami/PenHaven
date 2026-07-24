import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEMES SCREEN
// Manual theme picker. Tapping a theme persists it via AtmosphereState.
// Atmosphere painters still layer on top — "Gothic Ink + Rainy" still works.
// Swipe right to exit.
// ─────────────────────────────────────────────────────────────────────────────

class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final atmo = context.watch<AtmosphereState>();
    final isDark = appState.isDarkMode;
    final bg = atmo.backgroundFor(isDark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final currentManual = atmo.manualTheme;

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.chevron_left_rounded,
                          size: 28, color: mutedColor),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Themes',
                      style: GoogleFonts.crimsonPro(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(52, 4, 20, 20),
                child: Text(
                  'Atmosphere painters still layer on top of any theme.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: mutedColor, height: 1.4),
                ),
              ),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                  children: [
                    // Dynamic auto option at top
                    _ThemeCard(
                      name: 'Dynamic (Auto)',
                      feel: 'Responds to time, weather & mood',
                      bgLight: AppColors.warmWhite,
                      bgDark: AppColors.warmDark,
                      accent: AppColors.aqua,
                      isSelected: currentManual == null,
                      isDark: isDark,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTap: () => atmo.setManualTheme(null),
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
                      child: Text(
                        'MANUAL THEMES',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: mutedColor,
                          letterSpacing: 2,
                        ),
                      ),
                    ),

                    // Theme cards
                    ...AppColors.manualThemes.map((theme) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ThemeCard(
                            name: theme.name,
                            feel: theme.feel,
                            bgLight: theme.bgLight,
                            bgDark: theme.bgDark,
                            accent: theme.accent,
                            isSelected: currentManual == theme.key,
                            isDark: isDark,
                            textColor: textColor,
                            mutedColor: mutedColor,
                            onTap: () => atmo.setManualTheme(theme.key),
                          ),
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

// ── Theme card ─────────────────────────────────────────────────────────────

class _ThemeCard extends StatelessWidget {
  final String name;
  final String feel;
  final Color bgLight;
  final Color bgDark;
  final Color accent;
  final bool isSelected;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.name,
    required this.feel,
    required this.bgLight,
    required this.bgDark,
    required this.accent,
    required this.isSelected,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? Colors.white.withOpacity(isSelected ? 0.09 : 0.04)
        : Colors.black.withOpacity(isSelected ? 0.06 : 0.025);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent.withOpacity(0.55) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Active bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 3,
              height: isSelected ? 44 : 0,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Light / dark swatch pair with accent dot
            _BgSwatchPair(bgLight: bgLight, bgDark: bgDark, accent: accent),

            const SizedBox(width: 14),

            // Name + feel
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? accent : textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    feel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: mutedColor,
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Check or chevron
            if (isSelected)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 13, color: Colors.white),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: mutedColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}

// ── BG swatch pair — split light/dark with centered accent dot ─────────────

class _BgSwatchPair extends StatelessWidget {
  final Color bgLight;
  final Color bgDark;
  final Color accent;

  const _BgSwatchPair({
    required this.bgLight,
    required this.bgDark,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 54,
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withOpacity(0.1), width: 0.5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Stack(
          children: [
            // Left half — light bg
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 27,
              child: Container(color: bgLight),
            ),
            // Right half — dark bg
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 27,
              child: Container(color: bgDark),
            ),
            // Hairline divider between halves
            Center(
              child: Container(
                width: 0.5,
                color: Colors.black.withOpacity(0.12),
              ),
            ),
            // Accent dot centred
            Center(
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.45),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
