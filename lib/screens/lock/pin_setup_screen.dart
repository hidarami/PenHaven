import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/lock_service.dart';
import '../../theme/app_colors.dart';
import 'lock_numpad.dart';

enum PinSetupMode { setup, change, reset }

class PinSetupScreen extends StatefulWidget {
  final PinSetupMode mode;

  const PinSetupScreen({super.key, this.mode = PinSetupMode.setup});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  // steps: 0=verify current (change mode only), 1=enter new, 2=confirm, 3=recovery
  int _step = 0;
  String _input = '';
  String _first = '';
  bool _error = false;
  String? _recoveryCode;
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode != PinSetupMode.change) _step = 1; // skip verify step
    _checkBio();
  }

  Future<void> _checkBio() async {
    final ok = await LockService.instance.isBiometricAvailable();
    if (mounted) setState(() => _bioAvailable = ok);
  }

  void _onDigit(String d) {
    if (_input.length >= 4) return;
    setState(() { _input += d; _error = false; });
    if (_input.length == 4) _onComplete();
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _onComplete() async {
    if (_step == 0) {
      // Verify current PIN (change mode)
      final ok = await LockService.instance.verifyPin(_input);
      if (ok) {
        setState(() { _step = 1; _input = ''; _error = false; });
      } else {
        setState(() { _error = true; _input = ''; });
      }
    } else if (_step == 1) {
      // Store first entry, go to confirm
      setState(() { _first = _input; _input = ''; _step = 2; });
    } else if (_step == 2) {
      // Confirm
      if (_input == _first) {
        final code = await LockService.instance.setupPin(_input);
        await LockService.instance.setBiometricEnabled(_bioEnabled);
        if (mounted) {
          context.read<AppState>().setLockEnabled(true);
          setState(() { _recoveryCode = code; _step = 3; });
        }
      } else {
        setState(() {
          _error = true;
          _input = '';
          _step = 1; // back to enter
          _first = '';
        });
      }
    }
  }

  void _done() {
    if (widget.mode == PinSetupMode.reset && mounted) {
      context.read<AppState>().unlockApp();
      // Pop back to home (recovery flow has extra screens on stack)
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 3 && _recoveryCode != null) {
      return _RecoveryCodeDisplay(code: _recoveryCode!, onDone: _done);
    }

    final headings = {
      0: 'Confirm current PIN',
      1: widget.mode == PinSetupMode.change ? 'New PIN' : 'Set your PIN',
      2: 'Confirm PIN',
    };
    final subtitles = {
      0: 'Enter your current 4-digit PIN to continue.',
      1: 'Choose a 4-digit PIN for Flow.',
      2: 'Enter the same PIN again to confirm.',
    };

    return Scaffold(
      backgroundColor: AppColors.warmDark,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.chevron_left_rounded,
                    size: 30, color: AppColors.mutedDark),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Spacer(),

            Text(headings[_step]!, style: GoogleFonts.crimsonPro(
              fontSize: 30, fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            )),
            const SizedBox(height: 8),
            Text(subtitles[_step]!, style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.mutedDark,
            )),

            const SizedBox(height: 44),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 13, height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _input.length
                        ? AppColors.teal
                        : Colors.white.withOpacity(0.18),
                  ),
                );
              }),
            ),

            SizedBox(
              height: 28,
              child: _error
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _step == 0 ? 'Incorrect PIN.' : "PINs don't match. Try again.",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.danger.withOpacity(0.85),
                        ),
                      ),
                    )
                  : null,
            ),

            const SizedBox(height: 24),

            LockNumpad(onDigit: _onDigit, onDelete: _onDelete),

            // Biometric option (only on first-entry step)
            if (_bioAvailable && _step == 1) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => setState(() => _bioEnabled = !_bioEnabled),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: _bioEnabled ? AppColors.teal : Colors.transparent,
                        border: Border.all(
                          color: _bioEnabled ? AppColors.teal : AppColors.mutedDark,
                          width: 1.5,
                        ),
                      ),
                      child: _bioEnabled
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text('Also allow biometric unlock',
                        style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.mutedDark)),
                  ],
                ),
              ),
            ],

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ── Recovery code display (step 3) ───────────────────────────────────────────

class _RecoveryCodeDisplay extends StatelessWidget {
  final String code;
  final VoidCallback onDone;

  const _RecoveryCodeDisplay({required this.code, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(Icons.key_rounded, color: AppColors.teal, size: 40),
              const SizedBox(height: 18),
              Text('Save this recovery code',
                  style: GoogleFonts.crimsonPro(
                    fontSize: 30, fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  )),
              const SizedBox(height: 10),
              Text(
                'If you ever forget your PIN, this code is the only way back in. '
                'Write it somewhere safe — it will not be shown again.',
                style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.mutedDark, height: 1.55,
                ),
              ),
              const SizedBox(height: 36),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.teal.withOpacity(0.35), width: 1.5,
                    ),
                  ),
                  child: Text(code,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 30, color: AppColors.teal,
                        letterSpacing: 5, fontWeight: FontWeight.w600,
                      )),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text("I've written it down",
                      style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}