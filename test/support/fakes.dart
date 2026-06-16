import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tilo_translate/features/translator/data/audio_input_service.dart';
import 'package:tilo_translate/features/translator/data/audio_output_service.dart';
import 'package:tilo_translate/features/translator/data/live_token_api.dart';
import 'package:tilo_translate/features/translator/data/live_translate_websocket_client.dart';
import 'package:tilo_translate/features/translator/domain/live_translation_session.dart';

/// Token API whose backend echoes the requested target language back.
LiveTokenApi echoTokenApi() => LiveTokenApi(
      client: MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'token': 'auth_tokens/ok',
            'model': 'gemini-3.5-live-translate-preview',
            'expiresAt': '2999-01-01T00:00:00.000Z',
            'targetLanguageCode': body['targetLanguageCode'],
          }),
          200,
        );
      }),
    );

LiveTokenApi failTokenApi() => LiveTokenApi(
      client: MockClient((req) async => http.Response(
            jsonEncode({'error': {'code': 'NOT_CONFIGURED', 'message': 'no key'}}),
            503,
          )),
    );

class FakeAudioInput implements AudioInputService {
  FakeAudioInput({this.granted = true});

  bool granted;
  bool started = false;
  bool stopped = false;
  final StreamController<List<int>> controller = StreamController<List<int>>.broadcast();

  void emitChunk(List<int> bytes) => controller.add(bytes);

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Stream<List<int>> start() {
    started = true;
    return controller.stream;
  }

  @override
  Future<void> stop() async => stopped = true;
}

class FakeAudioOutput implements AudioOutputService {
  final List<List<int>> played = [];
  int clearCount = 0;
  bool disposed = false;

  @override
  void enqueue(List<int> pcm16) => played.add(pcm16);

  @override
  Future<void> clear() async => clearCount++;

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeWsClient implements LiveTranslateWebSocketClient {
  final StreamController<LiveEvent> _events = StreamController<LiveEvent>.broadcast();
  final List<List<int>> sent = [];
  bool connected = false;
  bool closed = false;
  LiveTokenResult? token;

  void emit(LiveEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  @override
  Stream<LiveEvent> get events => _events.stream;

  @override
  Future<void> connect(LiveTokenResult t) async {
    connected = true;
    token = t;
  }

  @override
  void sendAudioChunk(List<int> pcm16) => sent.add(pcm16);

  @override
  Future<void> close() async {
    closed = true;
    if (!_events.isClosed) await _events.close();
  }
}
