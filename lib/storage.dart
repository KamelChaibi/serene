import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Everything personal is stored encrypted on-device backed by Android Keystore.
/// Zero-knowledge architecture: No user data or credentials leave the device.
class Store {
  static const _s = FlutterSecureStorage();

  // Memories
  static Future<List<String>> memories() async {
    final v = await _s.read(key: 'mem');
    return v == null ? [] : List<String>.from(jsonDecode(v));
  }

  static Future<void> save(List<String> m) =>
      _s.write(key: 'mem', value: jsonEncode(m));

  static Future<bool> useMem() async => (await _s.read(key: 'useMem')) != 'false';
  static Future<void> setUseMem(bool v) => _s.write(key: 'useMem', value: '$v');

  // Generic structured lists (Moods, Journal, etc.)
  static Future<List<Map<String, dynamic>>> list(String k) async {
    final v = await _s.read(key: k);
    return v == null ? [] : List<Map<String, dynamic>>.from(jsonDecode(v));
  }

  static Future<void> putList(String k, List<Map<String, dynamic>> l) =>
      _s.write(key: k, value: jsonEncode(l));

  // Flags & Booleans
  static Future<bool> flag(String k) async => (await _s.read(key: k)) == 'true';
  static Future<void> setFlag(String k, bool v) => _s.write(key: k, value: '$v');

  // String values (e.g. Country selection)
  static Future<String?> getString(String k) => _s.read(key: k);
  static Future<void> setString(String k, String v) => _s.write(key: k, value: v);

  // Trusted Emergency Contact (for quick crisis dialing)
  static Future<Map<String, String>?> trustedContact() async {
    final name = await _s.read(key: 'trusted_name');
    final phone = await _s.read(key: 'trusted_phone');
    if (name != null && phone != null && phone.isNotEmpty) {
      return {'name': name, 'phone': phone};
    }
    return null;
  }

  static Future<void> setTrustedContact(String name, String phone) async {
    await _s.write(key: 'trusted_name', value: name);
    await _s.write(key: 'trusted_phone', value: phone);
  }

  static Future<void> removeTrustedContact() async {
    await _s.delete(key: 'trusted_name');
    await _s.delete(key: 'trusted_phone');
  }

  // Selected Country for Hotlines
  static Future<String> country() async {
    final c = await _s.read(key: 'user_country');
    return c ?? 'TN'; // Default to Tunisia or user choice
  }

  static Future<void> setCountry(String c) => _s.write(key: 'user_country', value: c);

  // Complete data wipe
  static Future<void> wipe() => _s.deleteAll();
}
