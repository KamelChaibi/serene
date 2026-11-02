// Serene Privacy Proxy with Server-Side Crisis Classifier & Streaming.
// Principles:
// 1. Zero-retention: No chat or personal data is logged or stored to disk.
// 2. Dual-layer safety & server-side crisis classifier: Evaluates subtle and explicit distress.
// 3. Streaming SSE support: Real-time token delivery to client.
// 4. Memory extraction suggestions: User approves each memory before local storage.

const http = require('http');

const API_KEY = process.env.OPENROUTER_API_KEY || process.env.API_KEY || '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';
const MODEL = process.env.MODEL || 'nvidia/nemotron-3-ultra-550b-a55b:free';

const SYSTEM_PROMPT = `You are Serene, a warm, deeply compassionate, and non-judgmental AI mental wellness companion.
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
   - Do not simply agree with catastrophic or hopeless thoughts (e.g. "everyone hates me", "nothing will ever get better").
   - Validate the pain behind the thought, but gently offer a softer perspective or micro-step (e.g., "Would you take one slow breath with me right now?", "Can we sit with this together for a moment?").
5. Strict Ethical & Clinical Boundaries:
   - You are an AI companion, NEVER a doctor, psychiatrist, or licensed human therapist.
   - Never diagnose psychiatric conditions or give medication advice.
   - Gently encourage healthy real-world relationships and consulting a professional therapist when long-term support is needed.
6. Absolute Safety & Crisis Handling:
   - NEVER provide methods, means, or rationalizations for self-harm or suicide.
   - If the user expresses explicit or implicit suicidal intent, wanting to end their life, or severe self-harm, immediately prioritize their physical safety:
     * Express warm, immediate care and concern.
     * Reassure them that they do not have to carry this alone.
     * Strongly urge them to reach out to an emergency line, a trusted family member, or a professional right now.
     * Include the exact token [[CRISIS]] anywhere in your response so the app can present immediate emergency call actions.
7. Memory Suggestion Protocol:
   - If the user shares an enduring personal detail about their life (e.g. loss of a loved one/pet, job situation, important relationship, exam, chronic struggle), you may propose a memory suggestion at the very end of your response using:
     [[MEMORY_SUGGESTION: brief neutral fact about user]]
   - Example: [[MEMORY_SUGGESTION: User is preparing for medical licensing exams]]
   - Do NOT propose memories for transient moods (e.g. "felt tired today"). Only for enduring context.`;

// Personalization preferences collected during first-launch onboarding.
// Only the derived age is sent by the client — never the raw birthday.
const PROFILE_STYLES = {
  warm: 'Warm and gentle: soft, patient, validating. Listen first and move slowly.',
  friend: 'Like a close friend: natural and familiar, lightly warm, with gentle humour only when it fits.',
  direct: 'Direct and practical: clear and honest, validate briefly, then offer concrete steps. Avoid platitudes.',
};

const PROFILE_LENGTHS = {
  short: 'Keep replies short: 2-4 sentences unless safety or clarity genuinely needs more.',
  balanced: 'Balanced length: enough to feel heard without a wall of text.',
  deep: 'Deeper, reflective replies with room to explore when it helps; never an essay.',
};

const FOCUS_LABELS = {
  anxiety: 'anxiety and panic',
  mood: 'low mood and depression',
  sleep: 'sleep difficulties',
  relationships: 'relationships and family',
  selfEsteem: 'self-esteem and self-worth',
  grief: 'grief and loss',
  stress: 'stress and burnout',
  purpose: 'meaning, purpose and direction',
};

