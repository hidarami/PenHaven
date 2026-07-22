import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE SERVICE
// Handles the full image flow:
//   1. Pick from device gallery (ImagePicker)
//   2. Crop (ImageCropper — user can freely crop or skip)
//   3. Copy to app's permanent storage so it survives gallery deletions
//
// Returns the permanent file path, or null if user cancelled at any step.
// ─────────────────────────────────────────────────────────────────────────────

class ImageService {
  ImageService._();
  static final ImageService instance = ImageService._();

  final ImagePicker _picker = ImagePicker();

  static const String _folderName = 'flow_images';

  // ─────────────────────────────────────────────────────────────────────────
  // STORAGE PATH
  // ─────────────────────────────────────────────────────────────────────────

  Future<Directory> _getImageDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(appDir.path, _folderName));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }

  String _generateFilename(String originalPath) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = p.extension(originalPath).isNotEmpty
        ? p.extension(originalPath)
        : '.jpg';
    return '${ts}_flow$ext';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAIN ENTRY POINT
  // ─────────────────────────────────────────────────────────────────────────

  /// Opens gallery → crop window → copies to app storage.
  /// Returns permanent path, or null if cancelled.
  Future<String?> pickAndSave({
    required BuildContext context,
    bool allowCrop = true,
    double? cropAspectRatioX,
    double? cropAspectRatioY,
  }) async {
    // 1. Pick from gallery
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // Compress on import
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return null;

    // 2. Crop (user can freely adjust or just confirm)
    String sourcePath = picked.path;
    if (allowCrop) {
      final cropped = await _crop(
        context: context,
        sourcePath: sourcePath,
        aspectRatioX: cropAspectRatioX,
        aspectRatioY: cropAspectRatioY,
      );
      if (cropped == null) return null; // User cancelled crop
      sourcePath = cropped;
    }

    // 3. Copy to permanent app storage
    return _copyToStorage(sourcePath);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CROP
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> _crop({
    required BuildContext context,
    required String sourcePath,
    double? aspectRatioX,
    double? aspectRatioY,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.warmDark : AppColors.warmWhite;
    final toolbarColor = isDark ? AppColors.warmDark : AppColors.warmWhite;
    final toolbarWidgetColor =
        isDark ? AppColors.textDark : AppColors.textLight;

    CropAspectRatio? aspectRatio;
    if (aspectRatioX != null && aspectRatioY != null) {
      aspectRatio = CropAspectRatio(
        ratioX: aspectRatioX,
        ratioY: aspectRatioY,
      );
    }

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: aspectRatio,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '',
          toolbarColor: toolbarColor,
          toolbarWidgetColor: toolbarWidgetColor,
          backgroundColor: bg,
          activeControlsWidgetColor: AppColors.teal,
          cropGridColor: AppColors.teal.withOpacity(0.4),
          cropFrameColor: AppColors.teal,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: aspectRatio != null,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: '',
          aspectRatioLockEnabled: aspectRatio != null,
          resetAspectRatioEnabled: aspectRatio == null,
          aspectRatioPickerButtonHidden: aspectRatio != null,
        ),
      ],
    );

    return croppedFile?.path;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STORAGE
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _copyToStorage(String sourcePath) async {
    final dir = await _getImageDir();
    final filename = _generateFilename(sourcePath);
    final destination = p.join(dir.path, filename);
    await File(sourcePath).copy(destination);
    return destination;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONVENIENCE WRAPPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// For header images — crop with a fixed aspect ratio.
  /// [ratioX] and [ratioY] define the locked ratio. If both null, free crop.
  Future<String?> pickHeaderImage(
    BuildContext context, {
    double? ratioX,
    double? ratioY,
    bool skipCrop = false,
  }) async {
    if (skipCrop) {
      return pickAndSave(context: context, allowCrop: false);
    }
    return pickAndSave(
      context: context,
      allowCrop: true,
      cropAspectRatioX: ratioX,
      cropAspectRatioY: ratioY,
    );
  }

  /// For inline body images — no forced crop ratio, user crops freely.
  Future<String?> pickInlineImage(BuildContext context) async {
    return pickAndSave(context: context, allowCrop: true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────────────────

  /// Deletes an image file from app storage.
  /// Call when user removes a header or inline image from an entry.
  Future<void> deleteImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Silently ignore — file might have already been removed.
    }
  }

  /// Returns total size of all stored images in bytes.
  Future<int> totalStorageBytes() async {
    try {
      final dir = await _getImageDir();
      int total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
