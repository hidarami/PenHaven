import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../providers/atmosphere_state.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SPLASH SCREEN — Liquid "Flow" water animation
// Sequence:
//   1. Background fades in
//   2. Ghost outline of "Flow" appears
//   3. Teal water rises from bottom with wave, filling the letters
//   4. "your sanctuary" fades in once text is ~90% full
//   5. Brief hold → crossfade to HomeScreen
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Background fade-in
  late final AnimationController _bgCtrl;
  late final Animation<double> _bgFade;

  // Water fill: 0.0 → 1.0
  late final AnimationController _fillCtrl;
  late final Animation<double> _fillAnim;

  // Continuous wave oscillation
  late final AnimationController _waveCtrl;

  // Subtitle fade-in
  late final AnimationController _subCtrl;
  late final Animation<double> _subFade;

  // Exit fade-out
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitFade;

  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bgFade = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn);

    _fillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _fillAnim = CurvedAnimation(parent: _fillCtrl, curve: Curves.easeInOut);

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    _subCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _subFade = CurvedAnimation(parent: _subCtrl, curve: Curves.easeIn);

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitFade = CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn);

    // Use addPostFrameCallback so context is ready before reading providers
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSequence());
  }

  Future<void> _runSequence() async {
    if (_disposed || !mounted) return;

    final appState = context.read<AppState>();
    final atmosphereState = context.read<AtmosphereState>();

    // Kick off data loading in parallel with animation
    final loadFuture = appState.init();
    atmosphereState.init();

    // Phase 1: Background fades in immediately
    _bgCtrl.forward();

    // Phase 2: Water fill starts after brief pause (ghost text visible first)
    await Future.delayed(const Duration(milliseconds: 380));
    if (_disposed || !mounted) return;
    _fillCtrl.forward();

    // Phase 3: Subtitle appears when fill reaches ~85%
    await Future.delayed(const Duration(milliseconds: 3800));
    if (_disposed || !mounted) return;
    _subCtrl.forward();

    // Phase 4: Wait for data load + minimum splash time
    await Future.wait([
      loadFuture,
      Future.delayed(const Duration(milliseconds: 700)),
    ]);
    if (_disposed || !mounted) return;

    // Phase 5: Exit
    _waveCtrl.stop();
    _exitCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    if (_disposed || !mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _bgCtrl.dispose();
    _fillCtrl.dispose();
    _waveCtrl.dispose();
    _subCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;

    return Scaffold(
      backgroundColor: bg,
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [_bgFade, _fillAnim, _waveCtrl, _subFade, _exitFade]),
        builder: (context, _) {
          final wavePhase = _waveCtrl.value * math.pi * 2;
          final fillProgress = _fillAnim.value;

          return Opacity(
            opacity: (1.0 - _exitFade.value).clamp(0.0, 1.0),
            child: FadeTransition(
              opacity: _bgFade,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Liquid "Flow" text ─────────────────────────────
                    _LiquidFlowText(
                      fillProgress: fillProgress,
                      wavePhase: wavePhase,
                      textColor: textColor,
                    ),

                    const SizedBox(height: 18),

                    // ── "your sanctuary" subtitle ──────────────────────
                    FadeTransition(
                      opacity: _subFade,
                      child: Text(
                        'your sanctuary',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textColor.withOpacity(0.36),
                          letterSpacing: 3.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIQUID FLOW TEXT
// Two layers:
//   1. Ghost "Flow" at 10% opacity — gives the sense of waiting to be filled
//   2. ClipPath rising wave reveals teal "Flow" beneath
// Both Text widgets use the same style so they overlay perfectly.
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidFlowText extends StatelessWidget {
  final double fillProgress;
  final double wavePhase;
  final Color textColor;

  const _LiquidFlowText({
    required this.fillProgress,
    required this.wavePhase,
    required this.textColor,
  });

  TextStyle _style(Color color) => GoogleFonts.crimsonPro(
        fontSize: 78,
        fontWeight: FontWeight.w300,
        color: color,
        letterSpacing: 10,
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Layer 1: Ghost text — always visible at low opacity
        Opacity(
          opacity: 0.10,
          child: Text('Flow', style: _style(textColor)),
        ),

        // Layer 2: Teal water fill, clipped by rising wave
        ClipPath(
          clipper: _WaveRiseClipper(
            fillProgress: fillProgress,
            wavePhase: wavePhase,
          ),
          // Solid aqua fill — full opacity version of the app's accent blue
          child: Text('Flow', style: _style(const Color(0xFF207BD5))),
        ),

        // Layer 3: Faint water shimmer line at the wave surface
        if (fillProgress > 0.02 && fillProgress < 0.99)
          _WaveSurface(
            fillProgress: fillProgress,
            wavePhase: wavePhase,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WAVE RISE CLIPPER
// Returns a path covering the region BELOW the animated wave.
// ClipPath shows only what's inside = only the bottom [fillProgress] of text.
// ─────────────────────────────────────────────────────────────────────────────

class _WaveRiseClipper extends CustomClipper<Path> {
  final double fillProgress;
  final double wavePhase;

  const _WaveRiseClipper({
    required this.fillProgress,
    required this.wavePhase,
  });

  @override
  Path getClip(Size size) {
    // Edge cases
    if (fillProgress <= 0) return Path();
    if (fillProgress >= 1) {
      return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    // Y coordinate of wave surface (0=top, size.height=bottom)
    final surfaceY = size.height * (1.0 - fillProgress);
    const waveAmp = 14.0; // amplitude in logical pixels
    const waveCycles = 2.0; // number of complete waves across width

    final path = Path();
    // Start at bottom-left
    path.moveTo(0, size.height);
    // Go up to wave level on left edge
    path.lineTo(0, surfaceY);

    // Trace the wave surface left → right
    for (double x = 0; x <= size.width + 1; x += 1.5) {
      final t = x / size.width;
      final y = surfaceY +
          waveAmp * math.sin(t * math.pi * 2 * waveCycles + wavePhase);
      path.lineTo(x, y);
    }

    // Close the shape at bottom-right → bottom-left
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveRiseClipper old) =>
      old.fillProgress != fillProgress || old.wavePhase != wavePhase;
}

// ─────────────────────────────────────────────────────────────────────────────
// WAVE SURFACE
// A bright thin line drawn at the wave surface for a light-reflection effect.
// Uses CustomPaint sized to match the parent Stack (intrinsic text size).
// ─────────────────────────────────────────────────────────────────────────────

class _WaveSurface extends StatelessWidget {
  final double fillProgress;
  final double wavePhase;

  const _WaveSurface({
    required this.fillProgress,
    required this.wavePhase,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaveSurfacePainter(
        fillProgress: fillProgress,
        wavePhase: wavePhase,
      ),
    );
  }
}

class _WaveSurfacePainter extends CustomPainter {
  final double fillProgress;
  final double wavePhase;

  const _WaveSurfacePainter({
    required this.fillProgress,
    required this.wavePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final surfaceY = size.height * (1.0 - fillProgress);
    const waveAmp = 14.0;
    const waveCycles = 2.0;

    // Bright highlight line along the wave surface
    final paint = Paint()
      ..color = const Color(0xFF207BD5).withOpacity(0.88)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    final path = Path();
    bool first = true;
    for (double x = 0; x <= size.width; x += 1.5) {
      final t = x / size.width;
      final y = surfaceY +
          waveAmp * math.sin(t * math.pi * 2 * waveCycles + wavePhase);
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WaveSurfacePainter old) =>
      old.fillProgress != fillProgress || old.wavePhase != wavePhase;
}
