import 'dart:math';

import 'translation_direction.dart';

/// A single translated utterance saved to local history.
///
/// Only text transcripts are stored — never audio (see privacy rules).
class ConversationMessage {
  ConversationMessage({
    String? id,
    required this.timestamp,
    required this.direction,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.inputTranscript,
    required this.outputTranscript,
  }) : id = id ?? _generateId();

  /// Stable unique id (used as list key / for de-dup).
  final String id;
  final DateTime timestamp;
  final TranslationDirection direction;
  final String sourceLanguageCode;
  final String targetLanguageCode;

  /// What the speaker said (source language).
  final String inputTranscript;

  /// The translation (target language).
  final String outputTranscript;

  ConversationMessage copyWith({
    String? inputTranscript,
    String? outputTranscript,
  }) {
    return ConversationMessage(
      id: id,
      timestamp: timestamp,
      direction: direction,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      inputTranscript: inputTranscript ?? this.inputTranscript,
      outputTranscript: outputTranscript ?? this.outputTranscript,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'direction': direction.wireValue,
        'sourceLanguageCode': sourceLanguageCode,
        'targetLanguageCode': targetLanguageCode,
        'inputTranscript': inputTranscript,
        'outputTranscript': outputTranscript,
      };

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      direction: (json['direction'] == 'B_TO_A')
          ? TranslationDirection.bToA
          : TranslationDirection.aToB,
      sourceLanguageCode: json['sourceLanguageCode'] as String? ?? '',
      targetLanguageCode: json['targetLanguageCode'] as String? ?? '',
      inputTranscript: json['inputTranscript'] as String? ?? '',
      outputTranscript: json['outputTranscript'] as String? ?? '',
    );
  }

  static String _generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rnd = Random().nextInt(0x7fffffff);
    return '$ts-$rnd';
  }
}
