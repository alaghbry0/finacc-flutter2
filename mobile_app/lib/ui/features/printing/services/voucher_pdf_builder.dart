/// بنّاء PDF السند المرقَّم (الشريحة 7 — FR-04-10 + FR-10-05): قالب A5
/// عمودي RTL لسند القبض/الصرف المطبوع من حركة نقدية.
///
/// كتلة المبلغ هي بطل السند (كبيرة عريضة بعملتها)، وشريط ذهبي يحمل
/// رقم السند — هوية القصاصة. كل تسمية تأتي مسبقة التعريب من
/// `VoucherLabels` — لا نص حرفي هنا غير اسم المنتج الثابت في التذييل.
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../core/print_fonts.dart';
import '../core/print_palette.dart';
import '../print_docs.dart';

/// يحوّل [VoucherPrintDoc] إلى `pw.Document` جاهز للمعاينة/الطباعة/
/// المشاركة (استدعِ `PrintFonts.load()` أولاً — يحدث داخل [build]).
class VoucherPdfBuilder {
  const VoucherPdfBuilder();

  /// البناء الكامل — A5 عمودي، صفحة واحدة (المعطيات محدودة أصلاً).
  Future<pw.Document> build(VoucherPrintDoc doc) async {
    await PrintFonts.load();
    final pdf = pw.Document(
      title: doc.voucherNo,
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

  pw.MultiPage _sheetPage(VoucherPrintDoc doc) {
    return pw.MultiPage(
      pageFormat: pw.PdfPageFormat(
        pw.PdfPageFormat.a5.width,
        pw.PdfPageFormat.a5.height,
        marginTop: 10 * pw.PdfPageFormat.mm,
        marginBottom: 12 * pw.PdfPageFormat.mm,
        marginLeft: 12 * pw.PdfPageFormat.mm,
        marginRight: 12 * pw.PdfPageFormat.mm,
      ),
      build: (context) => [
        _brandBand(doc),
        pw.SizedBox(height: 5 * pw.PdfPageFormat.mm),
        _titleText(doc),
        pw.SizedBox(height: 3 * pw.PdfPageFormat.mm),
        _numberDateRow(doc),
        pw.SizedBox(height: 5 * pw.PdfPageFormat.mm),
        _amountHero(doc),
        pw.SizedBox(height: 5 * pw.PdfPageFormat.mm),
        ..._fieldRows(doc),
        if ((doc.description ?? '').trim().isNotEmpty) ...[
          pw.SizedBox(height: 2 * pw.PdfPageFormat.mm),
          _descriptionBlock(doc),
        ],
        pw.SizedBox(height: 9 * pw.PdfPageFormat.mm),
        _signatureLine(doc),
        pw.SizedBox(height: 6 * pw.PdfPageFormat.mm),
        _footerLine(doc),
      ],
    );
  }

  // -------------------------------------------------------------------
  // الكتل
  // -------------------------------------------------------------------

  /// شريط الهوية: اسم المنشأة + هاتف/عنوان يميناً، والحرف الأول يساراً.
  pw.Widget _brandBand(VoucherPrintDoc doc) {
    final phone = (doc.header.phone ?? '').trim();
    final address = (doc.header.address ?? '').trim();
    final contact = address.isEmpty
        ? phone
        : phone.isEmpty
        ? address
        : '$phone · $address';
    return pw.Container(
      color: PrintPalette.brandDeep,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Container(
            width: 28,
            height: 28,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(color: PrintPalette.brand),
            child: pw.Text(
              _monogram(doc.header.name),
              style: PrintText.head(color: pw.PdfColors.white, size: 14),
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                doc.header.name,
                style: PrintText.head(color: pw.PdfColors.white, size: 13),
                textDirection: pw.TextDirection.rtl,
              ),
              if (contact.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1.5),
                  child: pw.Text(
                    contact,
                    style: PrintText.body(
                      color: const pw.PdfColor.fromInt(0xFFBEE5D8),
                      size: 8,
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

  /// عنوان السند الكبير: سند قبض / سند صرف (حسب [VoucherPrintDoc.isReceipt])
  /// — ExtraBold (إصلاح UX-audit ExtraBold).
  pw.Widget _titleText(VoucherPrintDoc doc) {
    return pw.Center(
      child: pw.Text(
        doc.isReceipt ? doc.labels.titleReceipt : doc.labels.titlePayment,
        style: PrintText.extraHead(color: PrintPalette.brandDeep, size: 20),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  /// صف الرقم والتاريخ: رقم السند (هوية القصاصة) يساراً داخل شريط ذهبي،
  /// والتاريخ يميناً.
  pw.Widget _numberDateRow(VoucherPrintDoc doc) {
    return pw.Container(
      color: PrintPalette.gold,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            doc.voucherNo,
            style: PrintText.head(
              color: const pw.PdfColor.fromInt(0xFF332405),
              size: 11,
            ),
          ),
          _pair(doc.labels.date, doc.dateLabel),
        ],
      ),
    );
  }

  /// بطل السند: المبلغ الكبير العريض بعملته يساراً، والتسمية يميناً.
  pw.Widget _amountHero(VoucherPrintDoc doc) {
    final amount = doc.currencyCode.isEmpty
        ? doc.amountLabel
        : '${doc.amountLabel} ${doc.currencyCode}';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PrintPalette.brand, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
        color: PrintPalette.zebra,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            amount,
            style: PrintText.head(color: PrintPalette.brandDeep, size: 17),
          ),
          pw.Text(
            doc.labels.amount,
            style: PrintText.head(color: PrintPalette.inkSoft, size: 14),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  /// صفوف البيانات: الطرف (إن وُجد) ثم الصندوق.
  List<pw.Widget> _fieldRows(VoucherPrintDoc doc) {
    final party = (doc.partyName ?? '').trim();
    return [
      if (party.isNotEmpty) _kvLine(doc.labels.party, party, size: 10),
      _kvLine(doc.labels.box, doc.boxName, size: 10),
    ];
  }

  /// كتلة البيان — إطار خفيف بتسمية أعلى النص.
  pw.Widget _descriptionBlock(VoucherPrintDoc doc) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PrintPalette.rule, width: 0.6),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            doc.labels.description,
            style: PrintText.head(color: PrintPalette.inkSoft, size: 8.5),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.Text(
            doc.description!.trim(),
            style: PrintText.body(size: 10),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  /// سطر التوقيع: فاصل أفقي + التسمية في المنتصف.
  pw.Widget _signatureLine(VoucherPrintDoc doc) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(color: PrintPalette.inkSoft, thickness: 0.5),
        pw.SizedBox(height: 2),
        pw.Text(
          doc.labels.signature,
          style: PrintText.body(color: PrintPalette.inkSoft, size: 8.5),
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  /// التذييل: شكر + نص المنشأة يميناً، ونسب التطبيق يساراً.
  pw.Widget _footerLine(VoucherPrintDoc doc) {
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
  ///
  /// القيمة تُرسم RTL **دائماً** (إصلاح UX-audit A3): بلا `textDirection`
  /// ترسم حزمة pdf العربيةَ (الطرف/الصندوق) بلا تشكيل معكوسةً مفككةً،
  /// وقد ينهار subsetter الخط حين يجتمع عربي غير مشكل بعربي مشكل.
  pw.Widget _kvLine(String label, String value, {double size = 9.5}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
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
                textDirection: pw.TextDirection.rtl,
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

  /// زوج «قيمة يساراً · تسمية يميناً» مضغوط (صف الرقم والتاريخ).
  pw.Widget _pair(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          value,
          style: PrintText.body(
            color: const pw.PdfColor.fromInt(0xFF332405),
            size: 10,
          ),
        ),
        pw.SizedBox(width: 5),
        pw.Text(
          label,
          style: PrintText.body(
            color: const pw.PdfColor.fromInt(0xFF332405),
            size: 10,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
      ],
    );
  }

  String _monogram(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'ف' : trimmed.substring(0, 1);
  }
}
