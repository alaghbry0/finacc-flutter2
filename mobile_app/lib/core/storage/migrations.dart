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
///
/// **الإصدار 2** = إصلاح بيانات (لا DDL): الأصناف المتتبعة للدفعات التي
/// سُجّل لها رصيد افتتاحي في `stock_level` دون أي صف `batch` (خلل الموجة 4)
/// كانت تُرفض في البيع بمتاح = 0 رغم رصيد كتابي كبير. تُنشأ لكل
/// (صنف × مخزن) دفعة افتتاحية بالفرق المتبقي بصلاحية بعيدة 9999-12-31 —
/// العبارة **idempotent** (إعادة تشغيلها لا تكرر: الفرق يصبح صفراً).
///
/// **الإصدار 3** (موجة UX-2a — التخصيص الشامل): عمود `logo_png` في
/// `company` (قرار المنسق: الشعار BLOB داخل القاعدة لينجو مع ملف النسخة
/// الاحتياطي) + بذر مفاتيح التخصيص الجديدة في `settings`
/// (`sale.default_payment` / `sale.show_discounts` / `display.font_scale`).
///
/// **الإصدار 4** (موجة UX-3 — قوالب الفواتير القابلة للتخصيص): جدول
/// `print_template` (صف لكل قالب × نوع مستند): كلاسيكي A4 أفقي (محاكاة
/// نموذج المالك) + بسيط A4 عمودي (سلوك البنّاء القائم — **هو الافتراضي**
/// حفاظاً على مخرجات المتاجر القائمة) + حراري 80مم. الشعار نفسه يبقى
/// في `company.logo_png` (لا تكرار هنا — قرار المنسق UX-audit-synthesis).
///
/// **الإصدار 5** (موجة UX-4 — الكميات المجانية/بونص): عمود `free_qty`
/// في `invoice_item` (NUMERIC(12,3) NOT NULL DEFAULT 0 — صفوف اليوم
/// القديمة تعني «بلا بونص» تلقائياً) + بذر مفتاح `sale.free_qty`
/// ('off' — التفعيل من «تفضيلات البيع»). **القرار التحاسبي الملزم**
/// (UX-audit-invoice §3 + المنسق): المنصرف الكلي = qty + free_qty
/// (حركة المخزون/stock_level/FEFO/COGS على الكلي)، والإيراد من qty
/// حصراً (subtotal/total/total_base/الائتمان بلا أثر للبونص) — فالبونص
/// يرفع COGS ويخفض الربح بالمقدار الحرفي، والبدائل (سطر بسعر صفر /
/// خصم 100%) تُشوّه التقارير وتفشل مع فاتورة مجانية بالكامل
/// (CHECK(total > 0)).
///
/// **الإصدار 6** (موجة R16-a — ثورة الكميات المجانية): **حذف مفتاح
/// `sale.free_qty` نهائياً** بقرار المالك الملزم: لا يوجد أي إعداد
/// لإظهار/إخفاء حقل الكمية المجانية — الشارة/الحقل يُضاف ديناميكياً
/// عند وجود كمية مجانية ولا يظهر إطلاقاً حين لا يوجد بونص. العبارة
/// **idempotent** بطبيعتها (DELETE لا يفعل شيئاً حين لا صف).
/// **تنبيهات جوهرية**: (1) عمود `invoice_item.free_qty` **لا يُمسّ
/// أبداً** — بونصات المتاجر القائمة محفوظة. (2) بنود الشراء تسكن
/// `invoice_item` نفسها (doc_type='purchase') والعمود موجود فيها منذ
/// v5 بذات التعريف المطلوب NUMERIC(12,3) NOT NULL DEFAULT 0 — فلا
/// DDL جديد لازماً للشراء (لا يوجد جدول purchase_item بالمخطط).
/// (3) الجدول اسمه `settings` (لا app_settings).
const List<DbMigration> migrations = <DbMigration>[
  DbMigration(version: 1, statements: schemaV1Ddl, seeds: _seedStatements),
  DbMigration(version: 2, statements: <String>[repairOpeningBatchesV2]),
  DbMigration(
    version: 3,
    statements: <String>[alterCompanyLogoPngV3],
    seeds: _seedStatementsV3,
  ),
  DbMigration(
    version: 4,
    statements: <String>[createPrintTemplateV4],
    seeds: _seedStatementsV4,
  ),
  DbMigration(
    version: 5,
    statements: <String>[alterInvoiceItemFreeQtyV5],
    seeds: _seedStatementsV5,
  ),
  DbMigration(
    version: 6,
    statements: <String>[deleteSaleFreeQtyKeyV6, deleteThermalTemplateV6],
  ),
];

