import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/auth_service.dart';
import '../services/lock_service.dart';
import '../theme/app_colors.dart';
import 'lock/lock_numpad.dart';

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

  @override
  void initState() {
    super.initState();
    _checkBiometricSetting();
  }

  Future<void> _checkBiometricSetting() async {
    final bioEnabled = await LockService.instance.isBiometricEnabled();
    if (mounted) {
      // If biometric is not enabled, show PIN entry immediately
      if (!bioEnabled) {
        setState(() => _showPinEntry = true);
      } else {
        // Try biometric first
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
    if (_showPinEntry) {
      return _PinEntryView(
        pinInput: _pinInput,
        pinError: _pinError,
        statusMessage: _statusMessage,
        attempting: _attempting,
        onDigit: _onDigit,
        onDelete: _onDelete,
      );
    }

    return _BiometricView(
      attempting: _attempting,
      statusMessage: _statusMessage,
      onRetry: _tryBiometricUnlock,
      onUsePin: () => setState(() => _showPinEntry = true),
    );
  }
}

// ── Biometric unlock view ─────────────────────────────────────────────────────

class _BiometricView extends StatelessWidget {
  final bool attempting;
  final String? statusMessage;
  final VoidCallback onRetry;
  final VoidCallback onUsePin;

  const _BiometricView({
    required this.attempting,
    required this.statusMessage,
    required this.onRetry,
    required this.onUsePin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmDark,
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
                AnimatedOpacity(
                  opacity: attempting ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 72,
                    color: AppColors.aqua,
                  ),
                ),
                const SizedBox(height: 16),
                if (attempting)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.aqua.withOpacity(0.7),
                    ),
                  )
                else
                  Text(
                    'Tap to unlock',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.mutedDark,
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
                        color: AppColors.textDark.withOpacity(0.45),
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
                        color: AppColors.aqua,
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

  const _PinEntryView({
    required this.pinInput,
    required this.pinError,
    required this.statusMessage,
    required this.attempting,
    required this.onDigit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmDark,
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
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock Flow to continue',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedDark,
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
                        ? AppColors.aqua
                        : Colors.white.withOpacity(0.18),
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

            LockNumpad(onDigit: onDigit, onDelete: onDelete),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
