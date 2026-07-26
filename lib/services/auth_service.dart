import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SERVICE
// Wraps local_auth for biometric authentication.
// Used for:
//   - App-level lock (if user enables in Settings)
//   - Per-story lock (if story.isLocked = true)
//
// Android: Fingerprint / face unlock via BiometricPrompt
// iOS: Face ID / Touch ID (same Dart API, different native impl)
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final LocalAuthentication _auth = LocalAuthentication();

  // ─────────────────────────────────────────────────────────────────────────
  // CAPABILITY CHECK
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if the device supports biometrics AND has enrolled ones.
  Future<bool> isBiometricAvailable() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;

      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Returns the list of available biometric types (for UI display).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTHENTICATE
  // ─────────────────────────────────────────────────────────────────────────

  /// Prompts biometric authentication.
  /// [reason] is shown to the user in the system dialog.
  /// Returns true if authentication succeeded.
  Future<bool> authenticate({
    String reason = 'Authenticate to access PenHaven',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow PIN fallback
          stickyAuth: true, // Keep prompt alive if user leaves app
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      // NotAvailable, NotEnrolled, LockedOut, etc.
      // Return false — caller handles the locked state gracefully.
      debugBiometricError(e);
      return false;
    }
  }

  /// Authenticate to unlock the app on resume.
  Future<bool> authenticateAppUnlock() async {
    return authenticate(
      reason: 'Unlock PenHaven to continue writing',
    );
  }

  /// Authenticate to open a locked story.
  Future<bool> authenticateStoryUnlock(String storyTitle) async {
    return authenticate(
      reason: 'Unlock "$storyTitle"',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEBUG
  // ─────────────────────────────────────────────────────────────────────────

  void debugBiometricError(PlatformException e) {
    // In production this is silently ignored.
    // In debug mode it prints to help during development.
    assert(() {
      // ignore: avoid_print
      print('[AuthService] PlatformException: ${e.code} — ${e.message}');
      return true;
    }());
  }
}
