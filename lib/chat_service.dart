import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'profile.dart';

// 10.0.2.2 is the Android emulator's alias for the host machine; the browser
// needs localhost instead. Production web builds should always pass
// --dart-define=API_URL=https://your-backend.example/chat.
const apiUrl = String.fromEnvironment('API_URL',
    defaultValue:
        kIsWeb ? 'http://localhost:8787/chat' : 'http://10.0.2.2:8787/chat');
const defaultOpenRouterKey = String.fromEnvironment(
  'OPENROUTER_API_KEY',
  defaultValue:
      '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',
);
const defaultModel = String.fromEnvironment(
  'MODEL',
  defaultValue: 'nvidia/nemotron-3-ultra-550b-a55b:free',
);

/// Shared client: repeat messages reuse the open keep-alive connection instead
/// of paying a new TCP/TLS handshake every time.
final http.Client _http = http.Client();

const Duration _proxyTimeout = Duration(milliseconds: 2500);
const Duration _directTimeout = Duration(seconds: 15);

/// After the proxy fails once, skip it for a few minutes. Without this, users
/// without a backend wait on a dead endpoint before *every* reply.
DateTime? _proxyDownUntil;

bool get _proxyLikelyDown =>
    _proxyDownUntil != null && DateTime.now().isBefore(_proxyDownUntil!);

void _markProxyDown() =>
    _proxyDownUntil = DateTime.now().add(const Duration(minutes: 3));

void _markProxyUp() => _proxyDownUntil = null;

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

const String _systemPromptTemplate = '''
You are Serene, a warm, deeply compassionate, and non-judgmental AI mental wellness companion.
You are talking to someone who may be struggling with loneliness, depression, anxiety, grief, heavy emotional burdens, or personal challenges.

### Core Persona & Principles:
1. Warmth & Human Presence: Speak like a close, trusted, and empathetic friend. Be unhurried, kind, gentle, and present.
2. Active Listening & Emotional Validation: First acknowledge and reflect the user's feelings before offering suggestions. Make them feel truly seen and heard.
3. Language & Dialects:
   - Match the user's language and dialect naturally.
   - If they speak Arabic, respond in Arabic (seamlessly matching their dialect: Tunisian/Maghrebi Derja, Egyptian, Levantine, Gulf, or Modern Standard Arabic).
   - If they write in Arabizi (e.g. "nheb nahki", "3ayez", "kifak"), understand it completely and reply warmly.
   - If they speak French or English, respond in natural, compassionate French or English.
4. Gentle Reframing & Coping Micro-Steps:
   - Validate the pain behind the thought, and gently offer a softer perspective or micro-step (e.g., "Would you take one slow breath with me right now?").
5. Strict Ethical & Clinical Boundaries:
   - You are an AI companion, NEVER a doctor, psychiatrist, or licensed human therapist. Never diagnose or give medication advice.
6. Absolute Safety & Crisis Handling:
   - If the user expresses explicit or implicit suicidal intent, wanting to end their life, or severe self-harm, immediately prioritize their safety, urge them to contact emergency hotlines, and include the exact token [[CRISIS]] in your response.
7. Memory Suggestion:
   - If the user shares an enduring personal detail (loss of loved one/pet, job status, exam, chronic struggle, important person), propose a single memory suggestion at the very end of your response using:
   [[MEMORY_SUGGESTION: User is currently grieving loss of their pet]]
''';

const Map<String, String> _focusLabels = {
  'anxiety': 'anxiety and panic',
  'mood': 'low mood and depression',
  'sleep': 'sleep difficulties',
  'relationships': 'relationships and family',
  'selfEsteem': 'self-esteem and self-worth',
  'grief': 'grief and loss',
  'stress': 'stress and burnout',
  'purpose': 'meaning, purpose and direction',
};

String _profileSection(Profile? profile) {
  if (profile == null || !profile.hasPreferences) return '';

  final lines = <String>[];
  final name = profile.trimmedName;
  if (name.isNotEmpty) {
    lines.add('- Preferred name: "$name". Use it naturally and sparingly — '
        'a warm check-in now and then, never in every message.');
  }

  final age = profile.age;
  if (age != null) {
    lines.add('- Age: $age.');
    if (age < 18) {
      lines.add('  They are a minor: keep language age-appropriate, avoid '
          'adult-only framing, and when distress is serious gently encourage '
          'them to involve a trusted adult, parent, or school counselor.');
    } else if (age >= 65) {
      lines.add('  Respect their life experience; do not patronize.');
    }
  }

  switch (profile.style) {
    case Profile.styleFriend:
      lines.add('- Preferred tone: like a close friend — natural, familiar, '
          'lightly warm, with gentle humour only when it fits.');
      break;
    case Profile.styleDirect:
      lines.add('- Preferred tone: direct and practical — clear and honest, '
          'validate briefly, then offer concrete steps. Avoid platitudes.');
      break;
    default:
      lines.add('- Preferred tone: warm and gentle — soft, patient and '
          'validating. Listen first and move slowly.');
  }

  switch (profile.length) {
    case Profile.lengthShort:
      lines.add('- Reply length: short. 2–4 sentences unless safety or '
          'clarity genuinely needs more.');
      break;
    case Profile.lengthDeep:
      lines.add('- Reply length: deeper and reflective, with room to explore '
          'when it helps. Never turn it into an essay.');
      break;
    default:
      lines.add('- Reply length: balanced — enough to feel heard, without a '
          'wall of text.');
  }

  if (profile.focuses.isNotEmpty) {
    final labels = profile.focuses
        .map((f) => _focusLabels[f])
        .whereType<String>()
        .toList(growable: false);
    if (labels.isNotEmpty) {
      lines.add('- They asked for support with: ${labels.join(', ')}. '
          'Let this guide what you notice, without bringing it up constantly.');
    }
  }

  if (profile.inTherapy) {
    lines.add('- They are currently seeing a therapist or counselor. Support '
        'that work; never position yourself as a replacement.');
  }

  final notes = profile.notes.trim();
  if (notes.isNotEmpty) {
    final trimmed = notes.length > 300 ? notes.substring(0, 300) : notes;
    lines.add('- In their own words: "$trimmed"');
  }

  return '''
### Personalization (self-reported during onboarding)
${lines.join('\n')}

Follow these preferences naturally. Never mention that you have a "profile" or recite these facts back. In acute distress, warmth and safety always come before style preferences.''';
}

