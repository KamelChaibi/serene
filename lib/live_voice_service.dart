import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import 'voice_api.dart';

/// High-level state shown in the call UI. It mirrors the agent's state but
/// also covers connection problems the agent cannot report.
enum LiveVoiceState {
  connecting,
  listening,
  thinking,
  speaking,
  idle,
  reconnecting,
  ended,
  failed,
}

/// Owns the LiveKit room for one call.
///
/// Everything the UI needs is exposed here: state, captions, mute, the crisis
/// flag, and whether the connection is alive. The widget never touches the
/// LiveKit SDK directly, which keeps the screen testable without a network.
class LiveVoiceService extends ChangeNotifier {
  static const dataTopic = 'serene.voice';
  static const controlTopic = 'serene.control';

  /// Message types that only the agent sends.
  static const _agentTypes = {'ready', 'state', 'transcript', 'crisis', 'error'};

  Room? _room;
  EventsListener<RoomEvent>? _listener;

  LiveVoiceState _state = LiveVoiceState.connecting;
  bool _muted = false;
  bool _closed = false;
  bool _disposed = false;
  bool _crisis = false;
  bool _reconnecting = false;
  bool _agentReady = false;

  String _lastUser = '';
  String _lastAssistant = '';
  String? _error;

  /// Called once per crisis event, so the screen can open the hotline sheet.
  VoidCallback? onCrisis;

  /// Called for each final transcript line, so the text chat can keep a copy.
  void Function(String role, String text)? onFinalTranscript;

  LiveVoiceState get state => _state;
  bool get muted => _muted;
  bool get crisisActive => _crisis;
  bool get reconnecting => _reconnecting;
  bool get connected =>
      _room?.connectionState == ConnectionState.connected && !_reconnecting;

  /// True once the agent worker has joined and announced itself. A room can be
  /// connected while no agent is present, which otherwise looks like a call
  /// where nobody answers.
  bool get agentReady => _agentReady;
  String get lastUser => _lastUser;
  String get lastAssistant => _lastAssistant;
  String? get error => _error;

