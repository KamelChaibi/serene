import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serene/chat_service.dart';
import 'package:serene/l10n.dart';
import 'package:serene/live_voice_call_screen.dart';
import 'package:serene/live_voice_service.dart';
import 'package:serene/profile.dart';
import 'package:serene/voice_api.dart';

/// A service that never opens a room or a microphone.
class _FakeVoice extends LiveVoiceService {
  _FakeVoice({this.silent = false});

  /// When true, simulates a room that connected but where no agent ever joins.
  final bool silent;

  bool connectCalled = false;
  bool disconnectCalled = false;
  int connectCount = 0;
  bool? mutedValue;

  /// Simulates the room dropping after the call was already connected.
  void drop() => debugFail('network');

  @override
  Future<void> connect(VoiceSession session) async {
    connectCalled = true;
    connectCount++;
    if (silent) return;
    debugHandleData({'v': 1, 'type': 'state', 'state': 'listening'});
    debugHandleData({
      'v': 1,
      'type': 'transcript',
      'role': 'assistant',
      'text': 'Hi Kamel, I am an AI, not a person.',
      'final': true,
    });
  }

  @override
  Future<void> disconnect() async {
    disconnectCalled = true;
  }

  @override
  Future<void> setMuted(bool value) async {
    mutedValue = value;
  }

  @override
  Future<void> interrupt() async {}
}

/// An API that returns a canned session without touching the network.
class _FakeApi extends VoiceApi {
  @override
  Future<bool> captionsEnabled() async => true;

  @override
  Future<void> setCaptionsEnabled(bool value) async {}

  @override
  Future<String> callLanguage(String appLanguageCode) async =>
      VoiceApi.normalizeLanguage(appLanguageCode);

  @override
  Future<VoiceSession> ensureSession({
    required String language,
    Profile profile = Profile.empty,
    List<String> memories = const [],
  }) async {
    return VoiceSession(
      url: 'ws://voice.test',
      token: 'token',
      room: 'room',
      identity: 'user-test',
      language: language,
    );
  }
}

Widget _screen({
  required LiveVoiceService service,
  required VoiceApi api,
  required RequestMicrophone requestMicrophone,
  List<Msg>? conversation,
  Profile profile = Profile.empty,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    home: LiveVoiceCallScreen(
      conversation: conversation ?? <Msg>[],
      profile: profile,
      memories: const [],
      appLanguage: 'en',
      service: service,
      api: api,
      requestMicrophone: requestMicrophone,
    ),
  );
}

