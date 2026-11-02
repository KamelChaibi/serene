/// Build-time feature switches.
///
/// Voice calls are fully implemented — `live_voice_service.dart`,
/// `live_voice_call_screen.dart`, `voice_settings.dart` and the matching
/// `voice_backend/` — but hidden from the interface for now: the self-hosted
/// stack needs an NVIDIA GPU with at least 8 GB of VRAM, which the current
/// development machine does not have.
///
/// Flip this to `true` to bring back the call button in the app bar, the
/// call button on the empty chat screen, and the voice settings tile. No
/// other change is needed; backend setup is documented in
/// `voice_backend/README.md`.
const bool voiceCallsVisible = false;
