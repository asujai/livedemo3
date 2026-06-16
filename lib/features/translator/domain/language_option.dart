import 'package:flutter/foundation.dart';

/// A selectable language, identified by its BCP-47 code.
@immutable
class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    this.popular = false,
  });

  /// BCP-47 code, e.g. "tr", "en", "pt-BR", "zh-Hans".
  final String code;

  /// English display name, e.g. "Turkish".
  final String name;

  /// Name in the language itself, e.g. "Türkçe".
  final String nativeName;

  /// Whether this language is shown in the "popular" section at the top.
  final bool popular;

  /// True if the [query] matches the name, native name or code.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        nativeName.toLowerCase().contains(q) ||
        code.toLowerCase().contains(q);
  }

  @override
  bool operator ==(Object other) =>
      other is LanguageOption && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'LanguageOption($code, $name)';
}