/// عبارة إصلاح الإصدار 2 — انظر [migrations]. (علنية لتُختبر مباشرة.)
///
/// الفرق = `stock_level.qty − مجموع الدفعات النشطة (غير المؤرشفة)`؛
/// يُدرَج فقط حين يكون الفرق موجباً (الدفعات المنتهية تبقى محجوزة
/// لرصيدها الكتابي ولا تُعوَّض — المنطق المحاسبي الصحيح).
const String repairOpeningBatchesV2 = '''
INSERT INTO batch(product_id, warehouse_id, batch_number, expiry_date,
                  cost_price, qty, created_at, updated_at)
SELECT sl.product_id, sl.warehouse_id,
       'افتتاحي-' || sl.product_id || '-' || sl.warehouse_id,
       '9999-12-31',
       COALESCE(p.cost_price, 0),
       sl.qty - COALESCE((
         SELECT SUM(b.qty) FROM batch b
         WHERE b.product_id = sl.product_id
           AND b.warehouse_id = sl.warehouse_id
           AND b.is_archived = 0
       ), 0),
       strftime('%Y-%m-%dT%H:%M:%SZ','now'),
       strftime('%Y-%m-%dT%H:%M:%SZ','now')
FROM stock_level sl
JOIN product p ON p.id = sl.product_id
WHERE p.track_batches = 1
  AND p.is_service = 0
  AND sl.qty > 0
  AND sl.qty > COALESCE((
    SELECT SUM(b.qty) FROM batch b
    WHERE b.product_id = sl.product_id
      AND b.warehouse_id = sl.warehouse_id
      AND b.is_archived = 0
  ), 0)
''';

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

/// عبارة DDL للإصدار 3 — عمود الشعار BLOB في جدول `company`.
///
/// (علنية لتُختبر مباشرة.) الشعار يُخزَّن كـ PNG مضغوط داخل القاعدة —
/// قرار المنسق في UX-audit-synthesis: ينجو تلقائياً مع ملف النسخة
/// الاحتياطي (zip = قاعدة كاملة) بلا مسار ملف خارجي ينقطع بالنقل.
const String alterCompanyLogoPngV3 =
    'ALTER TABLE company ADD COLUMN logo_png BLOB';

/// بذور الإصدار 3 — مفاتيح التخصيص الجديدة (موجة UX-2a).
///
/// `INSERT OR IGNORE` حصراً: البذر لا يدوس قيمة موجودة (قاعدة ترقّت يدوياً
/// أو مفتاح كتبه المستخدم قبل الترقية) — وبهذا إعادة تشغيل الهجرة فوق
/// أي حالة **idempotent** بلا ازدواج ولا فقد.
const List<String> _seedStatementsV3 = <String>[
  '''
  INSERT OR IGNORE INTO settings(key, value, updated_at) VALUES
    ('sale.default_payment', '"cash"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('sale.show_discounts', '"on"', strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('display.font_scale', '"normal"', strftime('%Y-%m-%dT%H:%M:%SZ','now'))
  ''',
];

/// عبارة DDL للإصدار 4 — جدول قوالب الطباعة (موجة UX-3).
///
/// (علنية لتُختبر مباشرة.) صف لكل (نوع مستند × قالب) بإعدادات JSON في
/// `config` — المفتاح `doc_type='sale'` في V1 (أنواع أخرى لاحقاً)،
/// و`is_default` يحدد القالب النشط الذي تمر عبره الطباعة/المعاينة.
const String createPrintTemplateV4 = '''
  CREATE TABLE print_template (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    doc_type TEXT NOT NULL DEFAULT 'sale',
    code TEXT NOT NULL,
    is_default INTEGER NOT NULL DEFAULT 0,
    config TEXT,
    created_at TEXT, updated_at TEXT, created_by INTEGER,
    UNIQUE(doc_type, code)
  )
''';

