/// إجماليات القالب الكلاسيكي (R19-D3c — مستخرجة حرفياً من
/// `classic_a4_template.dart` بلا أي تغيير دلالة) — الخط المزدوج +
/// جدول الإجماليات الصغير يميناً + الملاحظات ومساحة الختم يساراً.
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../../../../data/models/invoice_template_settings.dart';
import '../../../core/widgets/amount_text.dart';
import '../core/print_palette.dart';
import '../docs/print_docs.dart';
import 'classic_a4_helpers.dart';
import 'template_colors.dart';

/// خلفية صف الإجمالي الكريمية (نموذج المالك).
const pw.PdfColor kClassicCream = pw.PdfColor.fromInt(0xFFF7F1DF);

// -------------------------------------------------------------------
// الخط المزدوج + صف الإجماليات (جدول صغير يميناً + ملاحظات/ختم يساراً)
// -------------------------------------------------------------------

/// الخط المزدوج الفاصل (نموذج المالك): حافة علوية سميقة وسفلية رفيعة.
pw.Widget classicDoubleRule(InvoiceTemplateSettings settings) {
  final border = templatePdfColor(settings.borderArgb);
  return pw.Container(
    height: 3.2,
    decoration: pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: border, width: 1.3),
        bottom: pw.BorderSide(color: border, width: 0.5),
      ),
    ),
  );
}

pw.Widget classicTotalsRow(
  InvoicePrintDoc doc,
  InvoiceTemplateSettings settings,
) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // يسار الصفحة: خانة الملاحظات ثم مساحة الختم تحتها.
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (settings.showNotes && doc.templateLabels?.notesTitle != null)
              classicNotesBox(doc, settings),
            if (settings.showStampArea &&
                doc.templateLabels?.stampArea != null) ...[
              classicGap(2),
              classicStampBox(doc, settings),
            ],
          ],
        ),
      ),
      pw.SizedBox(width: 8 * pw.PdfPageFormat.mm),
      // يمين الصفحة: جدول الإجماليات الصغير.
      pw.Container(
        width: 82 * pw.PdfPageFormat.mm,
        child: classicTotalsTable(doc, settings),
      ),
    ],
  );
}

/// خانة الملاحظات — إطار خفيف بعنوان ومحتوى `notes_printed` (أو فراغ).
pw.Widget classicNotesBox(
  InvoicePrintDoc doc,
  InvoiceTemplateSettings settings,
) {
  return pw.Container(
    width: double.infinity,
    height: 20 * pw.PdfPageFormat.mm,
    padding: const pw.EdgeInsets.all(5),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(
        color: templatePdfColor(settings.borderArgb),
        width: 0.5,
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          doc.templateLabels!.notesTitle!,
          style: PrintText.head(color: PrintPalette.inkSoft, size: 9),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 3),
        pw.Expanded(
          child: pw.Text(
            (doc.notesPrinted ?? '').trim(),
            style: PrintText.body(),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      ],
    ),
  );
}

/// مساحة الختم المحجوزة — إطار خفيف بتسمية باهتة بلا دائرة (المالك).
pw.Widget classicStampBox(
  InvoicePrintDoc doc,
  InvoiceTemplateSettings settings,
) {
  return pw.Container(
    width: 46 * pw.PdfPageFormat.mm,
    height: 18 * pw.PdfPageFormat.mm,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(
        color: templatePdfColor(settings.borderArgb),
        width: 0.5,
      ),
    ),
    child: pw.Text(
      doc.templateLabels!.stampArea!,
      style: PrintText.body(color: PrintPalette.inkSoft, size: 8.5),
      textDirection: pw.TextDirection.rtl,
    ),
  );
}

/// جدول الإجماليات الصغير يميناً — [قيمة يساراً · تسمية يميناً]، صف
/// الإجمالي بخلفية كريمية والمتبقي بأحمر عريض (نموذج المالك).
pw.Widget classicTotalsTable(
  InvoicePrintDoc doc,
  InvoiceTemplateSettings settings,
) {
  final labels = doc.labels;
  final red = templatePdfColor(settings.accentRedArgb);
  final border = templatePdfColor(settings.borderArgb);
  final rows = <(String, String, ClassicTotalRowStyle)>[
    if (doc.discountAmount.abs() >= 0.005) ...[
      (
        labels.subtotal,
        _fmtMoney(doc, doc.subtotal),
        ClassicTotalRowStyle.plain,
      ),
      (
        labels.totalDiscount,
        _fmtMoney(doc, doc.discountAmount),
        ClassicTotalRowStyle.plain,
      ),
    ],
    (labels.grandTotal, _fmtMoney(doc, doc.total), ClassicTotalRowStyle.cream),
    if (doc.paidAmount.abs() >= 0.005)
      (labels.paid, _fmtMoney(doc, doc.paidAmount), ClassicTotalRowStyle.plain),
    if (doc.dueAmount.abs() >= 0.005)
      (labels.due, _fmtMoney(doc, doc.dueAmount), ClassicTotalRowStyle.red),
  ];
  return pw.Table(
    border: pw.TableBorder.all(color: border, width: 0.5),
    columnWidths: const {
      0: pw.FractionColumnWidth(1.15),
      1: pw.FractionColumnWidth(1),
    },
    children: [
      for (final (label, value, style) in rows)
        pw.TableRow(
          decoration: style == ClassicTotalRowStyle.cream
              ? const pw.BoxDecoration(color: kClassicCream)
              : null,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  value,
                  style: style == ClassicTotalRowStyle.red
                      ? PrintText.tabularHead(color: red)
                      : style == ClassicTotalRowStyle.cream
                      ? PrintText.tabularHead(color: PrintPalette.brandDeep)
                      : PrintText.tabular(
                          color: PrintPalette.brandDeep,
                          size: 10,
                        ),
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              child: pw.Text(
                label,
                style: style == ClassicTotalRowStyle.red
                    ? PrintText.head(color: red, size: 10.5)
                    : style == ClassicTotalRowStyle.cream
                    ? PrintText.head(color: PrintPalette.brandDeep, size: 10.5)
                    : PrintText.body(color: PrintPalette.inkSoft),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
          ],
        ),
    ],
  );
}

String _fmtMoney(InvoicePrintDoc doc, double value) =>
    AmountText.format(value, doc.decimals);

/// مخطط نمط صف الإجماليات.
enum ClassicTotalRowStyle { plain, cream, red }
