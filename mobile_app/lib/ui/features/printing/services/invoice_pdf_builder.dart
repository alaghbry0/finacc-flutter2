/// بنّاء PDF فاتورة المبيعات (الشريحة 7 — FR-10-01): قالب A4 عمودي RTL.
///
/// استراتيجية RTL: **ترتيب الأعمدة** يُصاغ فيزيائياً يسار→يمين بحيث
/// يقع وصف الصنف في العمود الأقصى يميناً (ترتيب القراءة العربية)، بينما
/// يتشكّل نص كل خلية نفسه RTL عبر محرك حزمة pdf (تشكيل عربي + BiDi).
/// كل تسمية داخل المستند تأتي مسبقة التعريب من `InvoiceLabels` — لا نص
/// حرفي هنا غير اسم المنتج الثابت في التذييل.
///
/// موجة UX-3: البنّاء نفسه صار قالب «simple_a4» تحت المحرك
/// ([`InvoiceTemplateEngine`]) — `[settings]` اختياري: غيابه = السلوك
/// التاريخي حرفياً؛ ومروره يطبّق مفاتيح الإظهار/الإخفاء والألوان حيث
/// يوفرها هذا التخطيط (أعمدة خصم/وحدة + تذييل + ضريبة + باركود)،
/// والإعدادات المبذورة له مطابقة لهويته الحالية فلا يتغير شيء افتراضاً.
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../../../core/widgets/amount_text.dart';
import '../core/print_fonts.dart';
import '../core/print_palette.dart';
import '../print_docs.dart';
import '../templates/invoice_template_settings.dart';
import '../templates/template_colors.dart';

/// يحوّل [InvoicePrintDoc] إلى `pw.Document` جاهز للمعاينة/الطباعة/
/// المشاركة (استدعِ `PrintFonts.load()` أولاً — يحدث داخل [build]).
class InvoicePdfBuilder {
  const InvoicePdfBuilder();

  /// البناء الكامل — A4 عمودي، MultiPage (البضائع الكثيرة تتدفق لصفحة
  /// ثانية بنفس الشريط والتذييل).
  Future<pw.Document> build(
    InvoicePrintDoc doc, {
    InvoiceTemplateSettings? settings,
  }) async {
    await PrintFonts.load();
    final pdf = pw.Document(
      title: doc.docNo,
      author: doc.header.name,
      creator: kPrintAppCredit,
      // Almarai في كل مكان — حتى النص الضمني لا يسقط أبداً إلى خط
      // Courier غير اليونيكودي.
      theme: pw.ThemeData.withFont(
        base: PrintFonts.regular,
        bold: PrintFonts.bold,
      ),
    );
    pdf.addPage(_sheetPage(doc, settings));
    return pdf;
  }

  // -------------------------------------------------------------------
  // الصفحة
  // -------------------------------------------------------------------

