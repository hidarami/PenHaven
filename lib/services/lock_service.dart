import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockService {
  LockService._();
  static final LockService instance = LockService._();

  static const _kPin = 'flow_lock_pin';
  static const _kRecovery = 'flow_lock_recovery';
  static const _kBiometric = 'flow_lock_biometric';

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> hasPin() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kPin);
  }

  /// Stores PIN and returns a 6-digit recovery code (e.g. "384-917").
  Future<String> setupPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPin, _encode(pin));
    final code = _makeCode();
    await p.setString(_kRecovery, _encode(code));
    return code;
  }

  Future<bool> verifyPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kPin) == _encode(pin);
  }

  Future<bool> verifyRecovery(String code) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kRecovery) == _encode(code.trim().toUpperCase());
  }

  Future<void> removePin() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kPin);
    await p.remove(_kRecovery);
    await p.remove(_kBiometric);
  }

  Future<bool> isBiometricAvailable() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      return (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kBiometric) ?? false;
  }

  Future<void> setBiometricEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kBiometric, v);
  }

  Future<bool> authenticateWithBiometric() async {
    try {
      final result = await _localAuth.authenticate(
        localizedReason: 'Unlock Flow',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow side-mounted fingerprint sensors
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      debugPrint('[LockService] Biometric auth result: $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint(
          '[LockService] Biometric auth failed: ${e.code} - ${e.message}');
      // Log specific error codes for debugging
      if (e.code == 'NotAvailable') {
        debugPrint('[LockService] Biometric hardware not available');
      } else if (e.code == 'NotEnrolled') {
        debugPrint('[LockService] No biometrics enrolled on device');
      } else if (e.code == 'LockedOut') {
        debugPrint('[LockService] Biometric locked out (too many attempts)');
      } else if (e.code == 'PermanentlyLockedOut') {
        debugPrint('[LockService] Biometric permanently locked out');
      }
      return false;
    } catch (e) {
      debugPrint('[LockService] Unexpected biometric error: $e');
      return false;
    }
  }

  String _encode(String v) => base64Encode(utf8.encode('flow🔒$v⚓'));

  String _makeCode() {
    final n = (DateTime.now().microsecondsSinceEpoch % 900000) + 100000;
    final s = n.toString();
    return '${s.substring(0, 3)}-${s.substring(3)}';
  }
}
