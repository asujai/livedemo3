import 'package:flutter_test/flutter_test.dart';
import 'package:tilo_translate/features/translator/domain/conversation_message.dart';
import 'package:tilo_translate/features/translator/domain/translation_direction.dart';

void main() {
  group('ConversationMessage', () {
    test('auto-generates a non-empty id', () {
      final m = ConversationMessage(
        timestamp: DateTime.now(),
        direction: TranslationDirection.aToB,
        sourceLanguageCode: 'tr',
        targetLanguageCode: 'en',
        inputTranscript: 'merhaba',
        outputTranscript: 'hello',
      );
      expect(m.id, isNotEmpty);
    });

    test('toJson/fromJson round trip preserves all fields', () {
      final original = ConversationMessage(
        id: 'fixed-id',
        timestamp: DateTime.parse('2026-06-15T10:30:00.000Z'),
        direction: TranslationDirection.bToA,
        sourceLanguageCode: 'en',
        targetLanguageCode: 'tr',
        inputTranscript: 'hello',
        outputTranscript: 'merhaba',
      );

      final restored = ConversationMessage.fromJson(original.toJson());

      expect(restored.id, 'fixed-id');
      expect(restored.timestamp, original.timestamp);
      expect(restored.direction, TranslationDirection.bToA);
      expect(restored.sourceLanguageCode, 'en');
      expect(restored.targetLanguageCode, 'tr');
      expect(restored.inputTranscript, 'hello');
      expect(restored.outputTranscript, 'merhaba');
    });

    test('direction serializes to wire values', () {
      expect(TranslationDirection.aToB.wireValue, 'A_TO_B');
      expect(TranslationDirection.bToA.wireValue, 'B_TO_A');
    });
  });
}
