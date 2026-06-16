import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_error.dart';
import '../domain/live_translation_session.dart';
import '../domain/translation_direction.dart';

/// Talks to the backend token server to obtain short-lived Gemini Live tokens.
///
/// This is the ONLY way the app gets credentials — the Gemini API key never
/// lives in the mobile app.
class LiveTokenApi {
  LiveTokenApi({http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Base URL of the token server (without trailing slash).
  String get _baseUrl => AppConfig.tokenServerUrl;

  /// Fetch a token for the given [direction] and language pair.
  ///
  /// Throws [AppError] on any failure (mapped to friendly messages).
  Future<LiveTokenResult> fetchToken({
    required TranslationDirection direction,
    required String languageA,
    required String languageB,
  }) async {
    final source = direction.sourceCode(languageA: languageA, languageB: languageB);
    final target = direction.targetCode(languageA: languageA, languageB: languageB);

    if (source == target) {
      throw AppError.sameLanguage();
    }

    final uri = Uri.parse('$_baseUrl/api/live-token');
    final body = jsonEncode({
      'sourceLanguageCode': source,
      'targetLanguageCode': target,
      'direction': direction.wireValue,
    });

    http.Response res;
    try {
      res = await _client
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout);
    } on TimeoutException catch (e) {
      throw AppError.backendOffline(e);
    } catch (e) {
      // SocketException / connection refused / DNS, etc.
      throw AppError.noInternet(e);
    }

    return _parseResponse(res);
  }

  LiveTokenResult _parseResponse(http.Response res) {
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      json = null;
    }

    if (res.statusCode == 200 && json != null && (json['token'] as String?)?.isNotEmpty == true) {
      return LiveTokenResult.fromJson(json);
    }

    final code = json?['error']?['code'] as String?;
    final serverMsg = json?['error']?['message'] as String?;
    debugPrint('LiveTokenApi error: HTTP ${res.statusCode} code=$code'); // never logs token/key

    switch (code) {
      case 'NOT_CONFIGURED':
        throw AppError.notConfigured();
      case 'SAME_LANGUAGE':
        throw AppError.sameLanguage();
      case 'RATE_LIMITED':
        throw AppError(AppErrorCode.tokenFetchFailed, 'Too many requests', detail: serverMsg);
      default:
        if (res.statusCode >= 500) {
          throw AppError.backendOffline();
        }
        throw AppError.tokenFetchFailed('HTTP ${res.statusCode}: $serverMsg');
    }
  }

  void dispose() => _client.close();
}
