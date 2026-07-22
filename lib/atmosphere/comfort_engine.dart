import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/editor_state.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COMFORT ENGINE — UI Layer
// Renders the whisper text overlay when comfort mode is triggered.
// Logic (trigger word detection, timer, comfort progress) lives in EditorState.
//
// Place inside the editor's Stack, after content and atmosphere overlay:
//
//   Stack(children: [
//     editorContent,
//     const AtmosphereOverlay(),
//     const ComfortWhisperOverlay(),
//   ])
// ─────────────────────────────────────────────────────────────────────────────

class ComfortWhisperOverlay extends StatelessWidget {
  const ComfortWhisperOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<EditorState, AppState>(
      builder: (context, editor, app, _) {
        if (!editor.showWhisper) return const SizedBox.shrink();

        final bg = app.isDarkMode ? AppColors.textDark : AppColors.textLight;

        return Positioned(
          bottom: 120, // Above the markdown toolbar
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: _WhisperText(
              text: editor.whisperText,
              color: bg,
            ),
          ),
        );
      },
    );
  }
}

class _WhisperText extends StatefulWidget {
  final String text;
  final Color color;

  const _WhisperText({required this.text, required this.color});

  @override
  State<_WhisperText> createState() => _WhisperTextState();
}

class _WhisperTextState extends State<_WhisperText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    // Fade in 0.8s → hold → fade out last 0.8s
    // Total duration driven by EditorState (3 seconds whisper window)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Center(
        child: Text(
          widget.text,
          style: GoogleFonts.crimsonPro(
            fontSize: 16,
            fontStyle: FontStyle.italic,
            // 15% opacity — felt more than seen
            color: widget.color.withOpacity(0.15),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMFORT PROGRESS INDICATOR
// Optional: a very subtle warm tint that grows over 50 seconds.
// Overlaid on top of the atmosphere background during comfort mode.
// ─────────────────────────────────────────────────────────────────────────────

class ComfortTintOverlay extends StatelessWidget {
  const ComfortTintOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<EditorState, AppState>(
      builder: (context, editor, app, _) {
        if (!editor.isComfortMode) return const SizedBox.shrink();

        final tint = app.isDarkMode
            ? AppColors.comfortDark.withOpacity(editor.comfortProgress * 0.3)
            : AppColors.comfortLight.withOpacity(editor.comfortProgress * 0.25);

        return Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: editor.comfortProgress.clamp(0.0, 1.0),
              duration: const Duration(seconds: 1),
              child: Container(color: tint),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MILESTONE OVERLAY
// Celebrates word count milestones (500, 1000, 2000, 5000 words).
// Shows briefly above toolbar — barely visible, warm, earned.
// ─────────────────────────────────────────────────────────────────────────────

class MilestoneOverlay extends StatefulWidget {
  const MilestoneOverlay({super.key});

  @override
  State<MilestoneOverlay> createState() => _MilestoneOverlayState();
}

class _MilestoneOverlayState extends State<MilestoneOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  int _lastShownMilestone = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorState>(
      builder: (context, editor, _) {
        // Animate in when milestone changes
        if (editor.showMilestone && editor.milestoneWords != _lastShownMilestone) {
          _lastShownMilestone = editor.milestoneWords;
          _ctrl.forward(from: 0);
          Future.delayed(const Duration(milliseconds: 2200), () {
            if (mounted) _ctrl.reverse();
          });
        }

        final dark = context.watch<AppState>().isDarkMode;
        final textColor = dark ? AppColors.textDark : AppColors.textLight;

        return Positioned(
          bottom: 130,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _opacity,
              child: Center(
                child: Text(
                  '✦ ${_milestoneLabel(editor.milestoneWords)} ✦',
                  style: GoogleFonts.crimsonPro(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: textColor.withOpacity(0.25),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _milestoneLabel(int words) {
    if (words >= 5000) return 'five thousand words';
    if (words >= 2000) return 'two thousand words';
    if (words >= 1000) return 'one thousand words';
    return 'five hundred words';
  }
}