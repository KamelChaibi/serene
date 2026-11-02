import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'profile.dart';

/// The voice backend address compiled into the app. Override at build time:
///
/// ```
/// flutter run --dart-define=VOICE_API_URL=http://192.168.1.10:8788
/// ```
///
/// The user can also change it at runtime in the voice settings screen; the
/// stored value wins.
const defaultVoiceApiUrl = String.fromEnvironment(
  'VOICE_API_URL',
  defaultValue: 'http://10.0.2.2:8788',
);

/// What went wrong when talking to the voice backend.
enum VoiceErrorKind {
  /// The phone could not reach the server at all.
  network,

  /// The server rejected this install (revoked, or a bad enrolment code).
  unauthorized,

  /// Too many calls or enrolments in a short window.
  rateLimited,

  /// The server answered with an error.
  server,

  /// The app or server configuration is incomplete.
  config,
}

class VoiceException implements Exception {
  final VoiceErrorKind kind;
  final String message;
  final int? status;

  const VoiceException(this.kind, this.message, {this.status});

  @override
  String toString() => 'VoiceException($kind, $status): $message';
}

/// A short-lived LiveKit room grant. Never persisted.
class VoiceSession {
  final String url;
  final String token;
  final String room;
  final String identity;
  final String language;
  final DateTime? expiresAt;

  const VoiceSession({
    required this.url,
    required this.token,
    required this.room,
    required this.identity,
    required this.language,
    this.expiresAt,
  });

  /// True when the token is close enough to expiry that a reconnect would be
  /// rejected. The screen uses this to end the call cleanly instead of
  /// freezing mid-sentence.
  bool get isExpiringSoon {
    final at = expiresAt;
    if (at == null) return false;
    return DateTime.now().isAfter(at.subtract(const Duration(seconds: 30)));
  }
}

/// Result of a settings-screen connectivity check.
class VoiceHealth {
  final bool reachable;
  final bool ready;
  final bool livekit;
  final bool ollama;
  final String? model;

  const VoiceHealth({
    required this.reachable,
    required this.ready,
    this.livekit = false,
    this.ollama = false,
    this.model,
  });
}

/// Talks to the public Serene voice API: device enrolment and room tokens.
///
/// The LiveKit API secret never exists on the phone. This class only ever
/// holds a random per-install device id, its secret, and a 10-minute token.
class VoiceApi {
  static const _storage = FlutterSecureStorage();

  static const _kServerUrl = 'voice_server_url';
  static const _kDeviceId = 'voice_device_id';
  static const _kDeviceSecret = 'voice_device_secret';
  static const _kEnrolled = 'voice_enrolled';
  static const _kEnrollmentCode = 'voice_enrollment_code';
  static const _kCaptions = 'voice_captions';
  static const _kLanguage = 'voice_language';

  static const supportedLanguages = <String>['en', 'fr', 'ar', 'tn'];

  final http.Client _client;

  VoiceApi({http.Client? client}) : _client = client ?? http.Client();

  // --- configuration -------------------------------------------------------

  /// The stored server address, or the one compiled into the app.
  Future<String> serverUrl() async {
    final stored = await _storage.read(key: _kServerUrl);
    final raw = (stored == null || stored.trim().isEmpty)
        ? defaultVoiceApiUrl
        : stored.trim();
    return normalizeServerUrl(raw);
  }

  /// Accepts `192.168.1.10:8788`, `http://host:8788/`, or `https://host`.
  static String normalizeServerUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return defaultVoiceApiUrl;
    if (!value.contains('://')) value = 'http://$value';
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// Persists a new address. A different server means a different enrolment,
  /// so the old device identity is discarded.
  Future<void> setServerUrl(String raw) async {
    final next = normalizeServerUrl(raw);
    final current = await serverUrl();
    await _storage.write(key: _kServerUrl, value: next);
    if (next != current) await forgetDevice();
  }

  Future<String> enrollmentCode() async =>
      (await _storage.read(key: _kEnrollmentCode)) ?? '';

  Future<void> setEnrollmentCode(String code) =>
      _storage.write(key: _kEnrollmentCode, value: code.trim());

