import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/neumorphic_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WORK DESK HEADER
// Title "Work Desk" on the left, hourglass Time Capsule icon on the right.
// The Time Capsule icon shows a badge dot if ready capsules or "on this day"
// entries exist.
//
// CRITICAL per Master Specification §3:
//   Time Capsule icon is in the UPPER-RIGHT corner, opposite the title.
//   NOT embedded inside the title text.
// ─────────────────────────────────────────────────────────────────────────────

class WorkDeskHeader extends StatelessWidget {
  final VoidCallback onTimeCapsuleTap;

  const WorkDeskHeader({super.key, required this.onTimeCapsuleTap});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dark = appState.isDarkMode;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    final hasTimeCapsuleContent = appState.readyCapsules.isNotEmpty ||
        appState.timeCapsuleEntries.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title + tagline ──────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Work Desk', style: AppTypography.panelHeader(textColor)),
              const SizedBox(height: 4),
              Text(
                'Tasks fade. It\'s okay to let go.',
                style: AppTypography.panelSubtitle(mutedColor),
              ),
            ],
          ),
        ),

        // ── Time Capsule icon (upper-right) ───────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            NeumorphicButton(
              onTap: onTimeCapsuleTap,
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.hourglass_empty_rounded,
                size: 20,
                color: mutedColor,
              ),
            ),
            // Badge dot — indicates ready-to-open content
            if (hasTimeCapsuleContent)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.aqua,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
