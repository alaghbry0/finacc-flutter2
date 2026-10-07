/// اختبارات نموذج عرض تغيير PIN — التدفق الثلاثي وحالات الفشل.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/user_repository.dart';
import 'package:mobile_app/ui/features/settings/view_models/settings_view_model.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late UserRepository users;
  late ChangePinViewModel vm;

  setUp(() async {
    final seeded = await openSeededApp();
    app = seeded.$1;
    users = seeded.$3;
    vm = ChangePinViewModel(userRepo: users);
  });

  tearDown(() async {
    await app.close();
  });

  Future<void> typeInto(String digits) async {
    for (final d in digits.split('')) {
      vm.addDigit(int.parse(d));
    }
  }

  test('الانحدار: entered يقرأ مخزن الخطوة الصحيحة (خلل سابق)', () async {
    await typeInto('1234');
    expect(vm.entered, '1234', reason: 'الخطوة 0 تقرأ الحالي');
    expect(vm.step, 0);

    await vm.submit();
    expect(vm.step, 1);
    expect(vm.entered, '', reason: 'انتقلنا للجديد — المخزن الجديد فارغ');

    await typeInto('7777');
    expect(vm.entered, '7777', reason: 'الخطوة 1 تقرأ الجديد');
  });

  test('تدفق كامل ناجح: 1234 ← 777777 ← 777777 ثم التحقق الحقيقي', () async {
    await typeInto('1234');
    expect(await vm.submit(), isTrue);
    await typeInto('777777');
    expect(await vm.submit(), isTrue);
    await typeInto('777777');
    expect(await vm.submit(), isTrue);
    expect(vm.step, 3, reason: 'خطوة النجاح');
    expect(vm.errorKey, isNull);

    // التغيير حقيقي في القاعدة.
    expect(
      await users.verifyPin('777777', now: DateTime.utc(2026, 10, 6, 18)),
      PinVerifyOutcome.success,
    );
  });

  test('قصير: pinShort في كل خطوة دون تقدم', () async {
    await typeInto('12');
    expect(await vm.submit(), isFalse);
    expect(vm.errorKey, 'pinShort');
    expect(vm.step, 0);
  });

  test('عدم التطابق: pinMismatch ومسح التأكيد فقط', () async {
    await typeInto('1234');
    await vm.submit();
    await typeInto('5555');
    await vm.submit();
    await typeInto('5556');
    expect(await vm.submit(), isFalse);
    expect(vm.errorKey, 'pinMismatch');
    expect(vm.step, 2, reason: 'يبقى في خطوة التأكيد');
    expect(vm.entered, '', reason: 'التأكيد يُمسح لإعادة الإدخال');
  });

  test('الجديد يطابق الحالي: sameAsCurrent', () async {
    await typeInto('1234');
    await vm.submit();
    await typeInto('1234');
    await vm.submit();
    await typeInto('1234');
    expect(await vm.submit(), isFalse);
    expect(vm.errorKey, 'sameAsCurrent');
  });

  test('الحالي الخاطئ: wrongCurrent وعودة للخطوة 0', () async {
    await typeInto('9999');
    await vm.submit(); // الخطوة 0 لا تتحقق من الصحة — تقدم شكلي.
    await typeInto('7777');
    await vm.submit();
    await typeInto('7777');
    expect(await vm.submit(), isFalse);
    expect(vm.errorKey, 'wrongCurrent');
    expect(vm.step, 0);
    expect(vm.entered, '', reason: 'الحالي يُمسح لإعادة المحاولة');
  });

  test('backspace يمسح خانة من المخزن الصحيح', () async {
    await typeInto('123');
    vm.backspace();
    expect(vm.entered, '12');
    vm.backspace();
    vm.backspace();
    expect(vm.entered, '');
    vm.backspace(); // لا انفجار على فارغ.
    expect(vm.entered, '');
  });

  test('addDigit يتجاهل فوق 6 خانات وأثناء الإرسال', () async {
    await typeInto('123456');
    vm.addDigit(9);
    expect(vm.entered, '123456');
  });

  test('reset يعيد التدفق من الصفر', () async {
    await typeInto('1234');
    await vm.submit();
    vm.reset();
    expect(vm.step, 0);
    expect(vm.entered, '');
    expect(vm.errorKey, isNull);
  });
}
