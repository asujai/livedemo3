import 'translation_direction.dart';

/// High-level connection/UX status surfaced in the header.
enum SessionStatus {
  idle, // Ready
  connecting, // Connecting
  listening, // Listening (mic open)
  translating, // Translating (receiving audio)
  error, // Error
}

extension SessionStatusLabel on SessionStatus {
  String get label => switch (this) {
        SessionStatus.idle => 'Ready',
        SessionStatus.connecting => 'Connecting',
        SessionStatus.listening => 'Listening',
        SessionStatus.translating => 'Translating',
        SessionStatus.error => 'Error',
      };
}

/// Result of a successful POST /api/live-token call.
class LiveTokenResult {
  LiveTokenResult({
    required this.token,
    required this.model,
    required this.expiresAt,
    required this.targetLanguageCode,
  });

  /// Ephemeral token value (`token.name`) — passed as ?access_token=.
  final String token;
  final String model;
  final DateTime expiresAt;
  final String targetLanguageCode;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory LiveTokenResult.fromJson(Map<String, dynamic> json) {
    return LiveTokenResult(
      token: json['token'] as String? ?? '',
      model: json['model'] as String? ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(minutes: 1)),
      targetLanguageCode: json['targetLanguageCode'] as String? ?? '',
    );
  }
}

/// Describes one direction's live session. In this stage it is a lightweight
/// state holder; the actual WebSocket/audio wiring arrives in a later stage.
class LiveTranslationSession {
  LiveTranslationSession({
    required this.direction,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    this.token,
    this.status = SessionStatus.idle,
  });

  final TranslationDirection direction;
  final String sourceLanguageCode;
  final String targetLanguageCode;

  LiveTokenResult? token;
  SessionStatus status;

  bool get hasValidToken => token != null && !token!.isExpired;
}
