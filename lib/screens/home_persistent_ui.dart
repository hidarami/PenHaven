import 'package:flutter/material.dart';

import '../widgets/sun_moon_indicator.dart';
import '../widgets/neumorphic_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME PERSISTENT UI
// Fixed overlay that always appears above all 3 panels.
// Contains ONLY:
//   - Sun/Moon indicator: top-left (RESERVED — no back buttons here)
//   - Glass menu button:  top-right (always visible, liquid glass style)
//
// Uses Positioned inside the home screen's Stack — not an AppBar.
// SafeArea padding is applied manually so it respects the status bar.
// ─────────────────────────────────────────────────────────────────────────────

class HomePersistentUI extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;

  const HomePersistentUI({
    super.key,
    required this.onMenuTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.only(
          top: topPadding + 8,
          left: 24,
          right: 20,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Sun/Moon indicator — top-left, ALWAYS ─────────────────────
            // CRITICAL: No back button here. This corner is reserved.
            const SunMoonIndicator(),

            // ── Search + Menu buttons — top-right, ALWAYS ─────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassButton(
                  onTap: onSearchTap,
                  child: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                GlassButton(
                  onTap: onMenuTap,
                  child: const Icon(
                    Icons.menu,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
