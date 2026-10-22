/// مساقيط التقارير الجدولية للتصدير (V7-C — شاشات التقارير بهوية SIM):
/// دوال **نقية** تُسقط حالة كل نموذج تقرير (الأعمار/حركة صنف/ملخص
/// المخزون/المبيعات حسب/جدول الأرباح) في [ReportPrintDoc] العام — قيم
/// مسبقة التعريب والتنسيق (قاعدة print_docs: القالب بلا نص حرفي قابل
/// للترجمة؛ كل تسمية تُبنى هنا من l10n وكل رقم يصل سلسلة منسقة
/// بأرقام غربية بفواصل آلاف عبر `AmountText.format`).
///
/// مصدر «الآن» و«الفترة» و«المنشأة» **قيم صرفة من حالة النموذج الحية**
/// تُلتقط عند بناء الشريط (يعاد بناؤه مع كل تغيّر حالة) فلا سياق عبر
/// فجوة غير متزامنة عند النقر — نمط تقرير الوردية.
///
/// الأعمدة بترتيب منطقي عربي: **أول عمود بالقائمة = أقصى يمين الجدول**
/// (البنّاء يقلب الترتيب فيزيائيًا بنفسه). الأصفار ذات الدلالة الضعيفة
/// (دلاء أعمار صفرية/أعمدة تدفق صفرية) تُرسم «—» كنمط التقارير المحاسبية
/// المطبوعة؛ القيم الجوهرية تبقى أرقامًا دائمًا.
library;

import '../../../../../data/repositories/debt_aging_repository.dart';
import '../../../../../data/repositories/movement_reports_repository.dart';
import '../../../../../data/repositories/profit_report_repository.dart';
import '../../../../../domain/models/company.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../printing/docs/print_docs.dart';
import '../../../printing/docs/report_print_doc.dart';
import '../../view_models/movement_reports_state.dart';
import 'item_movement_format.dart';
import 'item_movement_tile.dart' show itemMovementTypeLabel;
import 'profit_report_format.dart' show profitReportPlainDate;

/// خلية فارغة بالمعنى المحاسبي (دلو صفري/عمود لا يُجمع) — كنمط
/// `shift_print_doc` مع البنود غير المنطبقة.
const String _dash = '—';

/// رأس المنشأة المطبوع — من `AppController.company` (نمط تقرير الوردية).
PrintHeader reportPrintHeaderOf(Company? company) => PrintHeader(
  name: company?.name ?? '',
  phone: company?.phone,
  address: company?.address,
  footerText: company?.footerText,
);

/// «يوم/شهر/سنة ساعة:دقيقة» بأرقام غربية — قيمة «تاريخ التقرير».
String reportNowText(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(now.day)}/${two(now.month)}/${now.year} '
      '${two(now.hour)}:${two(now.minute)}';
}

/// مدى الفترة كقيمة مطبوعة: «من X إلى Y» بتواريخ `يوم/شهر/سنة` غربية —
/// مفصولة بشرطة سفلية عريضة (تسمية «الفترة» نفسها يرسمها القالب من
/// `l10n.reportPdfPeriodLabel`).
String reportRangeText(DateTime from, DateTime to) =>
    '${profitReportPlainDate(from)} — ${profitReportPlainDate(to)}';

/// مبلغ منسق (فواصل آلاف + منازل العملة).
String _fmt(double value, int decimals) => AmountText.format(value, decimals);

/// مبلغ منسق بإشارته (+/− بأسلوب شاشة الأرباح؛ الصفر بلا إشارة).
String _fmtSigned(double value, int decimals) {
  if (value > 0.005) return '+${_fmt(value, decimals)}';
  if (value < -0.005) return '−${_fmt(value.abs(), decimals)}';
  return _fmt(0, decimals);
}

/// كمية موقعة (نمط شاشة الحركة) أو «—» للصفر.
String _qtyOrDash(double qty) => qty == 0 ? _dash : itemMovementQtyText(qty);

// ─────────────────────────────────────────────────────────────────────
// أعمار الديون (FR-09-05)
// ─────────────────────────────────────────────────────────────────────

