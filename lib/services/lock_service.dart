import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOCK SERVICE
// PIN + biometric app lock. PINs and recovery codes are stored as salted
// SHA-256 hashes — never in a reversible form — so nothing readable ever
// touches disk even if SharedPreferences is extracted from the device.
// ─────────────────────────────────────────────────────────────────────────────

class LockService {
  LockService._();
  static final LockService instance = LockService._();

  static const _kPinHash = 'flow_lock_pin_hash_v2';
  static const _kSalt = 'flow_lock_salt_v2';
  static const _kRecoveryHash = 'flow_lock_recovery_hash_v2';
  static const _kBiometric = 'flow_lock_biometric';

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> hasPin() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kPinHash);
  }

  String _newSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hash(String value, String salt) {
    return sha256.convert(utf8.encode('$salt::$value')).toString();
  }

  /// Stores PIN (salted + hashed) and returns a 6-digit recovery code (e.g. "384-917").
  Future<String> setupPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final salt = _newSalt();
    await p.setString(_kSalt, salt);
    await p.setString(_kPinHash, _hash(pin, salt));
    final code = _makeCode();
    await p.setString(_kRecoveryHash, _hash(code.trim().toUpperCase(), salt));
    return code;
  }

  Future<bool> verifyPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final salt = p.getString(_kSalt);
    if (salt == null) return false;
    return p.getString(_kPinHash) == _hash(pin, salt);
  }

  Future<bool> verifyRecovery(String code) async {
    final p = await SharedPreferences.getInstance();
    final salt = p.getString(_kSalt);
    if (salt == null) return false;
    return p.getString(_kRecoveryHash) ==
        _hash(code.trim().toUpperCase(), salt);
  }

  Future<void> removePin() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kPinHash);
    await p.remove(_kRecoveryHash);
    await p.remove(_kSalt);
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
        localizedReason: 'Unlock PenHaven',
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

  String _makeCode() {
    final rnd = Random.secure();
    final n = 100000 + rnd.nextInt(900000); // 100000–999999, always 6 digits
    final s = n.toString();
    return '${s.substring(0, 3)}-${s.substring(3)}';
  }
}
