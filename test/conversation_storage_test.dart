import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilo_translate/features/translator/data/conversation_storage.dart';
import 'package:tilo_translate/features/translator/domain/conversation_message.dart';
import 'package:tilo_translate/features/translator/domain/translation_direction.dart';

ConversationMessage _msg(String input) => ConversationMessage(
      timestamp: DateTime.parse('2026-06-15T10:00:00.000Z'),
      direction: TranslationDirection.aToB,
      sourceLanguageCode: 'tr',
      targetLanguageCode: 'en',
      inputTranscript: input,
      outputTranscript: 'translated $input',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SharedPrefsConversationStorage', () {
    test('starts empty', () async {
      final storage = SharedPrefsConversationStorage();
      expect(await storage.load(), isEmpty);
    });

    test('add then load returns the message', () async {
      final storage = SharedPrefsConversationStorage();
      await storage.add(_msg('one'));
      final all = await storage.load();
      expect(all, hasLength(1));
      expect(all.first.inputTranscript, 'one');
    });

    test('saveAll replaces and persists across instances', () async {
      await SharedPrefsConversationStorage().saveAll([_msg('a'), _msg('b')]);
      // New instance reads from the same backing store.
      final reloaded = await SharedPrefsConversationStorage().load();
      expect(reloaded.map((m) => m.inputTranscript), ['a', 'b']);
    });

    test('clear empties storage', () async {
      final storage = SharedPrefsConversationStorage();
      await storage.add(_msg('x'));
      await storage.clear();
      expect(await storage.load(), isEmpty);
    });
  });
}
