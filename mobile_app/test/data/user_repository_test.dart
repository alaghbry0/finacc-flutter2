/// اختبارات مستودع المستخدم — تحقق PIN بالسياسة الكاملة + changePin + التدقيق.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/user_repository.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late UserRepository users;

  setUp(() async {
    final seeded = await openSeededApp();
    app = seeded.$1;
    users = seeded.$3;
  });

  tearDown(() async {
    await app.close();
  });

  group('verifyPin — النجاح', () {
    test('PIN صحيح: نجاح + تصفير العدّاد (بلا قيد تدقيق للنجاح العادي)', () async {
      // محاولتان خاطئتان أولاً لرفع العدّاد.
      await users.verifyPin('0000', now: DateTime.utc(2026, 10, 6, 13));
      await users.verifyPin('0000', now: DateTime.utc(2026, 10, 6, 13, 0, 1));
      final outcome = await users.verifyPin(
        '1234',
        now: DateTime.utc(2026, 10, 6, 13, 0, 2),
      );
      expect(outcome, PinVerifyOutcome.success);
      expect(await users.currentFailedAttempts(), 0);
      expect(await users.currentLockedUntil(), isNull);
      // النجاح العادي لا يقيّد في التدقيق — القيود للعتبات فقط (AC-15).
      expect(
        await app.db.query(
          'audit_log',
          where: "action LIKE 'pin_lockout%'",
        ),
        isEmpty,
        reason: 'محاولتان فقط دون بلوغ عتبة 5',
      );
      // آخر دخول مسجل.
      final admin = (await app.db.query('app_user')).first;
      expect(admin['last_login_at'], isNotNull);
    });

    test('hasPin بعد التأسيس', () async {
      expect(await users.hasPin(), isTrue);
    });
  });

  group('verifyPin — الفشل والسياسة', () {
    test('خاطئ: wrong + عدّاد يرتفع', () async {
      final outcome = await users.verifyPin(
        '9999',
        now: DateTime.utc(2026, 10, 6, 13),
      );
      expect(outcome, PinVerifyOutcome.wrong);
      expect(await users.currentFailedAttempts(), 1);
    });

    test('المحاولة 5 توجب تأخيراً 30 ثانية والمحاولة داخلها delayed', () async {
      var now = DateTime.utc(2026, 10, 6, 13);
      for (var i = 0; i < 4; i++) {
        await users.verifyPin('0000', now: now);
        now = now.add(const Duration(minutes: 3));
      }
      // المحاولة الخامسة الخاطئة.
      final fifth = await users.verifyPin('0000', now: now);
      expect(fifth, PinVerifyOutcome.wrong);
      expect(await users.currentFailedAttempts(), 5);
      final lockedUntil = await users.currentLockedUntil();
      expect(lockedUntil, isNotNull);

      // داخل نافذة الانتظار — ولو أدخل الصحيح.
      final inside = await users.verifyPin('1234', now: now.add(const Duration(seconds: 10)));
      expect(inside, PinVerifyOutcome.delayed);
      // العدّاد لم يزد (رفض مبكر).
      expect(await users.currentFailedAttempts(), 5);

      // بعد انقضاء النافذة: الصحيح يفتح.
      final after = await users.verifyPin(
        '1234',
        now: now.add(const Duration(seconds: 31)),
      );
      expect(after, PinVerifyOutcome.success);
      expect(await users.currentFailedAttempts(), 0);
    });

    test('المحاولة 10: بوابة عبارة المرور + قيد تدقيق', () async {
      var now = DateTime.utc(2026, 10, 6, 14);
      for (var i = 0; i < 10; i++) {
        await users.verifyPin('0000', now: now);
        // كل نافذة انتظار تنقضي قبل التالية (تسلسل الجدول المتدرج).
        now = now.add(const Duration(minutes: 16));
      }
      expect(await users.currentFailedAttempts(), 10);
      // حتى الصحيح يرفض — البوابة على عبارة المرور.
      final refused = await users.verifyPin('1234', now: now);
      expect(refused, PinVerifyOutcome.passphraseRequired);
      final lockouts = await app.db.query(
        'audit_log',
        where: "action LIKE 'pin_lockout%'",
      );
      expect(lockouts, isNotEmpty,
          reason: 'عتبات التأخير وعبارة المرور تقيَّد في التدقيق');
    });
  });

  group('verifyPassphrase', () {
    test('الصحيحة تتحقق، وresetLockout يصفر العدّاد (تدفق LockViewModel)', () async {
      var now = DateTime.utc(2026, 10, 6, 15);
      for (var i = 0; i < 10; i++) {
        await users.verifyPin('0000', now: now);
        now = now.add(const Duration(minutes: 16));
      }
      expect(await users.currentFailedAttempts(), 10);
      expect(await users.verifyPassphrase('wrong-pass'), isFalse);
      // التحقق الناجح وحده لا يصفر — الفصل مقصود (استرداد صريح).
      expect(await users.verifyPassphrase('Passphrase-2026'), isTrue);
      expect(await users.currentFailedAttempts(), 10);
      await users.resetLockout(now: now);
      expect(await users.currentFailedAttempts(), 0);
      expect(await users.currentLockedUntil(), isNull);
    });
  });

  group('changePin — الذرّية والتدقيق', () {
    test('نجاح: استبدال + تصفير العدّاد + قيد pin_change', () async {
      // رفع العدّاد أولاً.
      await users.verifyPin('0000', now: DateTime.utc(2026, 10, 6, 16));
      final outcome = await users.changePin(
        '1234',
        '777777',
        now: DateTime.utc(2026, 10, 6, 16, 1),
      );
      expect(outcome, PinChangeOutcome.success);
      expect(await users.currentFailedAttempts(), 0);
      // الرمز الجديد يعمل والقديم لا.
      expect(
        await users.verifyPin('777777', now: DateTime.utc(2026, 10, 6, 16, 2)),
        PinVerifyOutcome.success,
      );
      expect(
        await users.verifyPin('1234', now: DateTime.utc(2026, 10, 6, 16, 3)),
        PinVerifyOutcome.wrong,
      );
      final changes = await app.db.query(
        'audit_log',
        where: "action = 'pin_change'",
      );
      expect(changes, hasLength(1));
    });

    test('الحالي الخاطئ: رفض دون أي كتابة', () async {
      final outcome = await users.changePin(
        '0000',
        '777777',
        now: DateTime.utc(2026, 10, 6, 16),
      );
      expect(outcome, PinChangeOutcome.wrongCurrent);
      expect(
        await users.verifyPin('1234', now: DateTime.utc(2026, 10, 6, 16, 1)),
        PinVerifyOutcome.success,
        reason: 'الرمز القديم لم يتغير',
      );
      expect(
        await app.db.query('audit_log', where: "action = 'pin_change'"),
        isEmpty,
      );
    });

    test('الجديد خارج 4-6 خانات: invalidLength قبل أي استعلام', () async {
      expect(
        await users.changePin('1234', '77'),
        PinChangeOutcome.invalidLength,
      );
      expect(
        await users.changePin('1234', '7777777'),
        PinChangeOutcome.invalidLength,
      );
    });
  });

  test('audit يكتب أحداثاً بقيم مخصصة (كيان/معرف/تفاصيل)', () async {
    await users.audit(
      'settings_change',
      entity: 'settings',
      entityId: null,
      details: 'security.autolock_minutes=10',
      at: DateTime.utc(2026, 10, 6, 17),
    );
    final rows = await app.db.query(
      'audit_log',
      where: "action = 'settings_change'",
    );
    expect(rows, hasLength(1));
    expect(rows.first['details'], 'security.autolock_minutes=10');
  });

  test('adminDisplayName يعيد اسم المدير بعد التأسيس', () async {
    expect(await users.adminDisplayName(), 'أبو نور');
  });
}
