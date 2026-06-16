import '../../features/translator/domain/language_option.dart';

/// Supported languages, expressed with BCP-47 codes.
///
/// To add a language, just append a [LanguageOption] to [kSupportedLanguages].
/// "Popular" ones (popular: true) are surfaced at the top of the picker.
class Languages {
  Languages._();

  /// Default language A on first launch (staff).
  static const String defaultLanguageA = 'tr';

  /// Default language B on first launch (guest).
  static const String defaultLanguageB = 'en';

  /// Popular languages, shown first in the picker (order preserved).
  static const List<LanguageOption> popular = [
    LanguageOption(code: 'tr', name: 'Turkish', nativeName: 'Türkçe', popular: true),
    LanguageOption(code: 'en', name: 'English', nativeName: 'English', popular: true),
    LanguageOption(code: 'ar', name: 'Arabic', nativeName: 'العربية', popular: true),
    LanguageOption(code: 'ru', name: 'Russian', nativeName: 'Русский', popular: true),
    LanguageOption(code: 'de', name: 'German', nativeName: 'Deutsch', popular: true),
    LanguageOption(code: 'fr', name: 'French', nativeName: 'Français', popular: true),
    LanguageOption(code: 'es', name: 'Spanish', nativeName: 'Español', popular: true),
    LanguageOption(code: 'it', name: 'Italian', nativeName: 'Italiano', popular: true),
    LanguageOption(code: 'fa', name: 'Persian', nativeName: 'فارسی', popular: true),
    LanguageOption(code: 'uk', name: 'Ukrainian', nativeName: 'Українська', popular: true),
    LanguageOption(code: 'zh-Hans', name: 'Chinese (Simplified)', nativeName: '简体中文', popular: true),
    LanguageOption(code: 'zh-Hant', name: 'Chinese (Traditional)', nativeName: '繁體中文', popular: true),
    LanguageOption(code: 'ja', name: 'Japanese', nativeName: '日本語', popular: true),
    LanguageOption(code: 'ko', name: 'Korean', nativeName: '한국어', popular: true),
    LanguageOption(code: 'pt-BR', name: 'Portuguese (Brazil)', nativeName: 'Português (Brasil)', popular: true),
  ];

  /// Additional languages (expand freely).
  static const List<LanguageOption> more = [
    LanguageOption(code: 'pt-PT', name: 'Portuguese (Portugal)', nativeName: 'Português (Portugal)'),
    LanguageOption(code: 'nl', name: 'Dutch', nativeName: 'Nederlands'),
    LanguageOption(code: 'pl', name: 'Polish', nativeName: 'Polski'),
    LanguageOption(code: 'ro', name: 'Romanian', nativeName: 'Română'),
    LanguageOption(code: 'el', name: 'Greek', nativeName: 'Ελληνικά'),
    LanguageOption(code: 'sv', name: 'Swedish', nativeName: 'Svenska'),
    LanguageOption(code: 'no', name: 'Norwegian', nativeName: 'Norsk'),
    LanguageOption(code: 'da', name: 'Danish', nativeName: 'Dansk'),
    LanguageOption(code: 'fi', name: 'Finnish', nativeName: 'Suomi'),
    LanguageOption(code: 'cs', name: 'Czech', nativeName: 'Čeština'),
    LanguageOption(code: 'hu', name: 'Hungarian', nativeName: 'Magyar'),
    LanguageOption(code: 'bg', name: 'Bulgarian', nativeName: 'Български'),
    LanguageOption(code: 'sr', name: 'Serbian', nativeName: 'Српски'),
    LanguageOption(code: 'hr', name: 'Croatian', nativeName: 'Hrvatski'),
    LanguageOption(code: 'sk', name: 'Slovak', nativeName: 'Slovenčina'),
    LanguageOption(code: 'he', name: 'Hebrew', nativeName: 'עברית'),
    LanguageOption(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
    LanguageOption(code: 'ur', name: 'Urdu', nativeName: 'اردو'),
    LanguageOption(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
    LanguageOption(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia'),
    LanguageOption(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu'),
    LanguageOption(code: 'th', name: 'Thai', nativeName: 'ไทย'),
    LanguageOption(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
    LanguageOption(code: 'fil', name: 'Filipino', nativeName: 'Filipino'),
    LanguageOption(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili'),
    LanguageOption(code: 'az', name: 'Azerbaijani', nativeName: 'Azərbaycanca'),
    LanguageOption(code: 'kk', name: 'Kazakh', nativeName: 'Қазақша'),
    LanguageOption(code: 'uz', name: 'Uzbek', nativeName: 'Oʻzbekcha'),
  ];

  /// Full list (popular first, then the rest).
  static const List<LanguageOption> all = [...popular, ...more];

  /// Look up a language by code; returns null if unknown.
  static LanguageOption? byCode(String code) {
    for (final l in all) {
      if (l.code == code) return l;
    }
    return null;
  }

  /// Look up a language by code, falling back to a synthetic entry so the UI
  /// never crashes on an unexpected code.
  static LanguageOption byCodeOrFallback(String code) {
    return byCode(code) ?? LanguageOption(code: code, name: code, nativeName: code);
  }
}
