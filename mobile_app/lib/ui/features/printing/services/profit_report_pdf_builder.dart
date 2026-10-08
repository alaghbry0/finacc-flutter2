/// بنّاء PDF تقرير الأرباح والخسائر (الشريحة 10 — FR-09-02): قالب A4
/// عمودي RTL بنمط تقرير الوردية/كشف الحساب نفسه (Almarai + لوحة
/// الطباعة + استراتيجية الأعمدة الفيزيائية مع تشكيل عربي RTL).
///
/// بنية المستند: شريط هوية المنشأة ← صف العنوان («تقرير الأرباح
/// والخسائر» يميناً ورقاقة الفترة يساراً) ← شبكة البيانات (الفترة/
/// وقت الإنشاء/العملة) ← جدول البنود بأعمدة [القيمة، البند] فيزيائياً
/// يسار→يمين فيقع البند أقصى اليمين مع أقسام مظللة (الإيراد/التكلفة/
/// التسويات/المصاريف) وقيم موقّعة ملوّنة (أخضر إسهام+/أحمر إسهام−) ←
/// **بطاقة الربح البارزة بلمسة ذهبية** ← بطاقة الإغلاق (المسحوبات ثم
/// «صافي ما بقي للمالك») ← حاشية «مُشتق حصراً من خريطة الترحيل
/// (ملحق و)» ← تذييل.
///
/// قاعدة الملزمة المعمارية (نمط print_docs): كل نص داخل الـPDF يمر
/// عبر المسقط كتسمية **مسبقة التعريب** يبنيها `buildProfitPrintDoc`
/// من l10n — القالب نفسه بلا نص حرفي قابل للترجمة غير اسم المنتج
/// الثابت. الأرقام تُنسَّق عبر `AmountText.format`.
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../../../../data/repositories/profit_report_repository.dart';
import '../../../../domain/models/company.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/amount_text.dart';
import '../core/print_fonts.dart';
import '../core/print_palette.dart';
import '../print_docs.dart';

/// نغمة سطر البند (لون القيمة المطبوع).
enum ProfitLineTone {
  /// إسهام موجب في الربح — أخضر.
  positive,

  /// إسهام سالب — أحمر.
  negative,

  /// محايد — حبر داكن.
  neutral,
}

/// سطر بند في جدول الأرباح — كل القيم سلاسل جاهزة للعرض.
class ProfitReportLine {
  const ProfitReportLine({
    required this.itemLabel,
    required this.valueLabel,
    required this.tone,
    this.strong = false,
  });

  /// اسم البند (المبيعات/المصاريف/… — سلسلة جاهزة).
  final String itemLabel;

  /// القيمة موقّعة ومنسَّقة («+1,000» / «−250» — سلسلة جاهزة).
  final String valueLabel;

  /// نغمة اللون.
  final ProfitLineTone tone;

  /// سطر مجمع قوي (صافي المبيعات/صافي التكلفة).
  final bool strong;
}

/// قسم من أقسام الجدول (الإيراد/التكلفة/التسويات/المصاريف).
class ProfitPrintSection {
  const ProfitPrintSection({required this.title, required this.lines});

  /// عنوان القسم (سلسلة جاهزة).
  final String title;

  final List<ProfitReportLine> lines;
}

/// كل تسميات تقرير الأرباح داخل الـPDF — مبنية من l10n عند التجميع.
class ProfitLabels {
  const ProfitLabels({
    required this.title,
    required this.generatedAtLabel,
    required this.currencyNote,
    required this.itemCol,
    required this.valueCol,
    required this.profitLabel,
    required this.ownerDrawingsLabel,
    required this.netForOwnerLabel,
    required this.footerNote,
    required this.footerThanks,
  });

  /// عنوان المستند («تقرير الأرباح والخسائر»).
  final String title;

  /// سطر وقت الإنشاء (جاهز: «أُنشئ في …»).
  final String generatedAtLabel;

  /// ملاحظة العملة الأساسية (جاهزة).
  final String currencyNote;

  /// تسمية عمود البند.
  final String itemCol;

  /// تسمية عمود القيمة.
  final String valueCol;

  /// تسمية سطر الربح.
  final String profitLabel;

  /// تسمية سطر مسحوبات المالك.
  final String ownerDrawingsLabel;

  /// تسمية سطر الإغلاق «صافي ما بقي للمالك».
  final String netForOwnerLabel;

  /// حاشية خريطة الترحيل أسفل الجدول.
  final String footerNote;

  /// عبارة الشكر في التذييل.
  final String footerThanks;
}

/// مستند تقرير أرباح قابل للطباعة — يغذي قالب A4.
class ProfitPrintDoc {
  const ProfitPrintDoc({
    required this.header,
    required this.periodLabel,
    required this.currencyCode,
    required this.decimals,
    required this.sections,
    required this.profit,
    required this.ownerDrawings,
    required this.netForOwner,
    required this.labels,
  });

