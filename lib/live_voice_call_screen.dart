import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'chat_service.dart';
import 'crisis_sheet.dart';
import 'l10n.dart';
import 'live_voice_service.dart';
import 'profile.dart';
import 'voice_api.dart';

/// Result of asking for microphone access. Injectable so widget tests never
/// touch a platform channel.
class MicPermissionResult {
  final bool granted;
  final bool permanentlyDenied;

  const MicPermissionResult({
    required this.granted,
    this.permanentlyDenied = false,
  });
}

typedef RequestMicrophone = Future<MicPermissionResult> Function();

/// A real-time voice call with Serene.
///
/// Audio is full duplex: the microphone stays open and the agent decides when
/// the user has finished a turn. That makes the call feel like a phone call
/// rather than a walkie-talkie. The user can still mute, interrupt, or hang up.
///
/// Nothing is recorded on the phone. Audio is sent over WebRTC to the user's
/// own LiveKit server, where the self-hosted agent transcribes and answers it.
class LiveVoiceCallScreen extends StatefulWidget {
  /// Live chat history. Final call turns are appended so the conversation
  /// continues in the text tab when the call ends.
  final List<Msg> conversation;
  final Profile profile;
  final List<String> memories;

  /// The app's current language code (`en`, `fr`, `ar`). A voice-specific
  /// override in the settings screen takes precedence.
  final String appLanguage;

  /// Injectable for tests; the real screen creates its own service.
  final LiveVoiceService? service;
  final VoiceApi? api;

  /// Injectable for tests; defaults to the Android microphone prompt.
  final RequestMicrophone? requestMicrophone;

  const LiveVoiceCallScreen({
    super.key,
    required this.conversation,
    required this.profile,
    required this.memories,
    required this.appLanguage,
    this.service,
    this.api,
    this.requestMicrophone,
  });

  @override
  State<LiveVoiceCallScreen> createState() => _LiveVoiceCallScreenState();
}

