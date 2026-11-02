# Serene – 100% Free, Private AI Mental Wellness Companion

> *"You do not have to carry this alone."*

[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](#-download)
[![Languages](https://img.shields.io/badge/Languages-Arabic%20%7C%20French%20%7C%20English-blue)](#-key-features)
[![Privacy](https://img.shields.io/badge/Privacy-Zero--Knowledge%20%7C%20In--RAM-6f42c1)](#3-absolute-privacy--zero-knowledge-architecture)
[![License](https://img.shields.io/badge/License-Open%20Source-lightgrey)](#-open-source--ethical-mission)

**Serene** is an open-source, zero-knowledge, empathetic mental wellness companion designed to support people experiencing anxiety, depression, loneliness, grief, and emotional overwhelm.

It is currently available for **Android** in **Arabic (العربية)**, **French (Français)**, and **English** — with **French** set as the default first-run language. Serene aims to be a calm, trusted, and non-judgmental presence right in your pocket.

**➡️ [Download the latest Android APK](#-download)**

---

## 📥 Download

### Android APK

[![Download Serene v1.0.0 APK](https://img.shields.io/badge/Download-Serene%20v1.0.0%20APK-2EA44F?style=for-the-badge&logo=android&logoColor=white)](https://github.com/KamelChaibi/serene/releases/download/v1.0.0/Serene-v1.0.0.apk)

Can't use the button? [Download `Serene-v1.0.0.apk` directly](https://github.com/KamelChaibi/serene/releases/download/v1.0.0/Serene-v1.0.0.apk).

| Info | Details |
| --- | --- |
| **File** | `Serene-v1.0.0.apk` |
| **Version** | `1.0.0` |
| **Size** | ~90.2 MB |
| **Minimum Android** | 7.0 (API 24) |
| **Internet** | Required for AI chat; offline tools work without a connection |
| **Distribution** | Direct APK (sideload) |
| **PWA** | Not available at this time |

### Installation Instructions

1. Download the APK from the button above.
2. On your Android device, open the downloaded file from your Files app or browser.
3. If prompted, allow installation from your browser/file manager (`Settings > Apps > [App Name] > Install unknown apps`).
4. Tap **Install** and launch **Serene**.

> **Note:** Serene is not currently published on the Google Play Store. You can always find the latest official releases on the [GitHub Releases page](https://github.com/KamelChaibi/serene/releases).

---

## 📖 Contents

- [Download](#-download)
- [Key Features](#-key-features)
- [Build from Source](#-build-from-source)
- [Voice Calls (Self-Hosted)](#-voice-calls-self-hosted)
- [Tested vs. Untested](#-tested-vs-untested-honest-report)
- [Clinical & Legal Checklist](#-clinical--legal-checklist-before-public-release)
- [Open Source & Ethical Mission](#-open-source--ethical-mission)

---

## 🌟 Key Features

### 1. Empathetic, Non-Clinical AI Companion
- **Gentle First Hello**: A short onboarding asks for an optional name, a birthday (to derive age — the date itself never leaves the phone), preferred tone, reply length, and what the person wants support with. The AI adapts how it speaks accordingly, and every answer — plus light or dark appearance — can be changed later in settings.
- **A Warm Return**: A branded Serene splash opens the app, and returning users are greeted by name while their profile loads (never above the PIN lock screen).
- **Active Listening & Warmth**: Grounded in active reflection, gentle CBT cognitive reframing, and supportive validation.
- **Natural Dialect Fluency**: Supports Modern Standard Arabic as well as regional dialects (Tunisian / North African Derja, Egyptian, Levantine, Gulf) and Arabizi (Latin script Arabic), French, and English.
- **Real-Time Replies**: Answers stream token-by-token as the model writes them, with a fast direct fallback when the backend proxy is unavailable, so the conversation never feels stalled.
- **Hands-Free Voice Call** *(implemented, currently hidden in the UI)*: A full-screen, full-duplex call lets people talk instead of type. Serene greets them, listens, and answers out loud with natural prosody, and the user can interrupt her mid-sentence just by speaking. Mute, explicit interrupt, captions, live connection status, and a crisis hotline sheet are all one tap away. Speech recognition and speech synthesis run on **your own server** (faster-whisper, Qwen3, Kokoro/SILMA) - no cloud voice API and no per-minute fee. It is switched off in `lib/features.dart` (`voiceCallsVisible = false`) because the stack needs an 8 GB GPU; set it to `true` and follow [Voice calls](#-voice-calls-self-hosted) to bring it back.
- **Strict Clinical Boundaries**: Never pretends to be a therapist, psychiatrist, or medical doctor. Never diagnoses or prescribes. Gently encourages human relationships and professional therapy.

### 2. Rigorous Dual-Layer Crisis Safety Net
- **Layer 1 (Instant On-Device Regex)**: Detects explicit/implicit suicide or self-harm keywords across English, French, Arabic dialects, and Arabizi. Immediately presents a scripted, non-LLM emergency sheet.
- **Layer 2 (Backend Model Safety Classifier)**: If subtle, veiled crisis indicators escape regex, the server tags the response with `[[CRISIS]]` so the client triggers the safety modal.
- **Multi-Country Hotlines**: Verified numbers for Tunisia (SAMU 190), Algeria, Morocco, Egypt, Saudi Arabia, UAE, Lebanon (Embrace 1564), Jordan, Qatar, France (3114), Belgium, Switzerland, Canada (988), USA (988), UK (116 123), and International directories (findahelpline.com).
- **Emergency Trusted Contact**: Users can save a personal loved one or therapist for one-tap emergency calling; the contact lives in memory for the current session only.

### 3. Absolute Privacy & Zero-Knowledge Architecture
- **In-RAM Ephemeral Chats**: Chat logs are never stored in SQLite, shared preferences, or local disk. Closing the session clears the chat history.
- **Personal Data Never Touches Disk**: Memories, mood entries, trusted contact details, journal reflections, your personalization profile and the PIN are held in a plain in-memory map and are never written to the phone. Closing the app erases them — there is no file to recover and no "delete my data" step to forget. Only non-personal preferences persist: language, theme, reminder schedule, and the first-run consent/onboarding flags (see the `persistedKeys` allowlist in `lib/storage.dart`).
- **What that means day to day**: after a cold start, memories, moods, journal entries and the profile are empty, so personalisation has to be entered again — that is the price of not storing it. The language, theme and reminder schedule survive. Data written by older versions of the app is deleted at start-up. "In RAM" means exactly that: swiping the app away or an Android process kill clears everything, while merely backgrounding it keeps the current session alive.
- **Zero-Retention Backend**: The text backend proxy forwards chat requests to the LLM and does not log, save, or retain any prompt content or user transcripts.
- **Voice Is Never Recorded**: During a call the microphone streams to *your own* LiveKit server, where the self-hosted agent transcribes it in memory. `record=False` is set explicitly on the agent session, no audio is written to disk, and no transcript is logged. The agent keeps no history between calls; only the memories the user chose to store are sent, and only when memories are enabled. Captions are shown for the current call and then discarded.
- **Quick Privacy Shield**: A one-tap shield button instantly masks the screen with a calm, neutral quote—vital for users in non-private living situations.

### 4. Offline Self-Help & Regulation Toolkit
- **Guided Breathing Studio**:
  - *Calming Pace (4-6)*: Parasympathetic nervous system activation.
  - *Box Breathing (4-4-4-4)*: Acute panic and shock reduction.
  - *Deep Rest (4-7-8)*: Insomnia and racing thoughts relief.
- **5-4-3-2-1 Sensory Grounding**: Step-by-step interactive tool to break out of panic attacks and dissociation.
- **Mood Check-ins**: 5-point rating with contextual tags (`#anxiety`, `#burnout`, `#relationships`, `#sleep`) and a 14-day history chart, kept for the current session.
- **Private Journal**: In-memory notes with reflective prompts ("What weighed on you today?", "What brought a sliver of peace?").

---

## 🛠️ Build from Source

### Prerequisites
- Flutter SDK `>= 3.4.0`
- Node.js `>= 18` (for the text chat proxy)
- Android SDK (minSdk 24)
- For voice calls: an NVIDIA GPU (8 GB+), Docker, and the `voice_backend` stack

> Voice calls are **not** on-device. They need the self-hosted backend in
> [`voice_backend/`](voice_backend/README.md); see
> [Voice calls](#-voice-calls-self-hosted) below.

### Running the Backend Proxy
```bash
cd backend
npm install
ANTHROPIC_API_KEY="sk-ant-..." PORT=8787 node server.js
```

### Running the Android Client
```bash
flutter pub get
flutter run \
  --dart-define=API_URL=http://10.0.2.2:8787/chat \
  --dart-define=VOICE_API_URL=http://10.0.2.2:8788
```
*(Use `http://10.0.2.2:...` on the Android Emulator or your host's LAN IP on a physical device. Once voice calls are enabled with `voiceCallsVisible`, the address can also be changed at runtime in **Settings → Voice call settings**.)*

### Building the Release APK

The distributed APK is a standard Flutter release build. Point `API_URL` at your
production text-chat proxy, then build:

```bash
flutter build apk --release \
  --dart-define=API_URL=https://your-backend.example/chat
```

The universal APK is written to
`build/app/outputs/flutter-apk/app-release.apk`. Rename it to
`Serene-v<version>.apk`, verify it on a physical device, and attach it to a
GitHub Release so the download link above stays valid.

> Release builds require a signing configuration. See the
> [Flutter deployment guide](https://docs.flutter.dev/deployment/android#signing-the-app)
> if `android/key.properties` is not yet set up for your environment.

### Web build (not currently distributed)

The repository contains a Flutter web target, but **Serene is not distributed as a
PWA at this time**. The supported end-user build is the Android APK above.

Developers can still run the web target locally for UI work:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:8787/chat
```

The web target is not an officially supported release channel, so no installation
or hosting instructions are provided here.

### Testing & Linting
```bash
flutter test
flutter analyze
```

---

## 🎙️ Voice calls (self-hosted)

> **Hidden by default.** The client and backend are complete, but the call
> button and voice settings are gated behind `voiceCallsVisible` in
> [`lib/features.dart`](lib/features.dart). It is `false` because the stack
> needs an NVIDIA GPU with 8 GB+ VRAM. Set it to `true`, rebuild, and follow
> [`voice_backend/README.md`](voice_backend/README.md) to enable calls.

```
 Android app ──WebRTC──▶ LiveKit server ◀──WebRTC── LiveKit Agents worker
      │                      ▲                         │
      │  HTTP: token         │                         ├─▶ STT  (faster-whisper)
      └──────────────────────┴─ FastAPI API            ├─▶ LLM  (Ollama / Qwen3)
                                                       └─▶ TTS  (Kokoro / SILMA)
```

The phone never holds an API secret and never calls a model directly. It
enrols once, receives a **10-minute LiveKit token**, joins a room, and streams
microphone audio. The agent worker joins the same room and runs
VAD → STT → LLM → TTS. Nothing is billed per minute; the only recurring cost is
the electricity used by your own GPU.

### What you need to run

| Piece | Where |
|---|---|
| Flutter app | this repo |
| LiveKit server, FastAPI API, LiveKit agent, STT, TTS, Ollama | [`voice_backend/`](voice_backend/README.md) |

**Three different things are called "free", so be precise about which one you
get:** the *software* is free and open source (LiveKit, Whisper, Qwen3, Kokoro,
SILMA, this app); there is *no free hosted service* that will run a GPU voice
pipeline for you, and free tunnels cannot carry WebRTC media; the *hardware* is
yours to own, and the only recurring cost is electricity. A realistic floor is
an NVIDIA GPU with 8 GB of VRAM, which fits the `low_vram` profile — one call at
a time.

Follow [`voice_backend/README.md`](voice_backend/README.md) for the Docker
quick start, model downloads, VRAM profiles, and production/TLS notes. In
short:

```bash
cd voice_backend
cp .env.example .env          # set LIVEKIT_URL to your host's LAN IP, not 127.0.0.1
python scripts/download_models.py --profile low_vram
docker compose up -d --build
docker compose exec ollama ollama pull qwen3:4b
python scripts/smoke_test.py --api http://127.0.0.1:8788
```

Then enable voice calls (`voiceCallsVisible = true` in `lib/features.dart`
and rebuild), open **Settings → Voice call settings** (address, optional
enrolment code, call language, captions) and press **Test connection** before
starting a call.

### Languages

| Language | Speech recognition | Voice |
|---|---|---|
| English | faster-whisper | Kokoro `af_heart` |
| French | faster-whisper | Kokoro `ff_siwis` (needs `espeak-ng`) |
| Arabic (MSA) | faster-whisper | SILMA TTS v1 (Apache-2.0) |
| Tunisian Derja | faster-whisper (falls back to MSA recognition) | SILMA Derja fine-tune (CC-BY-NC-4.0), or SILMA MSA if the checkpoint is absent |

Serene answers in the language you speak. Whisper detects the language per
utterance, but the app also sends a preferred language so short or noisy turns
do not get misidentified. **Tunisian Derja is the weakest link**: Whisper has no
dedicated Derja mode, so recognition leans on MSA and code-switching, and the
Derja voice is a community fine-tune that is licensed for non-commercial use
only. Expect it to be noticeably less reliable than English or French. Test STT
and TTS separately (`scripts/smoke_test.py`) before blaming the app.

### Personality

The AI's identity, tone rules, per-language directives, greetings, and safety
lines live in [`voice_backend/prompts/serene_friend.yaml`](voice_backend/prompts/serene_friend.yaml),
**not in the Flutter code**. Edit it and restart the `agent` container; no app
rebuild is needed. Serene is written to be a warm, casual close friend who
gives short, human replies, remembers the current conversation, and never
claims to be a human or a therapist.

### Security and privacy

* Per-install device enrolment: a random id plus a 32-byte secret kept in
  Android Keystore-backed storage; the server stores only `sha256(secret)`.
  This is device authentication, not a user identity — anyone with an unlocked
  phone can start a call. It is the only credential the app persists; no
  personal content is stored alongside it.
* Short-lived tokens (10 min), one room, no admin grant. `LIVEKIT_API_SECRET`
  never reaches the app.
* No audio recording, no transcript logging, no conversation persistence
  between calls.
* The microphone is muted automatically when the app goes to the background.
* The token API is plaintext HTTP on a LAN, which is why the app permits
  cleartext (see `android/app/src/main/res/xml/network_security_config.xml`).
  Put the backend behind HTTPS before exposing it to the internet.

### Known security debt in the existing text chat (unchanged)

`lib/chat_service.dart` still ships a default `OPENROUTER_API_KEY` value and a
direct-OpenRouter streaming fallback. A key compiled into an APK can be
extracted, so treat that key as public: rotate it, and prefer routing text chat
through the proxy with `--dart-define=API_URL=...`. This was left as-is to
avoid changing unrelated behaviour, and it does not affect the voice path,
which never uses a client-side key.

---

## ✅ Tested vs. untested (honest report)

**Verified in the development environment (Windows 11, no GPU, no Docker daemon, no physical Android device):**

* `flutter analyze` — clean, no issues.
* `flutter test` — **61 tests pass**, including the new voice tests (server-URL and language normalisation, token-expiry handling, the agent data protocol, localisation completeness for every voice string in English/French/Arabic, and widget tests for "connect → reply appears → end call", "microphone denied shows instructions", "a dropped call offers a retry", and "connected but no agent answers"), storage tests proving that personal keys never reach the secure-storage plugin, that the allowlisted preferences do, that a wipe clears both while keeping the voice enrolment, that a legacy profile left on disk is never displayed, that old personal keys are purged at start-up, and that a first launch in French points hotlines at France, plus a test that the hidden voice-call entry points stay out of the chat UI.
* `flutter build apk --debug` — builds a real APK with `livekit_client` 2.13.2 and `permission_handler` 12.0.3.
* The merged Android manifest contains `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `INTERNET`, `ACCESS_NETWORK_STATE`, `BLUETOOTH`/`BLUETOOTH_CONNECT`, and the network security config.
* `voice_backend` — all modules compile and **95 unit tests pass** (crisis regexes, prompt building and bounding, device enrolment/authentication/rate limits, token claims and agent dispatch, API payload bounding, STT/TTS helpers, and the startup guard that refuses placeholder LiveKit secrets).
* The LiveKit Agents and plugin call signatures, the OpenAI-compatible STT/TTS request shapes, and the `livekit-api` JWT claim names were checked against the published package sources rather than assumed.

**Not verified here — you must confirm these on your own hardware:**

* Any real Android device: microphone permission flow, echo cancellation, Bluetooth routing, speaker/earpiece switching, and behaviour on a real cellular network.
* An end-to-end call through LiveKit: room join, agent dispatch, barge-in/interruption, and reconnection after network loss.
* Actual STT accuracy and TTS quality or latency for English, French, MSA, and Derja.
* Docker image builds (CUDA/torch/NeMo/pynini), the SILMA Derja checkpoint loader, and GPU memory fit on an 8 GB card.
* Concurrent calls, and any deployment behind TLS on the public internet.

The `voice_backend` README repeats this split from the server's point of view; both lists are deliberately pessimistic rather than optimistic.

---

## 🛡️ Clinical & Legal Checklist Before Public Release

1. **Hotline Verification**: Periodically re-verify every telephone number and NGO hotline in `lib/safety.dart` with local health ministries and non-profits.
2. **Clinical Adversarial Testing**: Conduct red-teaming with licensed mental health professionals to test corner cases in Arabizi and local colloquialisms.
3. **Data Protection & Legal Compliance**: Ensure the user-facing consent notice adheres to GDPR, local privacy laws, and medical disclaimer requirements.

---

## 🤝 Open Source & Ethical Mission

Serene is built to remain **100% free forever** for anyone in emotional pain. We welcome clinicians, developers, translators, and privacy researchers to contribute to the mission.
