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

  test('الهجرة 1 مسجّلة في _migrations بإصدار المخطط الحالي', () async {
    final rows = await app.db.query('_migrations');
    expect(rows, hasLength(1));
    expect(rows.first['version'], currentSchemaVersion);
    expect(currentSchemaVersion, 1);
  });

  test('بذور العملات: 4 عملات وYER أساسية بلا كسور (قاعدة 5.4-9)', () async {
    final rows = await app.db.query('currency');
    expect(rows, hasLength(4));
    final byCode = {
      for (final r in rows) r['code'] as String: r,
    };
    expect(byCode.keys, containsAll(['YER', 'SAR', 'USD', 'AED']));
    expect(byCode['YER']!['is_base'], 1);
    expect(byCode['YER']!['decimals'], 0,
        reason: 'الريال اليمني بلا كسور عشرية');
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
    final byKey = {
      for (final r in rows) r['key'] as String: r['value'],
    };
    expect(byKey.length, greaterThanOrEqualTo(15));
    expect(byKey['display.numerals'], '"western"');
    expect(byKey['ui.high_contrast'], '"off"');
    expect(byKey['security.autolock_minutes'], '5', reason: 'تُخزَّن الرقمية كنص رقمي خام');
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
}
