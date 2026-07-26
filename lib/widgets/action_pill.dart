import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single shared glassmorphic action pill used by every entry/reflection
/// viewer (Community feed, Reflection viewer, Library, homescreen reader).
/// Fixed, non-scrolling layout — icon-only for Respond/Write Back so the
/// pill is always the same width regardless of which buttons are present.
class ActionPill extends StatelessWidget {
  final bool hasClapped;
  final VoidCallback onClap;
  final VoidCallback? onRespond;
  final bool respondActive;
  final VoidCallback? onWriteBack;
  final VoidCallback? onShare;

  const ActionPill({
    super.key,
    required this.hasClapped,
    required this.onClap,
    this.onRespond,
    this.respondActive = false,
    this.onWriteBack,
    this.onShare,
  });

  Widget _divider() =>
      Container(width: 0.5, height: 22, color: Colors.white.withOpacity(0.3));

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Appreciate — the only labeled button
              GestureDetector(
                onTap: onClap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: hasClapped
                        ? const Color(0xFFE87FA0).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        hasClapped ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        key: ValueKey(hasClapped),
                        size: 18,
                        color: hasClapped ? const Color(0xFFE87FA0) : Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      hasClapped ? 'Appreciated' : 'Appreciate',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasClapped ? const Color(0xFFE87FA0) : Colors.white.withOpacity(0.9)),
                    ),
                  ]),
                ),
              ),
              if (onRespond != null) ...[
                _divider(),
                GestureDetector(
                  onTap: onRespond,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    child: Icon(
                      respondActive ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                      size: 17,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
              if (onWriteBack != null) ...[
                _divider(),
                GestureDetector(
                  onTap: onWriteBack,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    child: Icon(Icons.edit_note_rounded, size: 18, color: Colors.white.withOpacity(0.9)),
                  ),
                ),
              ],
              if (onShare != null) ...[
                _divider(),
                GestureDetector(
                  onTap: onShare,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    child: Icon(Icons.ios_share_outlined, size: 17, color: Colors.white.withOpacity(0.9)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}