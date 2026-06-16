import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tilo_translate/app.dart';
import 'package:tilo_translate/features/translator/data/conversation_storage.dart';
import 'package:tilo_translate/features/translator/data/live_token_api.dart';
import 'package:tilo_translate/features/translator/presentation/translator_controller.dart';

TranslatorController _testController() {
  final api = LiveTokenApi(
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
  return TranslatorController(tokenApi: api, storage: InMemoryConversationStorage());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders header and default languages', (tester) async {
    await tester.pumpWidget(TiloTranslateApp(controller: _testController()));
    await tester.pumpAndSettle();

    expect(find.text('Tilo Translate'), findsOneWidget);
    expect(find.text('Turkish'), findsWidgets); // language card + button
    expect(find.text('English'), findsWidgets);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('swap button exchanges staff and guest languages', (tester) async {
    final controller = _testController();
    await tester.pumpWidget(TiloTranslateApp(controller: controller));
    await tester.pumpAndSettle();

    expect(controller.languageA.code, 'tr');

    await tester.tap(find.byTooltip('Swap languages'));
    await tester.pumpAndSettle();

    expect(controller.languageA.code, 'en');
    expect(controller.languageB.code, 'tr');
  });

  testWidgets('debug "add demo message" shows a conversation bubble', (tester) async {
    await tester.pumpWidget(TiloTranslateApp(controller: _testController()));
    await tester.pumpAndSettle();

    // Empty-state hint visible first.
    expect(find.textContaining('Translated conversation appears here'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_comment_outlined));
    await tester.pumpAndSettle();

    expect(find.textContaining('demo translation'), findsOneWidget);
  });
}
