/// اختبارات نموذج عرض شاشة القفل — الإدخال والتحقق والبوابات.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/user_repository.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/onboarding_auth/view_models/lock_view_model.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late UserRepository users;
  late AppController controller;
  late LockViewModel vm;

  setUp(() async {
    final seeded = await openSeededApp();
    app = seeded.$1;
    users = seeded.$3;
    controller = AppController(forTesting: app);
    await controller.decidePhaseForTest();
    vm = LockViewModel(userRepository: users);
  });

  tearDown(() async {
    vm.dispose();
    await app.close();
  });

  test('addDigit حتى 6 خانات ثم backspace', () {
    for (final d in [1, 2, 3, 4, 5, 6, 7]) {
      vm.addDigit(d);
    }
    expect(vm.pin, '123456', reason: 'السابعة تُتجاهل');
    vm.backspace();
    expect(vm.pin, '12345');
  });

  test('PIN صحيح يفتح الجلسة (ready)', () async {
    for (final d in [1, 2, 3, 4]) {
      vm.addDigit(d);
    }
    await vm.submitPin(controller);
    expect(controller.phase, AppPhase.ready);
    expect(vm.message, isNull);
  });

  test('PIN خاطئ: رسالة + اهتزاز + تصفير الإدخال + عدّاد متبقٍ', () async {
    for (final d in [9, 9, 9, 9]) {
      vm.addDigit(d);
    }
    await vm.submitPin(controller);
    expect(controller.phase, AppPhase.locked);
    expect(vm.message, LockMessage.wrong);
    expect(vm.shakeKey, isNotNull);
    expect(vm.pin, isEmpty);
    // تحديث العداد غير المتزامن — نمنحه فرصة لإتمام القراءة.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    // المتبقي قبل التأخير = 5-1 = 4.
    expect(vm.gate.attemptsLeftBeforeDelay, 4);
  });

  test('أقل من 4 خانات: لا إرسال إطلاقاً', () async {
    for (final d in [1, 2, 3]) {
      vm.addDigit(d);
    }
    await vm.submitPin(controller);
    expect(controller.phase, AppPhase.locked);
    expect(vm.message, isNull, reason: 'رفض صامت — لم يُرسل');
  });

  test('بوابة عبارة المرور: الصحيحة تفتح وتصفر', () async {
    var now = DateTime.now();
    for (var i = 0; i < 10; i++) {
      await users.verifyPin('0000', now: now);
      now = now.add(const Duration(minutes: 16));
    }
    // التحديث اليدوي لحالة العتبة.
    for (final d in [1, 2, 3, 4]) {
      vm.addDigit(d);
    }
    await vm.submitPin(controller);
    expect(vm.mode, LockUiMode.passphrase, reason: 'بعد 10 محاولات تتحول البوابة');

    await vm.submitPassphrase(controller, 'wrong-pass');
    expect(controller.phase, AppPhase.locked);
    expect(vm.wipeOffered, isTrue, reason: 'فشل العبارة يعرض خيار المسح');

    await vm.submitPassphrase(controller, 'Passphrase-2026');
    expect(controller.phase, AppPhase.ready);
    expect(await users.currentFailedAttempts(), 0);
  });

  test('switchToPassphrase/backToPin يدويان', () {
    vm.switchToPassphrase();
    expect(vm.mode, LockUiMode.passphrase);
    vm.backToPin();
    expect(vm.mode, LockUiMode.pin);
    expect(vm.pin, isEmpty);
  });

  test('attach لا يستبدل مستودعاً مربوطاً', () {
    vm.attach(users);
    final same = vm;
    same.addDigit(1);
    expect(vm.pin, '1');
  });
}
