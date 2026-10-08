/// بنّاء PDF تقرير الوردية (الشريحة 9 — FR-04-04): قالب A4 عمودي RTL.
///
/// بنية المستند: شريط هوية المنشأة ← صف العنوان («تقرير الوردية» يميناً
/// ورقاقة الصندوق يساراً) ← شبكة البيانات (الصندوق/المستخدم/الفتح/
/// الإقفال) ← جدول المعادلة الشاملة بأعمدة [القيمة، الاتجاه، البند]
/// فيزيائياً يسار→يمين فيقع البند أقصى اليمين + حاشية الشيكات المؤجلة
/// ← بطاقة الإجماليات (الافتتاحي/إجمالي الوارد/الصادر) ← بطاقة الحسم
/// البارزة **المتوقع/العدّ الفعلي/الفرق ملوّناً** (أخضر زيادة/أحمر عجز/
/// محايد مطابق) ← سطر الملاحظات ← تذييل. استراتيجية RTL مطابقة لقالب
/// كشف الحساب: ترتيب الأعمدة فيزيائي وتشكيل كل نص عربية عبر
/// `TextDirection.rtl`. كل تسمية تأتي مسبقة التعريب من `ShiftLabels`.
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../../../core/widgets/amount_text.dart';
import '../core/print_fonts.dart';
import '../core/print_palette.dart';
import '../print_docs.dart';
import '../shift_print_doc.dart';

/// يحوّل [ShiftPrintDoc] إلى `pw.Document` جاهز للمعاينة/الطباعة/
/// المشاركة (استدعِ `PrintFonts.load()` أولاً — يحدث داخل [build]).
class ShiftReportPdfBuilder {
  const ShiftReportPdfBuilder();

  /// الفرق زيادة (موجب) — أخضر `FinColors.positive` الفاتح للورق.
  static const pw.PdfColor _surplus = pw.PdfColor.fromInt(0xFF0E7A4E);

  /// الفرق عجز (سالب) — أحمر `FinColors.negative` الفاتح للورق.
  static const pw.PdfColor _deficit = pw.PdfColor.fromInt(0xFFB3261E);

  /// البناء الكامل — A4 عمودي؛ تقرير الوردية صفحة واحدة دائماً
  /// (بنود المعادلة محدودة عددياً).
  Future<pw.Document> build(ShiftPrintDoc doc) async {
    await PrintFonts.load();
    final pdf = pw.Document(
      title: '${doc.labels.title} - ${doc.boxName}',
      author: doc.header.name,
      creator: kPrintAppCredit,
      // Almarai في كل مكان — حتى النص الضمني لا يسقط إلى خط غير
      // يونيكودي.
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
        header: (context) => _brandBand(doc),
        footer: (context) => _footerLine(doc),
        build: (context) => [
          pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
          _titleRow(doc),
          pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
          _metaGrid(doc),
          pw.SizedBox(height: 6 * pw.PdfPageFormat.mm),
          _equationBlock(doc),
          pw.SizedBox(height: 5 * pw.PdfPageFormat.mm),
          _totalsCard(doc),
          pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
          _settlementCard(doc),
          if ((doc.notes ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
            _notesLine(doc),
          ],
        ],
      ),
    );
    return pdf;
  }

  // -------------------------------------------------------------------
  // الكتل
  // -------------------------------------------------------------------

