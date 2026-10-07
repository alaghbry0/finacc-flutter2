/// بنّاء PDF كشف حساب الطرف (الشريحة 7 — مستند #3): قالب A4 عمودي RTL.
///
/// بنية المستند: شريط هوية المنشأة ← صف العنوان (العنوان يميناً واسم
/// الطرف في رقاقة يساراً) ← شبكة البيانات (الطرف/الإصدار/الفترة/العملة)
/// ← جدول الحركات بأعمدة [الرصيد، دائن، مدين، البيان، التاريخ] فيزيائياً
/// يسار→يمين فيقع التاريخ أقصى اليمين (ترتيب القراءة العربية) ← بطاقة
/// الإجماليات (إجمالي المدين/الدائن + **الرصيد الختامي** البارز) ← تذييل.
/// استراتيجية RTL مطابقة لقالب الفاتورة: ترتيب الأعمدة فيزيائي وتشكيل
/// نص كل خلية عربية عبر `TextDirection.rtl`. كل تسمية تأتي مسبقة التعريب
/// من `StatementLabels` — لا نص حرفي هنا غير اسم المنتج الثابت في التذييل.
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../../../core/widgets/amount_text.dart';
import '../core/print_fonts.dart';
import '../core/print_palette.dart';
import '../print_docs.dart';
import '../statement_print_doc.dart';

/// يحوّل [StatementPrintDoc] إلى `pw.Document` جاهز للمعاينة/الطباعة/
/// المشاركة (استدعِ `PrintFonts.load()` أولاً — يحدث داخل [build]).
class StatementPdfBuilder {
  const StatementPdfBuilder();

