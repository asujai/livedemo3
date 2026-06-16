import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/languages.dart';
import '../../../core/errors/app_error.dart';
import '../data/audio_input_service.dart';
import '../data/audio_output_service.dart';
import '../data/conversation_storage.dart';
import '../data/live_token_api.dart';
import '../data/live_translate_websocket_client.dart';
import '../data/settings_storage.dart';
import '../domain/app_settings.dart';
import '../domain/conversation_message.dart';
import '../domain/language_option.dart';
import '../domain/live_translation_session.dart';
import '../domain/translation_direction.dart';
import '../domain/translator_flow_state.dart';
import '../domain/usage_tracker.dart';

typedef WebSocketClientFactory = LiveTranslateWebSocketClient Function();

/// Owns all screen state + the real two-way Live Translate session lifecycle.
///
/// Dependencies are injectable so the orchestration can be tested with fakes
/// (no plugins, no real sockets).
class TranslatorController extends ChangeNotifier {
  TranslatorController({
    LiveTokenApi? tokenApi,
    ConversationStorage? storage,
    SettingsStorage? settingsStorage,
    AudioInputService? audioInput,
    AudioOutputService? audioOutput,
    WebSocketClientFactory? webSocketFactory,
    UsageTracker? usageTracker,
    this.idleTimeout = const Duration(seconds: 75),
  })  : _tokenApi = tokenApi ?? LiveTokenApi(),
        _storage = storage ?? SharedPrefsConversationStorage(),
        _settingsStorage = settingsStorage ?? SettingsStorage(),
        _audioInput = audioInput ?? RecordAudioInputService(),
        _audioOutput = audioOutput ?? PcmAudioOutputService(),
        _wsFactory = webSocketFactory ?? (() => GeminiLiveWebSocketClient()),
        _usage = usageTracker ?? UsageTracker();

  final LiveTokenApi _tokenApi;
  final ConversationStorage _storage;
  final SettingsStorage _settingsStorage;
  final AudioInputService _audioInput;
  final AudioOutputService _audioOutput;
  final WebSocketClientFactory _wsFactory;
  final UsageTracker _usage;
  final Duration idleTimeout;

  // ---- State ----
  AppSettings _settings = AppSettings.defaults;
  LanguageOption _languageA = Languages.byCodeOrFallback(Languages.defaultLanguageA);
  LanguageOption _languageB = Languages.byCodeOrFallback(Languages.defaultLanguageB);
  SessionStatus _status = SessionStatus.idle;
  TranslatorFlowState _flow = TranslatorFlowState.idle;
  TranslationDirection? _activeDirection;
  String? _lastError;
  List<ConversationMessage> _messages = const [];
  ConversationMessage? _pending; // in-progress utterance shown live

  int _tokenSeq = 0;

  // Connection (kept open briefly for reuse).
  LiveTranslateWebSocketClient? _client;
  TranslationDirection? _connectedDirection;
  LiveTokenResult? _connectedToken;
  StreamSubscription<LiveEvent>? _wsSub;
  StreamSubscription<List<int>>? _micSub;
  Timer? _idleTimer;
  Timer? _usageTicker;
  bool _intentionalClose = false;

  // ---- Getters ----
  AppSettings get settings => _settings;
  LanguageOption get languageA => _languageA;
  LanguageOption get languageB => _languageB;
  SessionStatus get status => _status;
  TranslatorFlowState get flow => _flow;
  TranslationDirection? get activeDirection => _activeDirection;
  String? get lastError => _lastError;
  bool get sameLanguage => _languageA.code == _languageB.code;
  bool get isBusy => _activeDirection != null;

  /// Saved messages plus the live (in-progress) one, oldest first.
  List<ConversationMessage> get messages =>
      [..._messages, if (_pending != null) _pending!];

  Duration get sessionUsage => _usage.sessionElapsed();
  Duration get todayUsage => _usage.todayElapsed();

  bool canActivate(TranslationDirection dir) =>
      _activeDirection == null || _activeDirection == dir;

