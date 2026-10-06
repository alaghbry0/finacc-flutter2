/// اختبارات سياسة قفل PIN — الجدول المتدرج وعتبة عبارة المرور (FR-12-06).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/use_cases/pin_policy.dart';

void main() {
  group('PinPolicy.lockoutDelay — الجدول المتدرج', () {
    test('أقل من 5 محاولات: لا انتظار', () {
      for (final attempts in [0, 1, 2, 3, 4]) {
        expect(
          PinPolicy.lockoutDelay(attempts),
          isNull,
          reason: 'المحاولة $attempts لا توجب انتظاراً',
        );
      }
    });

    test('5→30 ثانية، 6→دقيقتان، 7→5 دقائق، 8→10 دقائق، 9→15 دقيقة', () {
      expect(PinPolicy.lockoutDelay(5), const Duration(seconds: 30));
      expect(PinPolicy.lockoutDelay(6), const Duration(minutes: 2));
      expect(PinPolicy.lockoutDelay(7), const Duration(minutes: 5));
      expect(PinPolicy.lockoutDelay(8), const Duration(minutes: 10));
      expect(PinPolicy.lockoutDelay(9), const Duration(minutes: 15));
    });

    test('10 فأكثر: لا جدول زمني — البوابة على عبارة المرور', () {
      expect(PinPolicy.lockoutDelay(10), isNull);
      expect(PinPolicy.lockoutDelay(15), isNull);
    });

    test('lockedUntilAfter يضيف المدة إلى اللحظة الحالية', () {
      final now = DateTime(2026, 10, 6, 13, 0, 0);
      expect(
        PinPolicy.lockedUntilAfter(5, now),
        DateTime(2026, 10, 6, 13, 0, 30),
      );
      expect(PinPolicy.lockedUntilAfter(4, now), isNull);
      expect(PinPolicy.lockedUntilAfter(10, now), isNull);
    });
  });

  group('PinPolicy.statusFor — حالة البوابة', () {
    final now = DateTime(2026, 10, 6, 13);

    test('مفتوحة عند عدّاد منخفض ولا قفل جارٍ', () {
      expect(
        PinPolicy.statusFor(failedAttempts: 0, now: now, lockedUntil: null),
        PinGateStatus.open,
      );
    });

    test('متأخرة داخل نافذة الانتظار', () {
      expect(
        PinPolicy.statusFor(
          failedAttempts: 5,
          now: now,
          lockedUntil: now.add(const Duration(seconds: 20)),
        ),
        PinGateStatus.delayed,
      );
    });

    test('مفتوحة بعد انقضاء نافذة الانتظار (العدّاد دون العتبة العليا)', () {
      expect(
        PinPolicy.statusFor(
          failedAttempts: 5,
          now: now,
          lockedUntil: now.subtract(const Duration(seconds: 1)),
        ),
        PinGateStatus.open,
      );
    });

    test('عبارة المرور إلزامية عند 10 محاولات ولو انقضى أي انتظار', () {
      expect(
        PinPolicy.statusFor(failedAttempts: 10, now: now, lockedUntil: null),
        PinGateStatus.passphraseRequired,
      );
      expect(
        PinPolicy.statusFor(
          failedAttempts: 12,
          now: now,
          lockedUntil: now.subtract(const Duration(minutes: 5)),
        ),
        PinGateStatus.passphraseRequired,
      );
    });
  });

  group('PinPolicy.remainingDelay', () {
    test('صفر بلا قفل أو بعد انقضائه، والمتبقي خلاف ذلك', () {
      final now = DateTime(2026, 10, 6, 13);
      expect(
        PinPolicy.remainingDelay(now: now, lockedUntil: null),
        Duration.zero,
      );
      expect(
        PinPolicy.remainingDelay(
          now: now,
          lockedUntil: now.subtract(const Duration(seconds: 1)),
        ),
        Duration.zero,
      );
      expect(
        PinPolicy.remainingDelay(
          now: now,
          lockedUntil: now.add(const Duration(seconds: 25)),
        ),
        const Duration(seconds: 25),
      );
    });
  });
}
