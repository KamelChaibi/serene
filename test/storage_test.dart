import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serene/profile.dart';
import 'package:serene/security_service.dart';
import 'package:serene/storage.dart';

/// Stands in for the Android Keystore plugin so the test can see exactly which
/// keys the app tries to write to the phone.
class _DiskSpy {
  static const _channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  final Map<String, String> written = <String, String>{};

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'write':
          if (key != null) written[key] = args['value'] as String? ?? '';
          return null;
        case 'read':
          return key == null ? null : written[key];
        case 'delete':
          if (key != null) written.remove(key);
          return null;
        case 'deleteAll':
          written.clear();
          return null;
        case 'readAll':
          return Map<String, String>.from(written);
        case 'containsKey':
          return key != null && written.containsKey(key);
        default:
          return null;
      }
    });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _DiskSpy disk;

  setUp(() async {
    disk = _DiskSpy()..install();
    await Store.wipe();
  });

  tearDown(() {
    disk.remove();
  });

  group('persisted key allowlist', () {
    test('contains only non-personal preferences', () {
      expect(
        Store.persistedKeys,
        containsAll(<String>[
          'locale',
          'theme_mode',
          'reminder_enabled',
          'reminder_hour',
          'reminder_minute',
          'consent',
          'onboarding_done',
          'pin_hash',
          'pin_salt',
          'biometrics_enabled',
        ]),
      );
    });

    test('never contains personal content keys', () {
      const personal = <String>[
        'mem',
        'useMem',
        'moods',
        'journal',
        'profile',
        'trusted_name',
        'trusted_phone',
        'user_country',
      ];
      for (final key in personal) {
        expect(Store.persistsToDisk(key), isFalse,
            reason: '$key must stay in RAM');
        expect(Store.persistedKeys, isNot(contains(key)));
      }
    });

    test('allows exactly the allowlisted keys', () {
      for (final key in Store.persistedKeys) {
        expect(Store.persistsToDisk(key), isTrue);
      }
    });
  });

  group('personal data stays in memory', () {
    test('memories round-trip without touching the plugin', () async {
      await Store.save(['I love painting', 'My sister is called Lina']);

      expect(await Store.memories(), [
        'I love painting',
        'My sister is called Lina',
      ]);
      expect(disk.written.keys, isEmpty);
    });

    test('profile, moods, journal and trusted contact round-trip in RAM',
        () async {
      await Store.setProfile(const Profile(
        name: 'Kamel',
        style: Profile.styleFriend,
        focuses: ['sleep', 'anxiety'],
        notes: 'gentle in the evening',
      ));
      await Store.putList('moods', [
        {
          'mood': 3,
          'note': 'tired',
          'tags': ['#sleep']
        },
      ]);
      await Store.putList('journal', [
        {'text': 'A quiet day.', 'ts': 1700000000000},
      ]);
      await Store.setTrustedContact('Lina', '+21600000000');

      final profile = await Store.profile();
      expect(profile.name, 'Kamel');
      expect(profile.style, Profile.styleFriend);
      expect(profile.focuses, ['sleep', 'anxiety']);
      expect(profile.notes, 'gentle in the evening');

      expect(await Store.list('moods'), hasLength(1));
      expect(await Store.list('journal'), hasLength(1));

      final contact = await Store.trustedContact();
      expect(contact, {'name': 'Lina', 'phone': '+21600000000'});

      expect(disk.written.keys, isEmpty);
    });

    test('hotline country stays in RAM but follows the app language', () async {
      Store.setLocaleHint('fr');
      expect(await Store.country(), 'FR');

      await Store.setCountry('BE');
      expect(await Store.country(), 'BE');
      expect(disk.written.keys, isEmpty);

      Store.setLocaleHint('ar');
      expect(await Store.country(), 'BE',
          reason: 'an explicit choice wins over the language hint');
    });
  });

  group('non-personal config does persist', () {
    test('locale and theme reach secure storage', () async {
      await Store.setString('locale', 'ar');
      await Store.setString('theme_mode', 'dark');

      expect(disk.written['locale'], 'ar');
      expect(disk.written['theme_mode'], 'dark');
      expect(await Store.getString('locale'), 'ar');
    });

    test('first-run flags persist so onboarding is not repeated', () async {
      await Store.setFlag('consent', true);
      await Store.completeOnboarding();

      expect(disk.written['consent'], 'true');
      expect(disk.written['onboarding_done'], 'true');
      expect(await Store.onboardingDone(), isTrue);
    });
  });

  group('app lock survives a restart', () {
    test('setupPin stores only a salted hash, never the PIN', () async {
      await SecurityService.instance.setupPin('1234');

      expect(disk.written['pin_hash'], isNotNull);
      expect(disk.written['pin_salt'], isNotNull);
      expect(disk.written['pin_hash'], isNot('1234'));
      expect(disk.written['pin_hash'], hasLength(64));
      expect(disk.written.values, isNot(contains('1234')));

      expect(await SecurityService.instance.isLockEnabled(), isTrue);
    });

    test('the saved hash still verifies after the process restarts', () async {
      await SecurityService.instance.setupPin('2468');

      // A restart drops RAM but keeps secure storage. Reading straight from
      // the disk mock is exactly what the next launch does.
      final salt = disk.written['pin_salt']!;
      final hash = disk.written['pin_hash']!;
      expect(hash, SecurityService.hashPin('2468', salt));

      expect(await SecurityService.instance.verifyPin('2468'), isTrue);
      expect(await SecurityService.instance.verifyPin('0000'), isFalse);
      expect(await SecurityService.instance.verifyPin('2468'), isTrue);
    });

    test('removePin clears the lock and biometrics', () async {
      await SecurityService.instance.setupPin('1111');
      await SecurityService.instance.setBiometricsEnabled(true);
      expect(await SecurityService.instance.isBiometricsEnabled(), isTrue);

      await SecurityService.instance.removePin();

      expect(await SecurityService.instance.isLockEnabled(), isFalse);
      expect(await SecurityService.instance.isBiometricsEnabled(), isFalse);
      expect(disk.written['pin_hash'], '');
    });
  });

  group('wipe', () {
    test('clears personal data and persisted preferences', () async {
      await Store.save(['a memory']);
      await Store.setProfile(const Profile(name: 'Kamel'));
      await Store.setTrustedContact('Lina', '+21600000000');
      await Store.setCountry('FR');
      await Store.setString('locale', 'fr');
      await Store.setFlag('consent', true);

      await Store.wipe();

      expect(await Store.memories(), isEmpty);
      expect((await Store.profile()).name, isEmpty);
      expect(await Store.trustedContact(), isNull);
      expect(await Store.getString('locale'), isNull);
      expect(await Store.flag('consent'), isFalse);
      expect(disk.written, isEmpty);
    });

    test('keeps the voice enrolment, which has its own reset control',
        () async {
      disk.written.addAll(<String, String>{
        'voice_device_id': 'device-1',
        'voice_device_secret': 'secret',
        'voice_server_url': 'http://192.168.1.10:8788',
        'locale': 'fr',
      });

      await Store.wipe();

      expect(
          disk.written.keys,
          unorderedEquals(
              ['voice_device_id', 'voice_device_secret', 'voice_server_url']));
    });
  });

  group('legacy data from older builds', () {
    test('is deleted at start-up, preferences are kept', () async {
      // Simulate a phone upgrading from a version that wrote personal data to
      // secure storage.
      disk.written.addAll(<String, String>{
        'mem': '["old memory"]',
        'profile': '{"name":"Kamel"}',
        'trusted_phone': '+21600000000',
        'mood': '[]',
        'journal': '[]',
        'pin_hash': 'deadbeef',
        'pin_salt': 'salt',
        'biometrics_enabled': 'true',
        'locale': 'fr',
        'theme_mode': 'dark',
        'consent': 'true',
      });

      await Store.purgeLegacyPersonalData();

      // Personal content is gone, but preferences and the lock settings are
      // lock/app config, so they must survive the upgrade.
      expect(
          disk.written.keys,
          unorderedEquals([
            'locale',
            'theme_mode',
            'consent',
            'pin_hash',
            'pin_salt',
            'biometrics_enabled',
          ]));
      for (final key in Store.legacyPersonalKeys) {
        expect(disk.written, isNot(contains(key)),
            reason: '$key must be purged');
      }
    });

    test('keeps the PIN so an upgrade does not unlock the app', () async {
      disk.written.addAll(<String, String>{
        'pin_hash': 'deadbeef',
        'pin_salt': 'salt',
        'biometrics_enabled': 'true',
      });

      await Store.purgeLegacyPersonalData();

      expect(disk.written['pin_hash'], 'deadbeef');
      expect(disk.written['pin_salt'], 'salt');
      expect(disk.written['biometrics_enabled'], 'true');
    });

    test('purge tolerates an empty store', () async {
      await Store.purgeLegacyPersonalData();
      expect(disk.written, isEmpty);
    });
  });
}
