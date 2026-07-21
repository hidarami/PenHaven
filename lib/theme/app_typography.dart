import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP TYPOGRAPHY
// All TextStyles used in Flow, using Google Fonts at runtime.
// Every style is a static getter so it stays fresh with theme changes.
// ─────────────────────────────────────────────────────────────────────────────

class AppTypography {
  AppTypography._();

  // ── Instrument Serif (Serif — titles and headings) ─────────────────────────

  /// Story / panel title — 36pt bold serif
  static TextStyle storyTitle(Color color) => GoogleFonts.instrumentSerif(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.15,
      );

  /// Entry title in read-only view — 36pt bold, left-aligned
  static TextStyle entryTitle(Color color) => GoogleFonts.instrumentSerif(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.15,
      );

  /// Entry title in editor — 32pt bold
  static TextStyle editorTitle(Color color) => GoogleFonts.instrumentSerif(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2,
      );

  /// Entry title in card preview — 22pt bold italic
  static TextStyle entryCardTitle(Color color) => GoogleFonts.instrumentSerif(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: color,
        height: 1.3,
      );

  // ── Source Serif 4 (Serif — body text) ─────────────────────────────────────

  /// Entry body in read-only and editor — 18pt regular, line height 1.65
  static TextStyle entryBody(Color color) => GoogleFonts.sourceSerif4(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.65,
      );

  /// Comfort mode whisper text — 16pt italic, barely visible
  static TextStyle whisper(Color color) => GoogleFonts.crimsonPro(
        fontSize: 16,
        fontStyle: FontStyle.italic,
        color: color.withOpacity(0.15),
        height: 1.4,
      );

  /// Story description — 16pt italic, muted
  static TextStyle storyDescription(Color color) => GoogleFonts.crimsonPro(
        fontSize: 16,
        fontStyle: FontStyle.italic,
        color: color,
        height: 1.5,
      );

  // ── Markdown heading styles (used in MarkdownStyleSheet) ──────────────────

  static TextStyle mdH1(Color color) => GoogleFonts.crimsonPro(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2,
      );

  static TextStyle mdH2(Color color) => GoogleFonts.crimsonPro(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.25,
      );

  static TextStyle mdH3(Color color) => GoogleFonts.crimsonPro(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.3,
      );

  // ── Inter (Sans-serif — UI labels and system text) ────────────────────────

  /// Panel / section header — 28pt bold sans
  static TextStyle panelHeader(Color color) => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// Panel subtitle / tagline — 14pt regular sans, italic
  static TextStyle panelSubtitle(Color color) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: color,
      );

  /// Entry date in read-only — 13pt medium sans
  static TextStyle entryDate(Color color) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// "Entry N:" label above title in cards — 11pt semibold, spaced
  static TextStyle entryLabel(Color color) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 1.5,
      );

  /// Entry preview text in cards — 14pt regular sans
  static TextStyle entryPreview(Color color) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      );

  /// Small metadata — time spent, word count, last updated
  static TextStyle metaSmall(Color color) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color.withOpacity(0.5),
      );

  /// Button label — 14pt medium sans
  static TextStyle buttonLabel(Color color) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// Task item text — 15pt regular sans
  static TextStyle taskText(Color color) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );

  /// Settings / menu item — 15pt regular sans
  static TextStyle menuItem(Color color) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// Small section label — 11pt semibold, very spaced
  static TextStyle sectionLabel(Color color) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 2.0,
      );

  /// "N entries" count under story title — 11pt
  static TextStyle entryCount(Color color) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 1.5,
      );

  // ── JetBrains Mono (Monospace — code blocks) ──────────────────────────────

  static TextStyle codeBlock(Color color, Color bg) => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
        backgroundColor: bg,
        height: 1.6,
      );

  static TextStyle inlineCode(Color color) => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // ── Base theme text theme (used in ThemeData) ─────────────────────────────

  static TextTheme textTheme(bool dark) {
    final base = dark ? AppColors.textDark : AppColors.textLight;
    return TextTheme(
      displayLarge: storyTitle(base),
      displayMedium: panelHeader(base),
      bodyLarge: entryBody(base),
      bodyMedium: entryPreview(base),
      labelSmall: entryLabel(base),
      labelMedium: buttonLabel(base),
    );
  }
}
