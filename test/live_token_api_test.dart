import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tilo_translate/core/errors/app_error.dart';
import 'package:tilo_translate/features/translator/data/live_token_api.dart';
import 'package:tilo_translate/features/translator/domain/translation_direction.dart';

void main() {
  group('LiveTokenApi', () {
    test('parses a successful token response', () async {
      final client = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(req.url.path, '/api/live-token');
        expect(body['sourceLanguageCode'], 'tr');
        expect(body['targetLanguageCode'], 'en');
        expect(body['direction'], 'A_TO_B');
        return http.Response(
          jsonEncode({
            'token': 'auth_tokens/abc123',
            'model': 'gemini-3.5-live-translate-preview',
            'expiresAt': '2999-01-01T00:00:00.000Z',
            'targetLanguageCode': 'en',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = LiveTokenApi(client: client);
      final result = await api.fetchToken(
        direction: TranslationDirection.aToB,
        languageA: 'tr',
        languageB: 'en',
      );

      expect(result.token, 'auth_tokens/abc123');
      expect(result.targetLanguageCode, 'en');
      expect(result.isExpired, isFalse);
    });

    test('throws sameLanguage before any network call', () async {
      var called = false;
      final client = MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      });
      final api = LiveTokenApi(client: client);

      expect(
        () => api.fetchToken(direction: TranslationDirection.aToB, languageA: 'tr', languageB: 'tr'),
        throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.sameLanguage)),
      );
      expect(called, isFalse);
    });

    test('maps NOT_CONFIGURED error code', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({'error': {'code': 'NOT_CONFIGURED', 'message': 'no key'}}),
            503,
            headers: {'content-type': 'application/json'},
          ));
      final api = LiveTokenApi(client: client);

      expect(
        () => api.fetchToken(direction: TranslationDirection.bToA, languageA: 'tr', languageB: 'en'),
        throwsA(isA<AppError>().having((e) => e.code, 'code', AppErrorCode.notConfigured)),
      );
    });

    test('uses correct source/target for B_TO_A direction', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'token': 't',
            'model': 'm',
            'expiresAt': '2999-01-01T00:00:00.000Z',
            'targetLanguageCode': 'tr',
          }),
          200,
        );
      });
      final api = LiveTokenApi(client: client);

      await api.fetchToken(direction: TranslationDirection.bToA, languageA: 'tr', languageB: 'en');

      // B_TO_A: guest (B=en) speaks -> staff (A=tr) hears
      expect(sent['sourceLanguageCode'], 'en');
      expect(sent['targetLanguageCode'], 'tr');
      expect(sent['direction'], 'B_TO_A');
    });
  });
}