  Future<bool> captionsEnabled() async =>
      (await _storage.read(key: _kCaptions)) != 'false';

  Future<void> setCaptionsEnabled(bool value) =>
      _storage.write(key: _kCaptions, value: '$value');

  /// `auto`, or one of [supportedLanguages].
  Future<String> languagePreference() async =>
      (await _storage.read(key: _kLanguage)) ?? 'auto';

  Future<void> setLanguagePreference(String value) => _storage.write(
        key: _kLanguage,
        value: value == 'auto' ? 'auto' : normalizeLanguage(value),
      );

  /// Resolves the language a call should use from the app's current locale.
  Future<String> callLanguage(String appLanguageCode) async {
    final preference = await languagePreference();
    if (preference != 'auto') return normalizeLanguage(preference);
    return normalizeLanguage(appLanguageCode);
  }

  static String normalizeLanguage(String? raw) {
    final value = (raw ?? '').trim().toLowerCase().split('-').first;
    if (value == 'tn' || value == 'aeb') return 'tn';
    if (value == 'ar') return 'ar';
    if (value == 'fr') return 'fr';
    return 'en';
  }

  // --- device identity -----------------------------------------------------

  Future<bool> isEnrolled() async =>
      (await _storage.read(key: _kEnrolled)) == 'true';

  /// Removes this install's identity. The next call enrols again.
  Future<void> forgetDevice() async {
    await _storage.delete(key: _kDeviceId);
    await _storage.delete(key: _kDeviceSecret);
    await _storage.delete(key: _kEnrolled);
  }

  Future<_Credentials> _credentials() async {
    var id = await _storage.read(key: _kDeviceId);
    var secret = await _storage.read(key: _kDeviceSecret);
    if (id == null || id.length < 16 || secret == null || secret.length < 32) {
      id = _randomToken(12); // 16 url-safe characters
      secret = _randomToken(32); // 43 url-safe characters
      await _storage.write(key: _kDeviceId, value: id);
      await _storage.write(key: _kDeviceSecret, value: secret);
      await _storage.write(key: _kEnrolled, value: 'false');
    }
    return _Credentials(id, secret);
  }

  /// Makes sure this install can ask for a token, enrolling when needed.
  Future<void> ensureEnrolled() async {
    final credentials = await _credentials();
    if (await isEnrolled()) return;
    await _enroll(credentials);
  }

  /// Enrols if necessary, then returns a fresh short-lived room token.
  Future<VoiceSession> ensureSession({
    required String language,
    Profile profile = Profile.empty,
    List<String> memories = const [],
  }) async {
    final credentials = await _credentials();
    if (!await isEnrolled()) await _enroll(credentials);

    try {
      return await _requestToken(
        credentials,
        language: normalizeLanguage(language),
        profile: profile,
        memories: memories,
      );
    } on VoiceException catch (error) {
      if (error.kind != VoiceErrorKind.unauthorized) rethrow;
      // The server may have been reset or the device revoked. Enrol again once.
      await _enroll(credentials);
      return _requestToken(
        credentials,
        language: normalizeLanguage(language),
        profile: profile,
        memories: memories,
      );
    }
  }

  Future<void> _enroll(_Credentials credentials) async {
    final base = await serverUrl();
    final response = await _post(
      Uri.parse('$base/v1/device/enroll'),
      body: {
        'device_id': credentials.id,
        'secret': credentials.secret,
        'enrollment_code': await enrollmentCode(),
      },
    );

    if (response.statusCode == 200) {
      await _storage.write(key: _kEnrolled, value: 'true');
      return;
    }
    throw _errorFor(response, fallback: 'enrolment failed');
  }

