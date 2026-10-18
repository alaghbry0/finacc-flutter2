/// ذيل القالب الكلاسيكي (R19-D3c — مستخرج حرفياً من
/// `classic_a4_template.dart` بلا أي تغيير دلالة) — التوقيعات الثلاث
/// والباركود والتذييل.
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../core/print_palette.dart';
import '../docs/print_docs.dart';

// -------------------------------------------------------------------
// التوقيعات الثلاث + الباركود + التذييل
// -------------------------------------------------------------------

/// ثلاث خانات توقيع أفقية — فيزيائياً [البائع، المحصّل، المستلم] فيقرؤها
/// العربي من اليمين: المستلم ثم المحصّل ثم البائع (نموذج المالك).
pw.Widget classicSignaturesRow(InvoicePrintDoc doc) {
  final labels = doc.templateLabels;
  final cells = <String?>[
    labels?.signatureSeller,
    labels?.signatureCollector,
    labels?.signatureReceiver,
  ];
  return pw.Row(
    children: [
      for (var i = 0; i < cells.length; i++) ...[
        if (i > 0) pw.SizedBox(width: 5 * pw.PdfPageFormat.mm),
        pw.Expanded(
          child: pw.Container(
            height: 15 * pw.PdfPageFormat.mm,
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PrintPalette.rule, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  cells[i] ?? '—',
                  style: PrintText.body(color: PrintPalette.inkSoft, size: 9),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

/// باركود Code128 لرقم الفاتورة + الرقم تحته بالخط الجدولي.
pw.Widget classicBarcode(InvoicePrintDoc doc) {
  return pw.Center(
    child: pw.Column(
      children: [
        pw.BarcodeWidget(
          data: doc.docNo,
          barcode: pw.Barcode.code128(),
          drawText: false,
          height: 12 * pw.PdfPageFormat.mm,
          width: 58 * pw.PdfPageFormat.mm,
        ),
        pw.SizedBox(height: 1.5),
        pw.Text(
          doc.docNo,
          style: PrintText.tabular(color: PrintPalette.inkSoft, size: 8.5),
        ),
      ],
    ),
  );
}

/// التذييل: نص المنشأة/الشكر يميناً ونسبة التطبيق يساراً.
pw.Widget classicFooterRow(InvoicePrintDoc doc) {
  final companyFooter = (doc.header.footerText ?? '').trim();
  final thanks = doc.labels.footerThanks;
  final right = companyFooter.isEmpty ? thanks : '$thanks · $companyFooter';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Divider(color: PrintPalette.rule, thickness: 0.5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            kPrintAppCredit,
            style: PrintText.body(color: PrintPalette.inkSoft, size: 7.5),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.Text(
            right,
            style: PrintText.body(color: PrintPalette.inkSoft, size: 8),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    ],
  );
}
