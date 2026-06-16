/// UI-level flow state for the push-to-talk interaction.
///
/// Distinct from [SessionStatus] (which drives the header pill): this models the
/// per-direction request/stream lifecycle.
enum TranslatorFlowState {
  /// Nothing happening.
  idle,

  /// Asking the backend for a token / opening the Live socket.
  requestingToken,

  /// Socket open, setup acknowledged, ready to stream.
  ready,

  /// Button held; microphone audio is streaming to Gemini.
  listening,

  /// Something failed (see controller.lastError for the friendly message).
  error,
}
