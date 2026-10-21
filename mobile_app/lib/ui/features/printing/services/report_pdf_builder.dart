/// بنّاء PDF التقرير الجدولي العام (V7-B — عدة تصدير التقارير): قالب
/// A4 عمودي RTL يرسم أي [ReportPrintDoc] — نمط تقرير الوردية/كشف
/// الحساب نفسه (خطوط Cairo عبر PrintFonts + لوحة PrintPalette + تذييل
/// printFooterLine الموحد).
///
/// **الجدول RTL الفيزيائي**: بيئة حزمة pdf ترسم LTR، فيُقلب البنّاء
/// ترتيب الأعمدة والصفوف بنفسه — أول عمود بالقائمة المنطقية يقع أقصى
/// يمين الورقة (ترتيب القراءة العربية)، وكل خلية عربية تُرسم
/// `TextDirection.rtl` (إصلاح UX-audit A2: بلا تشكيل معكوس/مفكك
/// وانهيار subsetter)، وخلايا الأعمدة الرقمية [ReportColumnSpec.numeric]
/// تُرسم بالخط المرافق الجدولي LTR فتستقيم أعمدة المبالغ (UX-2b).
///
/// كل نص يصل من المسقط مسبق التعريب — لا نص حرفي هنا غير اسم المنتج
/// الثابت في التذييل (قاعدة print_docs).
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../core/print_fonts.dart';
import '../core/print_widgets.dart';
import '../core/print_palette.dart';
import '../docs/print_docs.dart';
import '../docs/report_print_doc.dart';

/// يحوّل [ReportPrintDoc] إلى `pw.Document` جاهز للمعاينة/الطباعة/
/// المشاركة/الترسيم صورة (استدعِ `PrintFonts.load()` أولاً — يحدث
/// داخل [build]).
class ReportPdfBuilder {
  const ReportPdfBuilder();

  /// البناء الكامل — A4 عمودي MultiPage: الجداول الطويلة تتدفق لصفحات
  /// إضافية بشريط الهوية والتذييل نفسه، ورأس الجدول يتكرر أعلى كل
  /// صفحة (`TableRow.repeat` — نمط TableHelper القائم).
  Future<pw.Document> build(ReportPrintDoc doc) async {
    await PrintFonts.load();
    final pdf = pw.Document(
      title: doc.title,
      author: doc.header.name,
      creator: kPrintAppCredit,
      // Cairo في كل مكان — حتى النص الضمني لا يسقط لخط غير يونيكودي.
      theme: pw.ThemeData.withFont(
        base: PrintFonts.regular,
        bold: PrintFonts.bold,
      ),
    );
    pdf.addPage(_sheetPage(doc));
    return pdf;
  }

  // -------------------------------------------------------------------
  // الصفحة
  // -------------------------------------------------------------------

  pw.MultiPage _sheetPage(ReportPrintDoc doc) {
    return pw.MultiPage(
      pageFormat: pw.PdfPageFormat(
        pw.PdfPageFormat.a4.width,
        pw.PdfPageFormat.a4.height,
        marginTop: 10 * pw.PdfPageFormat.mm,
        marginBottom: 13 * pw.PdfPageFormat.mm,
        marginLeft: 12 * pw.PdfPageFormat.mm,
        marginRight: 12 * pw.PdfPageFormat.mm,
      ),
      header: (context) => _brandBand(doc),
      footer: (context) =>
          printFooterLine(doc.header.footerText, doc.footerThanks),
      build: (context) => [
        pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
        _titleText(doc),
        pw.SizedBox(height: 3 * pw.PdfPageFormat.mm),
        _periodDateRow(doc),
        pw.SizedBox(height: 5 * pw.PdfPageFormat.mm),
        if (doc.columns.isNotEmpty) _table(doc),
      ],
    );
  }

  // -------------------------------------------------------------------
  // الكتل
  // -------------------------------------------------------------------

