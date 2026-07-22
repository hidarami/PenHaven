import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../providers/atmosphere_state.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SPLASH SCREEN
// Initializes AppState and AtmosphereState while showing a minimal
// centered wordmark. Routes to HomeScreen once ready.
// No onboarding flow is needed — first-time experience is handled inline
// on the Story Panel (Panel 1) per the Master Specification.
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fade;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeIn);
    _fade.forward();

    // Defer _init to after the first frame to prevent
    // "setState()/markNeedsBuild() called during build" from AppState.init() notifyListeners().
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final appState = context.read<AppState>();
    final atmosphereState = context.read<AtmosphereState>();

    // Load all persistent data
    await appState.init();

    

    // Start atmosphere engine with API key from settings
    atmosphereState.init(
      apiKey: appState.openWeatherApiKey.isNotEmpty
          ? appState.openWeatherApiKey
          : null,
    );

    // Minimum splash duration so the wordmark is readable
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    // Navigate to home — replace so back button doesn't return to splash
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _opacity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Flow',
                style: GoogleFonts.crimsonPro(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: textColor,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'your sanctuary',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.4),
                  letterSpacing: 3,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
