/// مسقط تقرير الأرباح للطباعة (نمط print_docs): كل الأنواع النقية
/// وجامع التسميات المسبقة التعريب — مستخرجة من profit_report_pdf_builder
/// (R19-D3d: نقل حرفي بلا أي تغيير سلوكي؛ يُصدَّر من ملف البنّاء فبقيت
/// استيرادات المستدعين كما هي).
///
/// بنية المستند: شريط هوية المنشأة ← صف العنوان («تقرير الأرباح
/// والخسائر» يميناً ورقاقة الفترة يساراً) ← شبكة البيانات (الفترة/
/// وقت الإنشاء/العملة) ← جدول البنود بأعمدة [القيمة، البند] فيزيائياً
/// يسار→يمين فيقع البند أقصى اليمين مع أقسام مظللة (الإيراد/التكلفة/
/// التسويات/المصاريف) وقيم موقّعة ملوّنة (أخضر إسهام+/أحمر إسهام−) ←
/// **بطاقة الربح البارزة بلمسة ذهبية** ← بطاقة الإغلاق (المسحوبات ثم
/// «صافي ما بقي للمالك») ← حاشية «مُشتق حصراً من خريطة الترحيل
/// (ملحق و)» ← تذييل.
library;

import '../../../../data/repositories/profit_report_repository.dart';
import '../../../../domain/models/company.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/amount_text.dart';
import '../docs/print_docs.dart';

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