  // ---- Lifecycle ----
  Future<void> init() async {
    _settings = await _settingsStorage.load();
    _languageA = Languages.byCodeOrFallback(_settings.staffLanguageCode);
    _languageB = Languages.byCodeOrFallback(_settings.guestLanguageCode);
    AppConfig.setTokenServerUrlOverride(_settings.tokenServerUrlOverride);
    _messages = _settings.saveHistory ? await _storage.load() : const [];
    final usage = await _settingsStorage.loadUsageToday(_usage.todayKey);
    _usage.loadToday(dateKey: usage.dateKey, total: Duration(seconds: usage.seconds));
    notifyListeners();
  }

  // ---- Language selection (closes active session) ----
  Future<bool> setLanguage({required bool isStaff, required LanguageOption lang}) async {
    final other = isStaff ? _languageB : _languageA;
    if (lang.code == other.code) {
      _lastError = 'The same language cannot be selected for both sides.';
      notifyListeners();
      return false;
    }
    await _hardResetSessions();
    if (isStaff) {
      _languageA = lang;
    } else {
      _languageB = lang;
    }
    await _persistLanguages();
    notifyListeners();
    return true;
  }

  Future<void> swap() async {
    await _hardResetSessions();
    final tmp = _languageA;
    _languageA = _languageB;
    _languageB = tmp;
    await _persistLanguages();
    notifyListeners();
  }

  // ---- Push-to-talk ----
  Future<void> startDirection(TranslationDirection dir) async {
    if (_activeDirection != null) return; // mutual exclusion
    if (sameLanguage) {
      _setError('Pick two different languages');
      return;
    }

    final granted = await _ensureMicPermission();
    if (!granted) {
      _setError('Microphone permission is required');
      return;
    }

    _activeDirection = dir;
    _lastError = null;
    _flow = TranslatorFlowState.requestingToken;
    _status = SessionStatus.connecting;
    _cancelIdleTimer();
    notifyListeners();

    final seq = ++_tokenSeq;
    try {
      // Reuse an open, valid connection for the same direction; otherwise build one.
      final reusable = _client != null &&
          _connectedDirection == dir &&
          _connectedToken != null &&
          !_connectedToken!.isExpired;

      if (!reusable) {
        await _teardownConnection();
        final token = await _tokenApi.fetchToken(
          direction: dir,
          languageA: _languageA.code,
          languageB: _languageB.code,
        );
        if (_stale(seq, dir)) return;

        final client = _wsFactory();
        _wsSub = client.events.listen(_onLiveEvent);
        await client.connect(token);
        if (_stale(seq, dir)) {
          await client.close();
          return;
        }
        _client = client;
        _connectedDirection = dir;
        _connectedToken = token;
      }

      // New utterance: drop any stale audio, open a live bubble.
      await _audioOutput.clear();
      _startPending(dir);
      _flow = TranslatorFlowState.ready;
      notifyListeners();

      // Start streaming the mic.
      _intentionalClose = false;
      _usageStart();
      _flow = TranslatorFlowState.listening;
      _status = SessionStatus.listening;
      notifyListeners();

      _micSub = _audioInput.start().listen(
        (chunk) => _client?.sendAudioChunk(chunk),
        onError: (Object e) {
          debugPrint('Mic error: ${e.runtimeType}');
          _failActive('Please try again');
        },
      );
    } on AppError catch (e) {
      if (seq != _tokenSeq) return;
      await _failActive(e.message);
    } catch (e) {
      if (seq != _tokenSeq) return;
      debugPrint('startDirection error: $e');
      await _failActive('Connection failed: ${e.toString()}');
    }
  }

  /// Released after a real (long-enough) press.
  Future<void> stopDirection(TranslationDirection dir) async {
    if (_activeDirection != dir) return;
    _tokenSeq++; // invalidate any in-flight connect
    await _stopMic();
    _usageStop();
    _activeDirection = null;
    if (_flow != TranslatorFlowState.error) {
      _flow = TranslatorFlowState.ready;
      _status = SessionStatus.idle;
    }
    _startIdleTimer(); // keep socket briefly for reuse
    notifyListeners();
  }