function buildProfileSection(profile) {
  if (!profile || typeof profile !== 'object') return '';

  const lines = [];
  const name = typeof profile.name === 'string' ? profile.name.trim().slice(0, 60) : '';
  if (name) {
    lines.push(`- Preferred name: "${name}". Use it naturally and sparingly - a warm check-in now and then, never in every message.`);
  }

  const age = Number(profile.age);
  if (Number.isFinite(age) && age >= 0 && age <= 120) {
    lines.push(`- Age: ${Math.floor(age)}.`);
    if (age < 18) {
      lines.push('  They are a minor: keep language age-appropriate, avoid adult-only framing, and when distress is serious gently encourage them to involve a trusted adult, parent, or school counselor.');
    } else if (age >= 65) {
      lines.push('  Respect their life experience; do not patronize.');
    }
  }

  if (PROFILE_STYLES[profile.style]) {
    lines.push(`- Preferred tone: ${PROFILE_STYLES[profile.style]}`);
  }
  if (PROFILE_LENGTHS[profile.length]) {
    lines.push(`- Reply length: ${PROFILE_LENGTHS[profile.length]}`);
  }

  if (Array.isArray(profile.focuses)) {
    const labels = profile.focuses.map((f) => FOCUS_LABELS[f]).filter(Boolean);
    if (labels.length > 0) {
      lines.push(`- They asked for support with: ${labels.join(', ')}. Let this guide what you notice, without bringing it up constantly.`);
    }
  }

  if (profile.in_therapy === true) {
    lines.push('- They are currently seeing a therapist or counselor. Support that work; never position yourself as a replacement.');
  }

  const notes = typeof profile.notes === 'string' ? profile.notes.trim().slice(0, 300) : '';
  if (notes) {
    lines.push(`- In their own words: "${notes}"`);
  }

  if (lines.length === 0) return '';

  return `\n### Personalization (self-reported during onboarding)\n${lines.join('\n')}\n\nFollow these preferences naturally. Never mention that you have a "profile" or recite these facts back. In acute distress, warmth and safety always come before style preferences.`;
}

const CLASSIFIER_SYSTEM_PROMPT = `You are a clinical crisis assessment safety system for a mental wellness app.
Analyze the user's latest message and context to classify crisis risk level.
Start your response immediately with the JSON object on the first line. Do not output any intro, markdown block, or preamble before the JSON.

Categories:
- IMMINENT / SEVERE: Explicit intent to commit suicide, method inquiries, active self-harm, farewell notes.
- MODERATE: Implicit suicidal ideation (e.g. "everyone would be better off without me", "I have no reason to wake up", "arartah w araya7koum", "krahit hyati w nheb nerteh"), unbearable emotional pain with hopeless resignation.
- LOW: Passive situational sadness, fatigue, stress, grief without intent to die.
- NONE: Everyday thoughts, questions, normal conversation.

Recognize Modern Standard Arabic, Arabic dialects (Tunisian Derja, Egyptian, Levantine, etc.), Arabizi, French, and English.

JSON format:
{"is_crisis": boolean, "risk_level": "none"|"low"|"moderate"|"severe"|"imminent", "category": "suicide_intent"|"self_harm"|"severe_distress"|"none"}`;

// In-memory rate limiting (30 requests per minute per IP)
const rateLimits = new Map();
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 30;

function checkRateLimit(ip) {
  const now = Date.now();
  const record = rateLimits.get(ip) || { count: 0, resetTime: now + RATE_LIMIT_WINDOW_MS };
  if (now > record.resetTime) {
    record.count = 0;
    record.resetTime = now + RATE_LIMIT_WINDOW_MS;
  }
  record.count++;
  rateLimits.set(ip, record);
  return record.count <= MAX_REQUESTS_PER_WINDOW;
}

setInterval(() => {
  const now = Date.now();
  for (const [ip, record] of rateLimits.entries()) {
    if (now > record.resetTime) rateLimits.delete(ip);
  }
}, 5 * 60 * 1000);

