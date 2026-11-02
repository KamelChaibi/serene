# Serene voice backend

Self-hosted, real-time voice for the Serene Flutter app.

```
 Android app ──WebRTC──▶ LiveKit server ◀──WebRTC── LiveKit Agents worker
      │                      ▲                         │
      │  HTTPS: token        │                         ├─▶ STT  (faster-whisper)
      └──────────────────────┴─ FastAPI (this repo)    ├─▶ LLM  (Ollama / Qwen3)
                                                       └─▶ TTS  (Kokoro / SILMA)
```

The phone never holds an API secret and never talks to a model directly. It
receives a 10-minute LiveKit token, joins a room, and streams audio. The agent
worker joins the same room and runs the voice pipeline. No cloud inference is
used at any point.

---

## What is actually free

| Component | Cost | Notes |
|---|---|---|
| LiveKit server (OSS) | free software | self-hosted, Apache-2.0 |
| LiveKit Agents / plugins | free software | Apache-2.0 |
| faster-whisper + Whisper weights | free software | MIT / MIT weights |
| Qwen3 via Ollama | free software | Apache-2.0 |
| Kokoro-82M | free software | Apache-2.0 |
| SILMA TTS v1 (Arabic MSA) | free software | Apache-2.0 |
| SILMA Derja fine-tune | free, **non-commercial** | CC-BY-NC-4.0 |
| This backend | free software | MIT |
| Hosting | **your hardware** | an 8 GB NVIDIA GPU is the realistic minimum |
| Electricity | **your cost** | a call is GPU-bound |

There is no per-minute fee, no subscription, and no metered API. The recurring
cost is electricity and the machine you already own.

---

## Requirements

* Docker with the NVIDIA Container Toolkit (for GPU services)
* An NVIDIA GPU with **8 GB VRAM** for the `low_vram` profile
* ~25 GB free disk for images and weights
* A phone and host on the same LAN (for development)
* Python 3.11+ on the host only if you want to run `scripts/download_models.py`

CPU-only works but is not conversational: Whisper medium on CPU is roughly
1–2× real time and SILMA is far slower. Treat CPU as a debugging mode.

---

## Quick start (Docker)

```bash
cd voice_backend

# 1. Configuration
cp .env.example .env

# 2. Set the address your phone will use.  This must NOT be 127.0.0.1.
#    Windows:  ipconfig    macOS/Linux:  ip addr
#    LIVEKIT_URL=ws://192.168.1.10:7880

# 3. Generate a real secret (do not ship the example value)
python -c "import secrets; print(secrets.token_urlsafe(48))"
#    put it in LIVEKIT_API_SECRET

# 4. Optional but recommended: a one-time enrolment code
python -c "import secrets; print(secrets.token_urlsafe(24))"
#    put it in SERENE_ENROLLMENT_CODE

# 5. Download weights into ./models (bind-mounted at /models)
pip install huggingface_hub
python scripts/download_models.py --profile low_vram

# 6. Build and start
docker compose up -d --build

# 7. Pull the language model (one time, ~2.5 GB for 4B)
docker compose exec ollama ollama pull qwen3:4b

# 8. Verify
python scripts/smoke_test.py --api http://127.0.0.1:8788
```

`smoke_test.py` enrols a throwaway device, mints a token, inspects its claims,
and synthesises one clip per voice. Add `--out-dir ./smoke-audio` to keep the
wav files for listening.

### Ports

| Port | Service | Exposure |
|---|---|---|
| 7880/tcp | LiveKit signalling (ws/wss) | phone |
| 7881/tcp | LiveKit WebRTC over TCP | phone |
| 7882–7892/udp | LiveKit WebRTC media | phone |
| 8788/tcp | Serene API | phone |
| 8001/tcp | STT | `127.0.0.1` only |
| 8002/tcp | TTS | `127.0.0.1` only |
| 11434/tcp | Ollama | `127.0.0.1` only |

Only 7880–7892 and 8788 need to be reachable from the phone. On a home router,
forward those ports to the host for internet use; see *Production* below.

### LAN-only LiveKit

