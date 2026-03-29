import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_colors.dart';
import 'menu_story_selector.dart';
import 'menu_actions.dart';

/// The liquid-glass overlay menu that slides in from the right.
/// Triggered by the hamburger icon always visible top-right.
///
/// Structure:
///   [Header — app name + close gesture]
///   [Story selector — switch active story]
///   [Divider]
///   [Menu actions — Archive, Settings, About, Lock]
class MenuPanel extends StatelessWidget {
  const MenuPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor: Colors.black.withAlpha(35),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => const MenuPanel(),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final atmosphereState = context.watch<AtmosphereState>();
    final isDark = appState.isDarkMode;
    final bg = atmosphereState.backgroundFor(isDark);

    // Panel sits right-aligned; left portion remains dismissible
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.82,
          height: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.warmDark.withAlpha(247)
                : AppColors.warmWhite.withAlpha(247),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(23),
                blurRadius: 32,
                offset: const Offset(-8, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MenuHeader(isDark: isDark, bg: bg),
                const SizedBox(height: 8),
                Expanded(
                  child: MenuStorySelector(isDark: isDark, bg: bg),
                ),
                _Divider(isDark: isDark),
                MenuActions(isDark: isDark, bg: bg),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private header ─────────────────────────────────────────────────────────

class _MenuHeader extends StatelessWidget {
  final bool isDark;
  final Color bg;

  const _MenuHeader({required this.isDark, required this.bg});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flow',
                style: GoogleFonts.crimsonPro(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'your sanctuary',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: mutedColor,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          // Close gesture target
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: mutedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;

  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Container(
        height: 0.5,
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.08),
      ),
    );
  }
}
