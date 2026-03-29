import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LIBRARY EMPTY STATE
// Shown when user has no stories yet.
// Large centered 80×80 circle "+" button with "Add New Story" label below.
// ─────────────────────────────────────────────────────────────────────────────

class LibraryEmptyState extends StatelessWidget {
  final VoidCallback onCreateStory;

  const LibraryEmptyState({super.key, required this.onCreateStory});

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large + button
          GestureDetector(
            onTap: onCreateStory,
            child: _LargePlusButton(isDark: dark),
          ),
          const SizedBox(height: 16),
          Text(
            'Add New Story',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: mutedColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 80), // Offset upward visually
        ],
      ),
    );
  }
}

class _LargePlusButton extends StatefulWidget {
  final bool isDark;
  const _LargePlusButton({required this.isDark});

  @override
  State<_LargePlusButton> createState() => _LargePlusButtonState();
}

class _LargePlusButtonState extends State<_LargePlusButton> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.neuLight(widget.isDark),
            offset: const Offset(-4, -4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: AppColors.neuDark(widget.isDark),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(
        Icons.add,
        size: 32,
        color: AppColors.teal,
      ),
    );
  }
}
