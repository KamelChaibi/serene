import 'package:flutter/material.dart';
import 'storage.dart';

/// Remembers the user's appearance choice (system, light, or dark) so it can
/// be applied before the first frame and changed live from settings.
class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._();
  ThemeService._();

  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final raw = await Store.getString(_key);
      final next = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
      if (next != null && next != _mode) {
        _mode = next;
        notifyListeners();
      }
    } catch (_) {
      // Fall back to following the system appearance.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode != _mode) {
      _mode = mode;
      notifyListeners();
    }
    try {
      await Store.setString(_key, _name(mode));
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }

  static String _name(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
