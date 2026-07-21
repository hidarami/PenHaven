import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/image_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR HEADER IMAGE
// Manages the optional banner image at the top of an entry.
//
// No image: Dashed border area with "Tap to add header image" text.
// Has image: Shows image full-width with a small "×" remove button overlay.
//
// Independent of inline body images — this is always the very first image
// element if it exists (before title in Read-Only).
// ─────────────────────────────────────────────────────────────────────────────

class EditorHeaderImage extends StatelessWidget {
  final String? currentPath;
  final ValueChanged<String?> onImageChanged; // null = remove

  const EditorHeaderImage({
    super.key,
    required this.currentPath,
    required this.onImageChanged,
  });

  Future<void> _pickImage(BuildContext context) async {
    final hasPermission =
        await PermissionService.instance.ensurePhotos(context);
    if (!hasPermission || !context.mounted) return;

    final path = await ImageService.instance.pickHeaderImage(context);
    if (path != null) onImageChanged(path);
  }

  void _removeImage() => onImageChanged(null);

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    final hasImage = currentPath != null &&
        currentPath!.isNotEmpty &&
        File(currentPath!).existsSync();

    if (hasImage) {
      return _ExistingImage(
        path: currentPath!,
        onRemove: _removeImage,
        onReplace: () => _pickImage(context),
      );
    }

    return _AddImageArea(
      onTap: () => _pickImage(context),
      mutedColor: mutedColor,
    );
  }
}

// ── No image: dashed tap area ────────────────────────────────────────────────

class _AddImageArea extends StatelessWidget {
  final VoidCallback onTap;
  final Color mutedColor;

  const _AddImageArea({required this.onTap, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: mutedColor.withOpacity(0.3),
            width: 1.5,
            // Dashed border via CustomPainter would be complex;
            // using low-opacity solid as a clean alternative.
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 18,
                color: mutedColor.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Tap to add header image',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: mutedColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Has image: full-width with remove/replace overlay ────────────────────────

class _ExistingImage extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  final VoidCallback onReplace;

  const _ExistingImage({
    required this.path,
    required this.onRemove,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Image
        GestureDetector(
          onTap: onReplace,
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Image.file(
              File(path),
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(height: 200),
            ),
          ),
        ),

        // Remove button — top-right
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
