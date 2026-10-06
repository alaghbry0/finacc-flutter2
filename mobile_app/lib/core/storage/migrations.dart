/// مشغّل الهجرات وبذور البيانات المرجعية — SRS v1.5 §5.2/§5.3 + ملحق هـ.
///
/// - كل هجرة موثّقة بسطر في جدول `_migrations` (الإصدار + وقت التطبيق).
/// - الهجرات متزايدة فقط ولا تُعدَّل بعد اعتمادها (المخطط مجمّد).
/// - البذور: العملات الأربع المعتمدة للسوق اليمني (YER أساسية بلا كسور —
///   FR-08-01) وفئة مصروف «رواتب» الافتراضية (FR-04-05) والإعدادات
///   الافتراضية لسجل الإعدادات (ملحق هـ — مفاتيح V1 فقط).
library;

import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// هجرة موثّقة واحدة.
class DbMigration {
  const DbMigration({
    required this.version,
    required this.statements,
    this.seeds = const <String>[],
  });

  /// رقم الإصدار (يتزايد فقط).
  final int version;

  /// عبارات DDL (كل عبارة تُنفَّذ على حدة).
  final List<String> statements;

  /// عبارات بذر البيانات المرجعية (تُنفَّذ مرة واحدة مع الهجرة).
  final List<String> seeds;
}

/// إصدار المخطط الحالي — آخر عنصر في [migrations].
int get currentSchemaVersion => migrations.last.version;

/// سجل الهجرات المعتمدة.
///
/// **الإصدار 1** = المخطط الكامل المجمّد في SRS v1.5 §5.3.
const List<DbMigration> migrations = <DbMigration>[
  DbMigration(version: 1, statements: schemaV1Ddl, seeds: _seedStatements),
];

/// بذور الإصدار 1 — العملات + فئة الرواتب + الإعدادات الافتراضية (ملحق هـ).
const List<String> _seedStatements = <String>[
  // العملات — §0.1: YER أساسية مع SAR/USD/AED بأسعار صرف يدوية يومية.
  // YER بلا كسور (decimals = 0) — قاعدة 5.4-9.
  '''
  INSERT INTO currency(code, name, is_base, decimals, is_active) VALUES
    ('YER', 'ريال يمني', 1, 0, 1),
    ('SAR', 'ريال سعودي', 0, 2, 1),
    ('USD', 'دولار أمريكي', 0, 2, 1),
    ('AED', 'درهم إماراتي', 0, 2, 1)
  ''',
  // فئة مصروف «رواتب» الافتراضية — FR-04-05 (بديل وحدة الموظفين المؤجلة).
  "INSERT INTO expense_category(name, created_at) VALUES ('رواتب', strftime('%Y-%m-%dT%H:%M:%SZ','now'))",
  // الإعدادات الافتراضية — ملحق هـ (مفاتيح V1 حصراً) بصيغة JSON.
  // القيم النصية تُخزَّن كـ JSON strings والرقمية كأرقام.
  '''
  INSERT INTO settings(key, value, updated_at) VALUES
    ('inventory.min_stock_alert', '"on"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('invoicing.tax_mode', '"on_total"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('invoicing.discount_below_margin', '"off"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('invoicing.print_on_save', '"ask"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('invoicing.payment_sheet', '"on"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('sale.over_avail_policy', '"warn"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('parties.credit_limit_action', '"warn"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('fx.daily_reminder', '"on"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('fx.fallback', '"off"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('display.numerals', '"western"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('ui.high_contrast', '"off"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('backup.schedule', '"weekly"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('backup.retention_count', '7', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('security.autolock_minutes', '5', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('dating.max_backdate_days', '30', strftime('%Y-%m-%dT%H:%M:%SZ','now'))
  ''',
];

/// يطبّق كل الهجرات المعلّقة فوق قاعدة مفتوحة (idempotent).
///
/// يُستدعى من `onCreate` و`onUpgrade` في خيارات فتح القاعدة، أو مباشرة
/// في اختبارات الوحدة فوق قاعدة فارغة.
Future<void> applyMigrations(DatabaseExecutor db) async {
  await db.execute(migrationsTableDdl);
  final applied = <int>{};
  final rows = await db.query('_migrations', columns: ['version']);
  for (final row in rows) {
    applied.add(row['version'] as int);
  }
  for (final migration in migrations) {
    if (applied.contains(migration.version)) continue;
    for (final statement in migration.statements) {
      await db.execute(statement);
    }
    for (final seed in migration.seeds) {
      await db.execute(seed);
    }
    await db.execute(
      "INSERT INTO _migrations(version, applied_at) VALUES(?, strftime('%Y-%m-%dT%H:%M:%SZ','now'))",
      <Object>[migration.version],
    );
  }
}
