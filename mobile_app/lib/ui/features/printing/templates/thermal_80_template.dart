/// قالب «حراري 80مم» (موجة UX-3) — إيصال رول للطابعات الحرارية:
/// `PdfPageFormat.roll80` متدفق (ارتفاع الصفحة **يتقلص لحجم المحتوى**
/// عبر آلية Page للارتفاع اللانهائي — صفحة رول واحدة قصيرة)، خطوط
/// 12–14pt، فواصل dashed، إجماليات مكدسة، وباركود Code128 لرقم الفاتورة
/// أسفل الإيصال، بلا توقيعات/ختم (طبيعة الإيصال).
///
/// استراتيجية RTL: سطر «تسمية يميناً : قيمة يساراً» فيزيائياً LTR
/// (القيمة أول أبناء Row) وكل نص عربي `textDirection: rtl` — النمط
/// المُجرَّب. كل تسمية تصل مسبقة التعريب من `InvoicePrintDoc`.
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../../../core/widgets/amount_text.dart';
import '../core/print_palette.dart';
import '../print_docs.dart';
import 'invoice_template_settings.dart';
import 'template_colors.dart';

/// عرض محتوى الإيصال بعد حشو الجانبين (80مم − 8مم = 72مم).
const double _kContentWidth = 72 * pw.PdfPageFormat.mm;

/// صيغة صفحة الرول: 80مم بارتفاع لانهائي وهامش صفري — الحشو الجانبي
/// داخل المحتوى (آلية Page تقصّ الارتفاع على المحتوى نفسه).
final pw.PdfPageFormat _kRollPage = pw.PdfPageFormat(
  80 * pw.PdfPageFormat.mm,
  double.infinity,
);

/// بنّاء قالب الإيصال الحراري.
class Thermal80InvoiceTemplate {
  const Thermal80InvoiceTemplate();

