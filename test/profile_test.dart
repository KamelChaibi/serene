import 'package:flutter_test/flutter_test.dart';
import 'package:serene/profile.dart';

void main() {
  group('Profile age', () {
    test('returns null when no birthday was shared', () {
      expect(Profile.empty.age, isNull);
    });

    test('counts full years only after the birthday has passed', () {
      final now = DateTime.now();
      final birthdayToday = DateTime(now.year - 20, now.month, now.day);
      expect(Profile(birthday: birthdayToday).age, 20);

      final birthdayTomorrow = DateTime(now.year - 20, now.month, now.day)
          .add(const Duration(days: 1));
      expect(Profile(birthday: birthdayTomorrow).age, 19);
    });

    test('treats under-18 users as minors', () {
      final now = DateTime.now();
      final child = Profile(
        birthday: DateTime(now.year - 12, now.month, now.day),
      );
      final adult = Profile(
        birthday: DateTime(now.year - 30, now.month, now.day),
      );
      expect(child.isMinor, isTrue);
      expect(adult.isMinor, isFalse);
    });
  });

  group('Profile serialization', () {
    test('round-trips through JSON', () {
      final profile = Profile(
        name: 'Sam',
        birthday: DateTime(1996, 4, 12),
        style: Profile.styleDirect,
        length: Profile.lengthShort,
        focuses: const ['anxiety', 'sleep'],
        inTherapy: true,
        notes: 'Keep it short when I panic.',
      );

      final restored = Profile.fromJson(profile.toJson());

      expect(restored.name, 'Sam');
      expect(restored.birthday, DateTime(1996, 4, 12));
      expect(restored.style, Profile.styleDirect);
      expect(restored.length, Profile.lengthShort);
      expect(restored.focuses, ['anxiety', 'sleep']);
      expect(restored.inTherapy, isTrue);
      expect(restored.notes, 'Keep it short when I panic.');
    });

    test('sanitizes unknown values from storage', () {
      final restored = Profile.fromJson({
        'name': '  Lea  ',
        'style': 'unknown',
        'length': 'unknown',
        'focuses': ['sleep', 'not-a-focus'],
        'in_therapy': 'yes',
      });

      expect(restored.name, 'Lea');
      expect(restored.style, Profile.styleWarm);
      expect(restored.length, Profile.lengthBalanced);
      expect(restored.focuses, ['sleep']);
      expect(restored.inTherapy, isFalse);
    });

    test('prompt payload shares age but never the raw birthday', () {
      final profile = Profile(
        name: 'Sam',
        birthday: DateTime(1990, 1, 1),
        style: Profile.styleFriend,
      );

      final payload = profile.toPromptMap();

      expect(payload['age'], isA<int>());
      expect(payload.containsKey('birthday'), isFalse);
      expect(payload['name'], 'Sam');
      expect(payload['style'], Profile.styleFriend);
    });

    test('a blank profile carries no personalization', () {
      expect(Profile.empty.hasPreferences, isFalse);
      expect(const Profile(name: 'Sam').hasPreferences, isTrue);
    });
  });
}
