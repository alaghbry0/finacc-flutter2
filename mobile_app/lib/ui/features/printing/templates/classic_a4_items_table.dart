/// جدول أصناف القالب الكلاسيكي (R19-D3c — مستخرج حرفياً من
/// `classic_a4_template.dart` بلا أي تغيير دلالة) — إطار خارجي سميك
/// وحدود داخلية رفيعة ورأس مظلل عريض.
library;

import 'package:pdf/widgets.dart' as pw;

import '../../../../data/models/invoice_template_settings.dart';
import '../core/print_palette.dart';
import '../docs/print_docs.dart';
import 'template_colors.dart';

// -------------------------------------------------------------------
// جدول الأصناف — إطار خارجي سميك وحدود داخلية رفيعة ورأس مظلل عريض
// -------------------------------------------------------------------

/// وصف أعمدة الجدول الفيزيائية (LTR — الصنف أقصى اليمين):
/// [المجموع، (الخصم)، السعر، الكمية، (الوحدة)، الصنف].
ClassicColumnsSpec classicColumns(
  InvoicePrintDoc doc,
  InvoiceTemplateSettings settings,
) {
  final templateLabels = doc.templateLabels;
  final showUnit =
      settings.showUnitColumn &&
      templateLabels?.unitCol != null &&
      doc.items.any((line) => (line.unitLabel ?? '').trim().isNotEmpty);
  final showDiscount = settings.showDiscountColumn;
  final headers = <String>[
    doc.labels.grandTotal,
    if (showDiscount) doc.labels.discount,
    doc.labels.price,
    doc.labels.qty,
    if (showUnit) templateLabels!.unitCol!,
    doc.labels.item,
  ];
  final widths = <double>[
    1.15,
    if (showDiscount) 0.85,
    1.05,
    0.6,
    if (showUnit) 0.75,
  ];
  // فهرس أول عمود نصي (الوحدة إن وُجدت وإلا الصنف).
  final textStart = headers.length - (showUnit ? 2 : 1);
  return ClassicColumnsSpec(
    headers: headers,
    fractions: widths,
    showDiscount: showDiscount,
    showUnit: showUnit,
    unitTextIndex: showUnit ? textStart : -1,
  );
}

pw.Widget classicItemsTable(
  InvoicePrintDoc doc,
  InvoiceTemplateSettings settings,
) {
  final spec = classicColumns(doc, settings);
  final data = <List<String>>[
    for (final line in doc.items)
      [
        line.totalLabel,
        if (spec.showDiscount) line.discountLabel,
        line.priceLabel,
        // UX-4: لاحقة البونص بجوار الكمية (qtyCellLabel) — لا عمود جديد.
        line.qtyCellLabel,
        if (spec.showUnit)
          (line.unitLabel ?? '').trim().isEmpty ? '—' : line.unitLabel!.trim(),
        line.desc,
      ],
  ];
  final border = templatePdfColor(settings.borderArgb);
  final headFill = templatePdfColor(settings.tableHeadArgb);
  final headText = templateOnColor(headFill);
  // الأعمدة الرقمية قبل عمودي الوحدة/الصنف — خط tnum الجدولي.
  final numericCount = spec.headers.length - (spec.showUnit ? 2 : 1);
  final columnWidths = <int, pw.TableColumnWidth>{
    for (var c = 0; c < spec.fractions.length; c++)
      c: pw.FractionColumnWidth(spec.fractions[c]),
  };
  return pw.TableHelper.fromTextArray(
    headers: spec.headers,
    data: data,
    border: pw.TableBorder(
      top: pw.BorderSide(color: border, width: 1.5),
      bottom: pw.BorderSide(color: border, width: 1.5),
      left: pw.BorderSide(color: border, width: 1.5),
      right: pw.BorderSide(color: border, width: 1.5),
      horizontalInside: pw.BorderSide(color: border, width: 0.4),
      verticalInside: pw.BorderSide(color: border, width: 0.4),
    ),
    headerDecoration: pw.BoxDecoration(color: headFill),
    headerStyle: PrintText.head(color: headText, size: 10.5),
    headerAlignments: classicAlignments(spec, numericCount),
    cellAlignments: classicAlignments(spec, numericCount),
    cellStyle: PrintText.body(size: 10),
    textStyleBuilder: (column, cell, rowNum) =>
        column < numericCount ? PrintText.tabular(size: 10) : null,
    headerDirection: pw.TextDirection.rtl,
    tableDirection: pw.TextDirection.rtl,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
    headerPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    columnWidths: columnWidths,
  );
}

/// محاذاة الأعمدة: المبالغ/السعر يساراً (تُقرأ LTR)، الخصم/الكمية/
/// الوحدة وسطاً، الصنف أقصى اليمين (RTL).
Map<int, pw.AlignmentGeometry> classicAlignments(
  ClassicColumnsSpec spec,
  int numericCount,
) {
  final map = <int, pw.AlignmentGeometry>{};
  var c = 0;
  // الإجمالي — رقمي يسار.
  map[c++] = pw.Alignment.centerLeft;
  // الخصم — وسط.
  if (spec.showDiscount) map[c++] = pw.Alignment.center;
  // السعر — رقمي يسار.
  map[c++] = pw.Alignment.centerLeft;
  // الكمية — وسط.
  map[c++] = pw.Alignment.center;
  // الوحدة — وسط.
  if (spec.showUnit) map[c++] = pw.Alignment.center;
  // الصنف — أقصى اليمين دائماً (الأخير فيزيائياً).
  map[c] = pw.Alignment.centerRight;
  return map;
}

/// وصف أعمدة جدول الأصناف المحسوبة (تخطيط فيزيائي LTR).
class ClassicColumnsSpec {
  const ClassicColumnsSpec({
    required this.headers,
    required this.fractions,
    required this.showDiscount,
    required this.showUnit,
    required this.unitTextIndex,
  });

  final List<String> headers;
  final List<double> fractions;
  final bool showDiscount;
  final bool showUnit;

  /// فهرس عمود الوحدة داخل الجزء النصي (−1 حين لا يوجد).
  final int unitTextIndex;
}
