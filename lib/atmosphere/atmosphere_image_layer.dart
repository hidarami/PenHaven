import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/atmosphere_state.dart';
import '../providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ATMOSPHERE IMAGE LAYER
// Renders PNG overlay assets on top of the glow painters.
// Each atmosphere has a different image + opacity + tint combo per mode.
//
// 3PM  + light : window_plant_shadow.png   — soft organic leaf/window shadows
// 3PM  + dark  : window_light_projection   — amber light panels in a dark room
// Midnight + dark : window_light_projection — cool moonlight through glass
// Midnight + light: window_light_projection  — very faint, cool texture
//
// errorBuilder silently skips if asset files haven't been added yet.
// ─────────────────────────────────────────────────────────────────────────────

class AtmosphereImageLayer extends StatelessWidget {
  const AtmosphereImageLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AtmosphereState, AppState>(
      builder: (context, atmo, app, _) {
        if (!atmo.isDynamicTheme) return const SizedBox.shrink();
        if (atmo.isComfortMode) return const SizedBox.shrink();

        final dark = app.isDarkMode;
        final atmosphere = atmo.current;

        _OverlayConfig? config;

        if (atmosphere == Atmosphere.golden3pm) {
          if (dark) {
            // Dark room, afternoon sun streams in as amber light panels
            config = _OverlayConfig(
              assetPath: 'assets/atmosphere/window_light_projection.png',
              opacity: 0.22,
              tintColor: const Color(0xFFFFAA44),
              tintOpacity: 0.38,
            );
          } else {
            // Bright room, plant shadow + window frame falls on warm wall
            config = _OverlayConfig(
              assetPath: 'assets/atmosphere/window_plant_shadow.png',
              opacity: 0.14,
              tintColor: const Color(0xFFFFDD88),
              tintOpacity: 0.22,
            );
          }
        } else if (atmosphere == Atmosphere.midnightInk) {
          if (dark) {
            // Moonlight streaming through window into dark room
            config = _OverlayConfig(
              assetPath: 'assets/atmosphere/window_light_projection.png',
              opacity: 0.17,
              tintColor: const Color(0xFF99AACC),
              tintOpacity: 0.32,
            );
          } else {
            // Light mode midnight: barely-there cool window shadow texture
            config = _OverlayConfig(
              assetPath: 'assets/atmosphere/window_light_projection.png',
              opacity: 0.055,
              tintColor: const Color(0xFF8899BB),
              tintOpacity: 0.45,
            );
          }
        }

        if (config == null) return const SizedBox.shrink();

        return Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Opacity(
                opacity: config.opacity,
                child: Image.asset(
                  config.assetPath,
                  fit: BoxFit.cover,
                  color: config.tintColor.withOpacity(config.tintOpacity),
                  colorBlendMode: BlendMode.srcATop,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OverlayConfig {
  final String assetPath;
  final double opacity; // Overall image visibility (0.0–1.0)
  final Color tintColor; // Color to blend into the image
  final double
      tintOpacity; // How strongly to tint (0 = no tint, 1 = solid tint)

  const _OverlayConfig({
    required this.assetPath,
    required this.opacity,
    required this.tintColor,
    required this.tintOpacity,
  });
}