`livekit.yaml` ships LAN-pinned (`rtc.use_external_ip: false` plus
`rtc.node_ip`), so LiveKit advertises an address clients can actually reach
instead of probing the internet for a public one. Set `node_ip` to your host's
LAN address — it must match the host part of `LIVEKIT_URL` in `.env`:

```yaml
rtc:
  use_external_ip: false
  node_ip: 192.168.1.17
```

For internet deployment, remove `node_ip` and set `use_external_ip: true`.

---

## Manual (no Docker)

Four processes, four terminals. Python 3.12 is recommended because `pynini`
publishes wheels for it.

```bash
cd voice_backend
python -m venv .venv && . .venv/bin/activate

pip install -e ".[agent,stt,tts]"
pip install -e ".[tts-ar]"        # Linux only: NeMo/pynini
```

```bash
# LiveKit server
livekit-server --config livekit.yaml

# Ollama
ollama serve
ollama pull qwen3:4b

# STT
uvicorn app.stt_server:app --host 0.0.0.0 --port 8001

# TTS
uvicorn app.tts_server:app --host 0.0.0.0 --port 8002

# Agent worker
python -m app.agent start

# API
uvicorn app.api:app --host 0.0.0.0 --port 8788
```

Export the same variables as `.env` in each terminal. On Windows, run the
API, agent and STT; the Arabic TTS group does not install because `pynini` has
no Windows wheels. English/French Kokoro TTS does install.

---

## Model profiles

### `low_vram` (8 GB)

| Model | Setting | Approx. VRAM |
|---|---|---|
| Qwen3 4B Q4 | `OLLAMA_MODEL=qwen3:4b` | 2.6 GB |
| Whisper medium int8 | `STT_MODEL_NAME=/models/faster-whisper/medium` | 0.8 GB |
| Silero VAD | bundled | <0.1 GB |
| Kokoro (en/fr) | lazy | 0.4 GB |
| SILMA MSA (ar) | lazy, fp16 | ~3.0 GB |

English and French calls peak around 4 GB. An Arabic call loads SILMA as well
and peaks around 7 GB. That fits, but only just: do not run two calls at once
on 8 GB.

### `quality` (12–16 GB)

| Model | Setting | Approx. VRAM |
|---|---|---|
| Qwen3 8B Q4 | `OLLAMA_MODEL=qwen3:8b` | 5.0 GB |
| Whisper large-v3 int8 | `/models/faster-whisper/large-v3` | 1.6 GB |
| SILMA MSA | lazy, fp16 | ~3.0 GB |

This **does not fit in 8 GB** together with Arabic TTS. Use it only on a
12 GB+ card. On 8 GB the models would swap on every turn, adding seconds of
latency.

Download either profile with:

```bash
python scripts/download_models.py --profile quality
```

Then update `OLLAMA_MODEL` and `STT_MODEL_NAME` in `.env` and restart.

### Kokoro is lazy per language

`af_heart` (English) and `ff_siwis` (French) share the Kokoro engine. French
needs `espeak-ng`, which the TTS image installs. If `espeak-ng` is missing on a
manual install, French synthesis fails at runtime with a phonemiser error.

### SILMA is lazy and falls back

`silma-derja` loads `models/silma-derja/model.pt`. If that file is missing, the
server logs a warning and synthesises with the MSA checkpoint instead. The
`/healthz` endpoint lists `fallbacks`.

---

## Configuration

Everything is environment-driven; `.env.example` documents every key. The
values that matter most:

| Variable | Purpose |
|---|---|
| `LIVEKIT_URL` | the URL returned to the phone (`ws://` LAN, `wss://` internet) |
| `LIVEKIT_INTERNAL_URL` | URL the agent uses inside Docker (defaults to `LIVEKIT_URL`) |
| `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET` | LiveKit credentials; the secret never reaches the app |
| `SERENE_ENROLLMENT_CODE` | optional shared code required once per install |
| `SERENE_TOKEN_TTL_SECONDS` | token lifetime, default 600 |
| `OLLAMA_MODEL` | `qwen3:4b` or `qwen3:8b` |
| `SERENE_PROMPT_FILE` | personality YAML |
| `SILMA_DERJA_REF_AUDIO` / `_REF_TEXT` | native Derja reference clip and transcript |

