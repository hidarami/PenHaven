import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class NavTutorialOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const NavTutorialOverlay({super.key, required this.onDone});

  @override
  State<NavTutorialOverlay> createState() => _NavTutorialOverlayState();
}

class _NavTutorialOverlayState extends State<NavTutorialOverlay> {
  int _step = 0;

  static const List<({IconData icon, String title, String body})> _steps = [
    (
      icon: Icons.grid_view_rounded,
      title: 'Tap to explore',
      body: 'Use the bar at the bottom to move between Home, Library, '
          'Sanctuary, and your Profile. The center button starts a new entry.',
    ),
    (
      icon: Icons.touch_app_outlined,
      title: 'Read, then write',
      body: 'Tap any entry to read it. Long-press or double-tap anywhere '
          'while reading to jump straight into editing.',
    ),
    (
      icon: Icons.chevron_left_rounded,
      title: 'No back buttons',
      body: 'Most screens close with a right-swipe instead of a back button '
          '— it keeps the page feeling calm and uncluttered.',
    ),
    (
      icon: Icons.auto_stories_outlined,
      title: 'Your haven awaits',
      body: 'The light around you shifts with the time of day. Nothing is '
          'timed, nothing is graded. Write whenever you want.',
    ),
  ];

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _steps[_step];
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.62),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: widget.onDone,
                    child: Text('Skip',
                        style:
                            GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, color: AppColors.aqua, size: 28),
                        const SizedBox(height: 14),
                        Text(s.title,
                            style: GoogleFonts.crimsonPro(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(s.body,
                            style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: Colors.white.withOpacity(0.8),
                                height: 1.55)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Row(
                      children: List.generate(_steps.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _step ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _step
                                ? AppColors.aqua
                                : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _next,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.aqua.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(24),
                          border:
                              Border.all(color: AppColors.aqua.withOpacity(0.5)),
                        ),
                        child: Text(
                          _step == _steps.length - 1 ? 'Got it' : 'Next',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.aqua),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}