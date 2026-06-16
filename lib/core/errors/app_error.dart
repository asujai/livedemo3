/// Machine-readable error categories used across the app.
enum AppErrorCode {
  noInternet,
  backendOffline,
  tokenFetchFailed,
  tokenExpired,
  webSocketDisconnected,
  microphonePermissionDenied,
  unsupportedAudioFormat,
  sameLanguage,
  pressedTooBriefly,
  emptyTranscript,
  audioQueueStuck,
  notConfigured,
  unknown,
}

/// A user-facing error with a short, non-technical message plus optional
/// developer detail (never shown to the user, safe to log — must not contain
/// tokens or keys).
class AppError implements Exception {
  AppError(this.code, this.message, {this.detail, this.cause});

  final AppErrorCode code;

  /// Short, friendly message safe to show in the UI.
  final String message;

  /// Extra context for logs/debugging only.
  final String? detail;

  /// The underlying error/exception, if any.
  final Object? cause;

  // ---- Convenience factories with the agreed friendly copy ----

  factory AppError.noInternet([Object? cause]) =>
      AppError(AppErrorCode.noInternet, 'Connection failed', detail: 'No internet connection', cause: cause);

  factory AppError.backendOffline([Object? cause]) =>
      AppError(AppErrorCode.backendOffline, 'Connection failed', detail: 'Backend unreachable', cause: cause);

  factory AppError.tokenFetchFailed([String? detail, Object? cause]) =>
      AppError(AppErrorCode.tokenFetchFailed, 'Please try again', detail: detail, cause: cause);

  factory AppError.tokenExpired([Object? cause]) =>
      AppError(AppErrorCode.tokenExpired, 'Refreshing translation session...', detail: 'Token expired', cause: cause);

  factory AppError.webSocketDisconnected([Object? cause]) =>
      AppError(AppErrorCode.webSocketDisconnected, 'Refreshing translation session...', detail: 'WebSocket disconnected', cause: cause);

  factory AppError.microphonePermissionDenied() =>
      AppError(AppErrorCode.microphonePermissionDenied, 'Microphone permission required');

  factory AppError.sameLanguage() =>
      AppError(AppErrorCode.sameLanguage, 'Pick two different languages');

  factory AppError.notConfigured() =>
      AppError(AppErrorCode.notConfigured, 'Server not configured', detail: 'Backend is missing its API key');

  factory AppError.unknown([Object? cause]) =>
      AppError(AppErrorCode.unknown, 'Please try again', cause: cause);

  @override
  String toString() => 'AppError(${code.name}: $message${detail != null ? ' — $detail' : ''})';
}
