import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'storage.dart';

class SecurityService extends ChangeNotifier {
  static final SecurityService instance = SecurityService._();
  SecurityService._();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _isLocked = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  bool get isLocked => _isLocked;
  bool get isLockedOut => _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  int get remainingLockoutSeconds => isLockedOut
      ? _lockoutUntil!.difference(DateTime.now()).inSeconds
      : 0;

  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin:$salt');
    return sha256.convert(bytes).toString();
  }

  static String generateSalt() {
    final rand = Random.secure();
    final values = List<int>.generate(16, (i) => rand.nextInt(256));
    return base64Url.encode(values);
  }

  Future<bool> isLockEnabled() async {
    final hash = await Store.getString('pin_hash');
    return hash != null && hash.isNotEmpty;
  }

  Future<bool> isBiometricsEnabled() async {
    return (await Store.getString('biometrics_enabled')) == 'true';
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await Store.setString('biometrics_enabled', enabled ? 'true' : 'false');
    notifyListeners();
  }

  Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<void> setupPin(String pin) async {
    final salt = generateSalt();
    final hash = hashPin(pin, salt);
    await Store.setString('pin_salt', salt);
    await Store.setString('pin_hash', hash);
    _failedAttempts = 0;
    _lockoutUntil = null;
    notifyListeners();
  }

  Future<void> removePin() async {
    await Store.setString('pin_hash', '');
    await Store.setString('pin_salt', '');
    await Store.setString('biometrics_enabled', 'false');
    _isLocked = false;
    _failedAttempts = 0;
    _lockoutUntil = null;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    if (isLockedOut) return false;

    final salt = await Store.getString('pin_salt');
    final storedHash = await Store.getString('pin_hash');
    if (salt == null || storedHash == null || storedHash.isEmpty) return true;

    final computedHash = hashPin(pin, salt);
    if (computedHash == storedHash) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      _isLocked = false;
      notifyListeners();
      return true;
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> authenticateBiometrics({String reason = 'Unlock Serene'}) async {
    if (isLockedOut) return false;
    try {
      final allowed = await isBiometricsEnabled();
      if (!allowed) return false;

      final success = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (success) {
        _failedAttempts = 0;
        _lockoutUntil = null;
        _isLocked = false;
        notifyListeners();
        return true;
      }
    } on PlatformException catch (_) {}
    return false;
  }

  Future<void> checkInitialLock() async {
    final enabled = await isLockEnabled();
    if (enabled) {
      _isLocked = true;
      notifyListeners();
    }
  }

  void lock() {
    _isLocked = true;
    notifyListeners();
  }

  void unlock() {
    _isLocked = false;
    _failedAttempts = 0;
    _lockoutUntil = null;
    notifyListeners();
  }
}

