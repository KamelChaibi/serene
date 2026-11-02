import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'profile.dart';

// 10.0.2.2 is the Android emulator's alias for the host machine; the browser
// needs localhost instead. Production builds must pass
// --dart-define=API_URL=https://your-backend.example/chat. No provider API key
// is compiled into the client: all model access goes through that proxy.
const apiUrl = String.fromEnvironment('API_URL',
    defaultValue:
        kIsWeb ? 'http://localhost:8787/chat' : 'http://10.0.2.2:8787/chat');

/// Shared client: repeat messages reuse the open keep-alive connection instead
/// of paying a new TCP/TLS handshake every time.
final http.Client _http = http.Client();

const Duration _proxyTimeout = Duration(seconds: 15);

const String _proxyUnavailable =
    'Unable to reach the Serene chat server. Check your connection and try again.';

/// Builds the wire history, dropping empty assistant placeholders (the client
/// inserts one immediately for the typing bubble) so the model never receives
/// a trailing empty turn.
List<Map<String, String>> _historyPayload(List<Msg> history) => history.reversed
    .take(20)
    .toList()
    .reversed
    .where((m) => m.text.trim().isNotEmpty)
    .map((m) => {
          'role': m.role == 'assistant' ? 'assistant' : 'user',
          'content': m.text,
        })
    .toList();

class Msg {
  final String role; // 'user' | 'assistant'
  String text;
  final DateTime timestamp;
  String? memorySuggestion;

  Msg(this.role, this.text, [DateTime? time, this.memorySuggestion])
      : timestamp = time ?? DateTime.now();
}

class ChatResponse {
  final String reply;
  final bool isCrisis;
  final String? memorySuggestion;

  const ChatResponse({
    required this.reply,
    this.isCrisis = false,
    this.memorySuggestion,
  });
}

class ChatStreamChunk {
  final String token;
  final bool isDone;
  final bool isCrisis;
  final String? memorySuggestion;
  final String? error;

  const ChatStreamChunk({
    this.token = '',
    this.isDone = false,
    this.isCrisis = false,
    this.memorySuggestion,
    this.error,
  });
}

/// Streams response tokens from the Serene proxy.
///
/// The client never talks to the model provider directly: every API key lives
/// on the server, so an extracted APK cannot leak one.
Stream<ChatStreamChunk> askStream(
  List<Msg> history,
  String lang,
  List<String> memories, {
  Profile? profile,
}) async* {
  final streamUrl = apiUrl.endsWith('/chat')
      ? apiUrl.replaceFirst('/chat', '/chat/stream')
      : '$apiUrl/stream';

  final payload = {
    'lang': lang,
    'memories': memories,
    if (profile != null && profile.hasPreferences)
      'profile': profile.toPromptMap(),
    'messages': _historyPayload(history),
  };

  http.StreamedResponse response;
  try {
    final request = http.Request('POST', Uri.parse(streamUrl))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode(payload);

    response = await _http.send(request).timeout(_proxyTimeout);
  } catch (_) {
    yield const ChatStreamChunk(error: _proxyUnavailable, isDone: true);
    return;
  }

  if (response.statusCode != 200) {
    yield ChatStreamChunk(
      error: '$_proxyUnavailable (HTTP ${response.statusCode})',
      isDone: true,
    );
    return;
  }

  bool gotToken = false;
  final lineStream =
      response.stream.transform(utf8.decoder).transform(const LineSplitter());

  await for (final line in lineStream) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
    if (!trimmed.startsWith('data: ')) continue;

    final dataStr = trimmed.substring(6).trim();
    if (dataStr == '[DONE]') break;

    try {
      final json = jsonDecode(dataStr) as Map<String, dynamic>;
      final token = json['token'] as String? ?? '';
      final done = json['done'] as bool? ?? false;
      final crisis = json['crisis'] as bool? ?? false;
      final mem = json['memory_suggestion'] as String?;
      final err = json['error'] as String?;

      if (err != null) {
        yield ChatStreamChunk(
          error: gotToken ? err : '$_proxyUnavailable ($err)',
          isDone: true,
        );
        return;
      }

      if (token.isNotEmpty) gotToken = true;

      yield ChatStreamChunk(
        token: token,
        isDone: done,
        isCrisis: crisis,
        memorySuggestion: mem,
      );
    } catch (_) {
      // Ignore malformed keep-alive or non-JSON event lines.
    }
  }

  if (!gotToken) {
    yield const ChatStreamChunk(error: _proxyUnavailable, isDone: true);
  }
}

/// Legacy non-streaming fallback
Future<ChatResponse> ask(
  List<Msg> history,
  String lang,
  List<String> memories, {
  Profile? profile,
}) async {
  final buffer = StringBuffer();
  bool crisis = false;
  String? memorySuggestion;

  await for (final chunk
      in askStream(history, lang, memories, profile: profile)) {
    if (chunk.error != null) throw Exception(chunk.error);
    buffer.write(chunk.token);
    if (chunk.isCrisis) crisis = true;
    if (chunk.memorySuggestion != null) {
      memorySuggestion = chunk.memorySuggestion;
    }
  }

  var text = buffer.toString();
  text = text
      .replaceAll(RegExp(r'\[\[MEMORY_SUGGESTION:\s*[^\]]+\]\]'), '')
      .trim();
  text = text.replaceAll('[[CRISIS]]', '').trim();

  return ChatResponse(
    reply: text.isEmpty ? '...' : text,
    isCrisis: crisis,
    memorySuggestion: memorySuggestion,
  );
}