/// بذور الإصدار 4 — القوالب الثلاثة لفواتير البيع (موجة UX-3).
///
/// `INSERT OR IGNORE` (نمط v3): إعادة التشغيل لا تكرر ولا تدوس تخصيصاً
/// كتبه المستخدم. البسيط A4 هو الافتراضي — سلوك المتاجر القائمة كما هو
/// حتى يختار المالك التغيير بنفسه من شاشة «الطباعة والفواتير».
const List<String> _seedStatementsV4 = <String>[
  '''
  INSERT OR IGNORE INTO print_template(doc_type, code, is_default, config,
                                      created_at, updated_at)
  VALUES
    ('sale', 'classic_a4', 0,
     '{"templateId":"classic_a4","tableHeadArgb":4288529382,"borderArgb":4281812815,"accentRedArgb":4291176488,"showDiscountColumn":true,"showUnitColumn":true,"showBarcode":false,"showTax":false,"showSignatures":true,"showStampArea":true,"showFooter":true,"showNotes":true,"badge":"none"}',
     strftime('%Y-%m-%dT%H:%M:%SZ','now'), strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('sale', 'simple_a4', 1,
     '{"templateId":"simple_a4","tableHeadArgb":4292864999,"borderArgb":4292667361,"accentRedArgb":4291176488,"showDiscountColumn":true,"showUnitColumn":false,"showBarcode":false,"showTax":false,"showSignatures":true,"showStampArea":true,"showFooter":true,"showNotes":true,"badge":"none"}',
     strftime('%Y-%m-%dT%H:%M:%SZ','now'), strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ('sale', 'thermal_80', 0,
     '{"templateId":"thermal_80","tableHeadArgb":4278190080,"borderArgb":4278190080,"accentRedArgb":4291176488,"showDiscountColumn":true,"showUnitColumn":false,"showBarcode":true,"showTax":false,"showSignatures":false,"showStampArea":false,"showFooter":true,"showNotes":true,"badge":"none"}',
     strftime('%Y-%m-%dT%H:%M:%SZ','now'), strftime('%Y-%m-%dT%H:%M:%SZ','now'))
  ''',
];

/// عبارة DDL للإصدار 5 — عمود الكمية المجانية (بونص) في بنود الفواتير
/// (موجة UX-4).
///
/// (علنية لتُختبر مباشرة.) `DEFAULT 0` يجعل كل صف قديم (فواتير ما قبل
/// البونص وكل بنود الشراء/المرتجعات) بلا بونص تلقائياً — لا هجرة بيانات
/// لازمة ولا مساس بالقيود القائمة (CHECK(qty > 0) يبقى على المدفوع
/// حصراً؛ البونص ≥ 0 يُتحقق منه في طبقة النطاق قبل الكتابة).
const String alterInvoiceItemFreeQtyV5 =
    'ALTER TABLE invoice_item ADD COLUMN free_qty NUMERIC(12,3) '
    'NOT NULL DEFAULT 0';

/// بذور الإصدار 5 — مفتاح تفعيل البونص (موجة UX-4).
///
/// `INSERT OR IGNORE` (نمط v3/v4): إعادة التشغيل لا تكرر ولا تدوس قيمة
/// كتبها المستخدم. المزروع 'off' — سلوك المتاجر القائمة كما هو حتى
/// يفعّله المالك بنفسه من «تفضيلات البيع» (درس المفاتيح الميتة مطبّق:
/// المفتاح موصول فعلياً بالكاشير من لحظة البذر).
const List<String> _seedStatementsV5 = <String>[
  '''
  INSERT OR IGNORE INTO settings(key, value, updated_at) VALUES
    ('sale.free_qty', '"off"', strftime('%Y-%m-%dT%H:%M:%SZ','now'))
  ''',
];

/// عبارة الإصدار 6 — إزالة مفتاح بوابة البونص المتقاعد (موجة R16-a).
///
/// (علنية لتُختبر مباشرة.) التكليف الأصلي ذكر `app_settings` وعموداً
/// لجدول `purchase_item` — بالمخطط المجمد الفعلي الجدول `settings`،
/// وبنود الشراء تسكن `invoice_item` (وحصلت `free_qty` بها منذ هجرة v5
/// بذات تعريف NUMERIC(12,3) NOT NULL DEFAULT 0)، فالهجرة تنظيف بيانات
/// حصراً. `DELETE` idempotent بطبيعته؛ وحين يمرّ أي قاعدة قديمة (زرع
/// v5 المفتاح 'off' أو كتب المستخدم 'on') يُحذف بلا استثناء — الإعداد
/// **لم يعد موجوداً** والبوابة الديناميكية (freeQty>0) هي القاعدة
/// الوحيدة الآن في البيع والشراء معاً.
const String deleteSaleFreeQtyKeyV6 =
    "DELETE FROM settings WHERE key = 'sale.free_qty'";

/// عبارة الإصدار 6 (تتمة — R16-b/المنسق): حذف صف قالب الطباعة الحراري
/// المتقاعد بقرار المالك. بذر v4 التاريخي يزرعه للقواعد الجديدة (هجرات
/// v1→v6 تعمل تسلسلياً وقت الإنشاء) فيُحذف هنا؛ والقواعد القديمة التي
/// بُذرت قبل الحذف يُنظّف صفها أيضاً — والقراءة فوق أي قاعدة متبقية
/// تحوّل `thermal_80` لكلاسيكي (طبقة normalize بالمستودع). DELETE
/// idempotent بطبيعته.
const String deleteThermalTemplateV6 =
    "DELETE FROM print_template WHERE code = 'thermal_80'";

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