### Personality

`prompts/serene_friend.yaml` holds the identity, rules, per-language
directives, greetings, safety lines, and profile modifiers. Edit it and restart
the `agent` container; no Flutter rebuild is needed.

The agent appends `/no_think` to the system prompt because Qwen3 otherwise
spends seconds generating reasoning tokens that are never spoken.

### Reference clips (Arabic)

F5-TTS conditions output on a reference recording. SILMA ships an Arabic MSA
clip; Derja has no shipped native clip. For better Derja prosody, record 4–8
seconds of Tunisian speech, put the file in `models/`, and set:

```
SILMA_DERJA_REF_AUDIO=/models/derja-ref.wav
SILMA_DERJA_REF_TEXT=<exact transcript of that clip>
```

The transcript must match the audio word for word.

---

## How a call works

1. The app enrols once (`POST /v1/device/enroll`) and stores the device id and
   a 32-byte secret in Android Keystore-backed secure storage.
2. Before each call the app posts the language, profile and (optionally)
   selected memories to `POST /v1/voice/token`.
3. The API mints a LiveKit JWT with a room grant **and** a room configuration
   that dispatches the `serene-voice` agent. The API keeps no session state.
4. The agent reads the call metadata, builds the system prompt, and starts
   `AgentSession(..., record=False)`.
5. Audio flows: Silero VAD → faster-whisper → Qwen3 → Kokoro/SILMA → room.
6. The agent publishes small JSON messages on topic `serene.voice`
   (`ready`, `state`, `transcript`, `crisis`, `error`).
7. Hanging up closes the room; the worker exits and clients are released.

### Crisis handling

Before the LLM answers, `app/safety.py` runs a transparent multilingual regex
over the final transcript. On a match the agent:

* publishes `{"type":"crisis"}` so the app opens the hotline sheet,
* speaks a fixed, reviewed safety line instead of an improvised reply,
* raises `StopResponse` so the model's answer is discarded.

This is a safety net, not a clinical classifier. The app keeps its own
on-device detector and an always-available emergency button.

---

## Security model

* **Device authentication, not user accounts.** A random per-install id and
  secret; the server stores only `sha256(secret)`. Anyone with an unlocked
  phone can start a call. This stops anonymous internet clients from minting
  tokens, nothing more.
* **Short-lived tokens.** 10 minutes by default, one room, publish/subscribe
  only, no room admin.
* **No placeholder secrets.** The API refuses to start if
  `LIVEKIT_API_SECRET` is empty, shorter than 32 characters, or one of the
  values published in this repository (`secret`, `devkey`,
  `change-me-please-use-a-long-random-string`). `docker-compose.yml` also
  requires both LiveKit values to be present instead of defaulting them.
* **No secrets in Flutter.** The app never sees `LIVEKIT_API_SECRET` or any
  model credential.
* **Rate limits.** Enrolment is limited per IP; token issuance per device.
  Both are in-memory, so they are per-replica.
* **Transport.** WebRTC media is encrypted with DTLS-SRTP even over `ws://`.
  Signalling and the token API are **plaintext** on a LAN. For internet use,
  terminate TLS in front of both (see *Production*).

### Privacy

* `record=False` is passed explicitly. The Agents SDK otherwise records audio
  and transcripts for debugging.
* No audio is written to disk. STT decodes the request body in memory.
* No transcript is logged. A redaction filter plus explicit logging keep only
  duration, language, segment count, character count and timing.
* SILMA's upstream code prints every text chunk to stdout; the TTS server
  redirects stdout to `/dev/null` around inference for that reason.
* The agent does not persist conversation history between calls. Only the
  memories held in the app's current session are sent, and only when enabled in
  the app. The app itself keeps no personal data on disk: memories, profile,
  moods and journal live in RAM and vanish when the app closes.
* LiveKit itself does not record unless you configure egress.

---

## Production

1. **TLS.** Put Caddy or nginx in front of LiveKit and the API:
   * `https://voice.example.com` → `api:8788`
   * `wss://rtc.example.com` → `livekit:7880`
   Set `LIVEKIT_URL=wss://rtc.example.com` and use the HTTPS API base URL in
   the app.
