/// ترويسة PDF تقرير الأرباح: شريط الهوية العميق وصف العنوان بشارة
/// الفترة وشبكة البيانات — مستخرجة من profit_report_pdf_builder
/// (R19-D3d: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../core/print_palette.dart';
import '../core/print_widgets.dart';
import 'profit_report_pdf_doc.dart';
import 'profit_report_pdf_helpers.dart';

/// شريط الهوية العميق — مطابق لقالب تقرير الوردية.
pw.Widget profitBrandBand(ProfitPrintDoc doc) {
  final phone = (doc.header.phone ?? '').trim();
  final address = (doc.header.address ?? '').trim();
  final contact = address.isEmpty
      ? phone
      : phone.isEmpty
      ? address
      : '$phone · $address';
  return pw.Container(
    color: PrintPalette.brandDeep,
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Container(
          width: 34,
          height: 34,
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(color: PrintPalette.brand),
          child: pw.Text(
            printMonogram(doc.header.name),
            style: PrintText.head(color: pw.PdfColors.white, size: 17),
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              doc.header.name,
              style: PrintText.head(color: pw.PdfColors.white, size: 15),
              textDirection: pw.TextDirection.rtl,
            ),
            if (contact.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  contact,
                  style: PrintText.body(
                    color: PrintPalette.highlight,
                    size: 8.5,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// صف العنوان: «تقرير الأرباح والخسائر» يميناً + رقاقة الفترة يساراً.
pw.Widget profitTitleRow(ProfitPrintDoc doc) {
  return pw.Row(
    children: [
      pw.Expanded(
        child: pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PrintPalette.brand,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              doc.periodLabel,
              style: PrintText.head(color: pw.PdfColors.white, size: 10),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ),
      ),
      pw.Text(
        doc.labels.title,
        style: PrintText.head(color: PrintPalette.brandDeep, size: 18),
        textDirection: pw.TextDirection.rtl,
      ),
    ],
  );
}

/// شبكة البيانات: وقت الإنشاء يميناً، والعملة يساراً.
pw.Widget profitMetaGrid(ProfitPrintDoc doc) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PrintPalette.rule, width: 0.7),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [profitKvLine(doc.labels.currencyNote, '')],
          ),
        ),
        pw.SizedBox(width: 8 * pw.PdfPageFormat.mm),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [profitKvLine(doc.labels.generatedAtLabel, '')],
          ),
        ),
      ],
    ),
  );
}