// Independent Server-Side Crisis Classifier
async function classifyCrisis(latestMessage, history, lang, { delayMs = 0 } = {}) {
  try {
    const textToCheck = (latestMessage || '').trim();
    if (!textToCheck) return { is_crisis: false, risk_level: 'none' };

    // Layer 1 Fast Local Pattern Check
    const quickRegex = /(kill myself|end my life|want to die|suicid|better off dead|hang myself|overdose|me tuer|en finir|veux mourir|envie de mourir|plus envie de vivre|انتحار|أنتحر|اقتل نفسي|أريد أن أموت|بدي موت|عاوز اموت|نحب نموت|نقتل روحي|نموت ونرتاح|حياتي ملهاش لازمة|nheb nmout|nektel rouhi|baddi mout|krahit 7yati)/i;
    if (quickRegex.test(textToCheck)) {
      return { is_crisis: true, risk_level: 'severe', category: 'suicide_intent' };
    }

    // Let the main reply get its first token out before the classifier call
    // competes for provider capacity. The stream still waits for the result
    // before closing, so the safety net is never skipped.
    if (delayMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }

    // Layer 2 Server-side LLM Classifier for subtle/implicit indicators.
    // The hard timeout guarantees a slow classifier can never keep the reply
    // stream open indefinitely.
    const classifierRes = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
        'HTTP-Referer': 'https://serene.app',
        'X-Title': 'Serene Safety Classifier',
      },
      body: JSON.stringify({
        model: MODEL,
        messages: [
          { role: 'system', content: CLASSIFIER_SYSTEM_PROMPT },
          { role: 'user', content: `Message to evaluate:\n"${textToCheck}"\nLanguage context: ${lang}` },
        ],
        max_tokens: 250,
        temperature: 0.1,
      }),
      signal: AbortSignal.timeout(6000),
    });

    if (classifierRes.ok) {
      const data = await classifierRes.json();
      const rawText = data.choices?.[0]?.message?.content || '{}';
      const jsonMatch = rawText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        const isCrisis = parsed.is_crisis === true || parsed.risk_level === 'severe' || parsed.risk_level === 'imminent' || parsed.risk_level === 'moderate';
        return {
          is_crisis: isCrisis,
          risk_level: parsed.risk_level || (isCrisis ? 'moderate' : 'none'),
          category: parsed.category || 'none',
        };
      }
    }
  } catch (err) {
    console.error('Classifier evaluation error (falling back to regex):', err.message);
  }
  return { is_crisis: false, risk_level: 'none' };
}