  /// Released too quickly — silently cancel.
  Future<void> cancelShortPress(TranslationDirection dir) async {
    if (_activeDirection != null && _activeDirection != dir) return;
    _tokenSeq++;
    await _stopMic();
    _usageStop();
    _discardPending();
    _activeDirection = null;
    if (_flow != TranslatorFlowState.error) {
      _flow = TranslatorFlowState.idle;
      _status = SessionStatus.idle;
    }
    _startIdleTimer();
    notifyListeners();
  }

  // ---- Incoming Live events ----
  void _onLiveEvent(LiveEvent event) {
    switch (event) {
      case LiveSetupComplete():
        if (_activeDirection != null && _flow == TranslatorFlowState.requestingToken) {
          _flow = TranslatorFlowState.ready;
          notifyListeners();
        }
      case LiveInputTranscript(:final text):
        _appendPending(input: text);
      case LiveOutputTranscript(:final text):
        _appendPending(output: text);
      case LiveAudioChunk(:final pcm16):
        if (_settings.autoPlayAudio) _audioOutput.enqueue(pcm16);
        if (_activeDirection != null && _status == SessionStatus.listening) {
          _status = SessionStatus.translating;
          notifyListeners();
        }
      case LiveInterrupted():
        _audioOutput.clear();
      case LiveTurnComplete():
        _finalizePending();
        if (_activeDirection != null && _status == SessionStatus.translating) {
          _status = SessionStatus.listening;
          notifyListeners();
        }
      case LiveTokenExpired():
        _lastError = 'Refreshing translation session';
        _status = SessionStatus.error;
        _connectedToken = null;
        _teardownConnection();
        notifyListeners();
      case LiveReconnectNeeded():
        _teardownConnection();
      case LiveError(:final message):
        _setError(_friendly(message));
      case LiveClosed(:final code):
        if (!_intentionalClose) {
          // Unexpected drop.
          if (_activeDirection != null) {
            _failActive('Connection failed: WebSocket closed with code $code');
          } else {
            _teardownConnection();
          }
        }
    }
  }

  // ---- Conversation ----
  Future<void> addMessage(ConversationMessage m) async {
    _messages = [..._messages, m];
    notifyListeners();
    if (_settings.saveHistory) await _storage.saveAll(_messages);
  }


  /// Clears only the UI/local conversation — does NOT touch the live session.
  Future<void> clearConversation() async {
    _messages = const [];
    notifyListeners();
    await _storage.clear();
  }

  /// Stop & close everything.
  Future<void> endSession() async {
    await _hardResetSessions();
    notifyListeners();
  }

  // ---- Settings ----
  Future<void> updateSettings({
    bool? saveHistory,
    bool? autoPlayAudio,
    String? tokenServerUrlOverride,
  }) async {
    _settings = _settings.copyWith(
      saveHistory: saveHistory,
      autoPlayAudio: autoPlayAudio,
      tokenServerUrlOverride: tokenServerUrlOverride,
    );
    if (tokenServerUrlOverride != null) {
      AppConfig.setTokenServerUrlOverride(tokenServerUrlOverride);
    }
    await _settingsStorage.save(_settings);
    notifyListeners();
  }

  // ---- Pending utterance (transcript merge) ----
  void _startPending(TranslationDirection dir) {
    _pending = ConversationMessage(
      timestamp: DateTime.now(),
      direction: dir,
      sourceLanguageCode: dir.sourceCode(languageA: _languageA.code, languageB: _languageB.code),
      targetLanguageCode: dir.targetCode(languageA: _languageA.code, languageB: _languageB.code),
      inputTranscript: '',
      outputTranscript: '',
    );
  }

