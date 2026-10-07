/// قالب PDF لفاتورة البيع / عرض السعر — A4 مفصّل (الشريحة 7، FR-10-01/05).
///
/// النموذج **مفصول كلياً عن نماذج النطاق**: المتصل (الشاشة) يحوّل بياناته
/// إلى [InvoicePdfData] ويملأ كل التسميات جاهزةً مترجمةً من l10n — هذا
/// الملف لا يقرأ الترجمة إطلاقاً فيبقى قابلاً للاختبار والاستخدام من أي
/// متصل لاحق (مرتجعات/مشتريات…).
///
/// اتجاه المستند RTL بالكامل:
/// - `MultiPage(textDirection: rtl)` يورّث الاتجاه لكل السياق.
/// - الابن الأول في `pw.Row` يظهر يميناً (محرك pdf يحترم Directionality
///   في Flex/Wrap).
/// - **الجدول لا يقلب أعمدته المحرك** (`Table` يرسم الأبناء من اليسار
///   دائماً) — لذلك تُسلَّم الأعمدة معكوسةً: الإجمالي أقصى اليسار و«#»
///   أقصى اليمين، مع `tableDirection: rtl` لتشكيل النص العربي داخل الخلايا.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'fin_pdf_fonts.dart';

/// سطر بند واحد في جدول الأصناف.
class InvoicePdfLine {
  const InvoicePdfLine({
    required this.desc,
    required this.qty,
    required this.unitPrice,
    required this.discountAmount,
    required this.lineTotal,
  });

  /// وصف السطر (اسم الصنف لحظة البيع).
  final String desc;

  /// الكمية.
  final double qty;

  /// سعر الوحدة بعملة المستند.
  final double unitPrice;

  /// الخصم الفعلي للسطر.
  final double discountAmount;

  /// صافي السطر.
  final double lineTotal;
}

/// حزمة بيانات مستند A4 (فاتورة/عرض) — التسميات كلها مُسبقة الترجمة.
class InvoicePdfData {
  const InvoicePdfData({
    required this.docTitle,
    required this.docNo,
    required this.issuedAt,
    this.validUntil,
    this.customerName,
    this.customerPhone,
    required this.currencyCode,
    required this.exchangeRate,
    required this.rateIsFallback,
    this.payStatusLabel,
    required this.lines,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    required this.paidAmount,
    required this.dueAmount,
    this.notesPrinted,
    required this.companyName,
    this.companyPhone,
    this.companyAddress,
    required this.footerNote,
    required this.customerLabel,
    required this.walkInCustomer,
    required this.exchangeRateLabel,
    required this.fallbackRateLabel,
    required this.subtotalLabel,
    required this.discountLabel,
    required this.totalLabel,
    required this.paidLabel,
    required this.dueLabel,
    required this.validUntilLabel,
    required this.printedNotesLabel,
    required this.colItem,
    required this.colQty,
    required this.colPrice,
    required this.colDiscount,
    required this.colTotal,
    required this.colNum,
  });

  /// عنوان المستند (فاتورة بيع / عرض سعر).
  final String docTitle;

  /// الرقم المرقّم `INV-YYYY-NNNNN` / `QTE-YYYY-NNNNN`.
  final String docNo;

  /// لحظة الإصدار.
  final DateTime issuedAt;

  /// تاريخ الصلاحية (عروض الأسعار — FR-02-11).
  final DateTime? validUntil;

  final String? customerName;
  final String? customerPhone;

  /// رمز عملة المستند (يُطبع بجوار المبالغ).
  final String currencyCode;

  /// Snapshot سعر الصرف (1 للعملة الأساسية).
  final double exchangeRate;

  /// هل السعر احتياطي؟ (شارة FR-02-20).
  final bool rateIsFallback;

  /// وصف حالة الدفع مترجماً (نقدي/آجل/مختلط) — null للعرض.
  final String? payStatusLabel;

  /// البنود.
  final List<InvoicePdfLine> lines;

  final double subtotal;
  final double discountAmount;
  final double total;
  final double paidAmount;
  final double dueAmount;

  /// ملاحظة خارجية تُطبع (FR-02-16).
  final String? notesPrinted;

  final String companyName;
  final String? companyPhone;
  final String? companyAddress;

  /// نص التذييل.
  final String footerNote;

  // ── التسميات المُسبقة الترجمة (يملؤها المتصل من l10n) ──
  final String customerLabel;
  final String walkInCustomer;
  final String exchangeRateLabel;
  final String fallbackRateLabel;
  final String subtotalLabel;
  final String discountLabel;
  final String totalLabel;
  final String paidLabel;
  final String dueLabel;
  final String validUntilLabel;
  final String printedNotesLabel;
  final String colItem;
  final String colQty;
  final String colPrice;
  final String colDiscount;
  final String colTotal;
  final String colNum;
}

