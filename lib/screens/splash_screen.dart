import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../providers/atmosphere_state.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SPLASH SCREEN — "A Haven" liquid-light animation
// Sequence:
//   1. Warm ambient glow breathes in behind everything
//   2. Ghost outline of "PenHaven" appears
//   3. Teal water rises with a wave, filling the letters
//   4. Softly drifting light particles (like dust motes settling in a room)
//   5. "a haven for your words" fades in with a gentle upward drift
//   6. Brief hold → crossfade to HomeScreen / Onboarding
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final Animation<double> _bgFade;

  late final AnimationController _glowCtrl; // breathing ambient glow, loops

  late final AnimationController _fillCtrl;
  late final Animation<double> _fillAnim;

  late final AnimationController _waveCtrl;

  late final AnimationController _particleCtrl;

  late final AnimationController _subCtrl;
  late final Animation<double> _subFade;
  late final Animation<Offset> _subSlide;

  late final AnimationController _exitCtrl;
  late final Animation<double> _exitFade;

  final List<_Particle> _particles =
      List.generate(16, (i) => _Particle.random(math.Random(i * 7919)));

  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _bgFade = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    _fillCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 5200));
    _fillAnim = CurvedAnimation(parent: _fillCtrl, curve: Curves.easeInOutCubic);

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _subCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _subFade = CurvedAnimation(parent: _subCtrl, curve: Curves.easeOut);
    _subSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _subCtrl, curve: Curves.easeOutCubic));

    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _exitFade = CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn);

    WidgetsBinding.instance.addPostFrameCallback((_) => _runSequence());
  }

  Future<void> _runSequence() async {
    if (_disposed || !mounted) return;

    final appState = context.read<AppState>();
    final atmosphereState = context.read<AtmosphereState>();

    final loadFuture = appState.init();
    atmosphereState.init();

    _bgCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 420));
    if (_disposed || !mounted) return;
    _fillCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 4000));
    if (_disposed || !mounted) return;
    _subCtrl.forward();

    await Future.wait([
      loadFuture,
      Future.delayed(const Duration(milliseconds: 750)),
    ]);
    if (_disposed || !mounted) return;

    _waveCtrl.stop();
    _glowCtrl.stop();
    _particleCtrl.stop();
    _exitCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 550));
    if (_disposed || !mounted) return;

    final goHome = appState.hasSeenOnboarding;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) =>
            goHome ? const HomeScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 550),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _bgCtrl.dispose();
    _glowCtrl.dispose();
    _fillCtrl.dispose();
    _waveCtrl.dispose();
    _particleCtrl.dispose();
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
        animation: Listenable.merge([
          _bgFade, _fillAnim, _waveCtrl, _glowCtrl, _particleCtrl,
          _subFade, _exitFade,
        ]),
        builder: (context, _) {
          final wavePhase = _waveCtrl.value * math.pi * 2;
          final fillProgress = _fillAnim.value;

          return Opacity(
            opacity: (1.0 - _exitFade.value).clamp(0.0, 1.0),
            child: FadeTransition(
              opacity: _bgFade,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Ambient breathing glow ─────────────────────────────
                  CustomPaint(
                    painter: _HavenGlowPainter(
                      pulse: _glowCtrl.value,
                      isDark: dark,
                    ),
                  ),

                  // ── Drifting particles (settled dust / warmth) ─────────
                  CustomPaint(
                    painter: _ParticleFieldPainter(
                      particles: _particles,
                      time: _particleCtrl.value,
                      isDark: dark,
                    ),
                  ),

                  // ── Centerpiece ─────────────────────────────────────────
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LiquidHavenText(
                          fillProgress: fillProgress,
                          wavePhase: wavePhase,
                          textColor: textColor,
                        ),
                        const SizedBox(height: 16),
                        SlideTransition(
                          position: _subSlide,
                          child: FadeTransition(
                            opacity: _subFade,
                            child: Column(
                              children: [
                                Container(
                                  width: 28,
                                  height: 1,
                                  color: textColor.withOpacity(0.25),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'a haven for your words',
                                  style: GoogleFonts.crimsonPro(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: textColor.withOpacity(0.42),
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIQUID "PenHaven" TEXT
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidHavenText extends StatelessWidget {
  final double fillProgress;
  final double wavePhase;
  final Color textColor;

  const _LiquidHavenText({
    required this.fillProgress,
    required this.wavePhase,
    required this.textColor,
  });

  TextStyle _style(Color color) => GoogleFonts.crimsonPro(
        fontSize: 52,
        fontWeight: FontWeight.w300,
        color: color,
        letterSpacing: 5,
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 0.10,
          child: Text('PenHaven', style: _style(textColor)),
        ),
        ClipPath(
          clipper: _WaveRiseClipper(
              fillProgress: fillProgress, wavePhase: wavePhase),
          child: Text('PenHaven', style: _style(const Color(0xFF207BD5))),
        ),
        if (fillProgress > 0.02 && fillProgress < 0.99)
          _WaveSurface(fillProgress: fillProgress, wavePhase: wavePhase),
      ],
    );
  }
}

class _WaveRiseClipper extends CustomClipper<Path> {
  final double fillProgress;
  final double wavePhase;

  const _WaveRiseClipper(
      {required this.fillProgress, required this.wavePhase});

  @override
  Path getClip(Size size) {
    if (fillProgress <= 0) return Path();
    if (fillProgress >= 1) {
      return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    final surfaceY = size.height * (1.0 - fillProgress);
    const waveAmp = 13.0;
    const waveCycles = 2.0;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, surfaceY);

    for (double x = 0; x <= size.width + 1; x += 1.5) {
      final t = x / size.width;
      final y = surfaceY +
          waveAmp * math.sin(t * math.pi * 2 * waveCycles + wavePhase);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveRiseClipper old) =>
      old.fillProgress != fillProgress || old.wavePhase != wavePhase;
}

class _WaveSurface extends StatelessWidget {
  final double fillProgress;
  final double wavePhase;
  const _WaveSurface({required this.fillProgress, required this.wavePhase});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaveSurfacePainter(
          fillProgress: fillProgress, wavePhase: wavePhase),
    );
  }
}

class _WaveSurfacePainter extends CustomPainter {
  final double fillProgress;
  final double wavePhase;
  const _WaveSurfacePainter(
      {required this.fillProgress, required this.wavePhase});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final surfaceY = size.height * (1.0 - fillProgress);
    const waveAmp = 13.0;
    const waveCycles = 2.0;

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

// ─────────────────────────────────────────────────────────────────────────────
// AMBIENT GLOW — breathing warm/cool radial light behind the wordmark
// ─────────────────────────────────────────────────────────────────────────────

class _HavenGlowPainter extends CustomPainter {
  final double pulse; // 0..1, breathes via reverse repeat
  final bool isDark;
  const _HavenGlowPainter({required this.pulse, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.shortestSide * (0.55 + pulse * 0.08);
    final opacity = isDark ? 0.10 + pulse * 0.05 : 0.07 + pulse * 0.04;

    final color =
        isDark ? const Color(0xFF207BD5) : const Color(0xFFFFDD99);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_HavenGlowPainter old) =>
      old.pulse != pulse || old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
// PARTICLE FIELD — slow drifting motes, warmth settling into the room
// ─────────────────────────────────────────────────────────────────────────────

class _Particle {
  final double x, y, size, speed, phase;
  const _Particle(
      {required this.x,
      required this.y,
      required this.size,
      required this.speed,
      required this.phase});

  factory _Particle.random(math.Random r) => _Particle(
        x: r.nextDouble(),
        y: r.nextDouble(),
        size: 1.0 + r.nextDouble() * 2.2,
        speed: 0.5 + r.nextDouble() * 0.8,
        phase: r.nextDouble() * math.pi * 2,
      );
}

class _ParticleFieldPainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  final bool isDark;
  const _ParticleFieldPainter(
      {required this.particles, required this.time, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final color = isDark ? const Color(0xFFB8D4FF) : const Color(0xFFFFE9B8);
    for (final p in particles) {
      final dy = math.sin(time * math.pi * 2 * p.speed + p.phase) * 10;
      final dx = math.cos(time * math.pi * 2 * p.speed * 0.6 + p.phase) * 6;
      final pos = Offset(p.x * size.width + dx, p.y * size.height + dy);
      final opacity =
          (0.10 + 0.16 * (math.sin(time * math.pi * 2 + p.phase) + 1) / 2);
      canvas.drawCircle(pos, p.size, Paint()..color = color.withOpacity(opacity));
    }
  }

  @override
  bool shouldRepaint(_ParticleFieldPainter old) => old.time != time;
}