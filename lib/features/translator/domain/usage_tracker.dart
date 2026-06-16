/// Tracks active microphone-sending time only.
///
/// Not a billing system — but structured so it can later become a credit/
/// subscription meter. Pure & clock-injectable for deterministic tests.
class UsageTracker {
  UsageTracker({DateTime? now}) : _dateKey = dateKeyFor(now ?? DateTime.now());

  Duration _session = Duration.zero;
  Duration _today = Duration.zero;
  String _dateKey;
  DateTime? _runningSince;

  static String dateKeyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get todayKey => _dateKey;
  bool get isRunning => _runningSince != null;

  /// Seed today's persisted total (e.g. from local storage on launch).
  void loadToday({required String dateKey, required Duration total}) {
    _dateKey = dateKey;
    _today = total;
  }

  /// Begin counting active time.
  void start(DateTime now) {
    _rollover(now);
    _runningSince ??= now;
  }

  /// Stop counting; accumulates the elapsed active time.
  void stop(DateTime now) {
    if (_runningSince == null) return;
    final delta = now.difference(_runningSince!);
    if (delta > Duration.zero) {
      _session += delta;
      _today += delta;
    }
    _runningSince = null;
  }

  Duration sessionElapsed([DateTime? now]) => _session + _liveDelta(now);
  Duration todayElapsed([DateTime? now]) => _today + _liveDelta(now);

  Duration _liveDelta(DateTime? now) {
    if (_runningSince == null) return Duration.zero;
    final t = now ?? DateTime.now();
    final d = t.difference(_runningSince!);
    return d > Duration.zero ? d : Duration.zero;
  }

  void _rollover(DateTime now) {
    final key = dateKeyFor(now);
    if (key != _dateKey) {
      _dateKey = key;
      _today = Duration.zero;
    }
  }

  /// mm:ss formatter for the UI.
  static String format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
