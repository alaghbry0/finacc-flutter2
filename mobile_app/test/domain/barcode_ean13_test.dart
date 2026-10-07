/// اختبارات مولّد الباركود EAN-13 — FR-01-02 (نطاق المتجر 200–299).
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/services/barcode_ean13.dart';

void main() {
  const generator = Ean13Generator();

  group('checkDigit — خانة التحقق mod-10', () {
    test('متجهات معروفة (أوزان 1،3 متناوبة من اليسار)', () {
      // 4006381333931 = قلم سويسري كلاسيكي (EAN قياسي).
      expect(generator.checkDigit('400638133393'), 1);
      // 200000000000: مجموع 2 → (10 − 2) % 10 = 8.
      expect(generator.checkDigit('200000000000'), 8);
      expect(generator.checkDigit('200000000001'), 5);
      expect(generator.checkDigit('200000000002'), 2);
      expect(generator.checkDigit('299999999999'), 1);
    });

    test('يرمي ArgumentError لمدخل ليس 12 رقماً', () {
      expect(() => generator.checkDigit('12345'), throwsArgumentError);
      expect(() => generator.checkDigit('1234567890123'), throwsArgumentError);
      expect(() => generator.checkDigit(''), throwsArgumentError);
    });

    test('يرمي ArgumentError لمحارف غير رقمية', () {
      expect(() => generator.checkDigit('40063813339X'), throwsArgumentError);
      expect(() => generator.checkDigit('40063813339 '), throwsArgumentError);
    });
  });

  group('generate — التوليد بنطاق المتجر', () {
    test('100 باركود متولّدة: كلها EAN-13 سليمة بنطاق 200–299', () {
      for (var i = 0; i < 100; i++) {
        final code = generator.generate();
        expect(code, hasLength(13), reason: 'الطول 13 رقماً');
        expect(code.startsWith('2'), isTrue, reason: 'الرقم الأول «2»');
        expect(RegExp(r'^\d{13}$').hasMatch(code), isTrue);
        final prefix = int.parse(code.substring(0, 3));
        expect(prefix, inInclusiveRange(200, 299));
        expect(
          Ean13Generator.isValidEan13(code),
          isTrue,
          reason: 'خانة التحقق سليمة: $code',
        );
      }
    });

    test('بذرة ثابتة ← نتائج قابلة للتكرار', () {
      final a = generator.generate(random: Random(42));
      final b = generator.generate(random: Random(42));
      expect(a, b);
      final seq1 = List.generate(
        5,
        (_) => generator.generate(random: Random(7)),
      );
      final seq2 = List.generate(
        5,
        (_) => generator.generate(random: Random(7)),
      );
      expect(seq1, seq2);
    });
  });

  group('isValidEan13 — التحقق الشامل', () {
    test('يقبل باركوداً سليماً ويرفض العبث بأي خانة', () {
      const valid = '2000000000008';
      expect(Ean13Generator.isValidEan13(valid), isTrue);
      // عبث بخانة التحقق.
      expect(Ean13Generator.isValidEan13('2000000000009'), isFalse);
      // عبث بخانة بيانات تكسر المجموع.
      expect(Ean13Generator.isValidEan13('2000000000108'), isFalse);
      // طول خاطئ.
      expect(Ean13Generator.isValidEan13('200000000000'), isFalse);
      expect(Ean13Generator.isValidEan13('20000000000088'), isFalse);
      // محارف غير رقمية.
      expect(Ean13Generator.isValidEan13('200000000000A'), isFalse);
      expect(Ean13Generator.isValidEan13(''), isFalse);
    });
  });
}