  /// رأس المنشأة.
  final PrintHeader header;

  /// الفترة منسَّقة («من X إلى Y» — سلسلة جاهزة).
  final String periodLabel;

  /// رمز العملة الأساسية.
  final String currencyCode;

  /// منازل العملة للعرض (YER = 0 — قرار المستدعي، قاعدة 5.4-9).
  final int decimals;

  /// أقسام البنود منسَّقة مسبقاً.
  final List<ProfitPrintSection> sections;

  /// الربح (الصيغة الملزمة — FR-09-02).
  final double profit;

  /// مسحوبات المالك (بند مستقل خارج المصاريف).
  final double ownerDrawings;

  /// صافي ما بقي للمالك = الربح − المسحوبات.
  final double netForOwner;

  /// كل تسميات المستند (مسبقة التعريب).
  final ProfitLabels labels;
}

/// يجمع مسقط تقرير الأرباح — **نقيّ وقابل للاختبار**: لا BuildContext
/// ولا I/O؛ l10n يُمرَّر معلماً والتسميات والقيم تُبنى هنا كلها.
///
/// [report] من `ProfitReportRepository.report` و[generatedAt] لحظة
/// الإنشاء (وقت الجهاز المحلي عادة). الإشارة في القيم تعني **إسهام
/// البند في الربح** (+ يزيد / − يقلّ).
ProfitPrintDoc buildProfitPrintDoc({
  required AppLocalizations l10n,
  required ProfitReport report,
  Company? company,
  required String currencyCode,
  required int decimals,
  required DateTime generatedAt,
}) {
  String fmtMoney(double value) => AmountText.format(value, decimals);
  String fmtSigned(double value) {
    if (value > 0.005) return '+${fmtMoney(value)}';
    if (value < -0.005) return '−${fmtMoney(value.abs())}';
    return '—';
  }

  ProfitLineTone toneOf(double value) => value > 0.005
      ? ProfitLineTone.positive
      : value < -0.005
      ? ProfitLineTone.negative
      : ProfitLineTone.neutral;

  final sections = <ProfitPrintSection>[
    ProfitPrintSection(
      title: l10n.profitSectionRevenue,
      lines: [
        ProfitReportLine(
          itemLabel: l10n.profitSales,
          valueLabel: fmtSigned(report.sales),
          tone: toneOf(report.sales),
        ),
        ProfitReportLine(
          itemLabel: l10n.profitSalesReturns,
          valueLabel: fmtSigned(-report.salesReturns),
          tone: report.salesReturns < -0.005
              ? ProfitLineTone.negative
              : ProfitLineTone.neutral,
        ),
        ProfitReportLine(
          itemLabel: l10n.profitNetSales,
          valueLabel: fmtSigned(report.netSales),
          tone: toneOf(report.netSales),
          strong: true,
        ),
      ],
    ),
    ProfitPrintSection(
      title: l10n.profitSectionCost,
      lines: [
        ProfitReportLine(
          itemLabel: l10n.profitCogs,
          valueLabel: fmtSigned(-report.cogs),
          tone: report.cogs > 0.005
              ? ProfitLineTone.negative
              : ProfitLineTone.neutral,
        ),
        ProfitReportLine(
          itemLabel: l10n.profitReturnCost,
          valueLabel: fmtSigned(report.returnCost),
          tone: toneOf(report.returnCost),
        ),
        ProfitReportLine(
          itemLabel: l10n.profitNetCogs,
          valueLabel: fmtSigned(-report.netCogs),
          tone: report.netCogs > 0.005
              ? ProfitLineTone.negative
              : ProfitLineTone.neutral,
          strong: true,
        ),
      ],
    ),
    ProfitPrintSection(
      title: l10n.profitSectionAdjustments,
      lines: [
        ProfitReportLine(
          itemLabel: l10n.profitStockSurplus,
          valueLabel: fmtSigned(report.stockSurplus),
          tone: toneOf(report.stockSurplus),
        ),
        ProfitReportLine(
          itemLabel: l10n.profitStockShortage,
          valueLabel: fmtSigned(-report.stockShortage),
          tone: report.stockShortage > 0.005
              ? ProfitLineTone.negative
              : ProfitLineTone.neutral,
        ),
        ProfitReportLine(
          itemLabel: l10n.profitFx,
          valueLabel: fmtSigned(report.fxGainLoss),
          tone: toneOf(report.fxGainLoss),
        ),
      ],
    ),
    ProfitPrintSection(
      title: l10n.profitSectionExpenses,
      lines: [
        ProfitReportLine(
          itemLabel: l10n.profitExpenses,
          valueLabel: fmtSigned(-report.expenses),
          tone: report.expenses > 0.005
              ? ProfitLineTone.negative
              : ProfitLineTone.neutral,
        ),
      ],
    ),
  ];

  final currencyNote = currencyCode.isEmpty
      ? l10n.profitBaseCurrencyNote
      : '${l10n.profitBaseCurrencyNote} ($currencyCode)';

  return ProfitPrintDoc(
    header: PrintHeader(
      name: company?.name ?? '',
      phone: company?.phone,
      address: company?.address,
      footerText: company?.footerText,
    ),
    periodLabel: l10n.periodCustomRange(
      _fmtDate(report.from),
      _fmtDate(report.to),
    ),
    currencyCode: currencyCode,
    decimals: decimals,
    sections: sections,
    profit: report.profit,
    ownerDrawings: report.ownerDrawings,
    netForOwner: report.netForOwner,
    labels: ProfitLabels(
      title: l10n.profitPdfTitle,
      generatedAtLabel: l10n.profitGeneratedAt(_fmtDateTime(generatedAt)),
      currencyNote: currencyNote,
      itemCol: l10n.profitPrintItemCol,
      valueCol: l10n.profitPrintValueCol,
      profitLabel: l10n.profitTotal,
      ownerDrawingsLabel: l10n.profitOwnerDrawings,
      netForOwnerLabel: l10n.profitNetForOwner,
      footerNote: l10n.profitPrintFooterNote,
      footerThanks: l10n.printingFooterThanks,
    ),
  );
}

