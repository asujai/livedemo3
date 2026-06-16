import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'live_translate_websocket_client.dart';

/// Pure helpers to build outgoing messages and parse incoming Gemini Live
/// frames. Kept free of any socket/plugin dependency so it is unit-testable.
class GeminiMessages {
  GeminiMessages._();

  static const model = 'gemini-3.5-live-translate-preview';
  static const inputMimeType = 'audio/pcm;rate=16000';

  // ---- Outgoing ----

  /// Setup/config message. Translation ALWAYS via translationConfig.
  static Map<String, dynamic> buildSetup({required String targetLanguageCode}) => {
        'setup': {
          'model': 'models/$model',
          'generationConfig': {
            'responseModalities': ['AUDIO'],
            'inputAudioTranscription': <String, dynamic>{},
            'outputAudioTranscription': <String, dynamic>{},
            'translationConfig': {
              'targetLanguageCode': targetLanguageCode,
              'echoTargetLanguage': false,
            },
          },
        },
      };

  /// realtimeInput audio message for a base64-encoded PCM16 chunk.
  static Map<String, dynamic> buildAudioMessage(String base64Pcm) => {
        'realtimeInput': {
          'audio': {'data': base64Pcm, 'mimeType': inputMimeType},
        },
      };

  static String encode(Map<String, dynamic> message) => jsonEncode(message);

  /// Encode a raw PCM16 chunk into the wire JSON string.
  static String encodeAudioChunk(List<int> pcm16) =>
      jsonEncode(buildAudioMessage(base64Encode(pcm16)));

  // ---- Incoming ----

  /// Parse a raw WebSocket frame (String or binary bytes) into [LiveEvent]s.
  static List<LiveEvent> parseFrame(dynamic frame) {
    Map<String, dynamic>? msg;
    try {
      if (frame is String) {
        msg = jsonDecode(frame) as Map<String, dynamic>;
      } else if (frame is List<int>) {
        msg = jsonDecode(utf8.decode(frame)) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('LiveWS parse error: ${e.runtimeType}');
      return const [];
    }
    if (msg == null) return const [];
    return parse(msg);
  }

  /// Parse an already JSON-decoded server message into [LiveEvent]s.
  static List<LiveEvent> parse(Map<String, dynamic> msg) {
    final events = <LiveEvent>[];

    if (msg.containsKey('setupComplete')) {
      events.add(const LiveSetupComplete());
    }

    final serverContent = _asMap(msg['serverContent']);
    if (serverContent != null) {
      final input = _asString(_asMap(serverContent['inputTranscription'])?['text']);
      if (input != null && input.isNotEmpty) events.add(LiveInputTranscript(input));

      final output = _asString(_asMap(serverContent['outputTranscription'])?['text']);
      if (output != null && output.isNotEmpty) events.add(LiveOutputTranscript(output));

      final parts = _asMap(serverContent['modelTurn'])?['parts'];
      if (parts is List) {
        for (final part in parts) {
          final inline = _asMap(_asMap(part)?['inlineData']);
          final data = _asString(inline?['data']);
          if (data != null && data.isNotEmpty) {
            try {
              events.add(LiveAudioChunk(base64Decode(data)));
            } catch (_) {/* skip malformed chunk */}
          }
        }
      }

      if (serverContent['interrupted'] == true) events.add(const LiveInterrupted());
      if (serverContent['turnComplete'] == true || serverContent['generationComplete'] == true) {
        events.add(const LiveTurnComplete());
      }
    }

    if (msg.containsKey('goAway')) events.add(const LiveReconnectNeeded());

    final error = _asMap(msg['error']);
    if (error != null) {
      events.add(LiveError(_asString(error['message']) ?? 'Connection failed'));
    }

    return events;
  }

  static Map<String, dynamic>? _asMap(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : null;

  static String? _asString(dynamic v) => v is String ? v : null;
}