  void _appendPending({String? input, String? output}) {
    _pending ??= ConversationMessage(
      timestamp: DateTime.now(),
      direction: _activeDirection ?? TranslationDirection.aToB,
      sourceLanguageCode: _languageA.code,
      targetLanguageCode: _languageB.code,
      inputTranscript: '',
      outputTranscript: '',
    );
    _pending = _pending!.copyWith(
      inputTranscript: input == null ? null : '${_pending!.inputTranscript}$input',
      outputTranscript: output == null ? null : '${_pending!.outputTranscript}$output',
    );
    notifyListeners();
  }

  void _finalizePending() {
    final p = _pending;
    _pending = null;
    if (p == null) return;
    // Discard truly empty turns (e.g. empty transcript from Gemini).
    if (p.inputTranscript.trim().isEmpty && p.outputTranscript.trim().isEmpty) {
      notifyListeners();
      return;
    }
    addMessage(p);
  }

  void _discardPending() {
    if (_pending != null) {
      _pending = null;
      notifyListeners();
    }
  }

  // ---- Session/connection teardown ----
  Future<void> _stopMic() async {
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _audioInput.stop();
    } catch (_) {/* recorder may already be stopped */}
  }

  Future<void> _teardownConnection() async {
    _intentionalClose = true;
    _cancelIdleTimer();
    await _wsSub?.cancel();
    _wsSub = null;
    final client = _client;
    _client = null;
    _connectedDirection = null;
    _connectedToken = null;
    await client?.close();
    await _audioOutput.clear();
  }

  Future<void> _hardResetSessions() async {
    _tokenSeq++;
    await _stopMic();
    _usageStop();
    await _teardownConnection();
    _discardPending();
    _activeDirection = null;
    _flow = TranslatorFlowState.idle;
    _status = SessionStatus.idle;
    _lastError = null;
  }

  Future<void> _failActive(String message) async {
    await _stopMic();
    _usageStop();
    await _teardownConnection();
    _discardPending();
    _activeDirection = null;
    _lastError = message;
    _flow = TranslatorFlowState.error;
    _status = SessionStatus.error;
    notifyListeners();
  }

  void _setError(String message) {
    _activeDirection = null;
    _lastError = message;
    _flow = TranslatorFlowState.error;
    _status = SessionStatus.error;
    notifyListeners();
  }

  // ---- Idle timer ----
  void _startIdleTimer() {
    _cancelIdleTimer();
    _idleTimer = Timer(idleTimeout, () {
      _teardownConnection();
      _flow = TranslatorFlowState.idle;
      _status = SessionStatus.idle;
      notifyListeners();
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  // ---- Usage ----
  void _usageStart() {
    _usage.start(DateTime.now());
    _usageTicker?.cancel();
    _usageTicker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }

  void _usageStop() {
    _usageTicker?.cancel();
    _usageTicker = null;
    if (_usage.isRunning) {
      _usage.stop(DateTime.now());
      _settingsStorage.saveUsageToday(_usage.todayKey, _usage.todayElapsed().inSeconds);
    }
  }

  // ---- Helpers ----
  Future<bool> _ensureMicPermission() async {
    if (await _audioInput.hasPermission()) return true;
    return _audioInput.requestPermission();
  }

  bool _stale(int seq, TranslationDirection dir) =>
      seq != _tokenSeq || _activeDirection != dir;

  String _friendly(String message) {
    debugPrint('Friendly raw message: $message');
    if (message.isEmpty) return 'Please try again';
    return message;
  }

  Future<void> _persistLanguages() async {
    _settings = _settings.copyWith(
      staffLanguageCode: _languageA.code,
      guestLanguageCode: _languageB.code,
    );
    await _settingsStorage.save(_settings);
  }

  @override
  void dispose() {
    _cancelIdleTimer();
    _usageTicker?.cancel();
    _micSub?.cancel();
    _wsSub?.cancel();
    _client?.close();
    _audioOutput.dispose();
    _tokenApi.dispose();
    super.dispose();
  }
}
