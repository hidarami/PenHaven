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
// Presents a ratio picker (16:9, 3:1, 4:3, 1:1, Full) before cropping.
// No image: Dashed border area with "Tap to add header image" text.
// Has image: Shows image full-width with "×" remove button overlay.
// ─────────────────────────────────────────────────────────────────────────────

class EditorHeaderImage extends StatelessWidget {
  final String? currentPath;
  final ValueChanged<(String?, String?)> onImageChanged; // (path, ratio), null path = remove

  const EditorHeaderImage({
    super.key,
    required this.currentPath,
    required this.onImageChanged,
  });

  String? _getRatioString(String choice) {
    switch (choice) {
      case 'full':
      case '16:9':
      case '4:3':
      case '3:1':
      case '1:1':
        return choice;
      default:
        return null;
    }
  }

  Future<void> _pickImage(BuildContext context) async {
    final hasPermission =
        await PermissionService.instance.ensurePhotos(context);
    if (!hasPermission || !context.mounted) return;

    // Show ratio picker first
    final choice = await _showRatioPicker(context);
    if (choice == null || !context.mounted) return; // User cancelled

    String? path;
    String? ratio = _getRatioString(choice);
    
    switch (choice) {
      case 'full':
        path = await ImageService.instance.pickHeaderImage(
          context,
          skipCrop: true,
        );
        break;
      case '16:9':
        path = await ImageService.instance.pickHeaderImage(
          context,
          ratioX: 16,
          ratioY: 9,
        );
        break;
      case '3:1':
        path = await ImageService.instance.pickHeaderImage(
          context,
          ratioX: 3,
          ratioY: 1,
        );
        break;
      case '4:3':
        path = await ImageService.instance.pickHeaderImage(
          context,
          ratioX: 4,
          ratioY: 3,
        );
        break;
      case '1:1':
        path = await ImageService.instance.pickHeaderImage(
          context,
          ratioX: 1,
          ratioY: 1,
        );
        break;
    }
    
    if (path != null) {
      onImageChanged((path, ratio));
    } else {
      onImageChanged((null, null));
    }
  }

  Future<String?> _showRatioPicker(BuildContext context) {
    final dark = context.read<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: mutedColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Banner size',
                style: GoogleFonts.crimsonPro(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(
                'Choose how wide your header image will be cropped.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: mutedColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Ratio options
              _RatioPicker(value: '16:9', label: '16 : 9', sub: 'Widescreen — best for most photos', textColor: textColor, mutedColor: mutedColor),
              _RatioPicker(value: '4:3', label: '4 : 3', sub: 'Classic photo ratio', textColor: textColor, mutedColor: mutedColor),
              _RatioPicker(value: '3:1', label: '3 : 1', sub: 'Cinematic strip — very wide', textColor: textColor, mutedColor: mutedColor),
              _RatioPicker(value: '1:1', label: '1 : 1', sub: 'Square — symmetrical', textColor: textColor, mutedColor: mutedColor),
              _RatioPicker(value: 'full', label: 'Full size', sub: 'No crop — use photo as-is', textColor: textColor, mutedColor: mutedColor),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage() => onImageChanged((null, null));

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

// ── Ratio picker option row ────────────────────────────────────────────────

class _RatioPicker extends StatelessWidget {
  final String value;
  final String label;
  final String sub;
  final Color textColor;
  final Color mutedColor;

  const _RatioPicker({
    required this.value,
    required this.label,
    required this.sub,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Visual ratio preview box
            Container(
              width: _previewWidth(),
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.aqua, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor)),
                  Text(sub,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: mutedColor,
                          height: 1.3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: mutedColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  // Visual preview box width that represents the ratio approximately
  double _previewWidth() {
    switch (value) {
      case '16:9': return 48;
      case '4:3': return 36;
      case '3:1': return 66;
      case '1:1': return 22;
      case 'full': return 38;
      default: return 40;
    }
  }
}

// ── No image: dashed tap area ─────────────────────────────────────────────────

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

// ── Has image: full-width with remove/replace overlay ─────────────────────────

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
        GestureDetector(
          onTap: onReplace,
          child: Image.file(
            File(path),
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(height: 200),
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
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}