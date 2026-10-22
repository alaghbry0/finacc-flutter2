/// تصدير التقرير إلى ملف Excel حقيقي (xlsx — V7-B، عدة تصدير التقارير).
///
/// طبقتان كما في منظومة الطباعة القائمة:
/// 1. **`buildReportExcelBytes`** — نقية بلا سياق: تبني مصنف xlsx عبر
///    `package:excel` (قائمة في pubspec — نفس محرّك استيراد الأصناف):
///    ورقة باسم `sheetTitle` (مقصوصًا لحد Excel 31 محرفًا مع تنظيف
///    محارف أسماء الأوراق المحظورة)، صف رؤوس **عريض**، ثم الصفوف —
///    والقيمة الرقمية الخالصة تُكتب **رقمًا خامًا** (Int/DoubleCellValue)
///    لا نصًا فتستقيم الجمع والفرز في Excel.
/// 2. **`exportReportExcel`** — عالية المستوى: تبني البايتات وتنزّلها
///    عبر `downloadBytes` (المساعد المشروط بالمنصة — ويب فقط حاليًا)
///    بنمط MIME الرسمي لـxlsx، وSnackBar نجاح اختياري (`showFeedback`
///    — كي تستهلكه الاختبارات بلا Scaffold).
///
/// اسم الملف: المستدعي يمرر الاسم **بلا امتداد** — يُنظَّف محارف
/// المسارات بنمط `pdf_preview_dialog._fileName` (استبدال بـ'-') ويُضاف
/// `.xlsx`. الاستثناءات (كالتنزيل على غير الويب) تُترك للمستدعي
/// يلتقطها ويعرض رسالته — لا مفاتيح فشل مقفلة لنا في l10n.
library;

import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/web_download.dart';
import '../../../../l10n/app_localizations.dart';

/// MIME الرسمي لملفات xlsx (Office Open XML).
const String kReportExcelMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// يبني بايتات مصنف xlsx للتقرير — **نقية وقابلة للاختبار** بلا سياق
/// ولا I/O منصة.
///
/// [sheetTitle] اسم الورقة (يقص عند حد Excel 31 محرفًا بعد تنظيف
/// المحارف المحظورة `: \ / ? * [ ]` — والفراغ يسقط لاسم ورقة Excel
/// الافتراضي). [headers] تسميات الأعمدة (تُرسم عريضة). [rows] القيم
/// نصية مسبقة التنسيق من المستدعي؛ الخلية الرقمية الخالصة (أعداد
/// int/double بلا محارف أخرى) تُكتب رقمًا خامًا.
Uint8List buildReportExcelBytes({
  required String sheetTitle,
  required List<String> headers,
  required List<List<String>> rows,
}) {
  final excel = Excel.createExcel();
  final sheetName = _sheetName(sheetTitle);
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null && defaultSheet != sheetName) {
    excel.rename(defaultSheet, sheetName);
  }
  final sheet = excel[sheetName];

  // مراجعة V7 🟡-3 — الورقة RTL: التقرير العربي يفتح باتجاه القراءة
  // الصحيح (العمود الأول أقصى اليمين) بدل LTR الافتراضي.
  sheet.isRTL = true;

  // صف الرؤوس ثم صفوف البيانات — appendRow يكتب بعد آخر صف معبأ.
  sheet.appendRow([for (final header in headers) TextCellValue(header)]);
  for (final row in rows) {
    sheet.appendRow([
      for (var c = 0; c < headers.length; c++) _cellValue(row, c),
    ]);
  }

  // ترويس عريض: يُعاد ضبط خلايا الصف الأول بنمط Bold فوق القيم نفسها.
  final headerStyle = CellStyle(bold: true);
  for (var c = 0; c < headers.length; c++) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      TextCellValue(headers[c]),
      cellStyle: headerStyle,
    );
  }

  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('تعذّر ترميز مصنف Excel للتقرير');
  }
  return Uint8List.fromList(bytes);
}

/// يبني ملف Excel للتقرير وينزّله — عالية المستوى لشاشات التقارير.
///
/// [fileName] بلا امتداد (يُضاف `.xlsx` بعد تنظيف محارف المسارات).
/// [showFeedback] (افتراضي true) يعرض SnackBar نجاح برسالة
/// `l10n.reportSimExportExcelDone` — عطّله في الاختبارات/الاستهلاك
/// الصامت. أي استثناء (تنزيل على غير الويب مثلًا) يُترك يطفو للمستدعي.
Future<void> exportReportExcel({
  required BuildContext context,
  required String fileName,
  required String sheetTitle,
  required List<String> headers,
  required List<List<String>> rows,
  bool showFeedback = true,
}) async {
  final bytes = buildReportExcelBytes(
    sheetTitle: sheetTitle,
    headers: headers,
    rows: rows,
  );
  downloadBytes(
    bytes,
    '${sanitizeReportFileName(fileName)}.xlsx',
    mime: kReportExcelMime,
  );
  if (showFeedback) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.reportSimExportExcelDone)));
  }
}

/// اسم ملف نظيف بلا امتداد — نمط `pdf_preview_dialog._fileName`
/// (استبدال محارف المسارات الممنوعة بـ'-') مع قصّ الفراغات الطرفية.
String sanitizeReportFileName(String raw) =>
    raw.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');

/// قيمة خلية: الرقم الخالص (int ثم double — بلا NaN/Infinity) يُكتب
/// رقمًا خامًا، وما سواه نصًا كما وصل.
CellValue _cellValue(List<String> row, int column) {
  final text = column < row.length ? row[column].trim() : '';
  if (text.isNotEmpty) {
    final asInt = int.tryParse(text);
    if (asInt != null) return IntCellValue(asInt);
    final asDouble = double.tryParse(text);
    if (asDouble != null && asDouble.isFinite) {
      return DoubleCellValue(asDouble);
    }
  }
  return TextCellValue(text);
}

/// اسم ورقة صالح لحدود Excel: ≤31 محرفًا، بلا المحارف المحظورة
/// `: \ / ? * [ ]`، والفراغ يسقط لاسم الورقة الافتراضي.
String _sheetName(String title) {
  var name = title
      .trim()
      .replaceAll(RegExp(r'[:\\/?*\[\]]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (name.length > 31) name = name.substring(0, 31);
  return name.isEmpty ? 'Sheet1' : name;
}