/// اللون المؤسسي (0xFF00695C) وألوان المستند المشتقة.
const PdfColor _teal = PdfColor.fromInt(0xFF00695C);
const PdfColor _tealLight = PdfColor.fromInt(0xFFE0F2F1);
const PdfColor _ink = PdfColor.fromInt(0xFF1F2937);
const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
const PdfColor _red = PdfColor.fromInt(0xFFB3261E);
const PdfColor _zebra = PdfColor.fromInt(0xFFF3F4F6);

/// يبني مستند A4 (فاتورة/عرض) ويعيد بايتات PDF.
Future<Uint8List> buildInvoicePdf(InvoicePdfData data) async {
  final fonts = await FinPdfFonts.load();
  final doc = pw.Document(title: data.docNo);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      textDirection: pw.TextDirection.rtl,
      theme: fonts.theme(),
      footer: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Center(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 14),
            child: pw.Text(
              data.footerNote,
              style: const pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
          ),
        ),
      ),
      build: (context) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _headerBand(fonts, data),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.9, color: _teal, height: 10),
              _customerBlock(data),
              pw.SizedBox(height: 14),
              _itemsTable(context, fonts, data),
              pw.SizedBox(height: 16),
              _totalsRow(fonts, data),
              if ((data.notesPrinted ?? '').isNotEmpty) ...[
                pw.SizedBox(height: 16),
                _notesBox(data),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

/// شريط الترويسة: المنشأة يميناً، بيانات المستند يساراً.
pw.Widget _headerBand(FinPdfFonts fonts, InvoicePdfData data) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // الابن الأول في صف RTL = الجهة اليمنى: المنشأة.
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            data.companyName,
            style: pw.TextStyle(
              font: fonts.extraBold,
              fontSize: 20,
              color: _teal,
            ),
          ),
          if ((data.companyPhone ?? '').isNotEmpty)
            pw.Text(
              data.companyPhone!,
              style: const pw.TextStyle(fontSize: 9, color: _grey),
            ),
          if ((data.companyAddress ?? '').isNotEmpty)
            pw.Text(
              data.companyAddress!,
              style: const pw.TextStyle(fontSize: 9, color: _grey),
            ),
        ],
      ),
      pw.SizedBox(width: 18),
      // الابن الثاني = الجهة اليسرى: المستند.
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              data.docTitle,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              data.docNo,
              textDirection: pw.TextDirection.ltr,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _teal,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              pdfDateTime(data.issuedAt),
              textDirection: pw.TextDirection.ltr,
              style: const pw.TextStyle(fontSize: 9, color: _grey),
            ),
            if (data.validUntil != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                '${data.validUntilLabel}: ${pdfDate(data.validUntil!)}',
                style: const pw.TextStyle(fontSize: 9, color: _grey),
              ),
            ],
            if (data.payStatusLabel != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                data.payStatusLabel!,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

/// سطر العميل (+ الهاتف) وسطر سعر الصرف عند اختلافه عن 1.
pw.Widget _customerBlock(InvoicePdfData data) {
  final fallbackSuffix = data.rateIsFallback
      ? '  ·  ${data.fallbackRateLabel}'
      : '';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        children: [
          pw.Text(
            '${data.customerLabel}: ',
            style: const pw.TextStyle(fontSize: 10, color: _grey),
          ),
          pw.Text(
            data.customerName ?? data.walkInCustomer,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          if ((data.customerPhone ?? '').isNotEmpty) ...[
            pw.SizedBox(width: 10),
            pw.Text(
              data.customerPhone!,
              textDirection: pw.TextDirection.ltr,
              style: const pw.TextStyle(fontSize: 10, color: _grey),
            ),
          ],
        ],
      ),
      if (data.exchangeRate != 1) ...[
        pw.SizedBox(height: 3),
        pw.Text(
          '${data.exchangeRateLabel}: ${pdfRate(data.exchangeRate)}'
          '$fallbackSuffix',
          style: pw.TextStyle(
            fontSize: 9,
            color: data.rateIsFallback ? _red : _grey,
          ),
        ),
      ],
    ],
  );
}