  /// البناء الكامل — A4 عمودي، MultiPage (الكشوف الطويلة تتدفق لصفحات
  /// إضافية بنفس الشريط والتذييل).
  Future<pw.Document> build(StatementPrintDoc doc) async {
    await PrintFonts.load();
    final pdf = pw.Document(
      title: '${doc.labels.title} - ${doc.partyName}',
      author: doc.header.name,
      creator: kPrintAppCredit,
      // Almarai في كل مكان — حتى النص الضمني لا يسقط أبداً إلى خط
      // Courier غير اليونيكودي.
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

  pw.MultiPage _sheetPage(StatementPrintDoc doc) {
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
      footer: (context) => _footerLine(doc),
      build: (context) => [
        pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
        _titleRow(doc),
        pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
        _metaGrid(doc),
        pw.SizedBox(height: 6 * pw.PdfPageFormat.mm),
        _movementsBlock(doc),
        pw.SizedBox(height: 5 * pw.PdfPageFormat.mm),
        _totalsCard(doc),
      ],
    );
  }

  // -------------------------------------------------------------------
  // الكتل
  // -------------------------------------------------------------------

  /// شريط الهوية العميق: اسم المنشأة + هاتف/عنوان يميناً (جهة القراءة
  /// الأولى)، ومربع الحرف الأول يساراً (شعار مؤقت حتى يُرفع شعار فعلي).
  pw.Widget _brandBand(StatementPrintDoc doc) {
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

  /// صف العنوان: «كشف حساب» يميناً + رقاقة اسم الطرف يساراً (هوية
  /// المستند — الكشف بلا رقم مستند، فالطرف هو هويته).
  pw.Widget _titleRow(StatementPrintDoc doc) {
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
                doc.partyName,
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

  /// شبكة البيانات: الطرف وهاتفه يميناً (أساسية)، والإصدار والفترة
  /// والعملة يساراً — داخل إطار مستدير خفيف.
  pw.Widget _metaGrid(StatementPrintDoc doc) {
    final partyPhone = (doc.partyPhone ?? '').trim();
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
                _kvLine(doc.labels.generatedAt, doc.generatedAtLabel),
                _kvLine(doc.labels.period, doc.periodLabel),
                _kvLine(
                  doc.labels.currency,
                  doc.currencyCode.isEmpty ? '—' : doc.currencyCode,
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 8 * pw.PdfPageFormat.mm),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _kvLine(doc.labels.party, doc.partyName),
                if (partyPhone.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 1.5),
                    child: pw.Text(
                      partyPhone,
                      style: PrintText.body(
                        color: PrintPalette.inkSoft,
                        size: 8.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// جدول الحركات — أو نص «لا قيود» عند كشف فارغ داخل الإطار نفسه.
  pw.Widget _movementsBlock(StatementPrintDoc doc) {
    if (doc.lines.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PrintPalette.rule, width: 0.7),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          doc.labels.emptyBody,
          style: PrintText.body(color: PrintPalette.inkSoft, size: 10),
          textAlign: pw.TextAlign.center,
          textDirection: pw.TextDirection.rtl,
        ),
      );
    }
    return _movementsTable(doc);
  }

  /// جدول الحركات — الأعمدة مُصاغة فيزيائياً يسار→يمين بحيث يكون
  /// «التاريخ» في أقصى اليمين: [الرصيد، دائن، مدين، البيان، التاريخ].
  pw.Widget _movementsTable(StatementPrintDoc doc) {
    final labels = doc.labels;
    final headers = <String>[
      labels.balanceCol,
      labels.creditCol,
      labels.debitCol,
      labels.descCol,
      labels.dateCol,
    ];
    final data = <List<String>>[
      for (final line in doc.lines)
        [
          line.balanceLabel,
          line.creditLabel,
          line.debitLabel,
          line.descLabel,
          line.dateLabel,
        ],
    ];
    return pw.TableHelper.fromTextArray(
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
        0: pw.FractionColumnWidth(1.15), // الرصيد — رقمي
        1: pw.FractionColumnWidth(0.95), // دائن
        2: pw.FractionColumnWidth(0.95), // مدين
        3: pw.FractionColumnWidth(2.7), // البيان — نص عربي
        4: pw.FractionColumnWidth(1.05), // التاريخ
      },
    );
  }

  Map<int, pw.AlignmentGeometry> _columnAlignments() => {
    0: pw.Alignment.centerLeft, // الرصيد — رقمي
    1: pw.Alignment.centerLeft, // دائن — رقمي
    2: pw.Alignment.centerLeft, // مدين — رقمي
    3: pw.Alignment.centerRight, // البيان — نص RTL
    4: pw.Alignment.center, // التاريخ
  };

  /// بطاقة الإجماليات: إجمالي المدين / إجمالي الدائن / **الرصيد الختامي**
  /// (شريط بارز بعملته — مطابق لبطاقة إجماليات الفاتورة).
  pw.Widget _totalsCard(StatementPrintDoc doc) {
    final labels = doc.labels;
    final rows = <(String, String, bool)>[
      (labels.totalDebit, _fmtMoney(doc, doc.totalDebit), false),
      (labels.totalCredit, _fmtMoney(doc, doc.totalCredit), false),
      (labels.closing, _fmtClosing(doc), true),
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
          for (final (label, value, strong) in rows)
            if (strong)
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 3),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                color: PrintPalette.tableHead,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      value,
                      style: PrintText.head(
                        color: PrintPalette.brandDeep,
                        size: 12,
                      ),
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
              _kvLine(label, value, size: 10),
        ],
      ),
    );
  }

  /// التذييل: شكر + نص المنشأة يميناً، ونسب التطبيق يساراً.
  pw.Widget _footerLine(StatementPrintDoc doc) {
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

  /// سطر «تسمية يميناً : قيمة يساراً» — النمط العربي الأساسي للمعلومات.
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

  String _fmtMoney(StatementPrintDoc doc, double value) =>
      AmountText.format(value, doc.decimals);

  /// الرصيد الختامي مع رمز العملة (إن وُجد) — «12,500 YER».
  String _fmtClosing(StatementPrintDoc doc) {
    final value = _fmtMoney(doc, doc.closingBalance);
    return doc.currencyCode.isEmpty ? value : '$value ${doc.currencyCode}';
  }

  String _monogram(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'ف' : trimmed.substring(0, 1);
  }
}