/// يحوّل [ProfitPrintDoc] إلى `pw.Document` جاهز للمعاينة/الطباعة/
/// المشاركة (استدعِ `PrintFonts.load()` أولاً — يحدث داخل [build]).
class ProfitReportPdfBuilder {
  const ProfitReportPdfBuilder();

  /// إسهام موجب — أخضر `FinColors.positive` الفاتح للورق.
  static const pw.PdfColor _surplus = pw.PdfColor.fromInt(0xFF0E7A4E);

  /// إسهام سالب — أحمر `FinColors.negative` الفاتح للورق.
  static const pw.PdfColor _deficit = pw.PdfColor.fromInt(0xFFB3261E);

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
        header: (context) => _brandBand(doc),
        footer: (context) => _footerLine(doc),
        build: (context) => [
          pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
          _titleRow(doc),
          pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
          _metaGrid(doc),
          pw.SizedBox(height: 6 * pw.PdfPageFormat.mm),
          _linesTable(doc),
          pw.SizedBox(height: 5 * pw.PdfPageFormat.mm),
          _profitCard(doc),
          pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
          _ownerCard(doc),
          pw.SizedBox(height: 4 * pw.PdfPageFormat.mm),
          _postingMapNote(doc),
        ],
      ),
    );
    return pdf;
  }

  // -------------------------------------------------------------------
  // الكتل
  // -------------------------------------------------------------------

  /// شريط الهوية العميق — مطابق لقالب تقرير الوردية.
  pw.Widget _brandBand(ProfitPrintDoc doc) {
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

  /// صف العنوان: «تقرير الأرباح والخسائر» يميناً + رقاقة الفترة يساراً.
  pw.Widget _titleRow(ProfitPrintDoc doc) {
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
                doc.periodLabel,
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

  /// شبكة البيانات: وقت الإنشاء يميناً، والعملة يساراً.
  pw.Widget _metaGrid(ProfitPrintDoc doc) {
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
              children: [_kvLine(doc.labels.currencyNote, '')],
            ),
          ),
          pw.SizedBox(width: 8 * pw.PdfPageFormat.mm),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [_kvLine(doc.labels.generatedAtLabel, '')],
            ),
          ),
        ],
      ),
    );
  }

  /// جدول البنود: [القيمة يساراً، البند أقصى اليمين] مع رؤوس الأقسام
  /// المظللة وقيم موقّعة ملوّنة (أخضر إسهام+/أحمر إسهام−).
  pw.Widget _linesTable(ProfitPrintDoc doc) {
    final rows = <pw.TableRow>[
      _tableRow(
        value: _cellText(
          doc.labels.valueCol,
          PrintText.head(color: PrintPalette.brandDeep, size: 9.5),
        ),
        item: _cellText(
          doc.labels.itemCol,
          PrintText.head(color: PrintPalette.brandDeep, size: 9.5),
          rtl: true,
        ),
        decoration: const pw.BoxDecoration(color: PrintPalette.tableHead),
      ),
    ];
    for (final section in doc.sections) {
      rows.add(
        _tableRow(
          value: _cellText('', PrintText.body(size: 4)),
          item: _cellText(
            section.title,
            PrintText.head(color: PrintPalette.brandDeep, size: 9.5),
            rtl: true,
          ),
          decoration: const pw.BoxDecoration(color: PrintPalette.zebra),
        ),
      );
      for (final line in section.lines) {
        final color = switch (line.tone) {
          ProfitLineTone.positive => _surplus,
          ProfitLineTone.negative => _deficit,
          ProfitLineTone.neutral => PrintPalette.brandDeep,
        };
        final style = line.strong
            ? PrintText.head(color: color, size: 9.5)
            : PrintText.body(color: color, size: 9.5);
        rows.add(
          _tableRow(
            value: _cellText(line.valueLabel, style),
            item: _cellText(
              line.itemLabel,
              line.strong
                  ? PrintText.head(color: PrintPalette.ink, size: 9.5)
                  : PrintText.body(color: PrintPalette.ink, size: 9.5),
              rtl: true,
            ),
            decoration: line.strong
                ? const pw.BoxDecoration(color: PrintPalette.zebra)
                : null,
          ),
        );
      }
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PrintPalette.rule, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: pw.FractionColumnWidth(1.15), // القيمة — رقمي
        1: pw.FractionColumnWidth(2.85), // البند — نص عربي
      },
      children: rows,
    );
  }

  /// بطاقة الربح البارزة — **لمسة ذهبية** وقيمة كبيرة ملوّنة بالإشارة.
  pw.Widget _profitCard(ProfitPrintDoc doc) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PrintPalette.gold, width: 1.1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            _fmtSigned(doc, doc.profit),
            style: PrintText.head(color: _toneColor(doc.profit), size: 14),
          ),
          pw.Text(
            doc.labels.profitLabel,
            style: PrintText.head(color: PrintPalette.brandDeep, size: 13),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  /// بطاقة الإغلاق: مسحوبات المالك ثم «صافي ما بقي للمالك» مؤكداً.
  pw.Widget _ownerCard(ProfitPrintDoc doc) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PrintPalette.rule, width: 0.7),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _kvLine(
            doc.labels.ownerDrawingsLabel,
            _fmtSigned(doc, -doc.ownerDrawings),
            size: 10.5,
          ),
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 4),
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            color: PrintPalette.tableHead,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  _fmtSigned(doc, doc.netForOwner),
                  style: PrintText.head(
                    color: _toneColor(doc.netForOwner),
                    size: 12.5,
                  ),
                ),
                pw.Text(
                  doc.labels.netForOwnerLabel,
                  style: PrintText.head(
                    color: PrintPalette.brandDeep,
                    size: 11.5,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// حاشية خريطة الترحيل — قيد الاشتقاق الحصري (ملحق و).
  pw.Widget _postingMapNote(ProfitPrintDoc doc) {
    return pw.Center(
      child: pw.Text(
        doc.labels.footerNote,
        style: PrintText.body(color: PrintPalette.inkSoft, size: 8),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  /// التذييل: شكر + نص المنشأة يميناً، ونسب التطبيق يساراً.
  pw.Widget _footerLine(ProfitPrintDoc doc) {
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

  pw.PdfColor _toneColor(double value) => value > 0.005
      ? _surplus
      : value < -0.005
      ? _deficit
      : PrintPalette.brandDeep;

  String _fmtSigned(ProfitPrintDoc doc, double value) {
    final magnitude = AmountText.format(value.abs(), doc.decimals);
    if (value > 0.005) return '+$magnitude';
    if (value < -0.005) return '−$magnitude';
    return magnitude;
  }

  /// خلية جدول نصية (قيمة يساراً/بند يميناً).
  pw.Widget _cellText(String text, pw.TextStyle style, {bool rtl = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4.5, vertical: 4),
      child: pw.Align(
        alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: style,
          textDirection: rtl ? pw.TextDirection.rtl : null,
        ),
      ),
    );
  }

  /// صف جدول: العمود ٠ = القيمة (يسار)، العمود ١ = البند (يمين).
  pw.TableRow _tableRow({
    required pw.Widget value,
    required pw.Widget item,
    pw.BoxDecoration? decoration,
  }) {
    return pw.TableRow(decoration: decoration, children: [value, item]);
  }

  /// سطر «تسمية يميناً» — عمود واحد ممتد (نمط بطاقات الوردية).
  pw.Widget _kvLine(String label, String value, {double size = 9.5}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.SizedBox()),
          pw.Text(
            value.isEmpty ? label : '$label: $value',
            style: PrintText.body(color: PrintPalette.inkSoft, size: size),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  String _monogram(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'ف' : trimmed.substring(0, 1);
  }
}

/// تاريخ للعرض `يوم/شهر/سنة` بأرقام جدولية.
String _fmtDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// تاريخ ووقت `يوم/شهر/سنة ساعة:دقيقة` بأرقام جدولية (نمط الوردية).
String _fmtDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_fmtDate(date)} $hour:$minute';
}
