import 'package:flutter_test/flutter_test.dart';
import 'package:tilo_translate/core/constants/languages.dart';
import 'package:tilo_translate/features/translator/domain/language_option.dart';

void main() {
  group('Languages', () {
    test('defaults are Turkish (staff) and English (guest)', () {
      expect(Languages.defaultLanguageA, 'tr');
      expect(Languages.defaultLanguageB, 'en');
      expect(Languages.byCode('tr')?.name, 'Turkish');
      expect(Languages.byCode('en')?.name, 'English');
    });

    test('popular languages appear before the rest in `all`', () {
      final firstPopularIndex = Languages.all.indexWhere((l) => l.code == 'tr');
      final firstNonPopular = Languages.all.indexWhere((l) => !l.popular);
      expect(firstPopularIndex, lessThan(firstNonPopular));
    });

    test('byCodeOrFallback never returns null', () {
      final unknown = Languages.byCodeOrFallback('xx-YY');
      expect(unknown.code, 'xx-YY');
    });

    group('search filtering (matches)', () {
      LanguageOption byCode(String c) => Languages.byCode(c)!;

      test('matches by English name (case-insensitive)', () {
        expect(byCode('de').matches('german'), isTrue);
        expect(byCode('de').matches('GERMAN'), isTrue);
      });

      test('matches by native name', () {
        expect(byCode('tr').matches('Türkçe'), isTrue);
        expect(byCode('ja').matches('日本語'), isTrue);
      });

      test('matches by code', () {
        expect(byCode('pt-BR').matches('pt-br'), isTrue);
        expect(byCode('zh-Hans').matches('zh-hans'), isTrue);
      });

      test('non-match returns false', () {
        expect(byCode('en').matches('zzzz'), isFalse);
      });

      test('empty query matches everything', () {
        expect(byCode('en').matches(''), isTrue);
      });
    });
  });
}