/// مسقط تقرير الأعمار: الطرف + الشرائح الأربعة الملونة (أعمدتها) +
/// الرصيد، وصف الإجمالي العام بدلاء الملخص نفسها.
ReportPrintDoc buildAgingPrintDoc({
  required AppLocalizations l10n,
  required Company? company,
  required AgingReport report,
  required int decimals,
  DateTime? now,
}) {
  String cell(double value) => value == 0 ? _dash : _fmt(value, decimals);
  return ReportPrintDoc(
    header: reportPrintHeaderOf(company),
    title: l10n.agingTitle,
    periodLabel: l10n.reportPdfPeriodLabel,
    periodText: l10n.agingAsOfLabel(profitReportPlainDate(report.asOf)),
    dateLabel: l10n.reportPdfDateLabel,
    dateText: reportNowText(now ?? DateTime.now()),
    columns: [
      ReportColumnSpec(l10n.printingLblParty),
      ReportColumnSpec(l10n.agingBucket0to30, numeric: true),
      ReportColumnSpec(l10n.agingBucket31to60, numeric: true),
      ReportColumnSpec(l10n.agingBucket61to90, numeric: true),
      ReportColumnSpec(l10n.agingBucket90plus, numeric: true),
      ReportColumnSpec(l10n.printingLblGrandTotal, numeric: true),
    ],
    rows: [
      for (final row in report.rows)
        [
          row.name,
          cell(row.bucket0to30),
          cell(row.bucket31to60),
          cell(row.bucket61to90),
          cell(row.bucket90Plus),
          _fmt(row.total, decimals),
        ],
    ],
    totalRow: [
      l10n.agingTotalLabel,
      cell(report.total0to30),
      cell(report.total31to60),
      cell(report.total61to90),
      cell(report.total90Plus),
      _fmt(report.grandTotal, decimals),
    ],
    footerThanks: l10n.printingFooterThanks,
  );
}

// ─────────────────────────────────────────────────────────────────────
// حركة صنف (FR-09-03)
// ─────────────────────────────────────────────────────────────────────

/// مسقط حركة صنف: دفتر **تصاعدي زمني** (ترتيب حساب الباقي التراكمي —
/// عرف الدفاتر المطبوعة)، البيان = نوع الحركة + مرجعها، وصف الإجمالي
/// بوارد/صادر الفترة والباقي الختامي.
ReportPrintDoc buildItemMovementPrintDoc({
  required AppLocalizations l10n,
  required Company? company,
  required ItemMovementReport report,
  DateTime? now,
}) {
  final closing = report.rows.isEmpty
      ? report.openingBalance
      : report.rows.last.balanceAfter;
  final net = report.totalIn - report.totalOut;
  return ReportPrintDoc(
    header: reportPrintHeaderOf(company),
    title: '${l10n.itemMovementTitle} — ${report.name}',
    periodLabel: l10n.reportPdfPeriodLabel,
    periodText: reportRangeText(report.from, report.to),
    dateLabel: l10n.reportPdfDateLabel,
    dateText: reportNowText(now ?? DateTime.now()),
    columns: [
      ReportColumnSpec(l10n.printingLblDate),
      ReportColumnSpec(l10n.printingLblDescription),
      ReportColumnSpec(l10n.printingLblQty, numeric: true),
      ReportColumnSpec(l10n.itemMovementBalanceAfter, numeric: true),
    ],
    rows: [
      // رصيد ما قبل الفترة يفتح الدفتر (نمط كشف الحساب بالرصيد الماضي).
      [
        profitReportPlainDate(report.from),
        l10n.itemMovementOpening,
        _dash,
        itemMovementQtyPlain(report.openingBalance),
      ],
      for (final row in report.rows)
        [
          profitReportPlainDate(row.movedAt),
          (row.notes ?? '').trim().isEmpty
              ? itemMovementTypeLabel(l10n, row.movementType)
              : '${itemMovementTypeLabel(l10n, row.movementType)} · '
                    '${row.notes!.trim()}',
          _qtyOrDash(row.qty),
          itemMovementQtyPlain(row.balanceAfter),
        ],
    ],
    totalRow: [
      l10n.printingLblGrandTotal,
      '${l10n.itemMovementTotalIn} ${itemMovementQtyPlain(report.totalIn)}'
          ' · ${l10n.itemMovementTotalOut} '
          '${itemMovementQtyOut(report.totalOut)}',
      itemMovementQtyText(net),
      itemMovementQtyPlain(closing),
    ],
    footerThanks: l10n.printingFooterThanks,
  );
}

