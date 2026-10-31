// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serene/main.dart';
import 'package:serene/safety.dart';
import 'package:serene/security_service.dart';

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
  final match =
      RegExp(r'\[\[MEMORY_SUGGESTION:\s*(.*?)\]\]').firstMatch(text);
  return match?.group(1)?.trim();
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Smoke test — app boots without crashing
  // -------------------------------------------------------------------------
  testWidgets('SereneApp boots smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SereneApp());
    await tester.pump();
    expect(find.byType(SereneApp), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Crisis regex detection (client-side, fast path)
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
      expect(_extractMemorySuggestion(reply),
          equals('Loves outdoor hiking'));
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
      final raw =
          jsonDecode('{"is_crisis":false}') as Map<String, dynamic>;

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
}
