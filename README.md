# Serene (سكينة) – 100% Free, Private AI Mental Wellness Companion

> **"You do not have to carry this alone."**

Serene (**سكينة**) is an open-source, zero-knowledge, empathetic mental wellness companion designed to support people experiencing anxiety, depression, loneliness, grief, and emotional overwhelm. Initially available on Android in **Arabic (العربية)**, **French (Français)**, and **English**, Serene acts as a calm, trusted, non-judgmental presence in the user's pocket.

---

## 🌟 Key Features

### 1. Empathetic, Non-Clinical AI Companion
- **Active Listening & Warmth**: Grounded in active reflection, gentle CBT cognitive reframing, and supportive validation.
- **Natural Dialect Fluency**: Supports Modern Standard Arabic as well as regional dialects (Tunisian / North African Derja, Egyptian, Levantine, Gulf) and Arabizi (Latin script Arabic), French, and English.
- **Strict Clinical Boundaries**: Never pretends to be a therapist, psychiatrist, or medical doctor. Never diagnoses or prescribes. Gently encourages human relationships and professional therapy.

### 2. Rigorous Dual-Layer Crisis Safety Net
- **Layer 1 (Instant On-Device Regex)**: Detects explicit/implicit suicide or self-harm keywords across English, French, Arabic dialects, and Arabizi. Immediately presents a scripted, non-LLM emergency sheet.
- **Layer 2 (Backend Model Safety Classifier)**: If subtle, veiled crisis indicators escape regex, the server tags the response with `[[CRISIS]]` so the client triggers the safety modal.
- **Multi-Country Hotlines**: Verified numbers for Tunisia (SAMU 190), Algeria, Morocco, Egypt, Saudi Arabia, UAE, Lebanon (Embrace 1564), Jordan, Qatar, France (3114), Belgium, Switzerland, Canada (988), USA (988), UK (116 123), and International directories (findahelpline.com).
- **Emergency Trusted Contact**: Users can save a personal loved one or therapist in encrypted storage for one-tap emergency calling.

### 3. Absolute Privacy & Zero-Knowledge Architecture
- **In-RAM Ephemeral Chats**: Chat logs are never stored in SQLite, shared preferences, or local disk. Closing the session clears the chat history.
- **Android Keystore Encryption**: Memories, mood entries, trusted contact details, and journal reflections are encrypted on-device via `flutter_secure_storage`.
- **Zero-Retention Backend**: The backend proxy forwards chat requests to the LLM and does not log, save, or retain any prompt content or user transcripts.
- **Quick Privacy Shield**: A one-tap shield button instantly masks the screen with a calm, neutral quote—vital for users in non-private living situations.

### 4. Offline Self-Help & Regulation Toolkit
- **Guided Breathing Studio**:
  - *Calming Pace (4-6)*: Parasympathetic nervous system activation.
  - *Box Breathing (4-4-4-4)*: Acute panic and shock reduction.
  - *Deep Rest (4-7-8)*: Insomnia and racing thoughts relief.
- **5-4-3-2-1 Sensory Grounding**: Step-by-step interactive tool to break out of panic attacks and dissociation.
- **Mood Check-ins**: 5-point rating with contextual tags (`#anxiety`, `#burnout`, `#relationships`, `#sleep`) and a 14-day history chart.
- **Private Journal**: Encrypted notes with reflective prompts ("What weighed on you today?", "What brought a sliver of peace?").

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `>= 3.3.0`
- Node.js `>= 18` (for the backend proxy)
- Android SDK (minSdk 23)

### Running the Backend Proxy
```bash
cd backend
npm install
ANTHROPIC_API_KEY="sk-ant-..." PORT=8787 node server.js
```

### Running the Android Client
```bash
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8787/chat
```
*(Use `http://10.0.2.2:8787/chat` on the Android Emulator or your local network IP on physical devices).*

### Testing & Linting
```bash
flutter test
flutter analyze
```

---

## 🛡️ Clinical & Legal Checklist Before Public Release

1. **Hotline Verification**: Periodically re-verify every telephone number and NGO hotline in `lib/safety.dart` with local health ministries and non-profits.
2. **Clinical Adversarial Testing**: Conduct red-teaming with licensed mental health professionals to test corner cases in Arabizi and local colloquialisms.
3. **Data Protection & Legal Compliance**: Ensure the user-facing consent notice adheres to GDPR, local privacy laws, and medical disclaimer requirements.

---

## 🤝 Open Source & Ethical Mission

Serene is built to remain **100% free forever** for anyone in emotional pain. We welcome clinicians, developers, translators, and privacy researchers to contribute to the mission.
