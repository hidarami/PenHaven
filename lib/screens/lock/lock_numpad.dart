import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class LockNumpad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;
  final Color accentColor;

  const LockNumpad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
    this.accentColor = AppColors.aqua,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _row(['1', '2', '3']),
          const SizedBox(height: 10),
          _row(['4', '5', '6']),
          const SizedBox(height: 10),
          _row(['7', '8', '9']),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: onBiometric != null
                    ? NumpadKey(
                        onTap: onBiometric!,
                        child: Icon(Icons.fingerprint_rounded,
                            size: 28, color: accentColor),
                      )
                    : const SizedBox(),
              ),
              NumpadKey(label: '0', onTap: () => onDigit('0')),
              NumpadKey(
                onTap: onDelete,
                child: const Icon(Icons.backspace_outlined,
                    size: 22, color: AppColors.mutedDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> digits) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: digits
            .map((d) => NumpadKey(label: d, onTap: () => onDigit(d)))
            .toList(),
      );
}

class NumpadKey extends StatefulWidget {
  final String? label;
  final Widget? child;
  final VoidCallback onTap;

  const NumpadKey({super.key, this.label, this.child, required this.onTap})
      : assert(label != null || child != null);

  @override
  State<NumpadKey> createState() => _NumpadKeyState();
}

class _NumpadKeyState extends State<NumpadKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressed
              ? Colors.white.withOpacity(0.14)
              : Colors.white.withOpacity(0.07),
        ),
        alignment: Alignment.center,
        child: widget.child ??
            Text(
              widget.label!,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w300,
                color: AppColors.textDark,
              ),
            ),
      ),
    );
  }
}