/// جدول البنود — الأعمدة معكوسة لأن `Table` يرسم من اليسار دائماً.
pw.Widget _itemsTable(
  pw.Context context,
  FinPdfFonts fonts,
  InvoicePdfData data,
) {
  final rows = <List<dynamic>>[
    // الترويسة: الإجمالي | الخصم | السعر | الكمية | الصنف | #
    <dynamic>[
      data.colTotal,
      data.colDiscount,
      data.colPrice,
      data.colQty,
      data.colItem,
      data.colNum,
    ],
    for (var i = 0; i < data.lines.length; i++)
      <dynamic>[
        pdfMoney(data.lines[i].lineTotal),
        data.lines[i].discountAmount > 0
            ? pdfMoney(data.lines[i].discountAmount)
            : '—',
        pdfMoney(data.lines[i].unitPrice),
        pdfQty(data.lines[i].qty),
        data.lines[i].desc,
        i + 1,
      ],
  ];

  return pw.TableHelper.fromTextArray(
    context: context,
    headers: rows.first,
    data: rows.skip(1).toList(),
    border: pw.TableBorder.all(color: _tealLight, width: 0.7),
    headerDecoration: const pw.BoxDecoration(color: _teal),
    headerStyle: pw.TextStyle(
      color: PdfColors.white,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    ),
    headerDirection: pw.TextDirection.rtl,
    tableDirection: pw.TextDirection.rtl,
    cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
    cellPadding: const pw.EdgeInsets.all(5),
    headerPadding: const pw.EdgeInsets.all(5),
    rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
    oddRowDecoration: const pw.BoxDecoration(color: _zebra),
    cellAlignments: {
      0: pw.Alignment.centerRight,
      1: pw.Alignment.centerRight,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.center,
      4: pw.Alignment.centerRight,
      5: pw.Alignment.center,
    },
    columnWidths: const {
      0: pw.FixedColumnWidth(64),
      1: pw.FixedColumnWidth(56),
      2: pw.FixedColumnWidth(62),
      3: pw.FixedColumnWidth(38),
      4: pw.FlexColumnWidth(),
      5: pw.FixedColumnWidth(24),
    },
  );
}

/// صف الإجماليات + رمز QR إلى جانبها.
pw.Widget _totalsRow(FinPdfFonts fonts, InvoicePdfData data) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // الابن الأول = يمين: عمود الإجماليات.
      pw.Expanded(child: _totalsColumn(data)),
      pw.SizedBox(width: 16),
      // الابن الثاني = يسار: رمز QR بعلامة المستند.
      _qrBox(data),
    ],
  );
}

pw.Widget _totalsColumn(InvoicePdfData data) {
  final money = '${pdfMoney(data.total)} ${data.currencyCode}';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _totalLine(
        data.subtotalLabel,
        '${pdfMoney(data.subtotal)} ${data.currencyCode}',
        _ink,
      ),
      if (data.discountAmount > 0)
        _totalLine(
          data.discountLabel,
          '− ${pdfMoney(data.discountAmount)} ${data.currencyCode}',
          _red,
        ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Divider(thickness: 0.7, color: _tealLight, height: 6),
      ),
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              data.totalLabel,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _teal,
              ),
            ),
          ),
          pw.Text(
            money,
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _teal,
            ),
          ),
        ],
      ),
      if (data.paidAmount > 0)
        _totalLine(
          data.paidLabel,
          '${pdfMoney(data.paidAmount)} ${data.currencyCode}',
          _ink,
        ),
      if (data.dueAmount > 0)
        _totalLine(
          data.dueLabel,
          '${pdfMoney(data.dueAmount)} ${data.currencyCode}',
          _red,
        ),
    ],
  );
}

pw.Widget _totalLine(String label, String value, PdfColor color) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: _grey),
          ),
        ),
        pw.Text(
          value,
          textDirection: pw.TextDirection.ltr,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// رمز QR بعلامة المستند: `FINACC|رقم|الإجمالي|تاريخ ISO` (~60×60 بإطار).
pw.Widget _qrBox(InvoicePdfData data) {
  final qrData =
      'FINACC|${data.docNo}|${data.total.toStringAsFixed(2)}'
      '|${data.issuedAt.toIso8601String()}';
  return pw.Container(
    width: 66,
    height: 66,
    padding: const pw.EdgeInsets.all(3),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: _grey, width: 0.6),
    ),
    child: pw.BarcodeWidget(
      barcode: pw.Barcode.qrCode(),
      data: qrData,
      width: 60,
      height: 60,
      drawText: false,
    ),
  );
}

/// صندوق الملاحظات المطبوعة بإطار.
pw.Widget _notesBox(InvoicePdfData data) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: _tealLight, width: 1),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          data.printedNotesLabel,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _teal,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          data.notesPrinted!,
          style: const pw.TextStyle(fontSize: 9.5, color: _ink),
        ),
      ],
    ),
  );
}
