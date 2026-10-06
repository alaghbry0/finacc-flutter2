/// اختبارات تجزئة PIN — PBKDF2-HMAC-SHA256 (100k دورة + ملح 16 بايت).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/services/pin_hasher.dart';

void main() {
  group('PinHasher', () {
    test('صيغة المخزن: scheme\$iterations\$ملح\$تجزئة بلا بيانات خام', () {
      final stored = PinHasher.hash('1234');
      expect(stored.startsWith('pbkdf2-sha256\$100000\$'), isTrue);
      expect(stored.contains('1234'), isFalse,
          reason: 'النص الخام لا يجوز ظهوره في المخزن');
      final parts = stored.split(r'$');
      expect(parts, hasLength(4));
      expect(parts[2].length, 32, reason: 'ملح 16 بايت = 32 محرفاً سداسياً');
      expect(parts[3].length, 64, reason: 'مفتاح 32 بايت = 64 محرفاً');
    });

    test('verify يقبل الصحيح ويرفض الخاطئ', () {
      final stored = PinHasher.hash('998877');
      expect(PinHasher.verify('998877', stored), isTrue);
      expect(PinHasher.verify('998876', stored), isFalse);
      expect(PinHasher.verify('', stored), isFalse);
    });

    test('كل تجزئة بملح فريد — نفس الرمز ينتج مخازن مختلفة', () {
      final a = PinHasher.hash('4321');
      final b = PinHasher.hash('4321');
      expect(a, isNot(b));
      // وكلاهما يتحقق.
      expect(PinHasher.verify('4321', a), isTrue);
      expect(PinHasher.verify('4321', b), isTrue);
    });

    test('صيغ الإدخال: PIN من 4-6 خانات رقمية وعبارة ≥ 8', () {
      expect(PinHasher.isValidPinFormat('1234'), isTrue);
      expect(PinHasher.isValidPinFormat('123456'), isTrue);
      expect(PinHasher.isValidPinFormat('123'), isFalse);
      expect(PinHasher.isValidPinFormat('1234567'), isFalse);
      expect(PinHasher.isValidPinFormat('12a4'), isFalse);
      expect(PinHasher.isValidPinFormat(''), isFalse);
      expect(PinHasher.isValidPassphrase('12345678'), isTrue);
      expect(PinHasher.isValidPassphrase('short'), isFalse);
    });

    test('مخزن تالف يُرفض بأمان لا باستثناء', () {
      expect(PinHasher.verify('1234', 'garbage'), isFalse);
      expect(PinHasher.verify('1234', ''), isFalse);
      expect(PinHasher.verify('1234', 'pbkdf2-sha256\$100000\$zz\$yy'), isFalse);
    });
  });
}
