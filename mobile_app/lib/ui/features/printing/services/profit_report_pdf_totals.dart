/// كتل إغلاق PDF تقرير الأرباح: بطاقة الربح البارزة بلمسة ذهبية
/// وبطاقة الإغلاق (المسحوبات ثم «صافي ما بقي للمالك») وحاشية خريطة
/// الترحيل — مستخرجة من profit_report_pdf_builder (R19-D3d: نقل حرفي
/// بلا أي تغيير سلوكي).
library;

import 'package:pdf/widgets.dart' as pw;

import '../core/print_palette.dart';
import 'profit_report_pdf_doc.dart';
import 'profit_report_pdf_helpers.dart';

/// بطاقة الربح البارزة — **لمسة ذهبية** وقيمة كبيرة ملوّنة بالإشارة.
pw.Widget profitProfitCard(ProfitPrintDoc doc) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PrintPalette.gold, width: 1.1),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          profitFmtSigned(doc, doc.profit),
          style: PrintText.head(color: profitToneColor(doc.profit), size: 14),
        ),
        pw.Text(
          doc.labels.profitLabel,
          style: PrintText.head(color: PrintPalette.brandDeep, size: 13),
          textDirection: pw.TextDirection.rtl,
        ),
      ],
    ),
  );
}

/// بطاقة الإغلاق: مسحوبات المالك ثم «صافي ما بقي للمالك» مؤكداً.
pw.Widget profitOwnerCard(ProfitPrintDoc doc) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PrintPalette.rule, width: 0.7),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        profitKvLine(
          doc.labels.ownerDrawingsLabel,
          profitFmtSigned(doc, -doc.ownerDrawings),
          size: 10.5,
        ),
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          color: PrintPalette.tableHead,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                profitFmtSigned(doc, doc.netForOwner),
                style: PrintText.head(
                  color: profitToneColor(doc.netForOwner),
                  size: 12.5,
                ),
              ),
              pw.Text(
                doc.labels.netForOwnerLabel,
                style: PrintText.head(
                  color: PrintPalette.brandDeep,
                  size: 11.5,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// حاشية خريطة الترحيل — قيد الاشتقاق الحصري (ملحق و).
pw.Widget profitPostingMapNote(ProfitPrintDoc doc) {
  return pw.Center(
    child: pw.Text(
      doc.labels.footerNote,
      style: PrintText.body(color: PrintPalette.inkSoft, size: 8),
      textDirection: pw.TextDirection.rtl,
    ),
  );
}
