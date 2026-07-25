import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../providers/atmosphere_state.dart';
import '../services/auth_service.dart';
import '../services/lock_service.dart';
import '../theme/app_colors.dart';
import 'lock/lock_numpad.dart';
import 'lock/recovery_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOCK SCREEN
// Supports both PIN and biometric authentication.
// - If biometric is enabled, tries biometric first
// - Falls back to PIN entry if biometric fails or isn't enabled
// - PIN verification uses LockService.verifyPin()
// ─────────────────────────────────────────────────────────────────────────────

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _attempting = false;
  bool _showPinEntry = false;
  String _pinInput = '';
  bool _pinError = false;
  String? _statusMessage;
  bool _bioAvailable = false; // hardware present + enrolled
  bool _bioEnabled = false; // user opted in during PIN setup

  @override
  void initState() {
    super.initState();
    _checkBiometricSetting();
  }

  Future<void> _checkBiometricSetting() async {
    // Check both hardware availability and user preference
    final bioAvailable = await LockService.instance.isBiometricAvailable();
    final bioEnabled = await LockService.instance.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _bioAvailable = bioAvailable;
        _bioEnabled = bioEnabled;
      });
      if (!bioEnabled || !bioAvailable) {
        // No bio configured — go straight to PIN
        setState(() => _showPinEntry = true);
      } else {
        // Hardware available and user enabled — try bio first
        _tryBiometricUnlock();
      }
    }
  }

  Future<void> _tryBiometricUnlock() async {
    if (_attempting || !mounted) return;

    setState(() {
      _attempting = true;
      _statusMessage = null;
    });

    bool ok = false;
    try {
      ok = await AuthService.instance
          .authenticateAppUnlock()
          .timeout(const Duration(seconds: 30), onTimeout: () => false);
    } catch (e) {
      ok = false;
    } finally {
      if (!mounted) return;
      if (ok) {
        context.read<AppState>().unlockApp();
      } else {
        setState(() {
          _attempting = false;
          _showPinEntry = true;
          _statusMessage = 'Biometric failed. Enter PIN to unlock.';
        });
      }
    }
  }

  Future<void> _verifyPin() async {
    if (_pinInput.length != 4 || _attempting) return;

    setState(() {
      _attempting = true;
      _pinError = false;
    });

    final ok = await LockService.instance.verifyPin(_pinInput);

    if (!mounted) return;

    if (ok) {
      context.read<AppState>().unlockApp();
    } else {
      setState(() {
        _attempting = false;
        _pinError = true;
        _pinInput = '';
        _statusMessage = 'Incorrect PIN. Try again.';
      });
    }
  }

  void _onDigit(String d) {
    if (_pinInput.length >= 4) return;
    setState(() {
      _pinInput += d;
      _pinError = false;
    });
    if (_pinInput.length == 4) _verifyPin();
  }

  void _onDelete() {
    if (_pinInput.isEmpty) return;
    setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AtmosphereState>().accentColor;
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;

    if (_showPinEntry) {
      return _PinEntryView(
        pinInput: _pinInput,
        pinError: _pinError,
        statusMessage: _statusMessage,
        attempting: _attempting,
        onDigit: _onDigit,
        onDelete: _onDelete,
        showBiometric: _bioAvailable && _bioEnabled,
        onBiometric:
            (_bioAvailable && _bioEnabled) ? _tryBiometricUnlock : null,
        accentColor: accent,
        isDark: dark,
        bg: bg,
      );
    }

    return _BiometricView(
      attempting: _attempting,
      statusMessage: _statusMessage,
      onRetry: _tryBiometricUnlock,
      onUsePin: () => setState(() => _showPinEntry = true),
      accentColor: accent,
      isDark: dark,
      bg: bg,
    );
  }
}

// ── Biometric unlock view ─────────────────────────────────────────────────────

class _BiometricView extends StatelessWidget {
  final bool attempting;
  final String? statusMessage;
  final VoidCallback onRetry;
  final VoidCallback onUsePin;
  final Color accentColor;
  final bool isDark;
  final Color bg;

  const _BiometricView({
    required this.attempting,
    required this.statusMessage,
    required this.onRetry,
    required this.onUsePin,
    this.accentColor = AppColors.aqua,
    this.isDark = true,
    this.bg = AppColors.warmDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;
    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: attempting ? null : onRetry,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Flow',
                  style: GoogleFonts.crimsonPro(
                    fontSize: 52,
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
                    color: textColor.withOpacity(0.4),
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 64),
                AnimatedOpacity(
                  opacity: attempting ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 72,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 16),
                if (attempting)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: accentColor.withOpacity(0.7),
                    ),
                  )
                else
                  Text(
                    'Tap to unlock',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: mutedColor,
                    ),
                  ),
                if (statusMessage != null && !attempting) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      statusMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                      fontSize: 12,
                      color: textColor.withOpacity(0.45),
                      height: 1.5,
                    ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (!attempting)
                  TextButton(
                    onPressed: onUsePin,
                    child: Text(
                      'Use PIN instead',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: accentColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── PIN entry view ───────────────────────────────────────────────────────────

class _PinEntryView extends StatelessWidget {
  final String pinInput;
  final bool pinError;
  final String? statusMessage;
  final bool attempting;
  final Function(String) onDigit;
  final VoidCallback onDelete;
  final bool showBiometric;
  final VoidCallback? onBiometric;
  final Color accentColor;
  final bool isDark;
  final Color bg;

  const _PinEntryView({
    required this.pinInput,
    required this.pinError,
    required this.statusMessage,
    required this.attempting,
    required this.onDigit,
    required this.onDelete,
    this.showBiometric = false,
    this.onBiometric,
    this.accentColor = AppColors.aqua,
    this.isDark = true,
    this.bg = AppColors.warmDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Spacer(),

            Text(
              'Enter PIN',
              style: GoogleFonts.crimsonPro(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock Flow to continue',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: mutedColor,
              ),
            ),

            const SizedBox(height: 44),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < pinInput.length
                        ? accentColor
                        : (isDark
                            ? Colors.white.withOpacity(0.18)
                            : Colors.black.withOpacity(0.15)),
                  ),
                );
              }),
            ),

            SizedBox(
              height: 28,
              child: pinError
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Incorrect PIN.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.danger.withOpacity(0.85),
                        ),
                      ),
                    )
                  : null,
            ),

            if (statusMessage != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  statusMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textDark.withOpacity(0.45),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            LockNumpad(
                onDigit: onDigit,
                onDelete: onDelete,
                accentColor: accentColor,
                isDark: isDark),

            // ── Biometric retry (shown when bio is configured) ─────────────
            if (showBiometric && onBiometric != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: attempting ? null : onBiometric,
                icon: Icon(
                  Icons.fingerprint_rounded,
                  color: accentColor,
                  size: 22,
                ),
                label: Text(
                  'Use Biometric',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: accentColor,
                  ),
                ),
              ),
            ],

            // ── Forgot PIN recovery link ───────────────────────────────────
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecoveryScreen(),
                ),
              ),
              child: Text(
                'Forgot PIN?',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: mutedColor.withOpacity(0.65),
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