2. **Firewall.** Expose only 443 (proxy), 7881/tcp and 7882–7892/udp. Never
   expose 8001, 8002 or 11434.
3. **Enrolment code.** Set `SERENE_ENROLLMENT_CODE` before going public, or
   anyone who finds the URL can enrol.
4. **Secret rotation.** Rotating `LIVEKIT_API_SECRET` invalidates outstanding
   tokens but not enrolled devices. Rotating `SERENE_ENROLLMENT_CODE` does not
   remove existing devices; delete rows from `devices.sqlite3` to revoke.
5. **Backups.** The only state is `api-data/devices.sqlite3`.
6. **Logs.** Keep `SERENE_ENV=prod`; it prevents the Agents SDK from emitting
   transcript-level logs.

### Free hosting limits

There is no free public host that gives you a GPU, a public IP and UDP media
ports. Options that actually work:

* your own machine + a free tunnel for the API only (Cloudflare Tunnel) **does
  not** carry WebRTC media;
* a free-tier VM has no GPU and will not run this at conversational latency;
* Oracle Cloud's free ARM tier can run LiveKit and the API, but not the models.

So "free hosting" here means "the computer you already own". That is the honest
trade-off.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| App says "cannot reach voice service" | `LIVEKIT_URL` is `127.0.0.1`, or the API is not reachable from the phone |
| Connects, then drops after ~10 s | UDP 7882–7892 blocked; LiveKit fell back to TCP 7881, which is also blocked |
| Agent joins but never speaks | check `docker compose logs agent`; usually TTS returned 503 |
| First turn takes 5–10 s | Qwen3 cold load; send one warm-up message or raise `OLLAMA_KEEP_ALIVE` |
| Arabic replies are silent | SILMA checkpoint missing; `curl localhost:8002/healthz` |
| French TTS 503 | `espeak-ng` missing |
| Transcript is empty | Whisper heard silence; check mic permission and the VAD threshold |
| `pynini` will not install | it is Linux-only; use Docker or WSL for Arabic TTS |

Logs:

```bash
docker compose logs -f api agent stt tts
```

---

## Tests

```bash
cd voice_backend
python -m pytest -q
```

The suite covers the crisis detector, prompt construction and bounding, device
enrolment/authentication/rate limiting, token claims (grants, agent dispatch,
TTL), API payload bounding, and STT/TTS helper functions. It does not load
Whisper, Kokoro or SILMA.

---

## Tested vs. untested (honest report)

**Tested in this environment (Windows, no GPU, no Docker daemon):**

* All Python modules compile.
* 95 unit tests pass: safety, prompts, auth, tokens, API bounding, STT/TTS
  helpers, and the configuration guard that rejects placeholder LiveKit
  secrets.
* Token minting verified against `livekit-api` 1.2.2: room grant, agent
  dispatch metadata, 600 s TTL, no secret in the payload.
* LiveKit Agents 1.8.10 and `livekit-plugins-openai` 1.8.10 signatures were
  read from the published wheels and the agent uses exactly those parameters
  (`STT(model, language, use_realtime, client)`,
  `TTS(model, voice, response_format, sample_rate, client)`,
  `AgentSession.start(..., record=False)`).
* The OpenAI-compatible contracts were verified against the plugin source:
  STT requests `verbose_json` for `whisper-1`; TTS requests `pcm` at 24 kHz and
  treats `audio/pcm` as raw int16.

**Not tested here — must be verified on your machine:**

* Docker image builds (torch, CUDA wheels, NeMo/pynini).
* Actual Whisper transcription accuracy in any language.
* Actual Kokoro and SILMA audio quality and latency.
* The SILMA Derja checkpoint loading path. The upstream `SilmaTTS` ignores its
  checkpoint argument, so this repo mirrors `load_model`/`load_vocoder`
  directly; that path has not been executed against the 650 MB Derja file.
* End-to-end call latency on an 8 GB GPU.
* Real Android device behaviour (mic permission, Bluetooth, echo).
* Network-loss recovery, LiveKit reconnection, and simultaneous calls.

Run `scripts/smoke_test.py` first; it isolates STT, TTS and token problems
before you debug the phone.
