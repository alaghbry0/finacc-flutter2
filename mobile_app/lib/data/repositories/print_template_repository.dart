/// مستودع قوالب الطباعة — جدول `print_template` (هجرة v4 — موجة UX-3).
///
/// صف واحد لكل (نوع مستند × قالب) بإعدادات JSON في `config`، وعمود
/// `is_default` يحدد القالب النشط الذي تمر عبره طباعة/معاينة الفواتير.
/// الشعار يبقى في `company.logo_png` (لا يُكرَّر هنا — قرار المنسق).
///
/// كل القراءات متحمّلة دفاعياً: JSON تالف يرد للافتراض، ولا صف افتراضي
/// يعني إعدادات البسيط A4 (سلوك المتجر قبل الترقية كما هو).
library;

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../ui/features/printing/templates/invoice_template_settings.dart';

/// صف قالب طباعة مقروء.
class PrintTemplateRow {
  const PrintTemplateRow({
    required this.id,
    required this.docType,
    required this.code,
    required this.isDefault,
    required this.config,
    required this.updatedAt,
  });

  final int id;

  /// نوع المستند (`sale` في V1).
  final String docType;

  /// كود القالب (`classic_a4` / `simple_a4`) — تحويل قراءة R16-b: أي
  /// صف قديم `thermal_80` (بذر v4) يُقرأ `classic_a4`.
  final String code;

  /// هو القالب النشط لهذا النوع؟
  final bool isDefault;

  /// الإعدادات المفكوكة (defensive: JSON سيئ = افتراضات).
  final InvoiceTemplateSettings config;

  /// آخر تحديث (ISO من القاعدة).
  final String? updatedAt;

  factory PrintTemplateRow.fromRow(Map<String, Object?> row) =>
      PrintTemplateRow(
        id: row['id'] as int,
        docType: row['doc_type'] as String? ?? 'sale',
        // R16-b — تحويل قراءة: القالب الحراري حُذف بقرار المالك؛ صف
        // `thermal_80` المحفوظ قديماً يُقرأ `classic_a4` فيراه المحرك
        // والشاشة كلاسيكياً (بلا هجرة schema).
        code: _normalizeCode(row['code'] as String),
        isDefault: (row['is_default'] as int? ?? 0) == 1,
        config: InvoiceTemplateSettings.fromJsonString(
          row['config'] as String?,
        ),
        updatedAt: row['updated_at'] as String?,
      );
}

/// إعدادات البذر الافتراضية لكل قالب — مرجع [resetToDefault]
/// واختبارات الوحدة. (R16-b: الحراري محذوف؛ صفه القديم إن وُجد لا
/// يُعاد ضبطه ويبقى محوَّلاً للكلاسيكي عند القراءة.)
const Map<String, InvoiceTemplateSettings> kPrintTemplateSeedConfigs =
    <String, InvoiceTemplateSettings>{
      'classic_a4': InvoiceTemplateSettings(
        templateId: kInvoiceTemplateClassicA4,
        tableHeadArgb: 0xFF9DC3E6,
        borderArgb: 0xFF37474F,
        showUnitColumn: true,
      ),
      'simple_a4': InvoiceTemplateSettings(
        templateId: kInvoiceTemplateSimpleA4,
        tableHeadArgb: 0xFFDFEBE7,
        borderArgb: 0xFFDCE7E1,
      ),
    };

/// القالب الافتراضي عند غياب أي صف (سلوك ما قبل الترقية).
const String kPrintTemplateDefaultCode = kInvoiceTemplateSimpleA4;

/// R16-b — تحويل قراءة كود الصف: القالب الحراري حُذف نهائياً بقرار
/// المالك، فأي صف قديم قيمته `thermal_80` (بذر هجرة v4 قديمة) يُقرأ
/// `classic_a4` — الشاشة والمحرك لا يعرفان الحراري أبداً بعد الآن.
String _normalizeCode(String code) =>
    code == kLegacyInvoiceTemplateThermal80 ? kInvoiceTemplateClassicA4 : code;

class PrintTemplateRepository {
  PrintTemplateRepository(this._db);

  final Database _db;

  /// القالب النشط لنوع المستند — `null` إن لم تُبذر الصفوف بعد
  /// (المستدعي يرد لإعدادات البسيط الافتراضية).
  Future<PrintTemplateRow?> activeFor(String docType) async {
    final rows = await _db.query(
      'print_template',
      where: 'doc_type = ? AND is_default = 1',
      whereArgs: [docType],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PrintTemplateRow.fromRow(rows.first);
  }

  /// كل قوالب نوع المستند بترتيب البذر (الكلاسيكي/البسيط — وصف
  /// `thermal_80` القديم إن وُجد يُقرأ كلاسيكياً).
  Future<List<PrintTemplateRow>> allFor(String docType) async {
    final rows = await _db.query(
      'print_template',
      where: 'doc_type = ?',
      whereArgs: [docType],
      orderBy: 'id ASC',
    );
    return [for (final row in rows) PrintTemplateRow.fromRow(row)];
  }

  /// يحفظ إعدادات قالب **ويعملّه** للنوع: صفه يُحدَّث بالإعدادات الجديدة
  /// و`is_default` ينتقل إليه حصراً (عملية واحدة ذرية التأثير).
  ///
  /// الكود غير المعروف يُرفض صراحة (الواجهة لا تعرض سوى المبذورة).
  Future<void> save(
    String code,
    InvoiceTemplateSettings config, {
    String docType = 'sale',
  }) async {
    if (!kInvoiceTemplateCodes.contains(code)) {
      throw ArgumentError('كود قالب طباعة غير معروف: $code');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _db.query(
      'print_template',
      columns: ['id'],
      where: 'doc_type = ? AND code = ?',
      whereArgs: [docType, code],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw ArgumentError('قالب غير مبذور لهذا النوع: $code ($docType)');
    }
    final id = rows.first['id'] as int;
    await _db.update(
      'print_template',
      {
        'is_default': 1,
        'config': jsonEncode(config.toJson()),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _db.rawUpdate(
      'UPDATE print_template SET is_default = 0, updated_at = ? '
      'WHERE doc_type = ? AND id != ?',
      <Object>[now, docType, id],
    );
  }

  /// يستعيد إعدادات البذر لكل قوالب النوع ويعيد البسيط A4 نشطاً —
  /// «استعادة الافتراضي» بشاشة التخصيص.
  Future<void> resetToDefault({String docType = 'sale'}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    for (final entry in kPrintTemplateSeedConfigs.entries) {
      await _db.update(
        'print_template',
        {
          'config': jsonEncode(entry.value.toJson()),
          'updated_at': now,
        },
        where: 'doc_type = ? AND code = ?',
        whereArgs: [docType, entry.key],
      );
    }
    await _db.rawUpdate(
      'UPDATE print_template SET is_default = CASE WHEN code = ? THEN 1 '
      'ELSE 0 END, updated_at = ? WHERE doc_type = ?',
      <Object>[kPrintTemplateDefaultCode, now, docType],
    );
  }
}