  /// يضيف صفحة الرول الواحدة (تتمدد مع طول البنود) داخل مستند المحرك.
  void addPages(
    pw.Document pdf,
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
  ) {
    pdf.addPage(
      pw.Page(
        pageFormat: _kRollPage,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(
            horizontal: 4 * pw.PdfPageFormat.mm,
            vertical: 5 * pw.PdfPageFormat.mm,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: _blocks(doc, settings),
          ),
        ),
      ),
    );
  }

  List<pw.Widget> _blocks(
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
  ) {
    final red = templatePdfColor(settings.accentRedArgb);
    final blocks = <pw.Widget>[
      // اسم المنشأة + بيانات المتجر.
      pw.Text(
        doc.header.name,
        style: PrintText.head(color: PrintPalette.ink, size: 14),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
      ),
      if ((doc.header.phone ?? '').trim().isNotEmpty ||
          (doc.header.address ?? '').trim().isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            [
              (doc.header.phone ?? '').trim(),
              (doc.header.address ?? '').trim(),
            ].where((s) => s.isNotEmpty).join(' · '),
            style: PrintText.body(color: PrintPalette.inkSoft, size: 12),
            textAlign: pw.TextAlign.center,
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      if (settings.showTax && (doc.taxNumber ?? '').trim().isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            '${doc.templateLabels?.taxNumber ?? ''}: ${doc.taxNumber}',
            style: PrintText.body(color: PrintPalette.inkSoft, size: 12),
            textAlign: pw.TextAlign.center,
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      _gap(3),
      _dash(),
      _gap(3),
      // وضع الدفع (فاتورة مبيعات نقد/آجل) — عنوان الإيصال.
      pw.Text(
        doc.payStatusLabel ?? doc.labels.title,
        style: PrintText.head(color: PrintPalette.brandDeep, size: 14),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
      ),
      _gap(3),
      _dash(),
      _gap(3),
      // بيانات الفاتورة.
      _kvLine(doc.labels.customer, doc.partyName),
      _kvLine(doc.labels.date, doc.dateLabel),
      _kvLine(
        doc.labels.currency,
        doc.currencyCode.isEmpty ? '—' : doc.currencyCode,
      ),
      _gap(2),
      _dash(),
      _gap(2),
    ];

    // البنود — وصف يميناً وصافي يساراً وسطر تفاصيل صغير تحته.
    for (var i = 0; i < doc.items.length; i++) {
      final line = doc.items[i];
      blocks.addAll([
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  line.totalLabel,
                  style: PrintText.tabular(
                    color: PrintPalette.brandDeep,
                    size: 12,
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Text(
                line.desc,
                style: PrintText.body(size: 12),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
          ],
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    _lineDetail(line, doc, settings),
                    style: PrintText.tabular(
                      color: PrintPalette.inkSoft,
                      size: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _gap(2),
        if (i < doc.items.length - 1) ...[_dashThin(), _gap(2)],
      ]);
    }

    // الإجماليات المكدسة.
    blocks.addAll([
      _dash(),
      _gap(3),
      if (doc.discountAmount.abs() >= 0.005) ...[
        _kvLine(doc.labels.subtotal, _fmtMoney(doc, doc.subtotal), size: 12),
        _kvLine(
          doc.labels.totalDiscount,
          _fmtMoney(doc, doc.discountAmount),
          size: 12,
        ),
      ],
      _kvLine(
        doc.labels.grandTotal,
        _fmtMoney(doc, doc.total),
        size: 13,
        strong: true,
      ),
      if (doc.paidAmount.abs() >= 0.005)
        _kvLine(doc.labels.paid, _fmtMoney(doc, doc.paidAmount), size: 12),
      if (doc.dueAmount.abs() >= 0.005)
        _kvLine(
          doc.labels.due,
          _fmtMoney(doc, doc.dueAmount),
          size: 13,
          strong: true,
          color: red,
        ),
      _gap(3),
    ]);

    // الملاحظات المطبوعة (إن وُجدت تسميتها وطلب المالك إظهارها).
    if (settings.showNotes &&
        doc.templateLabels?.notesTitle != null &&
        (doc.notesPrinted ?? '').trim().isNotEmpty) {
      blocks.addAll([
        _dash(),
        _gap(2),
        pw.Text(
          doc.templateLabels!.notesTitle!,
          style: PrintText.head(color: PrintPalette.inkSoft, size: 12),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.Text(
          doc.notesPrinted!.trim(),
          style: PrintText.body(size: 12),
          textDirection: pw.TextDirection.rtl,
        ),
        _gap(2),
      ]);
    }

    // باركود Code128 لرقم الفاتورة أسفل الإيصال.
    if (settings.showBarcode && _docNoIsEncodable(doc)) {
      blocks.addAll([
        _gap(3),
        pw.Center(
          child: pw.BarcodeWidget(
            data: doc.docNo,
            barcode: pw.Barcode.code128(),
            drawText: false,
            height: 11 * pw.PdfPageFormat.mm,
            width: _kContentWidth * 0.82,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1.5),
          child: pw.Center(
            child: pw.Text(
              doc.docNo,
              style: PrintText.tabular(color: PrintPalette.inkSoft, size: 12),
            ),
          ),
        ),
        _gap(2),
      ]);
    }

    // التذييل.
    if (settings.showFooter) {
      final companyFooter = (doc.header.footerText ?? '').trim();
      final thanks = doc.labels.footerThanks;
      final footer = companyFooter.isEmpty
          ? thanks
          : '$thanks · $companyFooter';
      blocks.addAll([
        _gap(2),
        _dash(),
        _gap(2),
        pw.Text(
          footer,
          style: PrintText.body(color: PrintPalette.inkSoft, size: 12),
          textAlign: pw.TextAlign.center,
          textDirection: pw.TextDirection.rtl,
        ),
      ]);
    }

    return blocks;
  }

  // -------------------------------------------------------------------
  // مساعدات
  // -------------------------------------------------------------------

  /// سطر «تسمية يميناً : قيمة يساراً» — القيمة أول أبناء Row فيزيائياً.
  pw.Widget _kvLine(
    String label,
    String value, {
    double size = 12,
    bool strong = false,
    pw.PdfColor color = PrintPalette.ink,
  }) {
    final isAmount = RegExp(
      r'^[\d\s.,\u0660-\u0669\u066B\u066C+\-]*[A-Z]{0,3}[\d\s.,\u0660-\u0669\u066B\u066C]*$',
    ).hasMatch(value);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                value,
                style: isAmount
                    ? (strong
                          ? PrintText.tabularHead(color: color, size: size)
                          : PrintText.tabular(color: color, size: size))
                    : (strong
                          ? PrintText.head(color: color, size: size)
                          : PrintText.body(color: color, size: size)),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
          ),
          pw.Text(
            label,
            style: strong
                ? PrintText.head(color: PrintPalette.inkSoft, size: size)
                : PrintText.body(color: PrintPalette.inkSoft, size: size),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  /// سطر تفاصيل البند: الكمية × السعر (والوحدة إن أُظهرت ووُجدت).
  /// UX-4: لاحقة البونص بجوار الكمية (qtyCellLabel) — لا بنية جديدة.
  String _lineDetail(
    InvoicePrintLine line,
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
  ) {
    final qtyPrice = '${line.qtyCellLabel} × ${line.priceLabel}';
    final unit = (line.unitLabel ?? '').trim();
    if (!settings.showUnitColumn || unit.isEmpty) return qtyPrice;
    return '$qtyPrice · $unit';
  }

  /// فاصل متقطع (dashed) بعرض المحتوى — بكسل رسم مباشر على الكانفس.
  pw.Widget _dash() => _dashedLine(0.6, [2.2, 1.8]);

  /// فاصل متقطع رفيع بين البنود.
  pw.Widget _dashThin() => _dashedLine(0.35, [1.4, 1.4]);

  pw.Widget _dashedLine(double width, List<double> pattern) {
    return pw.CustomPaint(
      size: pw.PdfPoint(_kContentWidth, width + 1.5),
      painter: (canvas, size) {
        canvas
          ..setStrokeColor(PrintPalette.rule)
          ..setLineWidth(width)
          ..setLineDashPattern(pattern)
          ..moveTo(0, size.y / 2)
          ..lineTo(size.x, size.y / 2)
          ..strokePath();
      },
    );
  }

  pw.SizedBox _gap(double mm) =>
      pw.SizedBox(height: mm * pw.PdfPageFormat.mm);

  bool _docNoIsEncodable(InvoicePrintDoc doc) =>
      RegExp(r'^[\x00-\x7F]*$').hasMatch(doc.docNo);

  String _fmtMoney(InvoicePrintDoc doc, double value) =>
      AmountText.format(value, doc.decimals);
}
