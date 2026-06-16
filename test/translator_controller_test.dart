import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tilo_translate/core/config/app_config.dart';
import 'package:tilo_translate/core/constants/languages.dart';
import 'package:tilo_translate/features/translator/data/conversation_storage.dart';
import 'package:tilo_translate/features/translator/data/live_token_api.dart';
import 'package:tilo_translate/features/translator/domain/live_translation_session.dart';
import 'package:tilo_translate/features/translator/domain/translation_direction.dart';
import 'package:tilo_translate/features/translator/domain/translator_flow_state.dart';
import 'package:tilo_translate/features/translator/domain/conversation_message.dart';
import 'package:tilo_translate/features/translator/presentation/translator_controller.dart';
import 'support/fakes.dart';

LiveTokenApi _okTokenApi() => LiveTokenApi(
      client: MockClient((req) async => http.Response(
            jsonEncode({
              'token': 'auth_tokens/ok',
              'model': 'gemini-3.5-live-translate-preview',
              'expiresAt': '2999-01-01T00:00:00.000Z',
              'targetLanguageCode': 'en',
            }),
            200,
          )),
    );

LiveTokenApi _failTokenApi() => LiveTokenApi(
      client: MockClient((req) async => http.Response(
            jsonEncode({'error': {'code': 'NOT_CONFIGURED', 'message': 'no key'}}),
            503,
          )),
    );

TranslatorController _controller({LiveTokenApi? api}) => TranslatorController(
      tokenApi: api ?? _okTokenApi(),
      storage: InMemoryConversationStorage(),
      audioInput: FakeAudioInput(),
      audioOutput: FakeAudioOutput(),
      webSocketFactory: () => FakeWsClient(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppConfig.setTokenServerUrlOverride(null));

  group('language selection', () {
    test('defaults to tr / en after init', () async {
      final c = _controller();
      await c.init();
      expect(c.languageA.code, 'tr');
      expect(c.languageB.code, 'en');
    });

    test('swap exchanges staff and guest', () async {
      final c = _controller();
      await c.init();
      await c.swap();
      expect(c.languageA.code, 'en');
      expect(c.languageB.code, 'tr');
    });

    test('cannot select the same language for both sides', () async {
      final c = _controller();
      await c.init();
      final ok = await c.setLanguage(isStaff: false, lang: Languages.byCode('tr')!);
      expect(ok, isFalse);
      expect(c.languageB.code, 'en'); // unchanged
      expect(c.lastError, contains('same language'));
    });

    test('setLanguage persists and survives reload', () async {
      final c = _controller();
      await c.init();
      await c.setLanguage(isStaff: false, lang: Languages.byCode('ar')!);
      expect(c.languageB.code, 'ar');

      final c2 = _controller();
      await c2.init();
      expect(c2.languageB.code, 'ar');
    });
  });

  group('push-to-talk flow', () {
    test('startDirection obtains token and enters listening', () async {
      final c = _controller(api: _okTokenApi());
      await c.init();
      await c.startDirection(TranslationDirection.aToB);
      expect(c.flow, TranslatorFlowState.listening);
      expect(c.status, SessionStatus.listening);
      expect(c.activeDirection, TranslationDirection.aToB);
    });

    test('only one direction can be active (mutual exclusion)', () async {
      final c = _controller(api: _okTokenApi());
      await c.init();
      await c.startDirection(TranslationDirection.aToB);
      expect(c.canActivate(TranslationDirection.bToA), isFalse);
      expect(c.canActivate(TranslationDirection.aToB), isTrue);
    });

    test('stopDirection returns to ready', () async {
      final c = _controller(api: _okTokenApi());
      await c.init();
      await c.startDirection(TranslationDirection.aToB);
      await c.stopDirection(TranslationDirection.aToB);
      expect(c.flow, TranslatorFlowState.ready);
      expect(c.activeDirection, isNull);
    });

    test('backend failure surfaces a friendly error', () async {
      final c = _controller(api: _failTokenApi());
      await c.init();
      await c.startDirection(TranslationDirection.aToB);
      expect(c.flow, TranslatorFlowState.error);
      expect(c.status, SessionStatus.error);
      expect(c.lastError, isNotNull);
      expect(c.activeDirection, isNull);
    });
  });

  group('conversation history', () {
    test('addMessage stores and clearConversation empties', () async {
      final c = _controller();
      await c.init();
      await c.addMessage(ConversationMessage(
        timestamp: DateTime.now(),
        direction: TranslationDirection.aToB,
        sourceLanguageCode: 'tr',
        targetLanguageCode: 'en',
        inputTranscript: 'Merhaba',
        outputTranscript: 'Hello',
      ));
      expect(c.messages, hasLength(1));
      await c.clearConversation();
      expect(c.messages, isEmpty);
    });
  });

  group('settings / token server URL config', () {
    test('override is applied to AppConfig and trailing slash stripped', () async {
      final c = _controller();
      await c.init();
      await c.updateSettings(tokenServerUrlOverride: 'http://1.2.3.4:9000/');
      expect(AppConfig.tokenServerUrl, 'http://1.2.3.4:9000');
    });

    test('empty override falls back to build-time default', () async {
      final c = _controller();
      await c.init();
      await c.updateSettings(tokenServerUrlOverride: '');
      expect(AppConfig.tokenServerUrl, 'http://192.168.1.17:8787');
    });

    test('toggles persist', () async {
      final c = _controller();
      await c.init();
      await c.updateSettings(saveHistory: false, autoPlayAudio: false);
      expect(c.settings.saveHistory, isFalse);
      expect(c.settings.autoPlayAudio, isFalse);
    });
  });
}
