/// Which way a translation is flowing.
///
/// Direction is decided strictly by which push-to-talk button is held — there
/// is no automatic speaker/language detection in this MVP.
enum TranslationDirection {
  /// Speaker A (staff) → Speaker B (guest). Target language = B.
  aToB,

  /// Speaker B (guest) → Speaker A (staff). Target language = A.
  bToA;

  /// Wire value used by the backend (`direction` field).
  String get wireValue => this == TranslationDirection.aToB ? 'A_TO_B' : 'B_TO_A';

  TranslationDirection get reversed =>
      this == TranslationDirection.aToB ? TranslationDirection.bToA : TranslationDirection.aToB;

  /// Source language code for this direction given the two configured languages.
  String sourceCode({required String languageA, required String languageB}) =>
      this == TranslationDirection.aToB ? languageA : languageB;

  /// Target language code for this direction given the two configured languages.
  String targetCode({required String languageA, required String languageB}) =>
      this == TranslationDirection.aToB ? languageB : languageA;

  /// Short human label.
  String get label =>
      this == TranslationDirection.aToB ? 'Staff → Guest' : 'Guest → Staff';
}
