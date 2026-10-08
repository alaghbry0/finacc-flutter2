/// اختبارات منطق PIN في التأسيس (موجة UX-fix — P2-9/P2-10):
///
/// - **P2-10**: `backToPin` من قسم عبارة المرور يعود لوضع تأكيد PIN
///   **مع حفظ الـ PIN الأول** — إعادة إدخال التأكيد فقط (كان يُصفَّر
///   كاملاً فيُعاد إدخال الـ PIN مرتين من جديد).
/// - حدود الإدخال: السقف 6 خانات، والحد الأدنى 4 لقبول المتابعة.
/// - عدم التطابق يعيد إدخال التأكيد فقط (الأول يبقى).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/ui/features/onboarding_auth/view_models/onboarding_view_model.dart';

void main() {
  OnboardingViewModel boot() {
    final vm = OnboardingViewModel();
    vm.goTo(OnboardingStep.security);
    return vm;
  }

  /// يُدخل PIN من ست خانات (يحاكي لوحة الأرقام بلا إرسال تلقائي —
  /// الإرسال التلقائي سلوك الواجهة ويغطيه اختبار الرحلة الكاملة).
  void enterSix(OnboardingViewModel vm, String pin) {
    for (final ch in pin.split('')) {
      vm.addPinDigit(int.parse(ch));
    }
  }

  group('P2-10 — backToPin يحفظ الـ PIN الأول', () {
    test('العودة من عبارة المرور تعيد التأكيد فقط ثم التطابق يكمل', () {
      final vm = boot();

      // رحلة كاملة حتى قسم عبارة المرور.
      enterSix(vm, '456789');
      expect(vm.pinContinuePressed(), isFalse, reason: 'انتقل للتأكيد');
      expect(vm.confirmingPin, isTrue);
      enterSix(vm, '456789');
      expect(vm.pinContinuePressed(), isTrue, reason: 'تطابق ← عبارة المرور');
      expect(vm.passphraseMode, isTrue);

      // العودة من عبارة المرور: وضع تأكيد والـ الأول محفوظ.
      vm.backToPin();
      expect(vm.passphraseMode, isFalse);
      expect(vm.confirmingPin, isTrue);
      expect(vm.pinForDots, '', reason: 'إعادة إدخال التأكيد فقط');
      expect(vm.pinDotsLength, 6, reason: 'طول العرض من الـ PIN المحفوظ');

      // تأكيد واحد (لا إدخالين) يعيدنا لعبارة المرور.
      enterSix(vm, '456789');
      expect(vm.pinContinuePressed(), isTrue);
      expect(vm.passphraseMode, isTrue);
    });

    test('عدم التطابق يعيد التأكيد فقط (الـ PIN الأول يبقى)', () {
      final vm = boot();
      enterSix(vm, '111222');
      vm.pinContinuePressed();
      enterSix(vm, '999000');
      expect(vm.pinContinuePressed(), isFalse, reason: 'لا تطابق');
      expect(vm.error, OnboardingError.pinMismatch);
      expect(vm.confirmingPin, isTrue);
      expect(vm.pinForDots, '', reason: 'التأكيد صُفِّر للأعادة');

      // الـ PIN الأول ما زال محفوظاً: التأكيد الصحيح يمر مباشرة.
      enterSix(vm, '111222');
      expect(vm.pinContinuePressed(), isTrue);
      expect(vm.passphraseMode, isTrue);
    });
  });

  group('حدود الإدخال', () {
    test('السقف 6 خانات — الرقم السابع يُهمل', () {
      final vm = boot();
      enterSix(vm, '123456');
      vm.addPinDigit(7);
      expect(vm.pinForDots, '123456');
    });

    test('أقل من 4 خانات يُرفض وأربعة تُقبل (بلا إرسال تلقائي)', () {
      final vm = boot();
      enterSix(vm, '123');
      expect(vm.pinContinuePressed(), isFalse);
      expect(vm.error, OnboardingError.pinInvalidLength);
      expect(vm.confirmingPin, isFalse);

      vm.addPinDigit(4);
      expect(vm.pinContinuePressed(), isFalse, reason: 'انتقل للتأكيد');
      expect(vm.confirmingPin, isTrue);
      expect(vm.pinDotsLength, 4, reason: 'العرض بطول الـ PIN المُدخل');
    });

    test('backspace يمس خانة واحدة من الإدخال الجاري', () {
      final vm = boot();
      enterSix(vm, '1234');
      vm.backspacePin();
      expect(vm.pinForDots, '123');
    });
  });
}
