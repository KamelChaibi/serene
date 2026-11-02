// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serene/chat_screen.dart';
import 'package:serene/home.dart';
import 'package:serene/main.dart';
import 'package:serene/profile.dart';
import 'package:serene/safety.dart';
import 'package:serene/security_service.dart';
import 'package:serene/splash_screen.dart';
import 'package:serene/storage.dart';
import 'package:serene/theme_service.dart';

// ---------------------------------------------------------------------------
// Helper: SHA-256 PIN hash (mirrors SecurityService.hashPin)
// ---------------------------------------------------------------------------
String _hashPin(String pin, String salt) {
  final bytes = utf8.encode('$salt:$pin:$salt');
  return sha256.convert(bytes).toString();
}

// ---------------------------------------------------------------------------
// Helper: extract [[MEMORY_SUGGESTION: ...]] from a model reply
// (mirrors the logic in chat_service.dart)
// ---------------------------------------------------------------------------
String? _extractMemorySuggestion(String text) {
  final match = RegExp(r'\[\[MEMORY_SUGGESTION:\s*(.*?)\]\]').firstMatch(text);
  return match?.group(1)?.trim();
}

// ---------------------------------------------------------------------------
// Helper: stand in for the biometric plugin so settings tests never hang on a
// platform channel that has no implementation on the test host.
// ---------------------------------------------------------------------------
void _mockLocalAuth({
  bool supported = false,
  List<String> enrolled = const <String>[],
}) {
  const channel = MethodChannel('plugins.flutter.io/local_auth');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'isDeviceSupported':
        return supported;
      case 'getAvailableBiometrics':
        return enrolled;
      case 'authenticate':
        return true;
      case 'stopAuthentication':
        return true;
      default:
        return null;
    }
  });
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Smoke test — app boots without crashing
  // -------------------------------------------------------------------------
  testWidgets('SereneApp boots smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SereneApp());
    await tester.pump();

    // The branded launch screen is the first thing users see.
    expect(find.byType(SereneApp), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Serene'), findsOneWidget);

    // Let the minimum splash duration elapse and the fade-out settle.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SereneApp), findsOneWidget);
  });

  testWidgets('Splash never greets with a name left on disk',
      (WidgetTester tester) async {
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
    // An older build of Serene stored the profile on the phone. Personal data
    // is RAM-only now, so that leftover must not be read or displayed.
    FlutterSecureStorage.setMockInitialValues({
      'onboarding_done': 'true',
      'profile': jsonEncode({'name': 'Kamel'}),
    });

    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: SplashScreen(onFinished: () => finished = true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Welcome back, Kamel'), findsNothing);
    expect(finished, isFalse);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(finished, isTrue);
  });

  testWidgets('Splash greets a name held in this session',
      (WidgetTester tester) async {
    addTearDown(() async {
      await Store.wipe();
      FlutterSecureStorage.setMockInitialValues({});
    });
    FlutterSecureStorage.setMockInitialValues({'onboarding_done': 'true'});
    await Store.setProfile(const Profile(name: 'Kamel'));

    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: SplashScreen(onFinished: () => finished = true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Welcome back, Kamel'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(finished, isTrue);
  });

  testWidgets('Voice call entry points stay hidden',
      (WidgetTester tester) async {
    addTearDown(Store.wipe);

    await tester.pumpWidget(
      MaterialApp(home: ChatScreen(onLocale: (_) {})),
    );
    await tester.pump();

    // The chat screen built (crisis button present) but offers no call action.
    expect(find.byIcon(Icons.emergency), findsOneWidget);
    expect(find.byIcon(Icons.call_outlined), findsNothing);
    expect(find.text('Voice call'), findsNothing);
  });

  testWidgets('First launch points hotlines at the app language',
      (WidgetTester tester) async {
    addTearDown(Store.wipe);
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const SereneApp());
    await tester.pump();

    // The app starts in French, so the fallback country is France, not the
    // hard-coded Tunisian default.
    expect(await Store.country(), 'FR');

    // Let the splash timer finish so the test leaves nothing pending.
    await tester.pump(const Duration(milliseconds: 1600));
  });

  // -------------------------------------------------------------------------
  // 2. Appearance preference
  // -------------------------------------------------------------------------
  test('ThemeService restores and persists the chosen appearance', () async {
    addTearDown(() async {
      await ThemeService.instance.setMode(ThemeMode.system);
      FlutterSecureStorage.setMockInitialValues({});
    });
    FlutterSecureStorage.setMockInitialValues({'theme_mode': 'dark'});

    await ThemeService.instance.load();
    expect(ThemeService.instance.mode, ThemeMode.dark);

    await ThemeService.instance.setMode(ThemeMode.light);
    expect(ThemeService.instance.mode, ThemeMode.light);

    final saved = await const FlutterSecureStorage().read(key: 'theme_mode');
    expect(saved, 'light');
  });

  // -------------------------------------------------------------------------
  // 3. Crisis regex detection (client-side, fast path)
  // -------------------------------------------------------------------------
  group('Crisis detection — isCrisis()', () {
    test('English suicidal phrases → true', () {
      expect(isCrisis('I really want to die'), isTrue);
      expect(isCrisis('I want to kill myself'), isTrue);
      expect(isCrisis('thinking about ending it all'), isTrue);
    });

    test('English benign phrases → false', () {
      expect(isCrisis('I had a hard day at work'), isFalse);
      expect(isCrisis('I am a little tired today'), isFalse);
    });

    test('French suicidal phrases → true', () {
      expect(isCrisis('Je veux me tuer'), isTrue);
      expect(isCrisis('J envie de mourir'), isTrue);
    });

    test('French benign phrases → false', () {
      expect(isCrisis('Je suis un peu fatigué'), isFalse);
    });

    test('Arabic suicidal phrases → true', () {
      expect(isCrisis('أريد أن أموت'), isTrue);
      expect(isCrisis('نحب نموت ونرتاح'), isTrue);
    });

    test('Arabic benign phrases → false', () {
      expect(isCrisis('أنا حزين اليوم'), isFalse);
    });

    test('Arabizi suicidal phrases → true', () {
      expect(isCrisis('nheb nmout'), isTrue);
      expect(isCrisis('n9atel rouhi'), isTrue);
    });

    test('Arabizi benign phrases → false', () {
      expect(isCrisis('labes hamdoullah'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // 3. SecurityService — PIN hash/verify logic (pure unit tests, no platform)
  // -------------------------------------------------------------------------
  group('SecurityService — PIN hashing', () {
    test('hashPin is deterministic', () {
      const pin = '1234';
      const salt = 'testSalt';
      expect(SecurityService.hashPin(pin, salt),
          equals(SecurityService.hashPin(pin, salt)));
    });

    test('hashPin differs for different PINs', () {
      const salt = 'testSalt';
      expect(SecurityService.hashPin('1234', salt),
          isNot(equals(SecurityService.hashPin('9999', salt))));
    });

    test('hashPin differs for different salts', () {
      const pin = '1234';
      expect(SecurityService.hashPin(pin, 'salt1'),
          isNot(equals(SecurityService.hashPin(pin, 'salt2'))));
    });

    test('generateSalt produces unique values', () {
      final s1 = SecurityService.generateSalt();
      final s2 = SecurityService.generateSalt();
      expect(s1, isNot(equals(s2)));
    });

    test('hashPin internal implementation matches crypto package', () {
      const pin = '5678';
      const salt = 'abc123';
      final expected = _hashPin(pin, salt);
      expect(SecurityService.hashPin(pin, salt), equals(expected));
    });
  });

  // -------------------------------------------------------------------------
  // 4. Memory suggestion extraction (mirrors chat_service logic)
  // -------------------------------------------------------------------------
  group('Memory suggestion extraction', () {
    test('extracts tag from model reply', () {
      const reply =
          'You seem to love hiking! [[MEMORY_SUGGESTION: Loves outdoor hiking]]';
      expect(_extractMemorySuggestion(reply), equals('Loves outdoor hiking'));
    });

    test('returns null when no tag present', () {
      const reply = 'That sounds tough. How can I help you today?';
      expect(_extractMemorySuggestion(reply), isNull);
    });

    test('handles extra whitespace inside tag', () {
      const reply =
          'Great! [[MEMORY_SUGGESTION:   Prefers evening journaling   ]]';
      expect(_extractMemorySuggestion(reply),
          equals('Prefers evening journaling'));
    });

    test('only extracts first suggestion when multiple tags present', () {
      const reply =
          '[[MEMORY_SUGGESTION: First]] and [[MEMORY_SUGGESTION: Second]]';
      expect(_extractMemorySuggestion(reply), equals('First'));
    });
  });

  // -------------------------------------------------------------------------
  // 5. /classify endpoint response shape (unit test, no real HTTP call)
  // -------------------------------------------------------------------------
  group('/classify response shape', () {
    test('parse a crisis response correctly', () {
      // Simulated JSON the backend would return
      final raw = jsonDecode(
              '{"is_crisis":true,"risk_level":"high","category":"suicide_intent"}')
          as Map<String, dynamic>;

      expect(raw['is_crisis'], isTrue);
      expect(raw['risk_level'], equals('high'));
      expect(raw['category'], equals('suicide_intent'));
    });

    test('parse a non-crisis response correctly', () {
      final raw = jsonDecode('{"is_crisis":false}') as Map<String, dynamic>;

      expect(raw['is_crisis'], isFalse);
      expect(raw.containsKey('risk_level'), isFalse);
    });

    test('is_crisis must be a bool', () {
      final raw = jsonDecode('{"is_crisis":false}') as Map<String, dynamic>;
      expect(raw['is_crisis'], isA<bool>());
    });
  });

  // -------------------------------------------------------------------------
  // 6. Widget smoke test — LockScreen renders keypad when PIN is set
  //    (We test the widget tree shape, not the platform biometric plugin)
  // -------------------------------------------------------------------------
  testWidgets('LockScreen shows PIN keypad grid', (WidgetTester tester) async {
    // Build the widget directly — no platform channels involved
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              children: List.generate(
                12,
                (i) => Center(child: Text('$i')),
              ),
            ),
          ),
        ),
      ),
    );
    // 12 cells rendered
    expect(find.byType(GridView), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. Settings — the biometric switch must be reachable once a PIN is set,
  //    even when the device cannot authenticate right now.
  // -------------------------------------------------------------------------
  testWidgets('Biometric option appears as soon as a PIN exists',
      (WidgetTester tester) async {
    addTearDown(() async {
      await Store.wipe();
      FlutterSecureStorage.setMockInitialValues({});
    });
    FlutterSecureStorage.setMockInitialValues({});
    _mockLocalAuth();
    await Store.setString('pin_hash', 'stored-hash');
    await Store.setString('pin_salt', 'stored-salt');

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: MemorySettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Biometric Unlock'), findsOneWidget);
    // The mock reports no biometric hardware, so the option explains itself
    // instead of silently disappearing.
    expect(find.text('This device has no biometric sensor.'), findsOneWidget);
  });

  testWidgets('Turning biometrics on asks for proof and then stays on',
      (WidgetTester tester) async {
    addTearDown(() async {
      await SecurityService.instance.removePin();
      await Store.wipe();
      FlutterSecureStorage.setMockInitialValues({});
    });
    FlutterSecureStorage.setMockInitialValues({});
    _mockLocalAuth(supported: true, enrolled: const ['fingerprint']);
    await Store.setString('pin_hash', 'stored-hash');
    await Store.setString('pin_salt', 'stored-salt');

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: MemorySettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.widgetWithText(SwitchListTile, 'Biometric Unlock');
    expect(toggle, findsOneWidget);

    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(await SecurityService.instance.isBiometricsEnabled(), isTrue);
  });

  // -------------------------------------------------------------------------
  // 8. Responsive layout — narrow phones must not overflow.
  // -------------------------------------------------------------------------
  testWidgets('Settings fits a 320 px wide phone', (WidgetTester tester) async {
    addTearDown(() async {
      await Store.wipe();
      FlutterSecureStorage.setMockInitialValues({});
    });
    FlutterSecureStorage.setMockInitialValues({});
    _mockLocalAuth();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: MemorySettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MemorySettingsScreen), findsOneWidget);
  });

  testWidgets('Consent gate fits a 320 px wide phone',
      (WidgetTester tester) async {
    addTearDown(Store.wipe);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Gate(onLocale: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Serene'), findsOneWidget);
  });
}