  /// Joins the room and opens the microphone. Throws on failure.
  Future<void> connect(VoiceSession session) async {
    if (_disposed) return;
    // A retry after a dropped call must not leak the previous room, its
    // listener, or its microphone track.
    if (_room != null) await _teardown();
    _closed = false;
    _crisis = false;
    _agentReady = false;
    _error = null;
    _setState(LiveVoiceState.connecting);

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: false,
        dynacast: false,
      ),
    );
    _room = room;

    final listener = room.createListener();
    _listener = listener;

    listener.on<RoomConnectedEvent>((_) {
      _reconnecting = false;
      if (_state == LiveVoiceState.connecting) {
        _setState(LiveVoiceState.listening);
      } else {
        _notify();
      }
    });
    listener.on<RoomReconnectingEvent>((_) {
      _reconnecting = true;
      _setState(LiveVoiceState.reconnecting);
    });
    listener.on<RoomReconnectedEvent>((_) {
      _reconnecting = false;
      _setState(LiveVoiceState.listening);
    });
    listener.on<RoomDisconnectedEvent>((event) {
      _reconnecting = false;
      if (_closed) return;
      _error = event.reason?.name ?? 'disconnected';
      _setState(LiveVoiceState.failed);
    });
    listener.on<DataReceivedEvent>(_onData);

    try {
      await room.connect(session.url, session.token);
      final local = room.localParticipant;
      if (local == null) {
        throw StateError('LiveKit did not create a local participant');
      }
      await local.setMicrophoneEnabled(
        true,
        audioCaptureOptions: const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      );
      // A companion call should come out of the loudspeaker, not the earpiece.
      try {
        await AudioManager.instance.setSpeakerOutputPreferred(true);
      } catch (_) {
        // Not every Android build exposes the audio route; not fatal.
      }
      _setState(LiveVoiceState.listening);
    } catch (error) {
      _error = '$error';
      _setState(LiveVoiceState.failed);
      await _teardown();
      rethrow;
    }
  }

  /// Mutes or unmutes the microphone. Muting stops the capture track entirely.
  Future<void> setMuted(bool value) async {
    if (_muted == value) return;
    _muted = value;
    _notify();
    final local = _room?.localParticipant;
    if (local == null) return;
    try {
      await local.setMicrophoneEnabled(
        !value,
        audioCaptureOptions: const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      );
    } catch (_) {
      // The room may already be closing; the UI stays consistent.
    }
  }

  /// Stops Serene mid-sentence. The agent also interrupts on barge-in; this is
  /// the explicit button for when the user cannot speak over her.
  Future<void> interrupt() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    try {
      await local.publishData(
        utf8.encode(jsonEncode({'action': 'interrupt'})),
        reliable: true,
        topic: controlTopic,
      );
      _setState(LiveVoiceState.listening);
    } catch (_) {
      // Nothing useful to show; the next agent state will correct the UI.
    }
  }

  /// Leaves the room and releases the microphone. Safe to call twice.
  Future<void> disconnect() async {
    if (_closed && _room == null) return;
    _closed = true;
    await _teardown();
    if (!_disposed) _setState(LiveVoiceState.ended);
  }

  Future<void> _teardown() async {
    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;

    try {
      await room?.localParticipant?.setMicrophoneEnabled(false);
    } catch (_) {}
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(false);
    } catch (_) {}
    try {
      await listener?.dispose();
    } catch (_) {}
    try {
      await room?.disconnect();
    } catch (_) {}
    try {
      await room?.dispose();
    } catch (_) {}
  }

  void _onData(DataReceivedEvent event) {
    if (event.topic != dataTopic) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(event.data, allowMalformed: true));
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    _handlePayload(decoded);
  }

  /// Feeds a data message straight into the protocol handler. Used by tests
  /// so the message contract can be checked without a LiveKit server.
  @visibleForTesting
  void debugHandleData(Map<String, dynamic> payload) => _handlePayload(payload);

  void _handlePayload(Map<dynamic, dynamic> decoded) {
    if (decoded['v'] != 1) return;

    // Any message from the agent proves the worker is in the room, even if the
    // explicit `ready` packet was lost.
    if (!_agentReady && _agentTypes.contains(decoded['type'])) {
      _agentReady = true;
      _notify();
    }

    switch (decoded['type']) {
      case 'state':
        _applyRemoteState(decoded['state']);
        break;
      case 'transcript':
        final role = decoded['role'];
        final text = (decoded['text'] as String? ?? '').trim();
        if (text.isEmpty) return;
        if (role == 'user') {
          _lastUser = text;
        } else if (role == 'assistant') {
          _lastAssistant = text;
        } else {
          return;
        }
        if (decoded['final'] != false) {
          onFinalTranscript?.call(role as String, text);
        }
        _notify();
        break;
      case 'crisis':
        if (_crisis) return;
        _crisis = true;
        _notify();
        onCrisis?.call();
        break;
      case 'error':
        _error = decoded['code'] as String? ?? 'agent_error';
        _notify();
        break;
      case 'ready':
        _agentReady = true;
        if (_state == LiveVoiceState.connecting) {
          _setState(LiveVoiceState.listening);
        }
        break;
    }
  }

  void _applyRemoteState(Object? raw) {
    switch (raw) {
      case 'connecting':
        _setState(LiveVoiceState.connecting);
        break;
      case 'listening':
        _setState(LiveVoiceState.listening);
        break;
      case 'thinking':
        _setState(LiveVoiceState.thinking);
        break;
      case 'speaking':
        _setState(LiveVoiceState.speaking);
        break;
      case 'idle':
        _setState(LiveVoiceState.idle);
        break;
    }
  }

  /// Marks the call as failed. Used by tests to simulate a dropped room
  /// without a LiveKit server; the real path is [RoomDisconnectedEvent].
  @visibleForTesting
  void debugFail(String reason) {
    _error = reason;
    _setState(LiveVoiceState.failed);
  }

  void _setState(LiveVoiceState next) {
    if (_state == next) return;
    _state = next;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _closed = true;
    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;
    // The widget is gone; finish the network teardown without awaiting it.
    unawaited(() async {
      try {
        await room?.localParticipant?.setMicrophoneEnabled(false);
      } catch (_) {}
      try {
        await AudioManager.instance.setSpeakerOutputPreferred(false);
      } catch (_) {}
      try {
        await listener?.dispose();
      } catch (_) {}
      try {
        await room?.disconnect();
      } catch (_) {}
      try {
        await room?.dispose();
      } catch (_) {}
    }());
    super.dispose();
  }
}
