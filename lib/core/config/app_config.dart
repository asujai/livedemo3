import 'package:flutter/foundation.dart';

/// Central app configuration.
///
/// The backend (token server) URL is provided at build time via:
///   flutter run --dart-define=TOKEN_SERVER_URL=http://10.0.2.2:8787
///
/// Defaults:
///   - Android emulator : http://10.0.2.2:8787  (host machine loopback)
///   - Physical device  : http://<your-LAN-IP>:8787
///   - Production        : https://your-backend.example.com
///
/// The value can also be overridden at runtime from the Settings screen
/// (wired up in a later stage); use [tokenServerUrl] as the single source of
/// truth and [setTokenServerUrlOverride] to change it.
class AppConfig {
  AppConfig._();

  static const String _buildTimeUrl = String.fromEnvironment(
    'TOKEN_SERVER_URL',
    defaultValue: 'http://192.168.1.17:8787',
  );

  /// Runtime override (e.g. set from Settings). Null = use build-time value.
  static final ValueNotifier<String?> _override = ValueNotifier<String?>(null);

  /// Listenable so UI can react to changes.
  static ValueListenable<String?> get tokenServerUrlListenable => _override;

  /// Effective token server base URL (no trailing slash).
  static String get tokenServerUrl {
    var raw = (_override.value?.trim().isNotEmpty ?? false)
        ? _override.value!.trim()
        : _buildTimeUrl;
    if (raw.toLowerCase().contains('pc_lan_ip')) {
      raw = raw.replaceAll(RegExp('pc_lan_ip', caseSensitive: false), '192.168.1.17');
    }
    
    // Replace any local IP (like 192.168.x.x, 10.x.x.x, or 172.x.x.x) with 192.168.1.17
    // so old settings stored on the physical device do not point to a stale IP.
    final ipRegex = RegExp(r'\b(?:192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(?:1[6-9]|2\d|3[01])\.\d+\.\d+)\b');
    if (ipRegex.hasMatch(raw) && !raw.contains('192.168.1.17')) {
      raw = raw.replaceAll(ipRegex, '192.168.1.17');
    }
    
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Override the server URL at runtime. Pass null/empty to fall back to build-time.
  static void setTokenServerUrlOverride(String? url) {
    _override.value = (url == null || url.trim().isEmpty) ? null : url.trim();
  }

  /// The Gemini Live Translate model id (kept in sync with the backend).
  static const String liveTranslateModel = 'gemini-3.5-live-translate-preview';
}
