import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';

/// Persists [AppSettings] using SharedPreferences (local only).
class SettingsStorage {
  static const _kStaff = 'settings.staffLanguageCode';
  static const _kGuest = 'settings.guestLanguageCode';
  static const _kSaveHistory = 'settings.saveHistory';
  static const _kAutoPlay = 'settings.autoPlayAudio';
  static const _kServerUrl = 'settings.tokenServerUrl';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      staffLanguageCode: prefs.getString(_kStaff) ?? AppSettings.defaults.staffLanguageCode,
      guestLanguageCode: prefs.getString(_kGuest) ?? AppSettings.defaults.guestLanguageCode,
      saveHistory: prefs.getBool(_kSaveHistory) ?? AppSettings.defaults.saveHistory,
      autoPlayAudio: prefs.getBool(_kAutoPlay) ?? AppSettings.defaults.autoPlayAudio,
      tokenServerUrlOverride:
          prefs.getString(_kServerUrl) ?? AppSettings.defaults.tokenServerUrlOverride,
    );
  }

  Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStaff, s.staffLanguageCode);
    await prefs.setString(_kGuest, s.guestLanguageCode);
    await prefs.setBool(_kSaveHistory, s.saveHistory);
    await prefs.setBool(_kAutoPlay, s.autoPlayAudio);
    await prefs.setString(_kServerUrl, s.tokenServerUrlOverride);
  }

  // ---- Usage meter persistence (today's active-mic seconds) ----
  static const _kUsageDate = 'usage.date';
  static const _kUsageSeconds = 'usage.seconds';

  /// Returns today's stored usage; 0 if the stored value is from another day.
  Future<({String dateKey, int seconds})> loadUsageToday(String todayKey) async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_kUsageDate);
    if (storedDate == todayKey) {
      return (dateKey: todayKey, seconds: prefs.getInt(_kUsageSeconds) ?? 0);
    }
    return (dateKey: todayKey, seconds: 0);
  }

  Future<void> saveUsageToday(String dateKey, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsageDate, dateKey);
    await prefs.setInt(_kUsageSeconds, seconds);
  }
}