  /// شريط الهوية العميق — مطابق لقالب كشف الحساب.
  pw.Widget _brandBand(ShiftPrintDoc doc) {
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
              _monogram(doc.header.name),
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
                      color: const pw.PdfColor.fromInt(0xFFBEE5D8),
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

  /// صف العنوان: «تقرير الوردية» يميناً + رقاقة الصندوق يساراً.
  pw.Widget _titleRow(ShiftPrintDoc doc) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: PrintPalette.brand,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                doc.boxName,
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

  /// شبكة البيانات: الصندوق والمستخدم يميناً، الفتح والإقفال يساراً.
  pw.Widget _metaGrid(ShiftPrintDoc doc) {
    final labels = doc.labels;
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
              children: [
                _kvLine(labels.opened, doc.openedAtLabel),
                _kvLine(labels.closed, doc.closedAtLabel),
              ],
            ),
          ),
          pw.SizedBox(width: 8 * pw.PdfPageFormat.mm),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _kvLine(labels.box, doc.boxName),
                _kvLine(labels.user, doc.userName ?? '—'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// جدول المعادلة الشاملة + حاشية الشيكات المؤجلة.
  pw.Widget _equationBlock(ShiftPrintDoc doc) {
    final labels = doc.labels;
    final headers = <String>[
      labels.valueCol,
      labels.directionCol,
      labels.itemCol,
    ];
    final data = <List<String>>[
      for (final line in doc.lines)
        [line.valueLabel, line.directionLabel, line.itemLabel],
    ];
    final table = pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PrintPalette.rule, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: PrintPalette.tableHead),
      headerStyle: PrintText.head(color: PrintPalette.brandDeep, size: 9.5),
      headerAlignments: _columnAlignments(),
      cellAlignments: _columnAlignments(),
      cellStyle: PrintText.body(size: 9.5),
      oddRowDecoration: const pw.BoxDecoration(color: PrintPalette.zebra),
      headerDirection: pw.TextDirection.rtl,
      tableDirection: pw.TextDirection.rtl,
      cellPadding: const pw.EdgeInsets.all(4.5),
      headerPadding: const pw.EdgeInsets.symmetric(
        horizontal: 4.5,
        vertical: 4,
      ),
      columnWidths: const {
        0: pw.FractionColumnWidth(1.1), // القيمة — رقمي
        1: pw.FractionColumnWidth(1.0), // الاتجاه
        2: pw.FractionColumnWidth(2.9), // البند — نص عربي
      },
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        table,
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2.5),
          child: pw.Text(
            '${doc.labels.chequesNote} · '
            '${doc.currencyCode.isEmpty ? '' : doc.currencyCode}',
            style: PrintText.body(color: PrintPalette.inkSoft, size: 7.5),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      ],
    );
  }

  /// بطاقة الإجماليات: الرصيد الافتتاحي + إجمالي الوارد + إجمالي الصادر.
  pw.Widget _totalsCard(ShiftPrintDoc doc) {
    final labels = doc.labels;
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PrintPalette.rule, width: 0.7),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _kvLine(labels.openingCount, _fmtMoney(doc, doc.openingCount)),
          _kvLine(labels.totalIn, _fmtMoney(doc, doc.totalIn)),
          _kvLine(labels.totalOut, _fmtMoney(doc, doc.totalOut)),
        ],
      ),
    );
  }

  /// بطاقة الحسم البارزة: المتوقع / العدّ الفعلي / **الفرق ملوّناً**
  /// (أخضر زيادة، أحمر عجز، حبر محايد عند التطابق).
  pw.Widget _settlementCard(ShiftPrintDoc doc) {
    final labels = doc.labels;
    final diff = doc.difference;
    final diffColor = diff > 0.005
        ? _surplus
        : diff < -0.005
        ? _deficit
        : PrintPalette.brandDeep;
    final diffWord = diff > 0.005
        ? labels.surplus
        : diff < -0.005
        ? labels.deficit
        : labels.matched;
    final rows = <(String, String, pw.PdfColor, double)>[
      (
        labels.expected,
        _fmtMoney(doc, doc.expected),
        PrintPalette.brandDeep,
        11,
      ),
      (labels.counted, _fmtMoney(doc, doc.counted), PrintPalette.brandDeep, 11),
      (labels.difference, '${_fmtMoney(doc, diff)} · $diffWord', diffColor, 13),
    ];
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PrintPalette.rule, width: 0.7),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          for (final (label, value, color, size) in rows)
            if (label == labels.difference)
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 4),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                color: PrintPalette.tableHead,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      value,
                      style: PrintText.head(color: color, size: size),
                    ),
                    pw.Text(
                      label,
                      style: PrintText.head(
                        color: PrintPalette.brandDeep,
                        size: 11,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ],
                ),
              )
            else
              _kvLine(label, value, size: 10.5),
        ],
      ),
    );
  }

  /// سطر ملاحظات الإقفال.
  pw.Widget _notesLine(ShiftPrintDoc doc) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PrintPalette.rule, width: 0.7),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        '${doc.labels.notesRow}: ${doc.notes}',
        style: PrintText.body(color: PrintPalette.ink, size: 9.5),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  /// التذييل: شكر + نص المنشأة يميناً، ونسب التطبيق يساراً.
  pw.Widget _footerLine(ShiftPrintDoc doc) {
    final companyFooter = (doc.header.footerText ?? '').trim();
    final thanks = doc.labels.footerThanks;
    final right = companyFooter.isEmpty ? thanks : '$thanks · $companyFooter';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(color: PrintPalette.rule, thickness: 0.6),
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

  // -------------------------------------------------------------------
  // مساعدات
  // -------------------------------------------------------------------

  Map<int, pw.AlignmentGeometry> _columnAlignments() => {
    0: pw.Alignment.centerLeft, // القيمة — رقمي
    1: pw.Alignment.center, // الاتجاه
    2: pw.Alignment.centerRight, // البند — نص RTL
  };

  /// سطر «تسمية يميناً : قيمة يساراً» — النمط العربي الأساسي.
  pw.Widget _kvLine(String label, String value, {double size = 9.5}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                value,
                style: PrintText.body(
                  color: PrintPalette.brandDeep,
                  size: size,
                ),
              ),
            ),
          ),
          pw.Text(
            label,
            style: PrintText.body(color: PrintPalette.inkSoft, size: size),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  String _fmtMoney(ShiftPrintDoc doc, double value) =>
      AmountText.format(value, doc.decimals);

  String _monogram(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'ف' : trimmed.substring(0, 1);
  }
}
