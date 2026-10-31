import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8787/chat');
const defaultOpenRouterKey = String.fromEnvironment(
  'OPENROUTER_API_KEY',
  defaultValue: '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',
);
const defaultModel = String.fromEnvironment(
  'MODEL',
  defaultValue: 'nvidia/nemotron-3-ultra-550b-a55b:free',
);

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
You are Serene (سكينة), a warm, deeply compassionate, and non-judgmental AI mental wellness companion.
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

String buildSystemPrompt(String lang, List<String> memories) {
  final memorySection = memories.isNotEmpty
      ? '\nUser Saved Memories:\n${memories.map((m) => '- $m').join('\n')}'
      : '';
  return '$_systemPromptTemplate\nUser interface language: $lang$memorySection';
}

/// Streams response tokens in real-time. Falls back seamlessly to direct OpenRouter SSE if proxy is unreachable.
Stream<ChatStreamChunk> askStream(
  List<Msg> history,
  String lang,
  List<String> memories,
) async* {
  final streamUrl = apiUrl.endsWith('/chat')
      ? apiUrl.replaceFirst('/chat', '/chat/stream')
      : '$apiUrl/stream';

  final payload = {
    'lang': lang,
    'memories': memories,
    'messages': history.reversed
        .take(20)
        .toList()
        .reversed
        .map((m) => {'role': m.role, 'content': m.text})
        .toList(),
  };

  bool proxySuccess = false;

  // Attempt 1: Stream from backend proxy
  try {
    final client = http.Client();
    final request = http.Request('POST', Uri.parse(streamUrl))
      ..headers.addAll({'Content-Type': 'application/json'})
      ..body = jsonEncode(payload);

    final streamedResponse = await client.send(request).timeout(const Duration(seconds: 10));

    if (streamedResponse.statusCode == 200) {
      proxySuccess = true;
      final lineStream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
        if (trimmed.startsWith('data: ')) {
          final dataStr = trimmed.substring(6).trim();
          if (dataStr == '[DONE]') {
            yield const ChatStreamChunk(isDone: true);
            break;
          }
          try {
            final json = jsonDecode(dataStr) as Map<String, dynamic>;
            final token = json['token'] as String? ?? '';
            final done = json['done'] as bool? ?? false;
            final crisis = json['crisis'] as bool? ?? false;
            final mem = json['memory_suggestion'] as String?;
            final err = json['error'] as String?;

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
    }
  } catch (_) {
    proxySuccess = false;
  }

  // Attempt 2: Direct OpenRouter streaming fallback
  if (!proxySuccess) {
    yield* _askDirectOpenRouterStream(history, lang, memories);
  }
}

Stream<ChatStreamChunk> _askDirectOpenRouterStream(
  List<Msg> history,
  String lang,
  List<String> memories,
) async* {
  final systemPrompt = buildSystemPrompt(lang, memories);

  final messages = [
    {'role': 'system', 'content': systemPrompt},
    ...history.reversed.take(20).toList().reversed.map((m) => {
          'role': m.role == 'assistant' ? 'assistant' : 'user',
          'content': m.text,
        }),
  ];

  final client = http.Client();
  final request = http.Request(
    'POST',
    Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
  )
    ..headers.addAll({
      'Content-Type': 'application/json',
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

  final streamedResponse = await client.send(request).timeout(const Duration(seconds: 20));

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
        final delta = json['choices']?[0]?['delta']?['content'] as String? ?? '';
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
  final match = RegExp(r'\[\[MEMORY_SUGGESTION:\s*([^\]]+)\]\]').firstMatch(accumulated);
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
Future<ChatResponse> ask(List<Msg> history, String lang, List<String> memories) async {
  final buffer = StringBuffer();
  bool crisis = false;
  String? memorySuggestion;

  await for (final chunk in askStream(history, lang, memories)) {
    if (chunk.error != null) throw Exception(chunk.error);
    buffer.write(chunk.token);
    if (chunk.isCrisis) crisis = true;
    if (chunk.memorySuggestion != null) memorySuggestion = chunk.memorySuggestion;
  }

  var text = buffer.toString();
  text = text.replaceAll(RegExp(r'\[\[MEMORY_SUGGESTION:\s*[^\]]+\]\]'), '').trim();
  text = text.replaceAll('[[CRISIS]]', '').trim();

  return ChatResponse(
    reply: text.isEmpty ? '...' : text,
    isCrisis: crisis,
    memorySuggestion: memorySuggestion,
  );
}