String buildSystemPrompt(String lang, List<String> memories,
    [Profile? profile]) {
  final memorySection = memories.isNotEmpty
      ? '\nUser Saved Memories:\n${memories.map((m) => '- $m').join('\n')}'
      : '';
  final profileSection = _profileSection(profile);
  return '$_systemPromptTemplate\nUser interface language: $lang'
      '$profileSection$memorySection';
}

/// Streams response tokens in real-time. Falls back seamlessly to direct OpenRouter SSE if proxy is unreachable.
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

  bool proxySuccess = false;

  // Attempt 1: stream from the warm backend proxy. It is skipped briefly
  // after a failure so a missing backend never delays every single message.
  if (!_proxyLikelyDown) {
    try {
      final request = http.Request('POST', Uri.parse(streamUrl))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode(payload);

      final streamedResponse = await _http.send(request).timeout(_proxyTimeout);

      if (streamedResponse.statusCode == 200) {
        _markProxyUp();
        bool gotToken = false;
        bool earlyError = false;

        final lineStream = streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in lineStream) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
          if (trimmed.startsWith('data: ')) {
            final dataStr = trimmed.substring(6).trim();
            if (dataStr == '[DONE]') break;
            try {
              final json = jsonDecode(dataStr) as Map<String, dynamic>;
              final token = json['token'] as String? ?? '';
              final done = json['done'] as bool? ?? false;
              final crisis = json['crisis'] as bool? ?? false;
              final mem = json['memory_suggestion'] as String?;
              final err = json['error'] as String?;

              // The proxy failed before producing anything: fall back fast
              // rather than leaving the user with an empty bubble.
              if (err != null && !gotToken) {
                earlyError = true;
                break;
              }

              if (token.isNotEmpty) gotToken = true;

              yield ChatStreamChunk(
                token: token,
                isDone: done,
                isCrisis: crisis,
                memorySuggestion: mem,
                error: err,
              );
            } catch (_) {}
          }
        }

        if (!earlyError && gotToken) {
          proxySuccess = true;
        } else if (!earlyError) {
          // Stream closed without a single token — treat as unhealthy.
          _markProxyDown();
        }
      } else {
        _markProxyDown();
      }
    } catch (_) {
      _markProxyDown();
    }
  }

  // Attempt 2: direct OpenRouter streaming fallback
  if (!proxySuccess) {
    yield* _askDirectOpenRouterStream(history, lang, memories,
        profile: profile);
  }
}

Stream<ChatStreamChunk> _askDirectOpenRouterStream(
  List<Msg> history,
  String lang,
  List<String> memories, {
  Profile? profile,
}) async* {
  final systemPrompt = buildSystemPrompt(lang, memories, profile);

  final messages = [
    {'role': 'system', 'content': systemPrompt},
    ..._historyPayload(history),
  ];

  final request = http.Request(
    'POST',
    Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
  )
    ..headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'Authorization': 'Bearer $defaultOpenRouterKey',
      'HTTP-Referer': 'https://serene.app',
      'X-Title': 'Serene Wellness Companion',
    })
    ..body = jsonEncode({
      'model': defaultModel,
      'messages': messages,
      'max_tokens': 800,
      'temperature': 0.7,
      'stream': true,
    });

  final streamedResponse = await _http.send(request).timeout(_directTimeout);

  if (streamedResponse.statusCode != 200) {
    yield ChatStreamChunk(
      error: 'HTTP ${streamedResponse.statusCode}',
      isDone: true,
    );
    return;
  }

  final lineStream = streamedResponse.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  String accumulated = '';
  bool isCrisis = false;

  await for (final line in lineStream) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
    if (trimmed == 'data: [DONE]') {
      break;
    }
    if (trimmed.startsWith('data: ')) {
      try {
        final json = jsonDecode(trimmed.substring(6)) as Map<String, dynamic>;
        final delta =
            json['choices']?[0]?['delta']?['content'] as String? ?? '';
        if (delta.isNotEmpty) {
          accumulated += delta;
          if (accumulated.contains('[[CRISIS]]')) {
            isCrisis = true;
          }
          yield ChatStreamChunk(
            token: delta,
            isCrisis: isCrisis,
          );
        }
      } catch (_) {}
    }
  }

  // Check for memory suggestions at the end
  String? memorySuggestion;
  final match =
      RegExp(r'\[\[MEMORY_SUGGESTION:\s*([^\]]+)\]\]').firstMatch(accumulated);
  if (match != null) {
    memorySuggestion = match.group(1)?.trim();
  }

  yield ChatStreamChunk(
    isDone: true,
    isCrisis: isCrisis,
    memorySuggestion: memorySuggestion,
  );
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