  pw.MultiPage _sheetPage(
    InvoicePrintDoc doc,
    InvoiceTemplateSettings? settings,
  ) {
    final showFooter = settings?.showFooter ?? true;
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
          showFooter ? _footerLine(doc) : pw.SizedBox(height: 4),
      build: (context) => [
        pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
        _titleRow(doc),
        pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
        _metaGrid(doc, settings),
        pw.SizedBox(height: 6 * pw.PdfPageFormat.mm),
        // عنوان القسم والجدول عنصران مستقلان في قائمة البناء (لا داخل
        // Column واحدة): الجدول SpanningWidget يتدفق عبر الصفحات عبر
        // MultiPage، ولفّه في Column كان يمنع التدفق فيرمي
        // TooManyPagesException (ويعلّق بناء الصفحات في الريليز) للفواتير
        // ذات البنود الكثيرة — إصلاح موجة 1-a فوق تدقيق UX-audit A5.
        _itemsTitle(doc),
        pw.SizedBox(height: 2 * pw.PdfPageFormat.mm),
        _itemsTable(doc, settings),
        pw.SizedBox(height: 5 * pw.PdfPageFormat.mm),
        _totalsCard(doc),
        if (settings?.showBarcode ?? false) ...[
          pw.SizedBox(height: 5 * pw.PdfPageFormat.mm),
          _barcodeBlock(doc),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------
  // الكتل
  // -------------------------------------------------------------------

  /// شريط الهوية العميق: اسم المنشأة + هاتف/عنوان يميناً (جهة القراءة
  /// الأولى)، ومربع الحرف الأول يساراً (شعار مؤقت حتى يُرفع شعار فعلي).
  pw.Widget _brandBand(InvoicePrintDoc doc) {
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

  /// صف العنوان: عنوان المستند يميناً + رقاقة رقم الفاتورة يساراً.
  pw.Widget _titleRow(InvoicePrintDoc doc) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PrintPalette.brand,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            doc.docNo,
            style: PrintText.head(color: pw.PdfColors.white, size: 10),
          ),
        ),
        pw.Text(
          doc.labels.title,
          // ExtraBold لعنوان المستند الكبير (إصلاح UX-audit ExtraBold).
          style: PrintText.extraHead(color: PrintPalette.brandDeep, size: 18),
          textDirection: pw.TextDirection.rtl,
        ),
      ],
    );
  }

  /// شبكة البيانات: العميل والتاريخ يميناً (أساسية)، العملة وهاتف
  /// العميل يساراً — داخل إطار مستدير خفيف. (UX-3: الرقم الضريبي تحت
  /// العملة حين يطلبه المالك ويتوفر.)
  pw.Widget _metaGrid(
    InvoicePrintDoc doc,
    InvoiceTemplateSettings? settings,
  ) {
    final partyPhone = (doc.partyPhone ?? '').trim();
    final taxNumber = (doc.taxNumber ?? '').trim();
    final showTax =
        (settings?.showTax ?? false) &&
        taxNumber.isNotEmpty &&
        doc.templateLabels?.taxNumber != null;
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
                _kvLine(
                  doc.labels.currency,
                  doc.currencyCode.isEmpty ? '—' : doc.currencyCode,
                ),
                if (showTax)
                  _kvLine(doc.templateLabels!.taxNumber!, taxNumber),
              ],
            ),
          ),
          pw.SizedBox(width: 8 * pw.PdfPageFormat.mm),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _kvLine(doc.labels.customer, doc.partyName),
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
                _kvLine(doc.labels.date, doc.dateLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// عنوان قسم البنود — عنصر مستقل أعلى الجدول: `Align` بعرض كامل يحافظ
  /// على محاذاة العنوان يميناً (كما كان داخل Column الممتدة) بينما يبقى
  /// الجدول حر التدفق لصفحات إضافية.
  pw.Widget _itemsTitle(InvoicePrintDoc doc) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        doc.labels.itemsSection,
        style: PrintText.head(color: PrintPalette.brandDeep, size: 12),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  /// جدول البنود — الأعمدة مُصاغة فيزيائياً يسار→يمين بحيث يكون «الصنف»
  /// في أقصى اليمين: [الإجمالي، خصم، السعر، كمية، الصنف]. (UX-3: عمود
  /// الخصم يسقط بطلب المالك، وعمود الوحدة يُدرج عند توفر أسماء الوحدات.)
  pw.Widget _itemsTable(
    InvoicePrintDoc doc,
    InvoiceTemplateSettings? settings,
  ) {
    final labels = doc.labels;
    final showDiscount = settings?.showDiscountColumn ?? true;
    final showUnit =
        (settings?.showUnitColumn ?? false) &&
        doc.templateLabels?.unitCol != null &&
        doc.items.any((line) => (line.unitLabel ?? '').trim().isNotEmpty);
    final headers = <String>[
      labels.grandTotal,
      if (showDiscount) labels.discount,
      labels.price,
      labels.qty,
      if (showUnit) doc.templateLabels!.unitCol!,
      labels.item,
    ];
    final data = <List<String>>[
      for (final line in doc.items)
        [
          line.totalLabel,
          if (showDiscount) line.discountLabel,
          line.priceLabel,
          // UX-4: لاحقة البونص بجوار الكمية (qtyCellLabel) — لا عمود جديد.
          line.qtyCellLabel,
          if (showUnit)
            (line.unitLabel ?? '').trim().isEmpty
                ? '—'
                : line.unitLabel!.trim(),
          line.desc,
        ],
    ];
    final tableHead = settings == null
        ? PrintPalette.tableHead
        : templatePdfColor(settings.tableHeadArgb);
    final border = settings == null
        ? PrintPalette.rule
        : templatePdfColor(settings.borderArgb);
    final numericCount = headers.length - 1;
    // محاذاة كل عمود فيزيائي بمعناه (المبالغ يساراً، الخصم/الكمية/
    // الوحدة وسطاً، الصنف أقصى اليمين).
    final aligns = <pw.AlignmentGeometry>[
      pw.Alignment.centerLeft, // الإجمالي — رقمي
      if (showDiscount) pw.Alignment.center, // خصم
      pw.Alignment.centerLeft, // السعر — رقمي
      pw.Alignment.center, // كمية
      if (showUnit) pw.Alignment.center, // الوحدة
    ];
    final alignmentMap = <int, pw.AlignmentGeometry>{
      for (var i = 0; i < aligns.length; i++) i: aligns[i],
      aligns.length: pw.Alignment.centerRight, // الصنف — نص RTL
    };
    // عروض الأعمدة بترتيبها الفيزيائي نفسه (الصنف آخراً يستولي على الباقي).
    final widths = <double>[
      1.5, // الإجمالي — رقمي
      if (showDiscount) 0.9, // خصم
      1.2, // السعر — رقمي
      0.75, // كمية
      if (showUnit) 0.85, // الوحدة
    ];
    final columnWidths = <int, pw.TableColumnWidth>{
      for (var i = 0; i < widths.length; i++)
        i: pw.FractionColumnWidth(widths[i]),
      widths.length: const pw.FractionColumnWidth(3.1), // الصنف — نص عربي
    };
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: border, width: 0.5),
      headerDecoration: pw.BoxDecoration(color: tableHead),
      headerStyle: PrintText.head(color: PrintPalette.brandDeep, size: 9.5),
      headerAlignments: alignmentMap,
      cellAlignments: alignmentMap,
      cellStyle: PrintText.body(size: 9.5),
      // أعمدة المبالغ (الإجمالي/الخصم/السعر/الكمية) بالخط المرافق
      // الجدولي (UX-2b): أرقام متساوية العرض تستقيم بها الأعمدة على
      // الورق — عمود الصنف يبقى Almarai لهوية النص العربي.
      textStyleBuilder: (column, cell, rowNum) =>
          column < numericCount ? PrintText.tabular(size: 9.5) : null,
      oddRowDecoration: const pw.BoxDecoration(color: PrintPalette.zebra),
      headerDirection: pw.TextDirection.rtl,
      tableDirection: pw.TextDirection.rtl,
      cellPadding: const pw.EdgeInsets.all(4.5),
      headerPadding: const pw.EdgeInsets.symmetric(
        horizontal: 4.5,
        vertical: 4,
      ),
      columnWidths: columnWidths,
    );
  }

  /// بطاقة الإجماليات: قبل الخصم / الخصم / **الإجمالي النهائي** (شريط
  /// بارز) / المدفوع / المتبقي — كما هي منذ الشريحة 7 (سلوك simple_a4
  /// «كما هو» — لا يُعاد تلوينها بإعدادات UX-3).
  pw.Widget _totalsCard(InvoicePrintDoc doc) {
    final labels = doc.labels;
    final rows = <(String, String, bool)>[
      (labels.subtotal, _fmtMoney(doc, doc.subtotal), false),
      if (doc.discountAmount.abs() >= 0.005)
        (labels.totalDiscount, _fmtMoney(doc, doc.discountAmount), false),
      (labels.grandTotal, _fmtGrandTotal(doc), true),
      if (doc.paidAmount.abs() >= 0.005)
        (labels.paid, _fmtMoney(doc, doc.paidAmount), false),
      if (doc.dueAmount.abs() >= 0.005)
        (labels.due, _fmtMoney(doc, doc.dueAmount), false),
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
                    // الإجمالي النهائي — أرقام جدولية عريضة (UX-2b).
                    pw.Text(
                      value,
                      style: PrintText.tabularHead(
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
  pw.Widget _footerLine(InvoicePrintDoc doc) {
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

  /// باركود Code128 لرقم الفاتورة أسفل بطاقة الإجماليات (UX-3 — يظهر
  /// فقط بطلب المالك `showBarcode`، والرقم اللاتيني دائماً قابل للترميز).
  pw.Widget _barcodeBlock(InvoicePrintDoc doc) {
    if (!RegExp(r'^[\x00-\x7F]*$').hasMatch(doc.docNo)) {
      return pw.SizedBox(height: 0);
    }
    return pw.Center(
      child: pw.Column(
        children: [
          pw.BarcodeWidget(
            data: doc.docNo,
            barcode: pw.Barcode.code128(),
            drawText: false,
            height: 13 * pw.PdfPageFormat.mm,
            width: 62 * pw.PdfPageFormat.mm,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            doc.docNo,
            style: PrintText.tabular(color: PrintPalette.inkSoft, size: 9),
          ),
        ],
      ),
    );
  }

  /// سطر «تسمية يميناً : قيمة يساراً» — النمط العربي الأساسي للمعلومات.
  ///
  /// القيمة تُرسم RTL **دائماً** (إصلاح UX-audit A1): بلا `textDirection`
  /// ترسم حزمة pdf العربيةَ بلا تشكيل معكوسةً مفككةً (شكوى المالك)، وقد
  /// ينهار subsetter الخط (`Bad state: No element`) حين يجتمع عربي غير
  /// مشكل بعربي مشكل في نفس المستند. الأرقام/اللاتيني داخل قيمة RTL
  /// يعاد ترتيبها وفق BiDi فيقرؤها العربي بترتيبها المنطقي الصحيح.
  pw.Widget _kvLine(String label, String value, {double size = 9.5}) {
    // هل القيمة مبلغاً رقمياً خالصاً؟ (رقم/فاصلة/نقطة/مسافة/رمز عملة
    // لاتيني) — إذن تُرسم بالخط الجدولي المرافق (UX-2b) وبترتيب LTR
    // (الأرقام تُقرأ يسار→يمين حتى داخل مستند عربي).
    final isAmount = RegExp(
      r'^[\d\s.,\u0660-\u0669\u066B\u066C+\-]*[A-Z]{0,3}[\d\s.,\u0660-\u0669\u066B\u066C]*$',
    ).hasMatch(value);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                value,
                style: isAmount
                    ? PrintText.tabular(
                        color: PrintPalette.brandDeep,
                        size: size,
                      )
                    : PrintText.body(color: PrintPalette.brandDeep, size: size),
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

  String _fmtMoney(InvoicePrintDoc doc, double value) =>
      AmountText.format(value, doc.decimals);

  /// الإجمالي النهائي مع رمز العملة (إن وُجد) — «12,500 YER».
  String _fmtGrandTotal(InvoicePrintDoc doc) {
    final value = _fmtMoney(doc, doc.total);
    return doc.currencyCode.isEmpty ? value : '$value ${doc.currencyCode}';
  }

  String _monogram(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'ف' : trimmed.substring(0, 1);
  }
}
