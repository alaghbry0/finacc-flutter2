/// اختبارات نظام الأرقام (western ↔ arabic_indic) — `display.numerals`.
///
/// التحويل عرضي صرف: التخزين يبقى دائماً بأرقام غربية.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/services/numerals.dart';

void main() {
  group('Numerals.toArabicIndic', () {
    test('الأرقام المجردة', () {
      expect(Numerals.toArabicIndic('0'), '٠');
      expect(Numerals.toArabicIndic('9'), '٩');
      expect(Numerals.toArabicIndic('123456'), '١٢٣٤٥٦');
    });

    test('المبالغ المنسقة: الفواصل والكسور بأشكال عربية قياسية', () {
      // U+066C (٬) للمئات وU+066B (٫) للكسور.
      expect(Numerals.toArabicIndic('1,234.50'), '١٬٢٣٤٫٥٠');
      expect(Numerals.toArabicIndic('0.00'), '٠٫٠٠');
      expect(Numerals.toArabicIndic('1,000,000'), '١٬٠٠٠٬٠٠٠');
    });

    test('النصوص المختلطة: الحروف تبقى والأرقام تتحول', () {
      expect(Numerals.toArabicIndic('INV-2026-001'), 'INV-٢٠٢٦-٠٠١');
      expect(
        Numerals.toArabicIndic('المحاولة 3 من 10'),
        'المحاولة ٣ من ١٠',
      );
    });

    test('سلسلة فارغة تبقى فارغة', () {
      expect(Numerals.toArabicIndic(''), '');
    });
  });

  group('Numerals.toWestern', () {
    test('استرجاع الأرقام الشرقية إلى غربية', () {
      expect(Numerals.toWestern('١٢٣٤٥٦'), '123456');
      expect(Numerals.toWestern('١٬٢٣٤٫٥٠'), '1,234.50');
    });

    test('دورة كاملة: غربي ← شرقي ← غربي بلا فقد', () {
      for (final original in ['7', '1,234.50', '0.00', '999,999.99', '42']) {
        final roundtrip = Numerals.toWestern(
          Numerals.toArabicIndic(original),
        );
        expect(roundtrip, original);
      }
    });

    test('مدخلات غربية تمر كما هي', () {
      expect(Numerals.toWestern('123'), '123');
      expect(Numerals.toWestern('abc'), 'abc');
    });
  });
}
