import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOCK SCREEN
// Fullscreen overlay shown when user locks the app via Menu.
// Immediately triggers biometric prompt. Shows a tap-to-unlock UI as fallback.
// ─────────────────────────────────────────────────────────────────────────────

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _attempting = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometric on appear
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    if (_attempting || !mounted) return;
    setState(() => _attempting = true);
    final ok = await AuthService.instance.authenticateAppUnlock();
    if (!mounted) return;
    if (ok) {
      context.read<AppState>().unlockApp();
    } else {
      setState(() => _attempting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmDark,
      body: GestureDetector(
        onTap: _attempting ? null : _tryUnlock,
        behavior: HitTestBehavior.translucent,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Flow',
                style: GoogleFonts.crimsonPro(
                  fontSize: 52,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textDark,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'your sanctuary',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textDark.withOpacity(0.4),
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 64),
              // Fingerprint icon — tap to trigger again
              AnimatedOpacity(
                opacity: _attempting ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 72,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _attempting ? 'Authenticating…' : 'Tap to unlock',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.mutedDark,
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