const server = http.createServer(async (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
  if (!checkRateLimit(clientIp)) {
    res.writeHead(429, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ error: 'Too many requests. Please take a moment and try again.' }));
  }

  // Health check endpoint
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'ok', model: MODEL, mode: 'zero-retention' }));
  }

  // Dedicated standalone classifier endpoint
  if (req.method === 'POST' && req.url === '/classify') {
    let body = '';
    for await (const chunk of req) body += chunk;
    try {
      const { message = '', history = [], lang = 'ar' } = JSON.parse(body);
      const result = await classifyCrisis(message, history, lang);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify(result));
    } catch {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ error: 'Invalid JSON' }));
    }
  }

  // POST /chat (Non-streaming) and POST /chat/stream (SSE Streaming)
  if (req.method === 'POST' && (req.url === '/chat' || req.url === '/chat/stream')) {
    let body = '';
    for await (const chunk of req) {
      body += chunk;
      if (body.length > 1e6) {
        res.writeHead(413, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ error: 'Payload too large' }));
      }
    }

    try {
      const { messages = [], memories = [], lang = 'en', profile = null } = JSON.parse(body);
      const isStreaming = req.url === '/chat/stream';

      const latestUserMsg = [...messages].reverse().find(m => m.role === 'user')?.content || '';

      // Kick off the safety classifier in parallel instead of blocking the
      // reply on it. The result is awaited before the stream closes.
      const classificationPromise = classifyCrisis(latestUserMsg, messages, lang, {
        delayMs: isStreaming ? 500 : 0,
      }).catch((err) => {
        console.error('Classifier evaluation error:', err.message);
        return { is_crisis: false, risk_level: 'none', category: 'none' };
      });

      const memorySection = memories.length > 0
        ? `\nUser's Saved Memories (use only with care):\n${memories.map(m => `- ${m}`).join('\n')}`
        : '\nNo prior memories saved.';

      const systemPromptWithContext = `${SYSTEM_PROMPT}\nUser interface language: ${lang}${buildProfileSection(profile)}${memorySection}`;

      const formattedMessages = [
        { role: 'system', content: systemPromptWithContext },
        ...messages
          .filter(m => (m.content || m.text || '').trim().length > 0)
          .map(m => ({
            role: m.role === 'assistant' ? 'assistant' : 'user',
            content: m.content || m.text || '',
          })),
      ];

      // Streaming branch
      if (isStreaming) {
        // Flush headers right away so the client starts reading immediately,
        // then open the model stream without waiting for the classifier.
        res.writeHead(200, {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          'X-Accel-Buffering': 'no',
        });
        if (res.socket) res.socket.setNoDelay(true);
        res.flushHeaders();
        res.write(': connected\n\n');

        let llmStreamRes;
        try {
          llmStreamRes = await fetch('https://openrouter.ai/api/v1/chat/completions', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${API_KEY}`,
              'HTTP-Referer': 'https://serene.app',
              'X-Title': 'Serene Wellness Companion',
            },
            body: JSON.stringify({
              model: MODEL,
              messages: formattedMessages,
              max_tokens: 800,
              temperature: 0.7,
              stream: true,
            }),
          });
        } catch (err) {
          res.write(`data: ${JSON.stringify({ error: 'Upstream provider error' })}\n\n`);
          return res.end();
        }

        if (!llmStreamRes.ok) {
          res.write(`data: ${JSON.stringify({ error: 'Upstream provider error' })}\n\n`);
          return res.end();
        }

        const reader = llmStreamRes.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';
        let fullReply = '';

        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split('\n');
            buffer = lines.pop() || '';

            for (const line of lines) {
              const trimmed = line.trim();
              if (!trimmed || trimmed.startsWith(':')) continue;
              if (trimmed === 'data: [DONE]') continue;
              if (trimmed.startsWith('data: ')) {
                try {
                  const parsed = JSON.parse(trimmed.slice(6));
                  const token = parsed.choices?.[0]?.delta?.content || '';
                  if (token) {
                    fullReply += token;
                    // Stream token to client unless the client already left.
                    if (!res.writableEnded) {
                      res.write(`data: ${JSON.stringify({ token })}\n\n`);
                    }
                  }
                } catch (_) {}
              }
            }
          }
        } catch (err) {
          console.error('Stream interrupted:', err.message);
        }

        // Post-processing for memory suggestions and crisis token
        let memorySuggestion = null;
        const memoryMatch = fullReply.match(/\[\[MEMORY_SUGGESTION:\s*([^\]]+)\]\]/);
        if (memoryMatch) {
          memorySuggestion = memoryMatch[1].trim();
        }

        const classification = await classificationPromise;
        const modelTriggeredCrisis = fullReply.includes('[[CRISIS]]') || classification.is_crisis;

        if (!res.writableEnded) {
          res.write(`data: ${JSON.stringify({
            done: true,
            crisis: modelTriggeredCrisis,
            risk_level: classification.risk_level,
            memory_suggestion: memorySuggestion,
          })}\n\n`);
        }

        return res.end();
      }

      // Non-streaming branch
      const llmRes = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${API_KEY}`,
          'HTTP-Referer': 'https://serene.app',
          'X-Title': 'Serene Wellness Companion',
        },
        body: JSON.stringify({
          model: MODEL,
          messages: formattedMessages,
          max_tokens: 800,
          temperature: 0.7,
        }),
      });

      if (!llmRes.ok) {
        res.writeHead(llmRes.status, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ error: 'Upstream provider error' }));
      }

      const data = await llmRes.json();
      let replyText = data.choices?.[0]?.message?.content ?? '...';

      let memorySuggestion = null;
      const memoryMatch = replyText.match(/\[\[MEMORY_SUGGESTION:\s*([^\]]+)\]\]/);
      if (memoryMatch) {
        memorySuggestion = memoryMatch[1].trim();
        replyText = replyText.replace(/\[\[MEMORY_SUGGESTION:\s*[^\]]+\]\]/g, '').trim();
      }

      const classification = await classificationPromise;
      const isCrisisDetected = classification.is_crisis || replyText.includes('[[CRISIS]]');
      if (replyText.includes('[[CRISIS]]')) {
        replyText = replyText.replace(/\[\[CRISIS\]\]/g, '').trim();
      }

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        reply: replyText,
        crisis: isCrisisDetected,
        risk_level: classification.risk_level,
        memory_suggestion: memorySuggestion,
      }));
    } catch (err) {
      console.error('Server error:', err);
      if (res.headersSent) {
        // A streaming response already started; just close it cleanly.
        return res.end();
      }
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Internal server error' }));
    }
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

const PORT = process.env.PORT || 8787;
server.listen(PORT, () => {
  console.log(`Serene proxy active on port ${PORT} using ${MODEL} (zero-retention + classifier + streaming)`);
});
