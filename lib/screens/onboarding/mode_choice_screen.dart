import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../home_screen.dart';

// Shown once after onboarding: Full vs Minimalist. Changeable anytime in
// Settings; switching never deletes headers/images already added.
class ModeChoiceScreen extends StatefulWidget {
  const ModeChoiceScreen({super.key});

  @override
  State<ModeChoiceScreen> createState() => _ModeChoiceScreenState();
}

class _ModeChoiceScreenState extends State<ModeChoiceScreen> {
  bool _busy = false;

  Future<void> _choose(bool minimalist) async {
    if (_busy) return;
    setState(() => _busy = true);
    await context.read<AppState>().setMinimalistMode(minimalist);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'How much do you\nwant to see?',
                style: GoogleFonts.crimsonPro(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You can change this anytime in Settings. Nothing you add — '
                'header images, pictures — is ever removed if you switch later.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.mutedDark,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 32),
              _ModeCard(
                title: 'Full Experience',
                subtitle: 'Themes, atmospheres, Sanctuary community, header '
                    'images, and the full toolbar.',
                icon: Icons.auto_awesome_rounded,
                accent: AppColors.aqua,
                busy: _busy,
                onTap: () => _choose(false),
              ),
              const SizedBox(height: 14),
              _ModeCard(
                title: 'Minimalist',
                subtitle: 'Just writing. A simpler toolbar, no cover art, '
                    'Sanctuary hidden. You can still add pictures inside an entry.',
                icon: Icons.crop_free_rounded,
                accent: const Color(0xFF7BA591),
                busy: _busy,
                onTap: () => _choose(true),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool busy;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.mutedDark, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}