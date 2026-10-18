/// بطاقة الربح البارزة بتقرير الأرباح — مستخرجة حرفياً من
/// `profit_report_screen.dart` (R20-D3d؛ كانت `_ProfitCard`).
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/profit_report_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/profit_report_view_model.dart';
import 'profit_report_format.dart';

/// بطاقة الربح البارزة — شريط ذهبي وقيمة عرض كبيرة بإشارة ملوّنة.
class ProfitReportTotalCard extends StatelessWidget {
  const ProfitReportTotalCard({
    super.key,
    required this.state,
    required this.report,
  });

  final ProfitReportState state;
  final ProfitReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FinCard(
      key: const Key('profit_total_card'),
      accent: FinColors.of(context).gold,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.profitTotal,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          AmountText(
            amount: report.profit.abs(),
            sign: profitReportSignOf(report.profit),
            size: AmountSize.display,
            decimals: state.decimals,
          ),
        ],
      ),
    );
  }
}
