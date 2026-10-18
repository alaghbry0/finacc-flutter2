/// كتلة بيانات الطرف للقالب الكلاسيكي (R19-D3c — مستخرجة حرفياً من
/// `classic_a4_template.dart` بلا أي تغيير دلالة).
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../core/print_palette.dart';
import '../docs/print_docs.dart';

// -------------------------------------------------------------------
// بيانات العميل — أسطر نصية يمينية بلا إطار (نموذج المالك)
// -------------------------------------------------------------------

pw.Widget classicCustomerLines(InvoicePrintDoc doc) {
  final phone = (doc.partyPhone ?? '').trim();
  final currency =
      '${doc.labels.currency}: ${doc.currencyCode.isEmpty ? '—' : doc.currencyCode}';
  return pw.Padding(
    padding: const pw.EdgeInsets.only(right: 2 * pw.PdfPageFormat.mm),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          '${doc.labels.customer}: ${doc.partyName}',
          style: PrintText.body(size: 10.5),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Text(
            phone.isEmpty ? currency : '$currency · $phone',
            style: PrintText.body(color: PrintPalette.inkSoft, size: 9),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      ],
    ),
  );
}
