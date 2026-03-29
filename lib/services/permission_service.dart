import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PERMISSION SERVICE
// Centralised runtime permission handling for Android.
// iOS permissions are handled inline by system APIs (image_picker, geolocator)
// so they don't need explicit requests here.
//
// Call check methods before using their associated features.
// If denied, show an explanation then direct user to app settings.
// ─────────────────────────────────────────────────────────────────────────────

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  // ─────────────────────────────────────────────────────────────────────────
  // PHOTOS / STORAGE
  // Android 13+ uses READ_MEDIA_IMAGES; older uses READ_EXTERNAL_STORAGE
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> requestPhotos() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.photos.request();
    if (status.isGranted) return true;

    // Android < 13 fallback
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<bool> hasPhotosPermission() async {
    if (!Platform.isAndroid) return true;
    final photos = await Permission.photos.status;
    if (photos.isGranted) return true;
    final storage = await Permission.storage.status;
    return storage.isGranted;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCATION (for weather)
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> requestLocation() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<bool> hasLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAMERA (optional — image_picker can also open camera)
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DENIED FOREVER HANDLER
  // ─────────────────────────────────────────────────────────────────────────

  /// Shows a dialog explaining why the permission is needed,
  /// then opens app settings if user taps "Open Settings".
  Future<void> showDeniedDialog(
    BuildContext context, {
    required String permissionName,
    required String reason,
  }) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$permissionName Required'),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONVENIENCE — request photos with dialog on denial
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> ensurePhotos(BuildContext context) async {
    if (await hasPhotosPermission()) return true;

    final granted = await requestPhotos();
    if (granted) return true;

    // Check if permanently denied
    final status = await Permission.photos.status;
    if (status.isPermanentlyDenied && context.mounted) {
      await showDeniedDialog(
        context,
        permissionName: 'Photo Library',
        reason:
            'Flow needs access to your photos to add images to your entries. '
            'Please enable it in Settings.',
      );
    }

    return false;
  }

  Future<bool> ensureLocation(BuildContext context) async {
    if (await hasLocationPermission()) return true;

    final granted = await requestLocation();
    if (granted) return true;

    final status = await Permission.locationWhenInUse.status;
    if (status.isPermanentlyDenied && context.mounted) {
      await showDeniedDialog(
        context,
        permissionName: 'Location',
        reason:
            'Flow uses your location to detect the local weather and set the '
            'right atmosphere for your writing. '
            'You can disable this in Settings.',
      );
    }

    return false;
  }
}
