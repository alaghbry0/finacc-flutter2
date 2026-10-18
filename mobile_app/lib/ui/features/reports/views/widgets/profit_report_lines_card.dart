/// بطاقة بنود تقرير الأرباح — مستخرجة حرفياً من
/// `profit_report_screen.dart` (R20-D3d؛ كانت `_LinesCard` بطريقتها
/// الخاصة `_countChip`).
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/profit_report_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/profit_report_view_model.dart';
import 'profit_report_format.dart';
import 'profit_report_rows.dart';

/// بطاقة البنود: أقسام الإيراد/التكلفة/التسويات/المصاريف — كل سطر
/// بمقداره (بالعملة الأساسية) وإشارته الملوّنة بدلالة إسهامه في الربح.
class ProfitReportLinesCard extends StatelessWidget {
  const ProfitReportLinesCard({
    super.key,
    required this.state,
    required this.report,
  });

  final ProfitReportState state;
  final ProfitReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final decimals = state.decimals;
    return FinCard(
      key: const Key('profit_lines_card'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfitReportSectionLabel(label: l10n.profitSectionRevenue),
          ProfitReportRow(
            label: l10n.profitSales,
            amount: report.sales,
            sign: FinSign.incoming,
            decimals: decimals,
            trailing: _countChip(context, l10n, report.salesInvoiceCount),
          ),
          ProfitReportRow(
            label: l10n.profitSalesReturns,
            amount: report.salesReturns,
            sign: report.salesReturns > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: decimals,
            trailing: _countChip(context, l10n, report.returnInvoiceCount),
          ),
          ProfitReportRow(
            label: l10n.profitNetSales,
            amount: report.netSales,
            sign: profitReportSignOf(report.netSales),
            decimals: decimals,
            strong: true,
          ),
          const SizedBox(height: 12),
          ProfitReportSectionLabel(label: l10n.profitSectionCost),
          ProfitReportRow(
            label: l10n.profitCogs,
            amount: report.cogs,
            sign: report.cogs > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: decimals,
          ),
          ProfitReportRow(
            label: l10n.profitReturnCost,
            amount: report.returnCost,
            sign: profitReportSignOf(report.returnCost),
            decimals: decimals,
          ),
          ProfitReportRow(
            label: l10n.profitNetCogs,
            amount: report.netCogs,
            sign: report.netCogs > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: decimals,
            strong: true,
          ),
          const SizedBox(height: 12),
          ProfitReportSectionLabel(label: l10n.profitSectionAdjustments),
          ProfitReportRow(
            label: l10n.profitStockSurplus,
            amount: report.stockSurplus,
            sign: profitReportSignOf(report.stockSurplus),
            decimals: decimals,
          ),
          ProfitReportRow(
            label: l10n.profitStockShortage,
            amount: report.stockShortage,
            sign: report.stockShortage > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: decimals,
          ),
          ProfitReportRow(
            label: l10n.profitFx,
            amount: report.fxGainLoss,
            sign: profitReportSignOf(report.fxGainLoss),
            decimals: decimals,
          ),
          const SizedBox(height: 12),
          ProfitReportSectionLabel(label: l10n.profitSectionExpenses),
          ProfitReportRow(
            label: l10n.profitExpenses,
            amount: report.expenses,
            sign: report.expenses > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: decimals,
          ),
          const SizedBox(height: 4),
          Text(
            state.currencyCode.isEmpty
                ? l10n.profitBaseCurrencyNote
                : '${l10n.profitBaseCurrencyNote} · ${state.currencyCode}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// شريحة عدد الفواتير الصغيرة (تفصيل رخيص من المستودع).
  Widget _countChip(BuildContext context, AppLocalizations l10n, int count) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Text(
        l10n.profitInvoicesCount(count),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
