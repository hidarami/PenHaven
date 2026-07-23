import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FONTS SCREEN
// Full-screen font picker with live preview cards for each available font.
// ─────────────────────────────────────────────────────────────────────────────

class FontsScreen extends StatelessWidget {
  const FontsScreen({super.key});

  static const _serifFonts = [
    'crimsonPro', 'ebGaramond', 'cormorantGaramond', 'playfairDisplay',
    'alegreya', 'spectral', 'cardo', 'sourceSerif4', 'lora',
    'merriweather', 'libreBaskerville', 'literata',
  ];

  static const _sansFonts = ['nunito', 'jost', 'dmSans'];

  static const _sampleText =
      'The light shifted at 3pm,\nand I began to write.';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final atmosphereState = context.watch<AtmosphereState>();
    final isDark = appState.isDarkMode;
    final bg = atmosphereState.backgroundFor(isDark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final divColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;

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
                      child: Icon(Icons.chevron_left_rounded, size: 28, color: mutedColor),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reading Font',
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
                padding: const EdgeInsets.fromLTRB(52, 4, 20, 16),
                child: Text(
                  'Affects how entries look when reading. ${AppTypography.fontDisplayNames[appState.preferredFont]} is selected.',
                  style: GoogleFonts.inter(fontSize: 12, color: mutedColor, height: 1.4),
                ),
              ),
              Divider(color: divColor, height: 1, thickness: 0.5),

              // Font list
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 48),
                  children: [
                    _SectionHeader(label: 'SERIF', mutedColor: mutedColor),
                    ..._serifFonts.map((key) => _FontCard(
                          fontKey: key,
                          displayName: AppTypography.fontDisplayNames[key] ?? key,
                          sampleText: _sampleText,
                          isSelected: appState.preferredFont == key,
                          isDark: isDark,
                          textColor: textColor,
                          mutedColor: mutedColor,
                          onTap: () => appState.setPreferredFont(key),
                        )),
                    const SizedBox(height: 8),
                    _SectionHeader(label: 'SANS-SERIF', mutedColor: mutedColor),
                    ..._sansFonts.map((key) => _FontCard(
                          fontKey: key,
                          displayName: AppTypography.fontDisplayNames[key] ?? key,
                          sampleText: _sampleText,
                          isSelected: appState.preferredFont == key,
                          isDark: isDark,
                          textColor: textColor,
                          mutedColor: mutedColor,
                          onTap: () => appState.setPreferredFont(key),
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

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color mutedColor;
  const _SectionHeader({required this.label, required this.mutedColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: mutedColor,
            letterSpacing: 2.0,
          ),
        ),
      );
}

// ── Font card ─────────────────────────────────────────────────────────────────

class _FontCard extends StatelessWidget {
  final String fontKey;
  final String displayName;
  final String sampleText;
  final bool isSelected;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _FontCard({
    required this.fontKey,
    required this.displayName,
    required this.sampleText,
    required this.isSelected,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? Colors.white.withOpacity(isSelected ? 0.08 : 0.04)
        : Colors.black.withOpacity(isSelected ? 0.05 : 0.025);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: AppColors.aqua.withOpacity(0.5), width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left accent when selected
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3,
              height: isSelected ? 40 : 0,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.aqua,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.aqua : mutedColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    sampleText,
                    style: AppTypography.bodyTextFor(
                      fontKey,
                      isSelected ? textColor : textColor.withOpacity(0.75),
                      size: 15,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),

            // Check indicator
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.aqua : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.aqua
                      : mutedColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}