  Future<VoiceSession> _requestToken(
    _Credentials credentials, {
    required String language,
    required Profile profile,
    required List<String> memories,
  }) async {
    final base = await serverUrl();
    final response = await _post(
      Uri.parse('$base/v1/voice/token'),
      headers: {
        'x-device-id': credentials.id,
        'x-device-secret': credentials.secret,
      },
      body: {
        'language': language,
        'session': _randomToken(8),
        'profile': profile.toPromptMap(),
        'memories': memories,
      },
    );

    if (response.statusCode != 200) {
      throw _errorFor(response, fallback: 'could not start the call');
    }

    final body = _decodeObject(response.body);
    final url = (body['url'] as String? ?? '').trim();
    final token = (body['token'] as String? ?? '').trim();
    if (url.isEmpty || token.isEmpty) {
      throw const VoiceException(
        VoiceErrorKind.server,
        'the server returned an incomplete session',
      );
    }

    return VoiceSession(
      url: url,
      token: token,
      room: body['room'] as String? ?? '',
      identity: body['identity'] as String? ?? '',
      language: normalizeLanguage(body['language'] as String? ?? language),
      expiresAt: _expiry(body['expires_at']),
    );
  }

  /// Checks the public API and, when available, the LiveKit/Ollama probes.
  Future<VoiceHealth> checkHealth() async {
    final base = await serverUrl();

    try {
      final response = await _client
          .get(Uri.parse('$base/readyz'))
          .timeout(const Duration(seconds: 8));
      final body = _decodeObject(response.body);
      if (response.statusCode == 200) {
        return VoiceHealth(
          reachable: true,
          ready: true,
          livekit: body['livekit'] == true,
          ollama: body['ollama'] == true,
          model: body['model'] as String?,
        );
      }
      if (response.statusCode == 503) {
        final detail = body['detail'];
        final map = detail is Map ? detail : const <String, dynamic>{};
        return VoiceHealth(
          reachable: true,
          ready: false,
          livekit: map['livekit'] == true,
          ollama: map['ollama'] == true,
          model: map['model'] as String?,
        );
      }
    } catch (_) {
      // Older deployments may not expose /readyz; fall through to /healthz.
    }

    try {
      final response = await _client
          .get(Uri.parse('$base/healthz'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = _decodeObject(response.body);
        return VoiceHealth(
          reachable: true,
          ready: body['status'] == 'ok',
          model: body['model'] as String?,
        );
      }
      return const VoiceHealth(reachable: true, ready: false);
    } on TimeoutException {
      return const VoiceHealth(reachable: false, ready: false);
    } on http.ClientException {
      return const VoiceHealth(reachable: false, ready: false);
    } catch (_) {
      return const VoiceHealth(reachable: false, ready: false);
    }
  }

  // --- plumbing ------------------------------------------------------------

  Future<http.Response> _post(
    Uri uri, {
    required Map<String, dynamic> body,
    Map<String, String> headers = const {},
  }) async {
    try {
      return await _client
          .post(
            uri,
            headers: {'content-type': 'application/json', ...headers},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const VoiceException(
        VoiceErrorKind.network,
        'the voice server did not answer in time',
      );
    } on http.ClientException catch (error) {
      throw VoiceException(VoiceErrorKind.network, error.message);
    } catch (error) {
      throw VoiceException(VoiceErrorKind.network, '$error');
    }
  }

  VoiceException _errorFor(http.Response response, {required String fallback}) {
    final detail = _detail(response.body) ?? fallback;
    switch (response.statusCode) {
      case 401:
      case 403:
        return VoiceException(
          VoiceErrorKind.unauthorized,
          detail,
          status: response.statusCode,
        );
      case 429:
        return VoiceException(
          VoiceErrorKind.rateLimited,
          detail,
          status: response.statusCode,
        );
      case 400:
        return VoiceException(
          VoiceErrorKind.config,
          detail,
          status: response.statusCode,
        );
      default:
        return VoiceException(
          VoiceErrorKind.server,
          detail,
          status: response.statusCode,
        );
    }
  }

  static Map<String, dynamic> _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  static String? _detail(String body) {
    final map = _decodeObject(body);
    final detail = map['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (detail is Map) {
      final message = detail['message'] ?? detail['error'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    return null;
  }

  static DateTime? _expiry(Object? raw) {
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch((raw * 1000).round());
    }
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static String _randomToken(int bytes) {
    final random = Random.secure();
    final buffer = List<int>.generate(bytes, (_) => random.nextInt(256));
    return base64Url.encode(buffer).replaceAll('=', '');
  }

  void close() => _client.close();
}

class _Credentials {
  final String id;
  final String secret;

  const _Credentials(this.id, this.secret);
}