class _LiveVoiceCallScreenState extends State<LiveVoiceCallScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _backdrop = Color(0xFF0F1513);
  static const _accent = Color(0xFF7FBFAE);
  static const _coreStart = Color(0xFF3F7F71);
  static const _coreEnd = Color(0xFF2A5A50);

  late final LiveVoiceService _voice = widget.service ?? LiveVoiceService();
  late final VoiceApi _api = widget.api ?? VoiceApi();
  late final AnimationController _pulse;

  bool _bootstrapped = false;
  bool _starting = true;
  bool _ended = false;
  bool _micDenied = false;
  bool _permanentlyDenied = false;
  bool _showCaptions = true;
  bool _userMuted = false;
  bool _backgroundMuted = false;
  bool _crisisSheetOpen = false;
  bool _agentMissing = false;
  String? _failureMessage;
  String _lastTranscriptKey = '';
  Timer? _agentWatchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _voice.addListener(_onVoiceChanged);
    _voice.onCrisis = _onCrisis;
    _voice.onFinalTranscript = _onFinalTranscript;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    unawaited(_bootstrap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A microphone left open in the background would be both unsettling and
    // battery-hungry. Mute on the way out and restore on the way back in.
    if (state == AppLifecycleState.resumed) {
      if (_backgroundMuted) {
        _backgroundMuted = false;
        if (!_userMuted) unawaited(_voice.setMuted(false));
      }
      return;
    }
    if (!_voice.muted && !_ended) {
      _backgroundMuted = true;
      unawaited(_voice.setMuted(true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ended = true;
    _agentWatchdog?.cancel();
    _pulse.dispose();
    _voice.removeListener(_onVoiceChanged);
    _voice.onCrisis = null;
    _voice.onFinalTranscript = null;
    if (widget.service == null) {
      _voice.dispose();
    } else {
      unawaited(_voice.disconnect());
    }
    if (widget.api == null) _api.close();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (_agentMissing && _voice.agentReady) {
      _agentWatchdog?.cancel();
      _agentMissing = false;
    }
    if (mounted) setState(() {});
  }

  /// A connected room with no agent looks exactly like a call where nobody
  /// answers. After 25 seconds, say so instead of leaving the user waiting.
  void _startAgentWatchdog() {
    _agentWatchdog?.cancel();
    _agentWatchdog = Timer(const Duration(seconds: 25), () {
      if (!mounted || _ended) return;
      if (_voice.agentReady) return;
      setState(() => _agentMissing = true);
    });
  }

  Future<MicPermissionResult> _requestMicrophone() async {
    final status = await Permission.microphone.request();
    return MicPermissionResult(
      granted: status.isGranted,
      permanentlyDenied: status.isPermanentlyDenied,
    );
  }

  Future<void> _bootstrap() async {
    final s = S.of(context);

    _showCaptions = await _api.captionsEnabled();
    if (!mounted) return;

    final permission = await (widget.requestMicrophone ?? _requestMicrophone)();
    if (!mounted) return;
    if (!permission.granted) {
      setState(() {
        _starting = false;
        _micDenied = true;
        _permanentlyDenied = permission.permanentlyDenied;
      });
      return;
    }

    try {
      final language = await _api.callLanguage(widget.appLanguage);
      final session = await _api.ensureSession(
        language: language,
        profile: widget.profile,
        memories: widget.memories,
      );
      if (!mounted || _ended) return;
      await _voice.connect(session);
      if (!mounted) return;
      setState(() => _starting = false);
      _startAgentWatchdog();
    } on VoiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _failureMessage = _messageFor(s, error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _failureMessage = s.t('voiceError');
      });
    }
  }

  String _messageFor(S s, VoiceException error) {
    switch (error.kind) {
      case VoiceErrorKind.network:
        return s.t('voiceUnavailable');
      case VoiceErrorKind.unauthorized:
        return s.t('voiceAuthFailed');
      case VoiceErrorKind.rateLimited:
        return s.t('voiceRateLimited');
      case VoiceErrorKind.config:
        return s.t('voiceNotConfigured');
      case VoiceErrorKind.server:
        return s.t('voiceError');
    }
  }

  Future<void> _retry() async {
    if (_ended) return;
    _agentWatchdog?.cancel();
    setState(() {
      _starting = true;
      _micDenied = false;
      _permanentlyDenied = false;
      _agentMissing = false;
      _failureMessage = null;
    });
    await _bootstrap();
  }

  void _onCrisis() {
    if (!mounted || _ended || _crisisSheetOpen) return;
    _crisisSheetOpen = true;
    unawaited(
      showVoiceCrisisSheet(context, S.of(context), onEnd: _end).whenComplete(() {
        _crisisSheetOpen = false;
      }),
    );
  }

  void _onFinalTranscript(String role, String text) {
    if (role != 'user' && role != 'assistant') return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final key = '$role:$trimmed';
    if (key == _lastTranscriptKey) return;
    _lastTranscriptKey = key;
    widget.conversation.add(Msg(role, trimmed));
  }

  Future<void> _toggleMicrophone() async {
    if (_ended || _starting) return;
    final next = !_voice.muted;
    _userMuted = next;
    await _voice.setMuted(next);
  }

  Future<void> _toggleCaptions() async {
    final next = !_showCaptions;
    setState(() => _showCaptions = next);
    await _api.setCaptionsEnabled(next);
  }

  Future<void> _tapStage() async {
    if (_ended || _starting || _micDenied || _failureMessage != null) return;
    if (_voice.state == LiveVoiceState.speaking) {
      await _voice.interrupt();
    }
  }

  void _end() {
    if (_ended) return;
    setState(() => _ended = true);
    unawaited(_voice.disconnect());
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  String _status(S s) {
    if (_starting) return s.t('voiceConnecting');
    if (_micDenied) return s.t('voicePermissionDenied');
    if (_failureMessage != null) return _failureMessage!;
    if (_agentMissing && !_voice.agentReady) return s.t('voiceAgentMissing');
    switch (_voice.state) {
      case LiveVoiceState.connecting:
        return s.t('voiceConnecting');
      case LiveVoiceState.listening:
        return s.t('voiceListening');
      case LiveVoiceState.thinking:
        return s.t('voiceThinking');
      case LiveVoiceState.speaking:
        return s.t('voiceSpeaking');
      case LiveVoiceState.idle:
        return s.t('voiceReady');
      case LiveVoiceState.reconnecting:
        return s.t('voiceReconnecting');
      case LiveVoiceState.ended:
        return s.t('voiceEnded');
      case LiveVoiceState.failed:
        return s.t('voiceError');
    }
  }

  IconData _coreIcon() {
    if (_micDenied || _failureMessage != null) return Icons.cloud_off_rounded;
    switch (_voice.state) {
      case LiveVoiceState.listening:
        return Icons.graphic_eq_rounded;
      case LiveVoiceState.speaking:
        return Icons.volume_up_rounded;
      case LiveVoiceState.thinking:
        return Icons.spa_rounded;
      case LiveVoiceState.reconnecting:
        return Icons.wifi_tethering_error_rounded;
      case LiveVoiceState.failed:
      case LiveVoiceState.ended:
        return Icons.call_end_rounded;
      case LiveVoiceState.connecting:
        return Icons.hourglass_top_rounded;
      case LiveVoiceState.idle:
        return Icons.spa_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final speaking = _voice.state == LiveVoiceState.speaking;
    final active = speaking || _voice.state == LiveVoiceState.listening;
    final hasError = _micDenied ||
        _failureMessage != null ||
        _voice.state == LiveVoiceState.failed;

    return Scaffold(
      backgroundColor: _backdrop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.18),
            radius: 1.05,
            colors: [Color(0xFF1E322C), Color(0xFF0F1513)],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(s),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasError)
                          _errorCard(s)
                        else ...[
                          GestureDetector(
                            onTap: _tapStage,
                            behavior: HitTestBehavior.opaque,
                            child: _stage(active: active, speaking: speaking),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _status(s),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (_showCaptions) _captions(s),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _controls(s),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  s.t('voicePrivacyNote'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: s.t('voiceEnd'),
            onPressed: _ended ? null : _end,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Serene',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                _connectionPill(s),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _connectionPill(S s) {
    final Color color;
    final String label;
    if (_starting || (!_voice.connected && !_voice.reconnecting)) {
      color = Colors.white.withValues(alpha: 0.45);
      label = s.t('voiceConnecting');
    } else if (_voice.reconnecting) {
      color = const Color(0xFFE0B050);
      label = s.t('voiceReconnecting');
    } else {
      color = _accent;
      label = s.t('voiceLive');
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  Widget _errorCard(S s) {
    final message = _micDenied
        ? s.t('voicePermissionDenied')
        : (_failureMessage ?? s.t('voiceError'));

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _micDenied ? Icons.mic_off_rounded : Icons.cloud_off_rounded,
            size: 44,
            color: Colors.white.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(s.t('voiceRetry')),
          ),
          if (_permanentlyDenied)
            TextButton(
              onPressed: openAppSettings,
              child: Text(s.t('voiceOpenSettings')),
            ),
        ],
      ),
    );
  }

  Widget _stage({required bool active, required bool speaking}) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = _pulse.value;
        return SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++) _ring(i, t, active: active),
              Container(
                width: 138,
                height: 138,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_coreStart, _coreEnd],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: speaking ? 0.40 : 0.25),
                      blurRadius: speaking ? 42 : 30,
                      spreadRadius: speaking ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(_coreIcon(), size: 54, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring(int index, double t, {required bool active}) {
    final progress = (t + index / 3) % 1.0;
    final size = 150 + progress * (active ? 150 : 80);
    final alpha = active
        ? (1 - progress) * (index == 0 ? 0.38 : 0.24)
        : (1 - progress) * 0.10;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _accent.withValues(alpha: alpha.clamp(0.0, 1.0)),
          width: 1.4,
        ),
      ),
    );
  }

  Widget _captions(S s) {
    final user = _voice.lastUser;
    final assistant = _voice.lastAssistant;

    if (user.isEmpty && assistant.isEmpty) {
      if (_starting) return const SizedBox.shrink();
      return Text(
        s.t('voiceTapToTalk'),
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user.isNotEmpty)
          Text(
            user,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        if (assistant.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            assistant,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }

  Widget _controls(S s) {
    final speaking = _voice.state == LiveVoiceState.speaking;
    final disabled = _ended || _starting;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(
          icon: _voice.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          tooltip: _voice.muted ? s.t('voiceUnmute') : s.t('voiceMute'),
          onTap: disabled ? null : _toggleMicrophone,
          size: 56,
        ),
        const SizedBox(width: 22),
        _circleButton(
          icon: Icons.call_end_rounded,
          tooltip: s.t('voiceEnd'),
          onTap: _ended ? null : _end,
          size: 74,
          iconSize: 32,
          background: const Color(0xFFD9534F),
        ),
        const SizedBox(width: 22),
        if (speaking)
          _circleButton(
            icon: Icons.front_hand_rounded,
            tooltip: s.t('voiceInterrupt'),
            onTap: disabled ? null : _voice.interrupt,
            size: 56,
          )
        else
          _circleButton(
            icon: _showCaptions
                ? Icons.subtitles_rounded
                : Icons.subtitles_off_rounded,
            tooltip: s.t('voiceCaptions'),
            onTap: disabled ? null : _toggleCaptions,
            size: 56,
          ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    required double size,
    double iconSize = 24,
    Color? background,
  }) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background ?? Colors.white.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: iconSize,
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
