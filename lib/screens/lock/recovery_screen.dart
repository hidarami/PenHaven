import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/atmosphere_state.dart';
import '../../services/lock_service.dart';
import '../../theme/app_colors.dart';
import 'pin_setup_screen.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _verify() async {
    if (_ctrl.text.trim().isEmpty || _busy) return;
    setState(() { _busy = true; _error = null; });
    final ok = await LockService.instance.verifyRecovery(_ctrl.text.trim());
    if (!mounted) return;
    if (ok) {
      // Remove old PIN first, then set a new one
      await LockService.instance.removePin();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const PinSetupScreen(mode: PinSetupMode.reset),
        ),
      );
    } else {
      setState(() { _error = 'Incorrect recovery code.'; _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AtmosphereState>().accentColor;
    return Scaffold(
      backgroundColor: AppColors.warmDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded,
                    size: 30, color: AppColors.mutedDark),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              Text('Forgot PIN',
                  style: GoogleFonts.crimsonPro(
                    fontSize: 34, fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  )),
              const SizedBox(height: 10),
              Text(
                'Enter the 6-digit recovery code you saved when you set up your PIN.',
                style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.mutedDark, height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 24, color: AppColors.textDark, letterSpacing: 5,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'XXX-XXX',
                    hintStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 24, color: AppColors.mutedDark, letterSpacing: 5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.danger.withOpacity(0.85),
                )),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent.withOpacity(0.2),
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _busy
                      ? SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: accent))
                      : Text('Verify Code', style: GoogleFonts.inter(
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