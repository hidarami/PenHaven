import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/atmosphere_state.dart';
import '../providers/app_state.dart';
import 'painters/golden_3pm_painter.dart';
import 'painters/other_painters.dart'; // GoldenHour, MidnightInk, SundayMorning, Rainy

// ─────────────────────────────────────────────────────────────────────────────
// ATMOSPHERE OVERLAY
// Sits on top of all screen content as an IgnorePointer so taps/typing
// pass through it unaffected. Routes to the correct CustomPainter based on
// the current atmosphere key and dark mode.
//
// Usage: Wrap your screen's Stack children list with this at the top level:
//
//   Stack(children: [
//     yourContent,
//     const AtmosphereOverlay(),
//     const ComfortWhisperOverlay(), // Only shows in editor
//   ])
// ─────────────────────────────────────────────────────────────────────────────

class AtmosphereOverlay extends StatelessWidget {
  const AtmosphereOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AtmosphereState, AppState>(
      builder: (context, atmo, app, _) {
        final dark = app.isDarkMode;
        final atmosphere = atmo.isComfortMode ? 'Comfort' : atmo.current;

        // No overlay when dynamic theme is off, or for Normal/Comfort atmospheres
        if (!atmo.isDynamicTheme ||
            atmosphere == Atmosphere.normal ||
            atmosphere == 'Comfort') {
          return const SizedBox.shrink();
        }

        final painter = _selectPainter(atmosphere, dark, atmo);
        if (painter == null) return const SizedBox.shrink();

        return Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: painter,
                size: Size.infinite,
              ),
            ),
          ),
        );
      },
    );
  }

  CustomPainter? _selectPainter(
    String atmosphere,
    bool dark,
    AtmosphereState atmo,
  ) {
    switch (atmosphere) {
      case Atmosphere.golden3pm:
        return Golden3pmPainter(isDark: dark);
      case Atmosphere.goldenHour:
        return GoldenHourPainter(isDark: dark);
      case Atmosphere.midnightInk:
        return MidnightInkPainter(isDark: dark);
      case Atmosphere.sundayMorning:
        return SundayMorningPainter(isDark: dark);
      case Atmosphere.rainy:
      case Atmosphere.foggy:
      case Atmosphere.snowy:
      case Atmosphere.stormy:
      case Atmosphere.cloudy:
        return RainyPainter(isDark: dark, condition: atmosphere);
      default:
        return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED ATMOSPHERE BACKGROUND
// AnimatedContainer that transitions the scaffold background color smoothly
// when atmosphere or dark mode changes. Wrap Scaffold's body with this.
// ─────────────────────────────────────────────────────────────────────────────

class AtmosphereBackground extends StatelessWidget {
  final Widget child;

  const AtmosphereBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AtmosphereState, AppState>(
      builder: (context, atmo, app, _) {
        final bg = atmo.backgroundFor(app.isDarkMode);
        return AnimatedContainer(
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
          color: bg,
          child: child,
        );
      },
    );
  }
}
