import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MANUAL THEME DATA — holds per-theme color palette
// ─────────────────────────────────────────────────────────────────────────────

class ManualThemeData {
  final String key;
  final String name;
  final String feel;
  final Color bgLight;
  final Color bgDark;
  final Color accent;

  const ManualThemeData({
    required this.key,
    required this.name,
    required this.feel,
    required this.bgLight,
    required this.bgDark,
    required this.accent,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// APP COLORS
// Single source of truth for every color value in PenHaven.
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
  static const Color golden3pmLight =
      Color(0xFFFEF8EC); // Warm cream — paper in afternoon sun
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
  static const Color cloudyLight = Color(0xFFEAEAEE);
  static const Color cloudyDark = Color(0xFF18181E);
  static const Color stormyLight = Color(0xFFD2D6E2);
  static const Color stormyDark = Color(0xFF090A14);
  static const Color summerHeatLight = Color(0xFFFFF6DE);
  static const Color summerHeatDark = Color(0xFF1E1608);
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
      case 'Cloudy':
        return dark ? cloudyDark : cloudyLight;
      case 'Stormy':
        return dark ? stormyDark : stormyLight;
      case 'SummerHeat':
        return dark ? summerHeatDark : summerHeatLight;
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
    if (!isDay) {
      if (atmosphere == 'Stormy' || atmosphere == 'Cloudy') {
        return const Color(0xFF6B7088);
      }
      return moonNight;
    }
    if (atmosphere == 'Golden3PM') return sunGolden3pm;
    if (atmosphere == 'Cloudy') return const Color(0xFF8890A0);
    if (atmosphere == 'Stormy') return const Color(0xFF505868);
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

  // ── Manual Theme Catalog ───────────────────────────────────────────────────
  static const List<ManualThemeData> manualThemes = [
    ManualThemeData(
      key: 'tokyoRain',
      name: 'Tokyo Rain',
      feel: 'noir · neon · urban',
      bgLight: Color(0xFFE8EDF5),
      bgDark: Color(0xFF05080F),
      accent: Color(0xFF00C4EE),
    ),
    ManualThemeData(
      key: 'amberLibrary',
      name: 'Amber Library',
      feel: 'warm · cozy · afternoon',
      bgLight: Color(0xFFFFF3DC),
      bgDark: Color(0xFF1A1200),
      accent: Color(0xFFD4820A),
    ),
    ManualThemeData(
      key: 'nordic',
      name: 'Nordic',
      feel: 'cold · stark · minimal',
      bgLight: Color(0xFFF0F4F8),
      bgDark: Color(0xFF0A0F18),
      accent: Color(0xFF5B8DB8),
    ),
    ManualThemeData(
      key: 'cherryBlossom',
      name: 'Cherry Blossom',
      feel: 'soft · romantic · Japanese',
      bgLight: Color(0xFFFFF0F5),
      bgDark: Color(0xFF180A10),
      accent: Color(0xFFE87FA0),
    ),
    ManualThemeData(
      key: 'deepOcean',
      name: 'Deep Ocean',
      feel: 'calm · vast · cool',
      bgLight: Color(0xFFEAF2F8),
      bgDark: Color(0xFF020C18),
      accent: Color(0xFF1B9B8D),
    ),
    ManualThemeData(
      key: 'parchment',
      name: 'Parchment',
      feel: 'aged · literary · sepia',
      bgLight: Color(0xFFF5EDD8),
      bgDark: Color(0xFF1A1508),
      accent: Color(0xFFB8922A),
    ),
    ManualThemeData(
      key: 'gothicInk',
      name: 'Gothic Ink',
      feel: 'dark · dramatic · intense',
      bgLight: Color(0xFFF2F0F5),
      bgDark: Color(0xFF060208),
      accent: Color(0xFF9B59C8),
    ),
    ManualThemeData(
      key: 'bamboo',
      name: 'Bamboo',
      feel: 'zen · muted · calm',
      bgLight: Color(0xFFEEF3EC),
      bgDark: Color(0xFF0A1208),
      accent: Color(0xFF5A8A5C),
    ),
    ManualThemeData(
      key: 'midnightCoffee',
      name: 'Midnight Coffee',
      feel: 'cozy · dark · caffeinated',
      bgLight: Color(0xFFF3EDE6),
      bgDark: Color(0xFF0E0905),
      accent: Color(0xFFC47A3A),
    ),
    ManualThemeData(
      key: 'arcticDawn',
      name: 'Arctic Dawn',
      feel: 'crisp · pale · ethereal',
      bgLight: Color(0xFFF0F7FC),
      bgDark: Color(0xFF060D16),
      accent: Color(0xFF6AAEDE),
    ),
    ManualThemeData(
      key: 'saharaDust',
      name: 'Sahara Dust',
      feel: 'warm · sand · ancient',
      bgLight: Color(0xFFFAF0DF),
      bgDark: Color(0xFF1A1206),
      accent: Color(0xFFCC7A24),
    ),
    ManualThemeData(
      key: 'lavenderField',
      name: 'Lavender Field',
      feel: 'dreamy · soft · romantic',
      bgLight: Color(0xFFF6F1FF),
      bgDark: Color(0xFF0E0918),
      accent: Color(0xFF9472D4),
    ),
    ManualThemeData(
      key: 'rustSteel',
      name: 'Rust & Steel',
      feel: 'industrial · raw · bold',
      bgLight: Color(0xFFF5ECE8),
      bgDark: Color(0xFF130806),
      accent: Color(0xFFBF4E28),
    ),
    ManualThemeData(
      key: 'forestDeep',
      name: 'Deep Forest',
      feel: 'lush · dark · earthy',
      bgLight: Color(0xFFEBF0E8),
      bgDark: Color(0xFF050C05),
      accent: Color(0xFF4A8A52),
    ),
    ManualThemeData(
      key: 'roseGold',
      name: 'Rose Gold',
      feel: 'elegant · warm · luxury',
      bgLight: Color(0xFFFFF1EE),
      bgDark: Color(0xFF1A0C0A),
      accent: Color(0xFFD47A5A),
    ),
    ManualThemeData(
      key: 'slateOcean',
      name: 'Slate Ocean',
      feel: 'moody · deep · philosophical',
      bgLight: Color(0xFFECEFF5),
      bgDark: Color(0xFF070B13),
      accent: Color(0xFF4A70B0),
    ),
    ManualThemeData(
      key: 'moonlitSage',
      name: 'Moonlit Sage',
      feel: 'herbal · night · serene',
      bgLight: Color(0xFFEEF3EF),
      bgDark: Color(0xFF07100A),
      accent: Color(0xFF6DAA88),
    ),
    ManualThemeData(
      key: 'cinnabar',
      name: 'Cinnabar',
      feel: 'bold · fiery · decisive',
      bgLight: Color(0xFFFFF5F0),
      bgDark: Color(0xFF180806),
      accent: Color(0xFFD44A28),
    ),
    ManualThemeData(
      key: 'abyssInk',
      name: 'Abyss Ink',
      feel: 'void · writer · nocturnal',
      bgLight: Color(0xFFEEEEF2),
      bgDark: Color(0xFF020204),
      accent: Color(0xFF7878C8),
    ),
    ManualThemeData(
      key: 'copperAge',
      name: 'Copper Age',
      feel: 'antique · museum · storied',
      bgLight: Color(0xFFF8F0E8),
      bgDark: Color(0xFF150E06),
      accent: Color(0xFFB8742A),
    ),
    ManualThemeData(
      key: 'bmwMotorsport',
      name: 'Motorsport',
      feel: 'pure · dark · precise',
      // Both variants stay dark on purpose — this theme is meant to always
      // read as a pure-black cockpit look, regardless of light/dark toggle,
      // so the white accent always has enough contrast to stay readable.
      bgLight: Color(0xFF17181A),
      bgDark: Color(0xFF000000),
      accent: Color(0xFFF4F4F4),
    ),
  ];

  /// Background for a manual theme key + dark flag. Null if key unknown.
  static Color? manualThemeBg(String key, bool dark) {
    for (final t in manualThemes) {
      if (t.key == key) return dark ? t.bgDark : t.bgLight;
    }
    return null;
  }

  /// Accent color for a manual theme key. Falls back to aqua.
  static Color manualThemeAccent(String key) {
    for (final t in manualThemes) {
      if (t.key == key) return t.accent;
    }
    return aqua;
  }
}
