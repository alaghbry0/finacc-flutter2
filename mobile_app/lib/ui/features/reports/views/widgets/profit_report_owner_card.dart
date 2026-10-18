/// بطاقة الإغلاق «صافي ما بقي للمالك» بتقرير الأرباح — مستخرجة حرفياً
/// من `profit_report_screen.dart` (R20-D3d؛ كانت `_NetForOwnerCard`).
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/profit_report_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/profit_report_view_model.dart';
import 'profit_report_format.dart';

/// سطر الإغلاق: «صافي ما بقي للمالك» — بطاقة مؤكدة متباينة بالاتجاه.
class ProfitReportOwnerCard extends StatelessWidget {
  const ProfitReportOwnerCard({
    super.key,
    required this.state,
    required this.report,
  });

  final ProfitReportState state;
  final ProfitReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final isNegative = report.netForOwner < 0;
    return FinCard(
      key: const Key('profit_owner_card'),
      accent: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.all(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isNegative
              ? colors.negativeContainer
              : colors.positiveContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.profitNetForOwner,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isNegative
                      ? colors.onNegativeContainer
                      : colors.onPositiveContainer,
                ),
              ),
            ),
            AmountText(
              amount: report.netForOwner.abs(),
              sign: profitReportSignOf(report.netForOwner),
              size: AmountSize.large,
              decimals: state.decimals,
            ),
          ],
        ),
      ),
    );
  }
}
