/// اختبارات مستودع قوالب الطباعة (موجة UX-3) — CRUD الجدول `print_template`:
/// القراءة بالبذر، التفعيل الحصري عند الحفظ، الذرية، رفض الأكواد
/// المجهولة/غير المبذورة، الاستعادة للبذر، والتحمّل الدفاعي لـJSON التالف.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/print_template_repository.dart';
import 'package:mobile_app/ui/features/printing/templates/invoice_template_settings.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late PrintTemplateRepository repo;

  setUp(() async {
    app = await openUniqueFileApp();
    addTearDown(app.close);
    repo = PrintTemplateRepository(app.db);
  });

  test('activeFor: البسيط A4 هو النشط المبذور لفواتير البيع', () async {
    final active = await repo.activeFor('sale');
    expect(active, isNotNull);
    expect(active!.code, kPrintTemplateDefaultCode);
    expect(active.docType, 'sale');
    expect(active.isDefault, isTrue);
    // الإعدادات المفكوكة من بذر v4: ألوان البسيط القائمة.
    expect(active.config.templateId, kInvoiceTemplateSimpleA4);
    expect(active.config.showDiscountColumn, isTrue);
    expect(active.config.showUnitColumn, isFalse);
  });

  test('allFor: القالبان المبذوران بترتيب البذر (كلاسيكي/بسيط) — الحراري محذوف', () async {
    final rows = await repo.allFor('sale');
    expect(rows.map((r) => r.code).toList(), [
      kInvoiceTemplateClassicA4,
      kInvoiceTemplateSimpleA4,
    ]);
    // بذور الكلاسيكي: أزرق سماوي + عمود وحدة.
    final classic = rows[0];
    expect(classic.config.tableHeadArgb, 0xFF9DC3E6);
    expect(classic.config.showUnitColumn, isTrue);
    // صف الحراري القديم حُذف بهجرة v6 — لا وجود له بقاعدة جديدة.
    expect(
      rows.where((r) => r.code == kLegacyInvoiceTemplateThermal80),
      isEmpty,
      reason: 'الحراري محذوف نهائياً بقرار المالك',
    );
  });

  test('activeFor لنوع بلا صفوف = null (المستدعي يرد للافتراضي)', () async {
    expect(await repo.activeFor('voucher'), isNull);
  });

  test('save يفعّل القالب حصراً وينقل is_default عن البقية', () async {
    await repo.save(
      kInvoiceTemplateClassicA4,
      kPrintTemplateSeedConfigs[kInvoiceTemplateClassicA4]!,
    );

    final active = await repo.activeFor('sale');
    expect(active!.code, kInvoiceTemplateClassicA4);
    final defaults = (await repo.allFor('sale')).where((r) => r.isDefault);
    expect(defaults, hasLength(1), reason: 'قالب نشط واحد حصراً');
    expect(defaults.single.code, kInvoiceTemplateClassicA4);
  });

  test('تحويل قراءة الصف القديم: thermal_80 المحفوظ قبل الحذف يُقرأ كلاسيكياً', () async {
    // قاعدة قديمة لم تمر بهجرة v6 بعد (أو صف متبقٍ) — طبقة normalize
    // بالمستودع تحوله لكلاسيكي فلا يعرفه المحرك/الشاشة أبداً.
    await app.db.rawInsert(
      "INSERT OR IGNORE INTO print_template(doc_type, code, is_default, config, "
      "created_at, updated_at) VALUES('sale', 'thermal_80', 0, "
      "'{\"templateId\":\"classic_a4\"}', "
      "strftime('%Y-%m-%dT%H:%M:%SZ','now'), strftime('%Y-%m-%dT%H:%M:%SZ','now'))",
    );
    final rows = await repo.allFor('sale');
    final legacy = rows.where((r) => r.code == kInvoiceTemplateClassicA4);
    expect(legacy, isNotEmpty, reason: 'الصف القديم يُقرأ كلاسيكياً');
    expect(
      rows.map((r) => r.code),
      everyElement(isNot(kLegacyInvoiceTemplateThermal80)),
      reason: 'لا يُكشف الحراري أبداً للمحرك/الشاشة',
    );
  });

  test('save يخزّن config كاملة وتستعاد الحقول بعد إعادة القراءة', () async {
    const custom = InvoiceTemplateSettings(
      templateId: kInvoiceTemplateClassicA4,
      tableHeadArgb: 0xFF00695C,
      borderArgb: 0xFF1A2420,
      accentRedArgb: 0xFF2E7D32,
      showDiscountColumn: false,
      showUnitColumn: true,
      showBarcode: true,
      showTax: true,
      showSignatures: false,
      showStampArea: false,
      showFooter: false,
      showNotes: false,
      badge: InvoiceBadgeMode.copy,
    );
    await repo.save(kInvoiceTemplateClassicA4, custom);

    final active = await repo.activeFor('sale');
    expect(active!.config, custom, reason: 'roundtrip كامل بالإequality');
    // العمود الخام JSON حقيقي بقيم التخصيص.
    final rawRow = (await app.db.query(
      'print_template',
      columns: ['config'],
      where: "doc_type = 'sale' AND code = ?",
      whereArgs: [kInvoiceTemplateClassicA4],
    )).single;
    final raw = rawRow['config'] as String;
    expect(raw, contains('"badge":"copy"'));
    expect(raw, contains('"showUnitColumn":true'));
  });

  test('save يرفض كود قالب مجهولاً (قائمة مغلقة)', () async {
    expect(
      () => repo.save('pos_58', const InvoiceTemplateSettings()),
      throwsArgumentError,
    );
  });

  test('save يرفض كوداً مبذوراً لنوع مستند آخر (غير مبذور هنا)', () async {
    expect(
      () => repo.save(
        kInvoiceTemplateClassicA4,
        const InvoiceTemplateSettings(),
        docType: 'voucher',
      ),
      throwsArgumentError,
    );
  });

  test('resetToDefault يستعيد بذور الجميع ويعيد البسيط نشطاً', () async {
    // المستخدم فعّل الكلاسيكي وخصّصه.
    await repo.save(
      kInvoiceTemplateClassicA4,
      const InvoiceTemplateSettings(templateId: kInvoiceTemplateClassicA4),
    );

    await repo.resetToDefault();

    final active = await repo.activeFor('sale');
    expect(active!.code, kPrintTemplateDefaultCode);
    final rows = await repo.allFor('sale');
    final classic = rows.firstWhere((r) => r.code == kInvoiceTemplateClassicA4);
    expect(classic.config.tableHeadArgb, 0xFF9DC3E6, reason: 'بذر الكلاسيكي');
  });

  test('تحمّل دفاعي: JSON تالف في config يرد للافتراض لا للاستثناء', () async {
    // تخريب مباشر بالقاعدة (نسخة يدوية/تحرير خارجي).
    await app.db.rawUpdate(
      "UPDATE print_template SET config = '{not valid json' "
      "WHERE code = 'simple_a4'",
    );
    final active = await repo.activeFor('sale');
    expect(active!.config, const InvoiceTemplateSettings(),
        reason: 'JSON التالف = إعدادات البسيط الافتراضية');
  });
}
