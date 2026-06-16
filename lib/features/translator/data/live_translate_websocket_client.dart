import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../domain/live_translation_session.dart';
import 'gemini_message_parser.dart';

/// Events emitted by the Live WebSocket connection.
sealed class LiveEvent {
  const LiveEvent();
}

class LiveSetupComplete extends LiveEvent {
  const LiveSetupComplete();
}

class LiveInputTranscript extends LiveEvent {
  const LiveInputTranscript(this.text);
  final String text;
}

class LiveOutputTranscript extends LiveEvent {
  const LiveOutputTranscript(this.text);
  final String text;
}

class LiveAudioChunk extends LiveEvent {
  const LiveAudioChunk(this.pcm16);

  /// 24 kHz mono PCM16 audio bytes.
  final List<int> pcm16;
}

class LiveTurnComplete extends LiveEvent {
  const LiveTurnComplete();
}

class LiveInterrupted extends LiveEvent {
  const LiveInterrupted();
}

class LiveReconnectNeeded extends LiveEvent {
  const LiveReconnectNeeded();
}

class LiveTokenExpired extends LiveEvent {
  const LiveTokenExpired();
}

class LiveError extends LiveEvent {
  const LiveError(this.message);
  final String message;
}

class LiveClosed extends LiveEvent {
  const LiveClosed({this.code});
  final int? code;
}

/// Connects to Gemini Live Translate over a Constrained WebSocket using a
/// short-lived token. The Gemini API key is never used here — only the token.
abstract class LiveTranslateWebSocketClient {
  Stream<LiveEvent> get events;

  /// Open the socket and send the setup/config (model + translationConfig).
  Future<void> connect(LiveTokenResult token);

  /// Send a 16 kHz mono PCM16 audio chunk.
  void sendAudioChunk(List<int> pcm16);

  /// Close the connection.
  Future<void> close();
}

/// Real implementation backed by `web_socket_channel`.
class GeminiLiveWebSocketClient implements LiveTranslateWebSocketClient {
  GeminiLiveWebSocketClient();

  static const _host = 'generativelanguage.googleapis.com';
  static const _path =
      '/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContentConstrained';

  final StreamController<LiveEvent> _events = StreamController<LiveEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _closed = false;

  @override
  Stream<LiveEvent> get events => _events.stream;

  @override
  Future<void> connect(LiveTokenResult token) async {
    final uri = Uri(
      scheme: 'wss',
      host: _host,
      path: _path,
      queryParameters: {'access_token': token.token},
    );

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    await channel.ready; // throws if the handshake fails

    _sub = channel.stream.listen(
      _onData,
      onError: (Object e, _) {
        debugPrint('LiveWS error: ${e.runtimeType}'); // never log token
        if (!_events.isClosed) _events.add(const LiveError('Connection failed'));
      },
      onDone: _onDone,
      cancelOnError: false,
    );

    // Send setup immediately after the socket opens.
    _send(GeminiMessages.buildSetup(targetLanguageCode: token.targetLanguageCode));
  }

  void _onData(dynamic data) {
    if (_events.isClosed) return;
    for (final ev in GeminiMessages.parseFrame(data)) {
      _events.add(ev);
    }
  }

  void _onDone() {
    final code = _channel?.closeCode;
    if (!_events.isClosed) {
      // 1008 (policy violation) / 1011 commonly signal auth/token problems.
      if (code == 1008 || code == 1011) {
        _events.add(const LiveTokenExpired());
      } else {
        _events.add(LiveClosed(code: code));
      }
    }
  }

  @override
  void sendAudioChunk(List<int> pcm16) {
    if (_closed || _channel == null) return;
    _channel!.sink.add(GeminiMessages.encodeAudioChunk(pcm16));
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(GeminiMessages.encode(message));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    await _channel?.sink.close(ws_status.normalClosure);
    if (!_events.isClosed) await _events.close();
  }
}
