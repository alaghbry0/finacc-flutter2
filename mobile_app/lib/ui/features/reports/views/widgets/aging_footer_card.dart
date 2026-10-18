/// تذييل إجماليات تقرير أعمار الديون (R19-D3a — مستخرج حرفياً من
/// `aging_report_screen.dart` بلا أي تغيير دلالة؛ كان `_FooterCard`).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../data/repositories/debt_aging_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import 'aging_currency_pill.dart';

/// تذييل الإجماليات — الإجمالي العام بعملة التقرير وعدد المدينين.
class AgingFooterCard extends StatelessWidget {
  const AgingFooterCard({
    super.key,
    required this.report,
    required this.decimals,
  });

  final AgingReport report;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.functions_rounded, size: 18, color: colors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.agingTotalLabel,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText(
                amount: report.grandTotal,
                decimals: decimals,
                size: AmountSize.large,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.agingCustomersCount(report.customersCount),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(width: 8),
          AgingCurrencyPill(code: report.currencyCode, accent: colors.gold),
        ],
      ),
    );
  }
}
