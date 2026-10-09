/// قالب «كلاسيكي A4 أفقي» (موجة UX-3) — محاكاة حرفية لنموذج المالك
/// الحكومي: إطار خارجي رفيع للصفحة · اسم المنشأة يميناً + الشعار وسطاً
/// (`company.logo_png` وإلا monogram) + بيانات المتجر يساراً · صندوق
/// أزرق سماوي بنص أبيض لوضع الدفع بمنتصف الأعلى · رقم الفاتورة
/// **بالأحمر** يميناً والتاريخ يساراً · بيانات العميل أسطر نصية يمينية
/// بلا إطار · جدول أصناف بإطار خارجي **سميك** وحدود داخلية رفيعة ورأس
/// **مظلل** عريض (الصنف أقصى اليمين) · خط مزدوج فاصل · جدول إجماليات
/// صغير يميناً (صف الإجمالي بخلفية كريمية والمتبقي بأحمر عريض) · خانة
/// ملاحظات · ثلاث خانات توقيع أفقية (المستلم/المحصل/البائع) · مساحة
/// ختم محجوزة.
///
/// استراتيجية RTL (النمط المُجرَّب بالبناة القائمة): الأعمدة فيزيائية
/// LTR بحيث يقع وصف الصنف أقصى اليمين، وكل خلية نص عربي تُرسم
/// `textDirection: rtl` — والأرقام بأعمدة tnum (Noto) بترتيبها الطبيعي.
///
/// كل تسمية تصل مسبقة التعريب من `InvoicePrintDoc` — لا نص حرفي هنا.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../../../core/widgets/amount_text.dart';
import '../core/print_palette.dart';
import '../print_docs.dart';
import 'invoice_template_settings.dart';
import 'template_colors.dart';

/// سقف البنود لصفحة الكلاسيكي المُأطَّرة الواحدة (A4 أفقي: ~198مم ارتفاع
/// محتوى — الترويسة/الإجماليات/التوقيعات تأكل النصيب الأكبر). فوقه
/// يتحول القالب تلقائياً إلى تدفق MultiPage (بلا إطار صفحة — الترويسة
/// والتذييل يتكرران بكل صفحة كنماذج الجهات المتعددة الصفحات).
const int kClassicSinglePageMaxRows = 14;

/// خلفية صف الإجمالي الكريمية (نموذج المالك).
const pw.PdfColor kClassicCream = pw.PdfColor.fromInt(0xFFF7F1DF);

/// بنّاء القالب الكلاسيكي.
class ClassicA4InvoiceTemplate {
  const ClassicA4InvoiceTemplate();

  /// يضيف صفحات القالب داخل مستند المحرك.
  void addPages(
    pw.Document pdf,
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
    Uint8List? logoPng,
  ) {
    if (doc.items.length <= kClassicSinglePageMaxRows) {
      pdf.addPage(_framedPage(doc, settings, logoPng));
    } else {
      _addFlowPages(pdf, doc, settings, logoPng);
    }
  }

  // -------------------------------------------------------------------
  // الصفحة المُأطَّرة الواحدة (نموذج المالك)
  // -------------------------------------------------------------------

