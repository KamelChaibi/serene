import 'package:flutter_test/flutter_test.dart';
import 'package:serene/l10n.dart';

/// Pulls `{placeholder}` names out of a translated string so we can check
/// that every language keeps the same interpolation slots.
Set<String> _placeholders(String value) {
  final matches = RegExp(r'\{(\w+)\}').allMatches(value);
  return matches.map((m) => m.group(1)!).toSet();
}

void main() {
  final tables = l10nTables;

  test('the three shipped languages are all present', () {
    expect(tables.keys.toSet(), containsAll(<String>['en', 'fr', 'ar']));
  });

  test('every language defines exactly the same keys as English', () {
    final english = tables['en']!;
    for (final entry in tables.entries) {
      final code = entry.key;
      expect(
        entry.value.keys.toSet(),
        english.keys.toSet(),
        reason: '$code has a different set of keys than en',
      );
    }
  });

  test('no translated string is blank', () {
    for (final entry in tables.entries) {
      for (final string in entry.value.entries) {
        expect(
          string.value.trim(),
          isNotEmpty,
          reason: '"${string.key}" is blank in ${entry.key}',
        );
      }
    }
  });

  test('placeholders match across languages', () {
    final english = tables['en']!;
    for (final entry in tables.entries) {
      if (entry.key == 'en') continue;
      for (final key in english.keys) {
        expect(
          _placeholders(entry.value[key]!),
          _placeholders(english[key]!),
          reason: '"$key" uses different placeholders in ${entry.key}',
        );
      }
    }
  });

  test('S.t falls back to English and then to the key', () {
    expect(S('en').t('send'), tables['en']!['send']);
    expect(S('fr').t('send'), tables['fr']!['send']);
    // Unknown language code falls back to English.
    expect(S('xx').t('send'), tables['en']!['send']);
    // Unknown key falls back to the key itself.
    expect(S('en').t('definitelyNotAKey'), 'definitelyNotAKey');
  });
}