  /// شريط الهوية العميق (نمط كشف الحساب/السند): اسم المنشأة + هاتف/عنوان
  /// يميناً (جهة القراءة الأولى)، ومربع الحرف الأول يساراً — يتكرر أعلى
  /// كل صفحة عبر رأس MultiPage.
  pw.Widget _brandBand(ReportPrintDoc doc) {
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

  /// عنوان التقرير الكبير — ExtraBold مركّز (نمط عنوان السند).
  pw.Widget _titleText(ReportPrintDoc doc) {
    return pw.Center(
      child: pw.Text(
        doc.title,
        style: PrintText.extraHead(color: PrintPalette.brandDeep, size: 17),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// صف «الفترة: … / تاريخ التقرير: …» — شريط زيبِرة خفيف: الفترة
  /// يميناً (جهة القراءة الأولى) وتاريخ التقرير يساراً (نمط صف الرقم
  /// والتاريخ بالسند). القيم جاهزة من المسقط؛ التسميات مرّرها المستدعي
  /// من l10n (reportPdfPeriodLabel/reportPdfDateLabel).
  pw.Widget _periodDateRow(ReportPrintDoc doc) {
    return pw.Container(
      color: PrintPalette.zebra,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          if (doc.dateLabel.trim().isNotEmpty) _datePair(doc),
          if (doc.periodLabel.trim().isNotEmpty) _periodPair(doc),
        ],
      ),
    );
  }

  /// زوج «القيمة يساراً · التسمية يميناً» للتاريخ — قيمة رقمية بالخط
  /// المرافق الجدولي (UX-2b).
  pw.Widget _datePair(ReportPrintDoc doc) {
    return pw.Row(
      children: [
        pw.Text(
          doc.dateText,
          style: PrintText.tabular(color: PrintPalette.brandDeep, size: 10),
        ),
        pw.SizedBox(width: 5),
        pw.Text(
          doc.dateLabel,
          style: PrintText.body(color: PrintPalette.inkSoft, size: 10),
          textDirection: pw.TextDirection.rtl,
        ),
      ],
    );
  }

  /// زوج «القيمة يساراً · التسمية يميناً» للفترة — قيمة عربية غالباً
  /// («من X إلى Y») فتُرسم RTL دائماً (إصلاح UX-audit A2).
  pw.Widget _periodPair(ReportPrintDoc doc) {
    return pw.Row(
      children: [
        pw.Text(
          doc.periodText,
          style: PrintText.body(color: PrintPalette.brandDeep, size: 10),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(width: 5),
        pw.Text(
          doc.periodLabel,
          style: PrintText.body(color: PrintPalette.inkSoft, size: 10),
          textDirection: pw.TextDirection.rtl,
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // الجدول — RTL فيزيائي
  // -------------------------------------------------------------------

  /// جدول التقرير: الأعمدة تُقلب فيزيائيًا (أول عمود منطقي = أقصى يمين)
  /// ورأس الجدول يتكرر أعلى كل صفحة تالية، وصف الإجمالي (إن وجد) يُرسم
  /// بشريط داكن بخط أبيض.
  pw.Widget _table(ReportPrintDoc doc) {
    final width = doc.columns.length;
    // الأعمدة الفيزيائية: يسار→يمين = عكس القائمة المنطقية.
    final physicalColumns = doc.columns.reversed.toList();

    final rows = <pw.TableRow>[
      _headerRow(physicalColumns),
      for (var i = 0; i < doc.rows.length; i++)
        _dataRow(
          _physicalCells(doc.rows[i], width),
          physicalColumns,
          zebra: i.isOdd,
        ),
      if (doc.totalRow != null)
        _totalRow(_physicalCells(doc.totalRow, width), physicalColumns),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PrintPalette.rule, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: {
        // نسب نسبية تُطبَّع تلقائياً على عرض الصفحة (خوارزمية حزمة pdf):
        // عمود النص العربي أعرض من العمود الرقمي (نمط كشف الحساب).
        for (var i = 0; i < physicalColumns.length; i++)
          i: pw.FractionColumnWidth(
            physicalColumns[i].numeric || physicalColumns[i].ltr ? 1.0 : 1.5,
          ),
      },
      children: rows,
    );
  }

  /// صف الرأس — تعبئة tableHead وحروف داكنة عريضة، يتكرر أعلى كل صفحة.
  pw.TableRow _headerRow(List<ReportColumnSpec> physicalColumns) {
    return pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: PrintPalette.tableHead),
      children: [
        for (final col in physicalColumns)
          _cell(
            col.label,
            col,
            style: PrintText.head(color: PrintPalette.brandDeep, size: 9.5),
          ),
      ],
    );
  }

  /// صف بيانات — زيبِرة كل صف ثانٍ (نمط كشف الحساب).
  pw.TableRow _dataRow(
    List<String> physicalCells,
    List<ReportColumnSpec> physicalColumns, {
    required bool zebra,
  }) {
    return pw.TableRow(
      decoration: zebra
          ? const pw.BoxDecoration(color: PrintPalette.zebra)
          : null,
      children: [
        for (var i = 0; i < physicalColumns.length; i++)
          _cell(
            physicalCells[i],
            physicalColumns[i],
            style: _bodyStyle(physicalColumns[i]),
          ),
      ],
    );
  }

  /// صف الإجمالي — الشريط الداكن (brandDeep) بخط أبيض: الأرقام جدولية
  /// عريضة (tabularHead) والنص عريض.
  pw.TableRow _totalRow(
    List<String> physicalCells,
    List<ReportColumnSpec> physicalColumns,
  ) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PrintPalette.brandDeep),
      children: [
        for (var i = 0; i < physicalColumns.length; i++)
          _cell(
            physicalCells[i],
            physicalColumns[i],
            style: physicalColumns[i].numeric
                ? PrintText.tabularHead(color: pw.PdfColors.white, size: 10)
                : PrintText.head(color: pw.PdfColors.white, size: 9.5),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // مساعدات
  // -------------------------------------------------------------------

  /// خلية جدول نصية — المحاذاة والاتجاه حسب نوع العمود: الرقمي/LTR
  /// يسارًا بلا `textDirection` (LTR)، والعربي يمينًا RTL دائماً
  /// (إصلاح UX-audit A2/A3).
  pw.Widget _cell(
    String text,
    ReportColumnSpec column, {
    required pw.TextStyle style,
  }) {
    final ltr = column.numeric || column.ltr;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4.5, vertical: 4),
      child: pw.Align(
        alignment: ltr ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
        child: pw.Text(
          text,
          style: style,
          textDirection: ltr ? null : pw.TextDirection.rtl,
        ),
      ),
    );
  }

  /// نمط خلية الجسم حسب نوع العمود: الرقمي بالخط المرافق الجدولي
  /// (UX-2b — أرقام متساوية العرض) واللاتيني/العربي بخط الجسم.
  pw.TextStyle _bodyStyle(ReportColumnSpec column) =>
      column.numeric ? PrintText.tabular() : PrintText.body();

  /// خلايا الصف بالترتيب الفيزيائي (يسار→يمين) مع حشو/قص صبر على
  /// الصفوف الناقصة/الزائدة عن عدد الأعمدة فلا ينهار الجدول أبدًا.
  List<String> _physicalCells(List<String>? row, int width) {
    final logical = List<String>.filled(width, '');
    if (row != null) {
      for (var i = 0; i < width && i < row.length; i++) {
        logical[i] = row[i];
      }
    }
    return logical.reversed.toList();
  }
}
