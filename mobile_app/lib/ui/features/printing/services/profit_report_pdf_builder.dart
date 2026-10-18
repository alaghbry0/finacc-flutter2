/// بنّاء PDF تقرير الأرباح والخسائر (الشريحة 10 — FR-09-02): قالب A4
/// عمودي RTL بنمط تقرير الوردية/كشف الحساب نفسه (Almarai + لوحة
/// الطباعة + استراتيجية الأعمدة الفيزيائية مع تشكيل عربي RTL).
///
/// قاعدة الملزمة المعمارية (نمط print_docs): كل نص داخل الـPDF يمر
/// عبر المسقط كتسمية **مسبقة التعريب** يبنيها `buildProfitPrintDoc`
/// من l10n — القالب نفسه بلا نص حرفي قابل للترجمة غير اسم المنتج
/// الثابت. الأرقام تُنسَّق عبر `AmountText.format`.
///
/// أقسام التخطيط مستخرجة إلى ملفات مركزّة بجوار البنّاء (R19-D3d):
/// المسقط والأنواع (`profit_report_pdf_doc.dart`) والترويسة
/// (`profit_report_pdf_header.dart`) وجدول البنود
/// (`profit_report_pdf_table.dart`) وكتل الإغلاق
/// (`profit_report_pdf_totals.dart`) والمساعدات المشتركة
/// (`profit_report_pdf_helpers.dart`).
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../core/print_fonts.dart';
import '../core/print_widgets.dart';
import '../docs/print_docs.dart';
import 'profit_report_pdf_doc.dart';
import 'profit_report_pdf_header.dart';
import 'profit_report_pdf_table.dart';
import 'profit_report_pdf_totals.dart';

export 'profit_report_pdf_doc.dart';

/// يحوّل [ProfitPrintDoc] إلى `pw.Document` جاهز للمعاينة/الطباعة/
/// المشاركة (استدعِ `PrintFonts.load()` أولاً — يحدث داخل [build]).
class ProfitReportPdfBuilder {
  const ProfitReportPdfBuilder();

  /// البناء الكامل — A4 عمودي؛ صفحة واحدة (بنود التقرير محدودة).
  Future<pw.Document> build(ProfitPrintDoc doc) async {
    await PrintFonts.load();
    final pdf = pw.Document(
      title: doc.labels.title,
      author: doc.header.name,
      creator: kPrintAppCredit,
      // Almarai في كل مكان — حتى النص الضمني لا يسقط لخط غير يونيكودي.
      theme: pw.ThemeData.withFont(
        base: PrintFonts.regular,
        bold: PrintFonts.bold,
      ),
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pw.PdfPageFormat(
          pw.PdfPageFormat.a4.width,
          pw.PdfPageFormat.a4.height,
          marginTop: 10 * pw.PdfPageFormat.mm,
          marginBottom: 13 * pw.PdfPageFormat.mm,
          marginLeft: 12 * pw.PdfPageFormat.mm,
          marginRight: 12 * pw.PdfPageFormat.mm,
        ),
        header: (context) => profitBrandBand(doc),
        footer: (context) =>
            printFooterLine(doc.header.footerText, doc.labels.footerThanks),
        build: (context) => [
          pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
          profitTitleRow(doc),
          pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
          profitMetaGrid(doc),
          pw.SizedBox(height: 6 * pw.PdfPageFormat.mm),
          profitLinesTable(doc),
          pw.SizedBox(height: 5 * pw.PdfPageFormat.mm),
          profitProfitCard(doc),
          pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
          profitOwnerCard(doc),
          pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
          profitPostingMapNote(doc),
        ],
      ),
    );
    return pdf;
  }
}
