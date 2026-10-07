/// اختبارات مستودع أسعار الصرف — الإدخال اليومي اليدوي والـ UPSERT
/// والرفض للعملة الأساسية والقراءة (FR-08-03 / 08-05 / 08-09).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late ExchangeRateRepository repo;
  late int adminId;
  late int yer;
  late int sar;
  late int usd;
  late int aed;

  setUp(() async {
    app = (await openSeededApp()).$1;
    repo = ExchangeRateRepository(app.db);
    adminId = (await app.db.query('app_user', limit: 1)).first['id'] as int;
    final currencies = {
      for (final row in await app.db.query('currency'))
        row['code'] as String: row['id'] as int,
    };
    yer = currencies['YER']!;
    sar = currencies['SAR']!;
    usd = currencies['USD']!;
    aed = currencies['AED']!;
  });

  tearDown(() async {
    await app.close();
  });

  test(
    'setRate يكتب الصف وقيد التدقيق بتفاصيل currency/date/rate (FR-08-03)',
    () async {
      final result = await repo.setRate(
        currencyId: sar,
        date: DateTime.utc(2026, 10, 6, 15),
        rate: 530.25,
        userId: adminId,
        now: DateTime.utc(2026, 10, 6, 15, 5),
      );
      expect(result.isOk, isTrue);

      final rows = await app.db.query(
        'exchange_rate',
        where: 'currency_id = ? AND rate_date = ?',
        whereArgs: [sar, '2026-10-06'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['rate'], 530.25);
      expect(rows.first['source'], 'manual');
      expect(rows.first['created_by'], adminId);

      final audit = await app.db.query(
        'audit_log',
        where: "action = 'fx_rate_set'",
      );
      expect(audit, hasLength(1));
      expect(audit.first['entity'], 'exchange_rate');
      expect(audit.first['entity_id'], rows.first['id']);
      expect(
        audit.first['details'],
        'currency=SAR date=2026-10-06 rate=530.25',
      );
    },
  );

  test('الإدخال المتكرر لنفس اليوم تحديث لا تكرار (UNIQUE — UPSERT)', () async {
    final first = await repo.setRate(
      currencyId: sar,
      date: DateTime.utc(2026, 10, 6),
      rate: 530,
      userId: adminId,
      now: DateTime.utc(2026, 10, 6, 8),
    );
    expect(first.isOk, isTrue);
    final second = await repo.setRate(
      currencyId: sar,
      date: DateTime.utc(2026, 10, 6, 20),
      rate: 531,
      userId: adminId,
      now: DateTime.utc(2026, 10, 6, 20, 30),
    );
    expect(second.isOk, isTrue);

    final rows = await app.db.query(
      'exchange_rate',
      where: 'currency_id = ? AND rate_date = ?',
      whereArgs: [sar, '2026-10-06'],
    );
    expect(rows, hasLength(1), reason: 'لا تكرار أبداً لنفس اليوم');
    expect(rows.first['rate'], 531);
    expect(
      rows.first['created_at'],
      '2026-10-06T08:00:00.000Z',
      reason: 'created_at الأصلي محفوظ بعد التحديث',
    );
    expect(
      await app.db.query('audit_log', where: "action = 'fx_rate_set'"),
      hasLength(2),
      reason: 'قيد تدقيق لكل عملية ضبط',
    );
  });

  test('رفض سعر العملة الأساسية — لا يُدخل سعر لليمني أبداً', () async {
    final failure = await repo.setRate(
      currencyId: yer,
      date: DateTime.utc(2026, 10, 6),
      rate: 1,
      userId: adminId,
    );
    expect(failure.isErr, isTrue);
    expect(failure.errorOrNull, 'لا يُدخل سعر للعملة الأساسية.');
    expect(
      await app.db.query(
        'exchange_rate',
        where: 'currency_id = ?',
        whereArgs: [yer],
      ),
      isEmpty,
    );
    expect(
      await app.db.query('audit_log', where: "action = 'fx_rate_set'"),
      isEmpty,
      reason: 'لا تدقيق لعملية مرفوضة',
    );
  });

  test('رفض السعر غير الموجب (صفر وسالب)', () async {
    final zero = await repo.setRate(
      currencyId: sar,
      date: DateTime.utc(2026, 10, 6),
      rate: 0,
      userId: adminId,
    );
    expect(zero.isErr, isTrue);
    expect(zero.errorOrNull, contains('أكبر من صفر'));

    final negative = await repo.setRate(
      currencyId: sar,
      date: DateTime.utc(2026, 10, 6),
      rate: -5,
      userId: adminId,
    );
    expect(negative.isErr, isTrue);
    expect(await app.db.query('exchange_rate'), isEmpty);
  });

  test('رفض عملة غير موجودة', () async {
    final failure = await repo.setRate(
      currencyId: 999,
      date: DateTime.utc(2026, 10, 6),
      rate: 5,
      userId: adminId,
    );
    expect(failure.isErr, isTrue);
    expect(failure.errorOrNull, contains('غير موجودة'));
  });

  test('rateFor: التاريخ نفسه بالضبط أو لا شيء', () async {
    await repo.setRate(
      currencyId: sar,
      date: DateTime.utc(2026, 10, 6),
      rate: 531,
      userId: adminId,
    );
    expect(
      await repo.rateFor(sar, DateTime.utc(2026, 10, 6, 23, 59)),
      closeTo(531, 0.0001),
    );
    expect(await repo.rateFor(sar, DateTime.utc(2026, 10, 7)), isNull);
    expect(await repo.rateFor(aed, DateTime.utc(2026, 10, 6)), isNull);
  });

  test('latestBefore: أحدث سعر بتاريخ ≤ المطلوب (شاملاً)', () async {
    await repo.setRate(
      currencyId: usd,
      date: DateTime.utc(2026, 10, 1),
      rate: 1580,
      userId: adminId,
    );
    await repo.setRate(
      currencyId: usd,
      date: DateTime.utc(2026, 10, 5),
      rate: 1590,
      userId: adminId,
    );

    expect(await repo.latestBefore(usd, DateTime.utc(2026, 10, 7)), 1590);
    expect(await repo.latestBefore(usd, DateTime.utc(2026, 10, 5)), 1590);
    expect(await repo.latestBefore(usd, DateTime.utc(2026, 10, 3)), 1580);
    expect(await repo.latestBefore(usd, DateTime.utc(2026, 9, 30)), isNull);
  });

  test('history: تنازلياً بالتاريخ مع احترام الحد', () async {
    await repo.setRate(
      currencyId: aed,
      date: DateTime.utc(2026, 10, 1),
      rate: 430,
      userId: adminId,
    );
    await repo.setRate(
      currencyId: aed,
      date: DateTime.utc(2026, 10, 5),
      rate: 432,
      userId: adminId,
    );
    await repo.setRate(
      currencyId: aed,
      date: DateTime.utc(2026, 10, 6),
      rate: 435,
      userId: adminId,
    );

    final all = await repo.history(aed);
    expect(all.map((e) => e.rateDate).toList(), [
      '2026-10-06',
      '2026-10-05',
      '2026-10-01',
    ]);
    expect(all.first.rate, 435);
    expect(all.first.source, 'manual');
    expect(all.first.rateDateUtc, DateTime.utc(2026, 10, 6));
    expect(all.first.currencyId, aed);

    final limited = await repo.history(aed, limit: 2);
    expect(limited, hasLength(2));
    expect(limited.first.rateDate, '2026-10-06');
  });

  test(
    'todayRates: عملات اليوم فقط — الغائبة تغيب من الخريطة (FR-08-09)',
    () async {
      await repo.setRate(
        currencyId: sar,
        date: DateTime.utc(2026, 10, 6),
        rate: 531,
        userId: adminId,
      );
      await repo.setRate(
        currencyId: usd,
        date: DateTime.utc(2026, 10, 6),
        rate: 1590,
        userId: adminId,
      );
      await repo.setRate(
        currencyId: aed,
        date: DateTime.utc(2026, 10, 5),
        rate: 432,
        userId: adminId,
      );

      final today = await repo.todayRates(DateTime.utc(2026, 10, 6, 18));
      expect(today, hasLength(2), reason: 'SAR وUSD فقط — AED ليوم آخر');
      expect(today[sar], closeTo(531, 0.0001));
      expect(today[usd], closeTo(1590, 0.0001));
      expect(today.containsKey(aed), isFalse);
      expect(today.containsKey(yer), isFalse, reason: 'الأساسية بلا سعر أصلاً');

      expect(await repo.todayRates(DateTime.utc(2026, 10, 7)), isEmpty);
    },
  );

  test('hasRateFor: صواب لنفس اليوم فقط', () async {
    await repo.setRate(
      currencyId: sar,
      date: DateTime.utc(2026, 10, 6),
      rate: 531,
      userId: adminId,
    );
    expect(await repo.hasRateFor(sar, DateTime.utc(2026, 10, 6)), isTrue);
    expect(await repo.hasRateFor(sar, DateTime.utc(2026, 10, 7)), isFalse);
    expect(await repo.hasRateFor(usd, DateTime.utc(2026, 10, 6)), isFalse);
  });
}
