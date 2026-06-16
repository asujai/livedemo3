import 'package:flutter/foundation.dart';

import '../../../core/constants/languages.dart';

/// User-configurable settings, persisted locally (never leaves the device).
@immutable
class AppSettings {
  const AppSettings({
    required this.staffLanguageCode,
    required this.guestLanguageCode,
    required this.saveHistory,
    required this.autoPlayAudio,
    required this.tokenServerUrlOverride,
  });

  final String staffLanguageCode;
  final String guestLanguageCode;
  final bool saveHistory;
  final bool autoPlayAudio;

  /// User override for the token server URL. Empty => use build-time default.
  final String tokenServerUrlOverride;

  static const AppSettings defaults = AppSettings(
    staffLanguageCode: Languages.defaultLanguageA,
    guestLanguageCode: Languages.defaultLanguageB,
    saveHistory: true,
    autoPlayAudio: true,
    tokenServerUrlOverride: '',
  );

  AppSettings copyWith({
    String? staffLanguageCode,
    String? guestLanguageCode,
    bool? saveHistory,
    bool? autoPlayAudio,
    String? tokenServerUrlOverride,
  }) {
    return AppSettings(
      staffLanguageCode: staffLanguageCode ?? this.staffLanguageCode,
      guestLanguageCode: guestLanguageCode ?? this.guestLanguageCode,
      saveHistory: saveHistory ?? this.saveHistory,
      autoPlayAudio: autoPlayAudio ?? this.autoPlayAudio,
      tokenServerUrlOverride: tokenServerUrlOverride ?? this.tokenServerUrlOverride,
    );
  }
}
