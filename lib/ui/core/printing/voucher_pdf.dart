/// قالب PDF للسند المرقّم (قبض RVT / صرف PMT — FR-04-10) — الشريحة 7.
///
/// سند A6 عرضي بثلاث مناطق: شريط علوي بلون الهوية يحمل العنوان والرقم،
/// متن يبرز المبلغ (خط ثقيل جداً 22pt) مع الطرف/الصندوق/التاريخ/الفئة
/// والبيان، ثم سطرا توقيع (المستلم وأمين الصندوق) وتذييل صغير.
///
/// نفس مبدأ الفاتورة: [VoucherPdfData] مفصول عن نماذج النطاق وكل
/// التسميات مُسبقة الترجمة من المتصل.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'fin_pdf_fonts.dart';

/// حزمة بيانات سند القبض/الصرف — التسميات مُسبقة الترجمة.
class VoucherPdfData {
  const VoucherPdfData({
    required this.isReceipt,
    required this.voucherNo,
    required this.txDate,
    this.partyName,
    required this.partyLabel,
    required this.amount,
    required this.currencyCode,
    required this.boxName,
    required this.boxLabel,
    this.description,
    this.categoryName,
    required this.companyName,
    required this.titleReceipt,
    required this.titlePayment,
    required this.amountLabel,
    required this.dateLabel,
    required this.signatureReceiver,
    required this.signatureCashier,
    required this.footerNote,
  });

  /// true = سند قبض (RVT من عميل)؛ false = سند صرف (PMT لمورد).
  final bool isReceipt;

  /// الرقم الكامل `RVT-YYYY-NNNNN` / `PMT-YYYY-NNNNN`.
  final String voucherNo;

  /// تاريخ الحركة.
  final DateTime txDate;

  /// اسم الطرف (عميل/مورد) — null للسند بلا طرف.
  final String? partyName;

  /// تسمية الطرف (العميل/المورد) مترجمة.
  final String partyLabel;

  /// المبلغ بعملة السند.
  final double amount;

  /// رمز عملة السند.
  final String currencyCode;

  /// اسم الصندوق.
  final String boxName;

  /// تسمية الصندوق مترجمة.
  final String boxLabel;

  /// البيان (ملاحظات السند) — اختياري.
  final String? description;

  /// الفئة (للمصاريف) — اختياري.
  final String? categoryName;

  /// اسم المنشأة (التذييل الصغير).
  final String companyName;

  // ── التسميات المُسبقة الترجمة ──
  final String titleReceipt;
  final String titlePayment;
  final String amountLabel;
  final String dateLabel;
  final String signatureReceiver;
  final String signatureCashier;
  final String footerNote;
}

const PdfColor _teal = PdfColor.fromInt(0xFF00695C);
const PdfColor _red = PdfColor.fromInt(0xFFB3261E);
const PdfColor _ink = PdfColor.fromInt(0xFF1F2937);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);

/// يبني سند A6 عرضي ويعيد بايتات PDF.
Future<Uint8List> buildVoucherPdf(VoucherPdfData data) async {
  final fonts = await FinPdfFonts.load();
  final accent = data.isReceipt ? _teal : _red;
  final title = data.isReceipt ? data.titleReceipt : data.titlePayment;

  final doc = pw.Document(title: data.voucherNo);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a6.landscape,
      margin: const pw.EdgeInsets.all(20),
      textDirection: pw.TextDirection.rtl,
      theme: fonts.theme(),
      build: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _titleBand(data, title),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: _body(fonts, data, accent),
              ),
            ),
            _signatureRow(data),
            pw.SizedBox(height: 8),
            _footer(data),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}

/// الشريط العلوي: العنوان يميناً والرقم المرقّم يساراً على أرضية الهوية.
pw.Widget _titleBand(VoucherPdfData data, String title) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: const pw.BoxDecoration(color: _teal),
    child: pw.Row(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
        pw.Spacer(),
        pw.Text(
          data.voucherNo,
          textDirection: pw.TextDirection.ltr,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ],
    ),
  );
}

/// المتن: المبلغ البطل ثم صفوف الطرف/الصندوق/التاريخ/الفئة/البيان.
pw.Widget _body(FinPdfFonts fonts, VoucherPdfData data, PdfColor accent) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Center(
        child: pw.Text(
          '${pdfMoney(data.amount)} ${data.currencyCode}',
          textDirection: pw.TextDirection.ltr,
          style: pw.TextStyle(
            font: fonts.extraBold,
            fontSize: 22,
            color: accent,
          ),
        ),
      ),
      pw.Center(
        child: pw.Text(
          data.amountLabel,
          style: const pw.TextStyle(fontSize: 9, color: _grey),
        ),
      ),
      pw.SizedBox(height: 12),
      if ((data.partyName ?? '').isNotEmpty)
        _infoRow(data.partyLabel, data.partyName!, _ink),
      _infoRow(data.boxLabel, data.boxName, _ink),
      _infoRow(data.dateLabel, pdfDate(data.txDate), _ink),
      if ((data.categoryName ?? '').isNotEmpty)
        _infoRow(data.categoryName!, data.description ?? '', _grey)
      else if ((data.description ?? '').isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text(
          data.description!,
          style: const pw.TextStyle(fontSize: 9.5, color: _grey),
        ),
      ],
    ],
  );
}

pw.Widget _infoRow(String label, String value, PdfColor color) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      children: [
        pw.Text(
          '$label: ',
          style: const pw.TextStyle(fontSize: 10, color: _grey),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// سطرا التوقيع أسفل المتن.
pw.Widget _signatureRow(VoucherPdfData data) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6),
    child: pw.Row(
      children: [
        pw.Expanded(child: _signatureLine(data.signatureReceiver)),
        pw.SizedBox(width: 28),
        pw.Expanded(child: _signatureLine(data.signatureCashier)),
      ],
    ),
  );
}

pw.Widget _signatureLine(String label) {
  return pw.Column(
    children: [
      pw.SizedBox(height: 16),
      pw.Container(
        height: 0.8,
        decoration: const pw.BoxDecoration(color: _grey),
      ),
      pw.SizedBox(height: 3),
      pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: _grey)),
    ],
  );
}

/// التذييل الصغير: اسم المنشأة + نص التذييل.
pw.Widget _footer(VoucherPdfData data) {
  return pw.Center(
    child: pw.Text(
      '${data.companyName}  ·  ${data.footerNote}',
      style: const pw.TextStyle(fontSize: 8, color: _grey),
    ),
  );
}
