import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GLASS BUTTON
// Liquid glass style — frosted, translucent, blurred background.
// Used ONLY for the floating menu button (hamburger icon).
// ─────────────────────────────────────────────────────────────────────────────

class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double size;

  const GlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(size / 2),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEUMORPHIC CARD
// Soft raised container. Used for story cards, entry cards, task items.
// Automatically adapts to dark mode.
// ─────────────────────────────────────────────────────────────────────────────

class NeumorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const NeumorphicCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final radius = borderRadius ?? BorderRadius.circular(12);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.neuLight(dark),
              offset: const Offset(-2, -2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: AppColors.neuDark(dark),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEUMORPHIC BUTTON
// Pressable neumorphic button. Inverts shadow on press.
// ─────────────────────────────────────────────────────────────────────────────

class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double? width;

  const NeumorphicButton({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.width,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final radius = widget.borderRadius ?? BorderRadius.circular(10);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.width,
        padding: widget.padding ??
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          boxShadow: _pressed
              ? [
                  // Pressed: invert — looks pushed in
                  BoxShadow(
                    color: AppColors.neuDark(dark),
                    offset: const Offset(-1, -1),
                    blurRadius: 2,
                  ),
                  BoxShadow(
                    color: AppColors.neuLight(dark),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.neuLight(dark),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: AppColors.neuDark(dark),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEUMORPHIC INPUT
// Neumorphic text input — appears slightly recessed (inner shadow illusion).
// ─────────────────────────────────────────────────────────────────────────────

class NeumorphicInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final Widget? prefixWidget;
  final Widget? suffixWidget;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final FocusNode? focusNode;

  const NeumorphicInput({
    super.key,
    this.controller,
    this.hintText,
    this.prefixWidget,
    this.suffixWidget,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.textStyle,
    this.hintStyle,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        // Recessed look: reversed shadow direction
        boxShadow: [
          BoxShadow(
            color: AppColors.neuDark(dark),
            offset: const Offset(1, 1),
            blurRadius: 3,
          ),
          BoxShadow(
            color: AppColors.neuLight(dark),
            offset: const Offset(-1, -1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          if (prefixWidget != null) ...[
            const SizedBox(width: 12),
            prefixWidget!,
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              maxLines: maxLines,
              style: textStyle ??
                  TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontFamily: 'Inter',
                  ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: hintStyle ??
                    TextStyle(color: mutedColor, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          if (suffixWidget != null) ...[
            suffixWidget!,
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
