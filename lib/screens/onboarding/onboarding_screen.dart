import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING SCREEN
// Shown once on first launch. 5 pages, swipeable, skippable.
// Marks hasSeenOnboarding on completion/skip so it never shows again.
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  late AnimationController _dotCtrl;
  int _page = 0;

  static const _pages = [
    _OPage(
      icon: Icons.water_outlined,
      title: 'Follow the current.',
      body:
          'Flow is your private sanctuary for writing — unhurried, unjudged, entirely yours.',
      accent: AppColors.aqua,
      bg: Color(0xFF060E1A),
    ),
    _OPage(
      icon: Icons.auto_stories_outlined,
      title: 'Stories & Entries.',
      body:
          'Organise your writing into Stories. Each story holds entries — your journal, your memoir, your ideas.',
      accent: Color(0xFF5B8DB8),
      bg: Color(0xFF060D18),
    ),
    _OPage(
      icon: Icons.wb_twilight_rounded,
      title: 'The world breathes with you.',
      body:
          'The atmosphere shifts with the time of day and weather — golden afternoon, midnight ink, rainy mornings.',
      accent: Color(0xFFD4820A),
      bg: Color(0xFF120A02),
    ),
    _OPage(
      icon: Icons.people_outline_rounded,
      title: 'The Sanctuary.',
      body:
          'Share reflections with a community of thoughtful writers. Anonymous or named — always your choice.',
      accent: Color(0xFF9472D4),
      bg: Color(0xFF0A0812),
    ),
    _OPage(
      icon: Icons.favorite_border_rounded,
      title: 'No streaks. No guilt.',
      body:
          'Write when you want. Flow remembers, but never judges.\n\nYour sanctuary awaits.',
      accent: Color(0xFFE87FA0),
      bg: Color(0xFF12060A),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await context.read<AppState>().markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: page.bg,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        color: page.bg,
        child: SafeArea(
          child: Column(
            children: [
              // Skip
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.mutedDark,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    child: Text('Skip',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppColors.mutedDark)),
                  ),
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _PageView(page: _pages[i]),
                ),
              ),

              // Dots + button
              Padding(
                padding: EdgeInsets.fromLTRB(32, 0, 32, bottomPad + 24),
                child: Row(
                  children: [
                    // Dots
                    Row(
                      children: List.generate(_pages.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _page ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? page.accent
                                : AppColors.mutedDark.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    // Next / Begin button
                    GestureDetector(
                      onTap: _next,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 13),
                        decoration: BoxDecoration(
                          color: page.accent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                              color: page.accent.withOpacity(0.45), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _page == _pages.length - 1 ? 'Begin' : 'Next',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: page.accent,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Icon(
                              _page == _pages.length - 1
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 16,
                              color: page.accent,
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
      ),
    );
  }
}

// ── Page data model ───────────────────────────────────────────────────────────

class _OPage {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final Color bg;

  const _OPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    required this.bg,
  });
}

// ── Page view widget ──────────────────────────────────────────────────────────

class _PageView extends StatelessWidget {
  final _OPage page;
  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon in glowing tile
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: page.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: page.accent.withOpacity(0.22), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: page.accent.withOpacity(0.18),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(page.icon, size: 30, color: page.accent),
          ),

          const SizedBox(height: 44),

          Text(
            page.title,
            style: GoogleFonts.crimsonPro(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              height: 1.1,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            page.body,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppColors.mutedDark,
              height: 1.72,
            ),
          ),
        ],
      ),
    );
  }
}