/// اختبارات الهجرات — سجل _migrations + البذور (عملات/فئات/إعدادات هـ).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/core/storage/migrations.dart';

import '../../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;

  setUp(() async {
    app = await openUniqueFileApp();
  });

  tearDown(() async {
    await app.close();
  });

  test('الهجرات 1+2+3 مسجّلات في _migrations بإصدار المخطط الحالي', () async {
    final rows = await app.db.query('_migrations');
    expect(rows, hasLength(3));
    expect(rows.last['version'], currentSchemaVersion);
    expect(currentSchemaVersion, 3);
  });

  test('بذور العملات: 4 عملات وYER أساسية بلا كسور (قاعدة 5.4-9)', () async {
    final rows = await app.db.query('currency');
    expect(rows, hasLength(4));
    final byCode = {for (final r in rows) r['code'] as String: r};
    expect(byCode.keys, containsAll(['YER', 'SAR', 'USD', 'AED']));
    expect(byCode['YER']!['is_base'], 1);
    expect(
      byCode['YER']!['decimals'],
      0,
      reason: 'الريال اليمني بلا كسور عشرية',
    );
    expect(byCode['SAR']!['is_base'], 0);
    expect(byCode['SAR']!['decimals'], 2);
  });

  test('بذرة فئة مصروف «رواتب» موجودة (FR-04-05)', () async {
    final rows = await app.db.query(
      'expense_category',
      where: "name = 'رواتب'",
    );
    expect(rows, hasLength(1));
  });

  test('بذور الإعدادات الـ15 من ملحق هـ بقيمها المعتمدة', () async {
    final rows = await app.db.query('settings');
    final byKey = {for (final r in rows) r['key'] as String: r['value']};
    expect(byKey.length, greaterThanOrEqualTo(15));
    expect(byKey['display.numerals'], '"western"');
    expect(byKey['ui.high_contrast'], '"off"');
    expect(
      byKey['security.autolock_minutes'],
      '5',
      reason: 'تُخزَّن الرقمية كنص رقمي خام',
    );
    expect(byKey['backup.retention_count'], '7');
    expect(byKey['dating.max_backdate_days'], '30');
    expect(byKey['invoicing.print_on_save'], '"ask"');
    expect(byKey['sale.over_avail_policy'], '"warn"');
    expect(byKey['fx.daily_reminder'], '"on"');
  });

  test('إعادة تطبيق الهجرات آمنة (idempotent — لا ازدواج بذور)', () async {
    await applyMigrations(app.db);
    final currencies = await app.db.query('currency');
    expect(currencies, hasLength(4));
    final settings = await app.db.query('settings');
    final before = settings.length;
    await applyMigrations(app.db);
    final after = (await app.db.query('settings')).length;
    expect(after, before);
  });

  group('هجرة الإصلاح v2 — تعويض الدفعات الافتتاحية للمتتبعين', () {
    test('متتبع بلا دفعات → دفعة بالفرق كاملاً، وجزئي → بالفرق فقط، '
        'وغير المتتبع لا يُمس (idempotent)', () async {
      final seeded = await openSeededApp();
      final db = seeded.$1.db;
      addTearDown(() => seeded.$1.close());

      final warehouseId =
          (await db.rawQuery('SELECT id FROM warehouse LIMIT 1')).first['id']
              as int;

      Future<int> insertProduct(String name, {required int tracked}) =>
          db.insert('product', {
            'name': name,
            'cost_price': 100,
            'min_stock': 0,
            'is_service': 0,
            'track_batches': tracked,
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
          });
      Future<void> setStock(int id, double qty) => db.insert('stock_level', {
        'product_id': id,
        'warehouse_id': warehouseId,
        'qty': qty,
      });

      // محاكاة حالة خلل الموجة 4: كتاب بلا دفعات + جزئي + عادي.
      final brokenId = await insertProduct('متتبع بلا دفعات', tracked: 1);
      final partialId = await insertProduct('متتبع جزئي', tracked: 1);
      final plainId = await insertProduct('عادي', tracked: 0);
      await setStock(brokenId, 40);
      await setStock(partialId, 50);
      await setStock(plainId, 60);
      await db.insert('batch', {
        'product_id': partialId,
        'warehouse_id': warehouseId,
        'batch_number': 'B-1',
        'expiry_date': '2027-06-01',
        'cost_price': 0,
        'qty': 20,
      });

      await db.execute(repairOpeningBatchesV2);

      final broken = await db.query(
        'batch',
        where: 'product_id = ?',
        whereArgs: [brokenId],
      );
      expect(broken, hasLength(1));
      expect((broken.first['qty'] as num).toDouble(), 40);
      expect(broken.first['expiry_date'], '9999-12-31');
      expect(broken.first['cost_price'], 100);

      final partial = await db.query(
        'batch',
        where: 'product_id = ?',
        whereArgs: [partialId],
      );
      expect(partial, hasLength(2), reason: 'الأصلية + افتتاحية بالفرق 30');
      final opening = partial.firstWhere(
        (r) => (r['batch_number'] as String).startsWith('افتتاحي-'),
      );
      expect((opening['qty'] as num).toDouble(), 30);

      expect(
        await db.query('batch', where: 'product_id = ?', whereArgs: [plainId]),
        isEmpty,
        reason: 'غير المتتبع لا يُدفَّع',
      );

      // idempotent: إعادة التنفيذ لا تضيف شيئاً.
      await db.execute(repairOpeningBatchesV2);
      expect(
        await db.query('batch', where: 'product_id = ?', whereArgs: [brokenId]),
        hasLength(1),
      );
      expect(
        await db.query(
          'batch',
          where: 'product_id = ?',
          whereArgs: [partialId],
        ),
        hasLength(2),
      );
    });
  });
}
