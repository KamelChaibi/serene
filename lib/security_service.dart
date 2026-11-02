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
  bool _isAuthenticating = false;

  /// The last error the platform reported while authenticating. `null` when
  /// the last attempt succeeded or has not run yet.
  String? _lastBiometricError;

  bool get isLocked => _isLocked;
  bool get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  int get remainingLockoutSeconds =>
      isLockedOut ? _lockoutUntil!.difference(DateTime.now()).inSeconds : 0;

  /// True while the system biometric prompt is on screen. The app lifecycle
  /// handler uses this to avoid re-locking the app just because the prompt
  /// briefly paused the activity.
  bool get isAuthenticating => _isAuthenticating;
  String? get lastBiometricError => _lastBiometricError;

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
    try {
      final hash = await Store.getString('pin_hash');
      return hash != null && hash.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricsEnabled() async {
    try {
      return (await Store.getString('biometrics_enabled')) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    try {
      await Store.setString('biometrics_enabled', enabled ? 'true' : 'false');
    } catch (_) {
      // The in-memory preference still applies for this session.
    }
    notifyListeners();
  }

  /// A platform biometric call that never answers (seen on some OEM builds)
  /// must not block the settings screen forever.
  static const _platformTimeout = Duration(seconds: 3);

  /// True when the device has biometric hardware *and* at least one fingerprint
  /// or face is enrolled. The previous implementation also required
  /// `canCheckBiometrics`, which is false on several Android builds even when
  /// biometrics work, so the toggle never appeared.
  Future<bool> canUseBiometrics() async {
    try {
      if (!await _auth.isDeviceSupported().timeout(_platformTimeout)) {
        return false;
      }
      final enrolled =
          await _auth.getAvailableBiometrics().timeout(_platformTimeout);
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// True when the hardware exists but nothing is enrolled yet. Used to show a
  /// helpful "set it up in your phone settings" message instead of hiding the
  /// option.
  Future<bool> hasBiometricHardware() async {
    try {
      return await _auth.isDeviceSupported().timeout(_platformTimeout);
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

    String? salt;
    String? storedHash;
    try {
      salt = await Store.getString('pin_salt');
      storedHash = await Store.getString('pin_hash');
    } catch (_) {
      return false;
    }
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

  /// Runs the system biometric prompt without checking the saved preference.
  /// Used when the user first turns biometric unlock on, so we only enable it
  /// after a successful proof that it actually works on this device.
  Future<bool> verifyBiometrics({String reason = 'Confirm it is you'}) async {
    if (_isAuthenticating || isLockedOut) return false;

    _isAuthenticating = true;
    _lastBiometricError = null;
    try {
      final success = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (success) {
        _failedAttempts = 0;
        _lockoutUntil = null;
      }
      return success;
    } on PlatformException catch (e) {
      _lastBiometricError = e.code;
      return false;
    } catch (_) {
      _lastBiometricError = 'unknown';
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<bool> authenticateBiometrics({
    String reason = 'Unlock Serene',
  }) async {
    if (isLockedOut) return false;
    if (!await isBiometricsEnabled()) return false;
    return verifyBiometrics(reason: reason);
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