void main() {
  group('voice strings', () {
    // Every key the call screen and the settings screen ask for. If one is
    // missing, S.t() falls back to the key itself, which would ship a raw
    // identifier to the user.
    const keys = <String>[
      'voiceCall',
      'voiceConnecting',
      'voiceReady',
      'voiceListening',
      'voiceThinking',
      'voiceSpeaking',
      'voiceReconnecting',
      'voiceLive',
      'voiceAgentMissing',
      'voiceEnded',
      'voiceTapToTalk',
      'voiceInterrupt',
      'voiceMute',
      'voiceUnmute',
      'voiceEnd',
      'voiceError',
      'voiceUnavailable',
      'voicePermissionDenied',
      'voiceOpenSettings',
      'voiceRetry',
      'voiceAuthFailed',
      'voiceRateLimited',
      'voicePrivacyNote',
      'voiceCrisisBody',
      'voiceCrisisContinue',
      'voiceSettings',
      'voiceServerUrl',
      'voiceServerUrlDesc',
      'voiceServerUrlInvalid',
      'voiceEnrollmentCode',
      'voiceEnrollmentCodeDesc',
      'voiceLanguage',
      'voiceLanguageAuto',
      'voiceLanguageTunisian',
      'voiceCaptions',
      'voiceCaptionsDesc',
      'voiceTestConnection',
      'voiceTesting',
      'voiceTestOk',
      'voiceTestDegraded',
      'voiceTestFail',
      'voiceResetDevice',
      'voiceResetDeviceDesc',
      'voiceResetDone',
      'voiceSaved',
      'voiceNotConfigured',
      'voiceSave',
    ];

    for (final code in const ['en', 'fr', 'ar']) {
      test('$code defines every voice string', () {
        final s = S(code);
        for (final key in keys) {
          expect(s.t(key), isNot(key), reason: 'missing "$key" in $code');
        }
      });
    }
  });

  group('VoiceApi helpers', () {
    test('normalizes server addresses', () {
      expect(
        VoiceApi.normalizeServerUrl('192.168.1.10:8788'),
        'http://192.168.1.10:8788',
      );
      expect(
        VoiceApi.normalizeServerUrl(' https://voice.example.com/ '),
        'https://voice.example.com',
      );
      expect(VoiceApi.normalizeServerUrl(''), defaultVoiceApiUrl);
    });

    test('normalizes language codes', () {
      expect(VoiceApi.normalizeLanguage('en-US'), 'en');
      expect(VoiceApi.normalizeLanguage('fr-FR'), 'fr');
      expect(VoiceApi.normalizeLanguage('ar'), 'ar');
      expect(VoiceApi.normalizeLanguage('ar-TN'), 'ar');
      expect(VoiceApi.normalizeLanguage('tn'), 'tn');
      expect(VoiceApi.normalizeLanguage('aeb'), 'tn');
      expect(VoiceApi.normalizeLanguage('de'), 'en');
      expect(VoiceApi.normalizeLanguage(null), 'en');
    });

    test('detects a token that is about to expire', () {
      final soon = VoiceSession(
        url: 'ws://voice.test',
        token: 't',
        room: 'r',
        identity: 'i',
        language: 'en',
        expiresAt: DateTime.now().add(const Duration(seconds: 5)),
      );
      final later = VoiceSession(
        url: 'ws://voice.test',
        token: 't',
        room: 'r',
        identity: 'i',
        language: 'en',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );
      expect(soon.isExpiringSoon, isTrue);
      expect(later.isExpiringSoon, isFalse);
    });
  });

  group('LiveVoiceService protocol', () {
    late LiveVoiceService service;

    setUp(() => service = LiveVoiceService());
    tearDown(() => service.dispose());

    test('applies the agent state', () {
      expect(service.state, LiveVoiceState.connecting);

      service.debugHandleData({'v': 1, 'type': 'state', 'state': 'thinking'});
      expect(service.state, LiveVoiceState.thinking);

      service.debugHandleData({'v': 1, 'type': 'state', 'state': 'speaking'});
      expect(service.state, LiveVoiceState.speaking);

      service.debugHandleData({'v': 1, 'type': 'state', 'state': 'listening'});
      expect(service.state, LiveVoiceState.listening);
    });

    test('shows interim captions but only reports final lines', () {
      final finals = <String>[];
      service.onFinalTranscript = (role, text) => finals.add('$role:$text');

      service.debugHandleData({
        'v': 1,
        'type': 'transcript',
        'role': 'user',
        'text': 'hello',
        'final': false,
      });
      expect(service.lastUser, 'hello');
      expect(finals, isEmpty);

      service.debugHandleData({
        'v': 1,
        'type': 'transcript',
        'role': 'user',
        'text': 'hello there',
        'final': true,
      });
      expect(service.lastUser, 'hello there');
      expect(finals, ['user:hello there']);
    });

    test('keeps the assistant caption separate from the user caption', () {
      service.debugHandleData({
        'v': 1,
        'type': 'transcript',
        'role': 'user',
        'text': 'I am tired',
        'final': true,
      });
      service.debugHandleData({
        'v': 1,
        'type': 'transcript',
        'role': 'assistant',
        'text': 'That sounds heavy.',
        'final': true,
      });
      expect(service.lastUser, 'I am tired');
      expect(service.lastAssistant, 'That sounds heavy.');
    });

    test('fires the crisis callback once', () {
      var calls = 0;
      service.onCrisis = () => calls++;
      service.debugHandleData({'v': 1, 'type': 'crisis'});
      service.debugHandleData({'v': 1, 'type': 'crisis'});
      expect(calls, 1);
      expect(service.crisisActive, isTrue);
    });

    test('ignores unknown protocol versions and blank transcripts', () {
      service.debugHandleData({'v': 99, 'type': 'state', 'state': 'speaking'});
      expect(service.state, LiveVoiceState.connecting);

      service.debugHandleData({
        'v': 1,
        'type': 'transcript',
        'role': 'user',
        'text': '   ',
        'final': true,
      });
      expect(service.lastUser, isEmpty);
    });
  });

  testWidgets('voice call connects, shows the reply, and can be ended',
      (WidgetTester tester) async {
    final voice = _FakeVoice();
    final conversation = <Msg>[];

    await tester.pumpWidget(
      _screen(
        service: voice,
        api: _FakeApi(),
        requestMicrophone: () async => const MicPermissionResult(granted: true),
        conversation: conversation,
        profile: Profile.fromJson({'name': 'Kamel'}),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Serene'), findsOneWidget);
    expect(voice.connectCalled, isTrue);
    expect(find.text('I\'m listening…'), findsOneWidget);
    expect(find.textContaining('Hi Kamel'), findsOneWidget);
    expect(
      conversation.any(
        (message) =>
            message.role == 'assistant' && message.text.contains('Kamel'),
      ),
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pump();

    expect(voice.disconnectCalled, isTrue);

    // Dispose the tree so the repeating animation is cleaned up.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a denied microphone explains what to do',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _screen(
        service: _FakeVoice(),
        api: _FakeApi(),
        requestMicrophone: () async =>
            const MicPermissionResult(granted: false, permanentlyDenied: true),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('microphone access'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a dropped call offers a retry that reconnects',
      (WidgetTester tester) async {
    final voice = _FakeVoice();

    await tester.pumpWidget(
      _screen(
        service: voice,
        api: _FakeApi(),
        requestMicrophone: () async => const MicPermissionResult(granted: true),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(voice.connectCount, 1);
    expect(find.text('Try again'), findsNothing);

    voice.drop();
    await tester.pump();

    expect(find.text('The call dropped. Please try again.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(voice.connectCount, 2);
    expect(find.text('Try again'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('warns when the room connects but no agent answers',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _screen(
        service: _FakeVoice(silent: true),
        api: _FakeApi(),
        requestMicrophone: () async => const MicPermissionResult(granted: true),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('not answering'), findsNothing);

    await tester.pump(const Duration(seconds: 26));
    expect(find.textContaining('not answering'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