// ─────────────────────────────────────────────────────────────────────
// ملخص حركة المخزون (FR-09-04)
// ─────────────────────────────────────────────────────────────────────

/// مسقط ملخص المخزون: الصنف + أعمدة التدفق الأربعة الموقّعة + الرصيد
/// الختامي وقيمته بالتكلفة. صف الإجمالي يجمع **القيمة** حصرًا (مجموع
/// الكميات عبر أصناف وحدات مختلفة بلا معنى محاسبي — «—» صادقة).
ReportPrintDoc buildStockSummaryPrintDoc({
  required AppLocalizations l10n,
  required Company? company,
  required StockSummaryState state,
  DateTime? now,
}) {
  final rows = state.rows ?? const <StockSummaryRow>[];
  var totalValue = 0.0;
  for (final row in rows) {
    totalValue += row.valueAtCost;
  }
  return ReportPrintDoc(
    header: reportPrintHeaderOf(company),
    title: l10n.stockSummaryTitle,
    periodLabel: l10n.reportPdfPeriodLabel,
    periodText: reportRangeText(
      state.from ?? DateTime.now(),
      state.to ?? DateTime.now(),
    ),
    dateLabel: l10n.reportPdfDateLabel,
    dateText: reportNowText(now ?? DateTime.now()),
    columns: [
      ReportColumnSpec(l10n.printingLblItem),
      ReportColumnSpec(l10n.stockSummaryQtyIn, numeric: true),
      ReportColumnSpec(l10n.stockSummaryQtyOut, numeric: true),
      ReportColumnSpec(l10n.stockSummaryQtyReturns, numeric: true),
      ReportColumnSpec(l10n.stockSummaryQtyAdjust, numeric: true),
      ReportColumnSpec(l10n.stockSummaryEndBalance, numeric: true),
      ReportColumnSpec(l10n.shiftPrintValueCol, numeric: true),
    ],
    rows: [
      for (final row in rows)
        [
          row.name,
          _qtyOrDash(row.qtyIn),
          _qtyOrDash(-row.qtyOut),
          _qtyOrDash(row.qtyReturns),
          _qtyOrDash(row.qtyAdjustNet),
          itemMovementQtyPlain(row.endBalance),
          _fmt(row.valueAtCost, state.decimals),
        ],
    ],
    totalRow: [
      l10n.stockSummaryTotalItems(rows.length),
      _dash,
      _dash,
      _dash,
      _dash,
      _dash,
      _fmt(totalValue, state.decimals),
    ],
    footerThanks: l10n.printingFooterThanks,
  );
}

// ─────────────────────────────────────────────────────────────────────
// المبيعات حسب (FR-09-06)
// ─────────────────────────────────────────────────────────────────────

