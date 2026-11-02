import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'profile.dart';

/// What Serene keeps on the phone, and what it deliberately does not.
///
/// Personal content — memories, moods, journal entries, the profile and the
/// trusted contact — lives in a plain in-memory map for the lifetime of the
/// process. It is never encoded, never written to secure storage, and it
/// disappears the moment Android closes the app. There is no "delete my data"
/// step to forget: there is nothing to delete.
///
/// A small, explicit allowlist of preferences does persist, so the app does not
/// reset itself every launch: the language, the appearance, the reminder
/// schedule, the two first-run flags, and the *lock settings*. The lock stores
/// only a salted hash of the PIN — never the PIN itself — plus whether
/// biometric unlock is on, so the lock still protects the app after a restart.
///
/// Anything not on the allowlist is treated as personal and stays in RAM. That
/// default matters: a new key added later cannot silently start leaking to
/// disk.
class Store {
  static const _s = FlutterSecureStorage();

  /// The only keys that may ever be written to the phone.
  @visibleForTesting
  static const persistedKeys = <String>{
    'locale',
    'theme_mode',
    'reminder_enabled',
    'reminder_hour',
    'reminder_minute',
    'reminder_title',
    'reminder_body',
    'consent',
    'onboarding_done',
    // Lock settings. `pin_hash` is a salted SHA-256 digest; the raw PIN is
    // never written anywhere.
    'pin_hash',
    'pin_salt',
    'biometrics_enabled',
  };

  /// Session-only values. Cleared when the process ends.
  static final Map<String, String> _ram = <String, String>{};

  /// Country used for hotlines until the user picks one this session. Set from
  /// the app language at start-up so a French speaker does not get Tunisian
  /// numbers after a restart.
  static String _localeCountry = 'TN';

  static const _localeCountries = <String, String>{
    'fr': 'FR',
    'ar': 'TN',
    'en': 'US',
  };

  @visibleForTesting
  static bool persistsToDisk(String key) => persistedKeys.contains(key);

  static Future<String?> _read(String key) async {
    if (persistedKeys.contains(key)) {
      try {
        final value = await _s.read(key: key);
        if (value != null) return value;
      } catch (_) {
        // Fall through to the in-memory copy below.
      }
    }
    return _ram[key];
  }

  static Future<void> _write(String key, String value) async {
    if (persistedKeys.contains(key)) {
      try {
        await _s.write(key: key, value: value);
        _ram.remove(key);
        return;
      } catch (_) {
        // Secure storage can be unavailable on some devices. Keeping the value
        // in RAM is better than losing the setting for this session.
      }
    }
    _ram[key] = value;
  }

  static Future<void> _delete(String key) async {
    if (persistedKeys.contains(key)) {
      try {
        await _s.delete(key: key);
      } catch (_) {
        // Nothing to remove, or secure storage is unavailable.
      }
    }
    _ram.remove(key);
  }

  // Memories
  static Future<List<String>> memories() async {
    final v = await _read('mem');
    return v == null ? [] : List<String>.from(jsonDecode(v));
  }

  static Future<void> save(List<String> m) => _write('mem', jsonEncode(m));

  static Future<bool> useMem() async => (await _read('useMem')) != 'false';
  static Future<void> setUseMem(bool v) => _write('useMem', '$v');

  // Generic structured lists (Moods, Journal, etc.)
  static Future<List<Map<String, dynamic>>> list(String k) async {
    final v = await _read(k);
    return v == null ? [] : List<Map<String, dynamic>>.from(jsonDecode(v));
  }

  static Future<void> putList(String k, List<Map<String, dynamic>> l) =>
      _write(k, jsonEncode(l));

  // Flags & Booleans
  static Future<bool> flag(String k) async => (await _read(k)) == 'true';
  static Future<void> setFlag(String k, bool v) => _write(k, '$v');

  // String values (e.g. Country selection)
  static Future<String?> getString(String k) => _read(k);
  static Future<void> setString(String k, String v) => _write(k, v);

  // Trusted Emergency Contact (for quick crisis dialing)
  static Future<Map<String, String>?> trustedContact() async {
    final name = await _read('trusted_name');
    final phone = await _read('trusted_phone');
    if (name != null && phone != null && phone.isNotEmpty) {
      return {'name': name, 'phone': phone};
    }
    return null;
  }

  static Future<void> setTrustedContact(String name, String phone) async {
    await _write('trusted_name', name);
    await _write('trusted_phone', phone);
  }

  static Future<void> removeTrustedContact() async {
    await _delete('trusted_name');
    await _delete('trusted_phone');
  }

  // Personalization profile (name, age, tone preferences…)
  static Future<Profile> profile() async {
    final v = await _read('profile');
    if (v == null || v.isEmpty) return Profile.empty;
    try {
      return Profile.fromJson(Map<String, dynamic>.from(jsonDecode(v)));
    } catch (_) {
      return Profile.empty;
    }
  }

  static Future<void> setProfile(Profile p) =>
      _write('profile', jsonEncode(p.toJson()));

  /// Set once the first-launch onboarding has been completed or skipped.
  static Future<bool> onboardingDone() => flag('onboarding_done');
  static Future<void> completeOnboarding() => setFlag('onboarding_done', true);

  // Selected Country for Hotlines
  static Future<String> country() async {
    final chosen = await _read('user_country');
    return chosen ?? _localeCountry;
  }

  static Future<void> setCountry(String c) => _write('user_country', c);

  /// Called when the app language changes. Only used as a fallback for the
  /// hotline country, and only until the user picks one in settings.
  static void setLocaleHint(String languageCode) {
    _localeCountry = _localeCountries[languageCode] ?? _localeCountry;
  }

  /// Keys that older versions of Serene wrote to secure storage before personal
  /// data became RAM-only. They are deleted once at start-up so an upgrade does
  /// not leave stale memories, moods or contacts on the phone forever.
  ///
  /// The PIN keys are deliberately *not* in this list any more: they are a
  /// lock setting now, so deleting them on every launch would silently turn
  /// the app lock off after an upgrade.
  @visibleForTesting
  static const legacyPersonalKeys = <String>[
    'mem',
    'useMem',
    'profile',
    'trusted_name',
    'trusted_phone',
    'user_country',
    'mood',
    'journal',
  ];

  /// Best-effort removal of personal data written by a previous version.
  static Future<void> purgeLegacyPersonalData() async {
    for (final key in legacyPersonalKeys) {
      try {
        await _s.delete(key: key);
      } catch (_) {
        // Nothing to remove, or secure storage is unavailable.
      }
    }
  }

  /// Forgets everything personal for this session and resets the persisted
  /// preferences. Used by "clear this session's data" in settings.
  ///
  /// Deliberately deletes only the allowlisted keys: the voice enrolment has
  /// its own "Forget this device" control and should not vanish as a side
  /// effect of clearing session data.
  static Future<void> wipe() async {
    _ram.clear();
    for (final key in persistedKeys) {
      try {
        await _s.delete(key: key);
      } catch (_) {
        // Secure storage may be unavailable (older Android, tests). The
        // in-memory data is already gone, which is the part that matters.
      }
    }
  }
}