  pw.Page _framedPage(
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
    Uint8List? logoPng,
  ) {
    return pw.Page(
      pageFormat: pw.PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(6 * pw.PdfPageFormat.mm),
      build: (context) => pw.Container(
        // الإطار الخارجي الرفيع للصفحة كلها.
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: templatePdfColor(settings.borderArgb),
            width: 0.8,
          ),
        ),
        padding: const pw.EdgeInsets.all(4 * pw.PdfPageFormat.mm),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _topHeader(doc, settings, logoPng),
            _gap(2),
            _customerLines(doc),
            _gap(2),
            pw.Expanded(child: _itemsTable(doc, settings)),
            _gap(2),
            _doubleRule(settings),
            _gap(2),
            _totalsRow(doc, settings),
            _gap(3),
            if (settings.showSignatures) ...[
              _signaturesRow(doc),
              _gap(2),
            ],
            if (settings.showBarcode && _docNoIsEncodable(doc)) _barcode(doc),
            if (settings.showFooter) _footerRow(doc),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // التدفق للبنود الكثيرة (فوق السقف) — نفس اللغة البصرية بلا إطار
  // -------------------------------------------------------------------

  void _addFlowPages(
    pw.Document pdf,
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
    Uint8List? logoPng,
  ) {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pw.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(8 * pw.PdfPageFormat.mm),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _topHeader(doc, settings, logoPng),
            _gap(2),
            _customerLines(doc),
            _gap(2),
          ],
        ),
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _gap(2),
            if (settings.showSignatures) ...[
              _signaturesRow(doc),
              _gap(2),
            ],
            if (settings.showBarcode && _docNoIsEncodable(doc)) _barcode(doc),
            if (settings.showFooter) _footerRow(doc),
          ],
        ),
        build: (context) => [
          _itemsTable(doc, settings),
          _gap(2),
          _doubleRule(settings),
          _gap(2),
          _totalsRow(doc, settings),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // الترويسة: المنشأة يميناً + الشعار وسطاً + بيانات المتجر يساراً +
  // صندوق وضع الدفع + صف رقم الفاتورة/التاريخ/الشارة
  // -------------------------------------------------------------------

  pw.Widget _topHeader(
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
    Uint8List? logoPng,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // بيانات المتجر — يسار الصفحة (فيزيائياً أولاً).
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _storeLine(doc.header.phone),
                  _storeLine(doc.header.address),
                  if (settings.showTax &&
                      (doc.taxNumber ?? '').trim().isNotEmpty)
                    _storeLine(doc.taxNumber, prefix: _taxLabel(doc)),
                ],
              ),
            ),
            pw.SizedBox(width: 6 * pw.PdfPageFormat.mm),
            // الشعار — وسط الترويسة (BLOB المنشأة وإلا monogram).
            _logoBox(logoPng, doc.header.name),
            pw.SizedBox(width: 6 * pw.PdfPageFormat.mm),
            // اسم المنشأة — يمين الصفحة (جهة القراءة الأولى).
            pw.Expanded(
              child: pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  doc.header.name,
                  style: PrintText.head(color: PrintPalette.brandDeep, size: 16),
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
            ),
          ],
        ),
        _gap(2),
        // صندوق وضع الدفع الملون بنص أبيض — منتصف أعلى النموذج.
        pw.Center(
          child: pw.Container(
            width: 74 * pw.PdfPageFormat.mm,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4.5,
            ),
            color: templateDarken(templatePdfColor(settings.tableHeadArgb)),
            child: pw.Text(
              doc.payStatusLabel ?? doc.labels.title,
              style: PrintText.head(color: pw.PdfColors.white, size: 13.5),
              textAlign: pw.TextAlign.center,
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ),
        _gap(2),
        _docNoRow(doc, settings),
      ],
    );
  }

  /// سطر بيانات متجر صغير (أو «تسمية: قيمة» للضريبة) — يسار الترويسة.
  pw.Widget _storeLine(String? value, {String? prefix}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return pw.SizedBox(height: 0);
    final composed = prefix == null || prefix.isEmpty ? text : '$prefix: $text';
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Text(
        composed,
        style: PrintText.body(color: PrintPalette.inkSoft, size: 9),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  String? _taxLabel(InvoicePrintDoc doc) => doc.templateLabels?.taxNumber;

  /// الشعار وسط الترويسة — من `company.logo_png` وإلا monogram بالحرف
  /// الأول داخل إطار مستدير الزوايا (نفس فكرة البنّاء القائم).
  pw.Widget _logoBox(Uint8List? logoPng, String businessName) {
    if (logoPng != null && logoPng.isNotEmpty) {
      final image = pw.MemoryImage(logoPng);
      final pxW = image.width?.toDouble() ?? 0;
      final pxH = image.height?.toDouble() ?? 0;
      if (pxW > 0 && pxH > 0) {
        const maxH = 17.0 * pw.PdfPageFormat.mm;
        const maxW = 26.0 * pw.PdfPageFormat.mm;
        var h = maxH;
        var w = h * pxW / pxH;
        if (w > maxW) {
          w = maxW;
          h = w * pxH / pxW;
        }
        return pw.Center(child: pw.Image(image, width: w, height: h));
      }
    }
    return pw.Container(
      width: 15 * pw.PdfPageFormat.mm,
      height: 15 * pw.PdfPageFormat.mm,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PrintPalette.brand, width: 1.2),
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Text(
        _monogram(businessName),
        style: PrintText.head(color: PrintPalette.brandDeep, size: 15),
      ),
    );
  }

  /// صف رقم الفاتورة (أحمر عريض يميناً) + التاريخ يساراً + شارة النسخة.
  pw.Widget _docNoRow(InvoicePrintDoc doc, InvoiceTemplateSettings settings) {
    final red = templatePdfColor(settings.accentRedArgb);
    final badgeText = _badgeText(doc, settings);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // يسار (فيزيائياً أولاً): التاريخ وتحته/بجانبه شارة النسخة.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (badgeText != null) ...[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: red, width: 0.9),
                ),
                child: pw.Text(
                  badgeText,
                  style: PrintText.head(color: red, size: 10),
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
              pw.SizedBox(width: 4 * pw.PdfPageFormat.mm),
            ],
            pw.Text(
              '${doc.labels.date}: ${doc.dateLabel}',
              style: PrintText.body(color: PrintPalette.ink, size: 10),
              textDirection: pw.TextDirection.rtl,
            ),
          ],
        ),
        // يمين: رقم الفاتورة بالأحمر العريض (نموذج المالك).
        pw.Text(doc.docNo, style: PrintText.head(color: red, size: 13)),
      ],
    );
  }

  /// نص شارة النسخة (أصل/صورة) — null عند «بلا» أو غياب التسمية.
  String? _badgeText(InvoicePrintDoc doc, InvoiceTemplateSettings settings) {
    final labels = doc.templateLabels;
    return switch (settings.badge) {
      InvoiceBadgeMode.original => labels?.badgeOriginal,
      InvoiceBadgeMode.copy => labels?.badgeCopy,
      InvoiceBadgeMode.none => null,
    };
  }

  // -------------------------------------------------------------------
  // بيانات العميل — أسطر نصية يمينية بلا إطار (نموذج المالك)
  // -------------------------------------------------------------------

  pw.Widget _customerLines(InvoicePrintDoc doc) {
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
            style: PrintText.body(color: PrintPalette.ink, size: 10.5),
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

  // -------------------------------------------------------------------
  // جدول الأصناف — إطار خارجي سميك وحدود داخلية رفيعة ورأس مظلل عريض
  // -------------------------------------------------------------------

  /// وصف أعمدة الجدول الفيزيائية (LTR — الصنف أقصى اليمين):
  /// [المجموع، (الخصم)، السعر، الكمية، (الوحدة)، الصنف].
  _ColumnsSpec _columns(InvoicePrintDoc doc, InvoiceTemplateSettings settings) {
    final templateLabels = doc.templateLabels;
    final showUnit =
        settings.showUnitColumn &&
        templateLabels?.unitCol != null &&
        doc.items.any((line) => (line.unitLabel ?? '').trim().isNotEmpty);
    final showDiscount = settings.showDiscountColumn;
    final headers = <String>[
      doc.labels.grandTotal,
      if (showDiscount) doc.labels.discount,
      doc.labels.price,
      doc.labels.qty,
      if (showUnit) templateLabels!.unitCol!,
      doc.labels.item,
    ];
    final widths = <double>[
      1.15,
      if (showDiscount) 0.85,
      1.05,
      0.6,
      if (showUnit) 0.75,
    ];
    // فهرس أول عمود نصي (الوحدة إن وُجدت وإلا الصنف).
    final textStart = headers.length - (showUnit ? 2 : 1);
    return _ColumnsSpec(
      headers: headers,
      fractions: widths,
      showDiscount: showDiscount,
      showUnit: showUnit,
      unitTextIndex: showUnit ? textStart : -1,
    );
  }

  pw.Widget _itemsTable(InvoicePrintDoc doc, InvoiceTemplateSettings settings) {
    final spec = _columns(doc, settings);
    final data = <List<String>>[
      for (final line in doc.items)
        [
          line.totalLabel,
          if (spec.showDiscount) line.discountLabel,
          line.priceLabel,
          // UX-4: لاحقة البونص بجوار الكمية (qtyCellLabel) — لا عمود جديد.
          line.qtyCellLabel,
          if (spec.showUnit)
            (line.unitLabel ?? '').trim().isEmpty ? '—' : line.unitLabel!.trim(),
          line.desc,
        ],
    ];
    final border = templatePdfColor(settings.borderArgb);
    final headFill = templatePdfColor(settings.tableHeadArgb);
    final headText = templateOnColor(headFill);
    // الأعمدة الرقمية قبل عمودي الوحدة/الصنف — خط tnum الجدولي.
    final numericCount = spec.headers.length - (spec.showUnit ? 2 : 1);
    final columnWidths = <int, pw.TableColumnWidth>{
      for (var c = 0; c < spec.fractions.length; c++)
        c: pw.FractionColumnWidth(spec.fractions[c]),
    };
    return pw.TableHelper.fromTextArray(
      headers: spec.headers,
      data: data,
      border: pw.TableBorder(
        top: pw.BorderSide(color: border, width: 1.5),
        bottom: pw.BorderSide(color: border, width: 1.5),
        left: pw.BorderSide(color: border, width: 1.5),
        right: pw.BorderSide(color: border, width: 1.5),
        horizontalInside: pw.BorderSide(color: border, width: 0.4),
        verticalInside: pw.BorderSide(color: border, width: 0.4),
      ),
      headerDecoration: pw.BoxDecoration(color: headFill),
      headerStyle: PrintText.head(color: headText, size: 10.5),
      headerAlignments: _alignments(spec, numericCount),
      cellAlignments: _alignments(spec, numericCount),
      cellStyle: PrintText.body(size: 10),
      textStyleBuilder: (column, cell, rowNum) =>
          column < numericCount ? PrintText.tabular(size: 10) : null,
      headerDirection: pw.TextDirection.rtl,
      tableDirection: pw.TextDirection.rtl,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      columnWidths: columnWidths,
    );
  }

  /// محاذاة الأعمدة: المبالغ/السعر يساراً (تُقرأ LTR)، الخصم/الكمية/
  /// الوحدة وسطاً، الصنف أقصى اليمين (RTL).
  Map<int, pw.AlignmentGeometry> _alignments(
    _ColumnsSpec spec,
    int numericCount,
  ) {
    final map = <int, pw.AlignmentGeometry>{};
    var c = 0;
    // الإجمالي — رقمي يسار.
    map[c++] = pw.Alignment.centerLeft;
    // الخصم — وسط.
    if (spec.showDiscount) map[c++] = pw.Alignment.center;
    // السعر — رقمي يسار.
    map[c++] = pw.Alignment.centerLeft;
    // الكمية — وسط.
    map[c++] = pw.Alignment.center;
    // الوحدة — وسط.
    if (spec.showUnit) map[c++] = pw.Alignment.center;
    // الصنف — أقصى اليمين دائماً (الأخير فيزيائياً).
    map[c] = pw.Alignment.centerRight;
    return map;
  }

  // -------------------------------------------------------------------
  // الخط المزدوج + صف الإجماليات (جدول صغير يميناً + ملاحظات/ختم يساراً)
  // -------------------------------------------------------------------

  /// الخط المزدوج الفاصل (نموذج المالك): حافة علوية سميقة وسفلية رفيعة.
  pw.Widget _doubleRule(InvoiceTemplateSettings settings) {
    final border = templatePdfColor(settings.borderArgb);
    return pw.Container(
      height: 3.2,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: border, width: 1.3),
          bottom: pw.BorderSide(color: border, width: 0.5),
        ),
      ),
    );
  }

  pw.Widget _totalsRow(InvoicePrintDoc doc, InvoiceTemplateSettings settings) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // يسار الصفحة: خانة الملاحظات ثم مساحة الختم تحتها.
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (settings.showNotes &&
                  doc.templateLabels?.notesTitle != null)
                _notesBox(doc, settings),
              if (settings.showStampArea &&
                  doc.templateLabels?.stampArea != null) ...[
                _gap(2),
                _stampBox(doc, settings),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 8 * pw.PdfPageFormat.mm),
        // يمين الصفحة: جدول الإجماليات الصغير.
        pw.Container(
          width: 82 * pw.PdfPageFormat.mm,
          child: _totalsTable(doc, settings),
        ),
      ],
    );
  }

  /// خانة الملاحظات — إطار خفيف بعنوان ومحتوى `notes_printed` (أو فراغ).
  pw.Widget _notesBox(InvoicePrintDoc doc, InvoiceTemplateSettings settings) {
    return pw.Container(
      width: double.infinity,
      height: 20 * pw.PdfPageFormat.mm,
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: templatePdfColor(settings.borderArgb),
          width: 0.5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            doc.templateLabels!.notesTitle!,
            style: PrintText.head(color: PrintPalette.inkSoft, size: 9),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.SizedBox(height: 3),
          pw.Expanded(
            child: pw.Text(
              (doc.notesPrinted ?? '').trim(),
              style: PrintText.body(size: 9.5),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  /// مساحة الختم المحجوزة — إطار خفيف بتسمية باهتة بلا دائرة (المالك).
  pw.Widget _stampBox(InvoicePrintDoc doc, InvoiceTemplateSettings settings) {
    return pw.Container(
      width: 46 * pw.PdfPageFormat.mm,
      height: 18 * pw.PdfPageFormat.mm,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: templatePdfColor(settings.borderArgb),
          width: 0.5,
        ),
      ),
      child: pw.Text(
        doc.templateLabels!.stampArea!,
        style: PrintText.body(color: PrintPalette.inkSoft, size: 8.5),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  /// جدول الإجماليات الصغير يميناً — [قيمة يساراً · تسمية يميناً]، صف
  /// الإجمالي بخلفية كريمية والمتبقي بأحمر عريض (نموذج المالك).
  pw.Widget _totalsTable(
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
  ) {
    final labels = doc.labels;
    final red = templatePdfColor(settings.accentRedArgb);
    final border = templatePdfColor(settings.borderArgb);
    final rows = <(String, String, _TotalRowStyle)>[
      if (doc.discountAmount.abs() >= 0.005) ...[
        (labels.subtotal, _fmtMoney(doc, doc.subtotal), _TotalRowStyle.plain),
        (
          labels.totalDiscount,
          _fmtMoney(doc, doc.discountAmount),
          _TotalRowStyle.plain,
        ),
      ],
      (labels.grandTotal, _fmtMoney(doc, doc.total), _TotalRowStyle.cream),
      if (doc.paidAmount.abs() >= 0.005)
        (labels.paid, _fmtMoney(doc, doc.paidAmount), _TotalRowStyle.plain),
      if (doc.dueAmount.abs() >= 0.005)
        (labels.due, _fmtMoney(doc, doc.dueAmount), _TotalRowStyle.red),
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: border, width: 0.5),
      columnWidths: const {
        0: pw.FractionColumnWidth(1.15),
        1: pw.FractionColumnWidth(1),
      },
      children: [
        for (final (label, value, style) in rows)
          pw.TableRow(
            decoration: style == _TotalRowStyle.cream
                ? const pw.BoxDecoration(color: kClassicCream)
                : null,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    value,
                    style: style == _TotalRowStyle.red
                        ? PrintText.tabularHead(color: red, size: 11)
                        : style == _TotalRowStyle.cream
                        ? PrintText.tabularHead(
                            color: PrintPalette.brandDeep,
                            size: 11,
                          )
                        : PrintText.tabular(
                            color: PrintPalette.brandDeep,
                            size: 10,
                          ),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                child: pw.Text(
                  label,
                  style: style == _TotalRowStyle.red
                      ? PrintText.head(color: red, size: 10.5)
                      : style == _TotalRowStyle.cream
                      ? PrintText.head(color: PrintPalette.brandDeep, size: 10.5)
                      : PrintText.body(color: PrintPalette.inkSoft, size: 9.5),
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // التوقيعات الثلاث + الباركود + التذييل
  // -------------------------------------------------------------------

  /// ثلاث خانات توقيع أفقية — فيزيائياً [البائع، المحصّل، المستلم] فيقرؤها
  /// العربي من اليمين: المستلم ثم المحصّل ثم البائع (نموذج المالك).
  pw.Widget _signaturesRow(InvoicePrintDoc doc) {
    final labels = doc.templateLabels;
    final cells = <String?>[
      labels?.signatureSeller,
      labels?.signatureCollector,
      labels?.signatureReceiver,
    ];
    return pw.Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 5 * pw.PdfPageFormat.mm),
          pw.Expanded(
            child: pw.Container(
              height: 15 * pw.PdfPageFormat.mm,
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PrintPalette.rule, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    cells[i] ?? '—',
                    style: PrintText.body(color: PrintPalette.inkSoft, size: 9),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// باركود Code128 لرقم الفاتورة + الرقم تحته بالخط الجدولي.
  pw.Widget _barcode(InvoicePrintDoc doc) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.BarcodeWidget(
            data: doc.docNo,
            barcode: pw.Barcode.code128(),
            drawText: false,
            height: 12 * pw.PdfPageFormat.mm,
            width: 58 * pw.PdfPageFormat.mm,
          ),
          pw.SizedBox(height: 1.5),
          pw.Text(
            doc.docNo,
            style: PrintText.tabular(color: PrintPalette.inkSoft, size: 8.5),
          ),
        ],
      ),
    );
  }

  /// التذييل: نص المنشأة/الشكر يميناً ونسبة التطبيق يساراً.
  pw.Widget _footerRow(InvoicePrintDoc doc) {
    final companyFooter = (doc.header.footerText ?? '').trim();
    final thanks = doc.labels.footerThanks;
    final right = companyFooter.isEmpty ? thanks : '$thanks · $companyFooter';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(color: PrintPalette.rule, thickness: 0.5),
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

  pw.SizedBox _gap(double mm) =>
      pw.SizedBox(height: mm * pw.PdfPageFormat.mm);

  /// هل رقم الفاتورة قابلاً للترميز Code128؟ (لاتيني/أرقام حصراً —
  /// الأكواد الحالية `INV-YYYY-NNNNN` دائماً كذلك).
  bool _docNoIsEncodable(InvoicePrintDoc doc) =>
      RegExp(r'^[\x00-\x7F]*$').hasMatch(doc.docNo);

  String _monogram(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'ف' : trimmed.substring(0, 1);
  }

  String _fmtMoney(InvoicePrintDoc doc, double value) =>
      AmountText.format(value, doc.decimals);
}

/// مخطط نمط صف الإجماليات.
enum _TotalRowStyle { plain, cream, red }

/// وصف أعمدة جدول الأصناف المحسوبة (تخطيط فيزيائي LTR).
class _ColumnsSpec {
  const _ColumnsSpec({
    required this.headers,
    required this.fractions,
    required this.showDiscount,
    required this.showUnit,
    required this.unitTextIndex,
  });

  final List<String> headers;
  final List<double> fractions;
  final bool showDiscount;
  final bool showUnit;

  /// فهرس عمود الوحدة داخل الجزء النصي (−1 حين لا يوجد).
  final int unitTextIndex;
}
