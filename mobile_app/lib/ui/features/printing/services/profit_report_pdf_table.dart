/// جدول بنود PDF تقرير الأرباح: [القيمة يساراً، البند أقصى اليمين]
/// مع رؤوس الأقسام المظللة وقيم موقّعة ملوّنة — مستخرج من
/// profit_report_pdf_builder (R19-D3d: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:pdf/widgets.dart' as pw;

import '../core/print_palette.dart';
import 'profit_report_pdf_doc.dart';
import 'profit_report_pdf_helpers.dart';

pw.Widget profitLinesTable(ProfitPrintDoc doc) {
  final rows = <pw.TableRow>[
    _tableRow(
      value: _cellText(
        doc.labels.valueCol,
        PrintText.head(color: PrintPalette.brandDeep, size: 9.5),
      ),
      item: _cellText(
        doc.labels.itemCol,
        PrintText.head(color: PrintPalette.brandDeep, size: 9.5),
        rtl: true,
      ),
      decoration: const pw.BoxDecoration(color: PrintPalette.tableHead),
    ),
  ];
  for (final section in doc.sections) {
    rows.add(
      _tableRow(
        value: _cellText('', PrintText.body(size: 4)),
        item: _cellText(
          section.title,
          PrintText.head(color: PrintPalette.brandDeep, size: 9.5),
          rtl: true,
        ),
        decoration: const pw.BoxDecoration(color: PrintPalette.zebra),
      ),
    );
    for (final line in section.lines) {
      final color = switch (line.tone) {
        ProfitLineTone.positive => kProfitSurplus,
        ProfitLineTone.negative => kProfitDeficit,
        ProfitLineTone.neutral => PrintPalette.brandDeep,
      };
      final style = line.strong
          ? PrintText.head(color: color, size: 9.5)
          : PrintText.body(color: color);
      rows.add(
        _tableRow(
          value: _cellText(line.valueLabel, style),
          item: _cellText(
            line.itemLabel,
            line.strong ? PrintText.head(size: 9.5) : PrintText.body(),
            rtl: true,
          ),
          decoration: line.strong
              ? const pw.BoxDecoration(color: PrintPalette.zebra)
              : null,
        ),
      );
    }
  }
  return pw.Table(
    border: pw.TableBorder.all(color: PrintPalette.rule, width: 0.5),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    columnWidths: const {
      0: pw.FractionColumnWidth(1.15), // القيمة — رقمي
      1: pw.FractionColumnWidth(2.85), // البند — نص عربي
    },
    children: rows,
  );
}

/// خلية جدول نصية (قيمة يساراً/بند يميناً).
pw.Widget _cellText(String text, pw.TextStyle style, {bool rtl = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4.5, vertical: 4),
    child: pw.Align(
      alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: style,
        textDirection: rtl ? pw.TextDirection.rtl : null,
      ),
    ),
  );
}

/// صف جدول: العمود ٠ = القيمة (يسار)، العمود ١ = البند (يمين).
pw.TableRow _tableRow({
  required pw.Widget value,
  required pw.Widget item,
  pw.BoxDecoration? decoration,
}) {
  return pw.TableRow(decoration: decoration, children: [value, item]);
}