/// مسقط المبيعات حسب: تسمية البعد (عمودها الأول بعنوان البعد الجاري) +
/// المبلغ بالعملة الأساسية، وصف الإجمالي بمجموع الفترة.
ReportPrintDoc buildSalesByPrintDoc({
  required AppLocalizations l10n,
  required Company? company,
  required SalesByState state,
  DateTime? now,
}) {
  final rows = state.rows ?? const <SalesByRow>[];
  String labelOf(SalesByRow row) {
    if (row.label.isEmpty) {
      return state.dimension == SalesByDimension.customer
          ? l10n.salesByNoCustomer
          : l10n.salesByUncategorized;
    }
    if (state.dimension == SalesByDimension.day) {
      final day = DateTime.tryParse(row.label);
      if (day != null) return profitReportPlainDate(day);
    }
    return row.label;
  }

  var total = 0.0;
  for (final row in rows) {
    total += row.salesBase;
  }
  return ReportPrintDoc(
    header: reportPrintHeaderOf(company),
    title: l10n.salesByTitle,
    periodLabel: l10n.reportPdfPeriodLabel,
    periodText: reportRangeText(
      state.from ?? DateTime.now(),
      state.to ?? DateTime.now(),
    ),
    dateLabel: l10n.reportPdfDateLabel,
    dateText: reportNowText(now ?? DateTime.now()),
    columns: [
      ReportColumnSpec(_dimensionHeader(l10n, state.dimension)),
      ReportColumnSpec(l10n.printingLblAmount, numeric: true),
    ],
    rows: [
      for (final row in rows)
        [labelOf(row), _fmt(row.salesBase, state.decimals)],
    ],
    totalRow: [l10n.salesByTotal, _fmt(total, state.decimals)],
    footerThanks: l10n.printingFooterThanks,
  );
}

String _dimensionHeader(AppLocalizations l10n, SalesByDimension dimension) =>
    switch (dimension) {
      SalesByDimension.customer => l10n.salesByCustomer,
      SalesByDimension.category => l10n.salesByCategory,
      SalesByDimension.item => l10n.salesByItem,
      SalesByDimension.day => l10n.salesByDay,
    };

// ─────────────────────────────────────────────────────────────────────
// جدول الأرباح (لصورة/تفوق شاشة الأرباح — V7-C)
// ─────────────────────────────────────────────────────────────────────

/// مسقط جدول الأرباح والخسائر: **موجّه للصورة والتفوق** — زر PDF
/// بالشاشة يستهلك بانيها الغني القائم (قرار نقد V7: لا يُستبدل
/// بالعام)، فهذان الزران يحتاجان مسقطًا جدوليًا عامًا بنفس بنود
/// بطاقة الشاشة (الإيراد/التكلفة/التسويات/المصاريف + الرصيد الذهبي).
ReportPrintDoc buildProfitTableDoc({
  required AppLocalizations l10n,
  required Company? company,
  required ProfitReport report,
  required int decimals,
  DateTime? now,
}) {
  return ReportPrintDoc(
    header: reportPrintHeaderOf(company),
    title: l10n.profitPdfTitle,
    periodLabel: l10n.reportPdfPeriodLabel,
    periodText: reportRangeText(report.from, report.to),
    dateLabel: l10n.reportPdfDateLabel,
    dateText: reportNowText(now ?? DateTime.now()),
    columns: [
      ReportColumnSpec(l10n.profitPrintItemCol),
      ReportColumnSpec(l10n.profitPrintValueCol, numeric: true),
    ],
    rows: [
      [l10n.profitSales, _fmtSigned(report.sales, decimals)],
      [l10n.profitSalesReturns, _fmtSigned(-report.salesReturns, decimals)],
      [l10n.profitNetSales, _fmtSigned(report.netSales, decimals)],
      [l10n.profitCogs, _fmtSigned(-report.cogs, decimals)],
      [l10n.profitReturnCost, _fmtSigned(report.returnCost, decimals)],
      [l10n.profitNetCogs, _fmtSigned(-report.netCogs, decimals)],
      [l10n.profitStockSurplus, _fmtSigned(report.stockSurplus, decimals)],
      [l10n.profitStockShortage, _fmtSigned(-report.stockShortage, decimals)],
      [l10n.profitFx, _fmtSigned(report.fxGainLoss, decimals)],
      [l10n.profitExpenses, _fmtSigned(-report.expenses, decimals)],
      [l10n.profitOwnerDrawings, _fmtSigned(-report.ownerDrawings, decimals)],
      [l10n.profitNetForOwner, _fmtSigned(report.netForOwner, decimals)],
    ],
    totalRow: [l10n.profitTotal, _fmtSigned(report.profit, decimals)],
    footerThanks: l10n.printingFooterThanks,
  );
}
