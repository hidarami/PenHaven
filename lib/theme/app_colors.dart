import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP COLORS
// Single source of truth for every color value in Flow.
// Import this file wherever you need a named color constant.
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color teal = Color(0xFF7BA591);
  static const Color tealLight = Color(0xFFB2D4C5);
  static const Color tealDark = Color(0xFF4E7A65);
  static const Color aqua = Color.fromARGB(173, 32, 123, 213);

  // ── Base Neutrals ──────────────────────────────────────────────────────────
  static const Color warmWhite = Color(0xFFF7F3EE);
  static const Color warmDark = Color(0xFF1A1410);

  // ── Neumorphic Shadows (Light Mode) ───────────────────────────────────────
  static const Color neuLightShadowLight = Color(0xFFFFFFFF);
  static const Color neuDarkShadowLight = Color(0xFFD4CFC9);

  // ── Neumorphic Shadows (Dark Mode) ────────────────────────────────────────
  static const Color neuLightShadowDark = Color(0xFF2A2218);
  static const Color neuDarkShadowDark = Color(0xFF0E0C09);

  // ── Liquid Glass ──────────────────────────────────────────────────────────
  static const Color glassWhite = Color(0x26FFFFFF); // White 15%
  static const Color glassBorder = Color(0x80FFFFFF); // White 50%

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textLight = Color(0xFF1A1410);
  static const Color textDark = Color(0xFFF0EBE3);
  static const Color mutedLight = Color(0xFF8A8178);
  static const Color mutedDark = Color(0xFF6B6058);

  // ── Comfort Mode ──────────────────────────────────────────────────────────
  static const Color comfortLight = Color(0xFFFFF0E8);
  static const Color comfortDark = Color(0xFF2A1E18);

  // ── Atmosphere Backgrounds (Light) ─────────────────────────────────────────
  // Near-white neutral — window light projects onto a bright wall, not yellow
  static const Color golden3pmLight = Color(0xFFFEF8EC); // Warm cream — paper in afternoon sun
  static const Color midnightInkLight = Color(0xFFE8E3F5);
  static const Color sundayMorningLight = Color(0xFFF5F1E8);
  static const Color goldenHourLight = Color(0xFFFFF0CC);
  static const Color rainyLight = Color(0xFFE8EDF5);
  static const Color foggyLight = Color(0xFFEEEEEE);
  static const Color snowyLight = Color(0xFFF0F4FF);
  static const Color normalLight = warmWhite;

  // ── Atmosphere Backgrounds (Dark) ──────────────────────────────────────────
  static const Color golden3pmDark = Color(0xFF1E1600);
  static const Color midnightInkDark = Color(0xFF0D0D1A);
  static const Color sundayMorningDark = Color(0xFF1A1912);
  static const Color goldenHourDark = Color(0xFF1C1400);
  static const Color rainyDark = Color(0xFF0D1220);
  static const Color foggyDark = Color(0xFF141414);
  static const Color snowyDark = Color(0xFF0F1220);
  static const Color normalDark = warmDark;

  // ── Sun/Moon Indicator Colors ──────────────────────────────────────────────
  static const Color sunGolden3pm = Color(0xFFD4A017); // Solid gold
  static const Color sunMorning = Color(0xFF8B7355); // Solid cornsilk brown
  static const Color sunDaytime = Color(0xFFCD853F); // Solid peru
  static const Color moonNight = Color(0xFF4682B4); // Solid steel blue

  // ── Markdown / Editor ─────────────────────────────────────────────────────
  static const Color blockquoteBorder = teal;
  static const Color blockquoteBg = Color(0x197BA591); // Teal 10%
  static const Color codeBgLight = Color(0xFFECE9E3);
  static const Color codeBgDark = Color(0xFF262116);
  static const Color linkColor = teal;

  // ── Divider / Border ──────────────────────────────────────────────────────
  static const Color dividerLight = Color(0xFFDED9D2);
  static const Color dividerDark = Color(0xFF2E2820);

  // ── Danger ────────────────────────────────────────────────────────────────
  // Used only for delete confirmation, never for "overdue" tasks.
  static const Color danger = Color(0xFFC0392B);

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the correct atmosphere background for the given
  /// [atmosphere] key and [dark] mode flag.
  static Color atmosphereBg(String atmosphere, bool dark) {
    switch (atmosphere) {
      case 'Golden3PM':
        return dark ? golden3pmDark : golden3pmLight;
      case 'MidnightInk':
        return dark ? midnightInkDark : midnightInkLight;
      case 'SundayMorning':
        return dark ? sundayMorningDark : sundayMorningLight;
      case 'GoldenHour':
        return dark ? goldenHourDark : goldenHourLight;
      case 'Rainy':
        return dark ? rainyDark : rainyLight;
      case 'Foggy':
        return dark ? foggyDark : foggyLight;
      case 'Snowy':
        return dark ? snowyDark : snowyLight;
      case 'Comfort':
        return dark ? comfortDark : comfortLight;
      default:
        return dark ? normalDark : normalLight;
    }
  }

  /// Derives a readable high-contrast text color from a background.
  static Color readableText(Color bg) {
    return bg.computeLuminance() > 0.4 ? textLight : textDark;
  }

  /// Derives a muted/secondary text color from a background.
  static Color readableMuted(Color bg) {
    return bg.computeLuminance() > 0.4 ? mutedLight : mutedDark;
  }

  /// Sun/moon indicator color for the current [atmosphere] and [isDay].
  static Color sunMoonColor(String atmosphere, bool isDay) {
    if (!isDay) return moonNight;
    if (atmosphere == 'Golden3PM') return sunGolden3pm;
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 10) return sunMorning;
    return sunDaytime;
  }

  /// Neumorphic light shadow — adapts to dark mode.
  static Color neuLight(bool dark) =>
      dark ? neuLightShadowDark : neuLightShadowLight;

  /// Neumorphic dark shadow — adapts to dark mode.
  static Color neuDark(bool dark) =>
      dark ? neuDarkShadowDark : neuDarkShadowLight;
}
