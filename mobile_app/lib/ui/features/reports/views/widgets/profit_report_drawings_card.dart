/// بطاقة مسحوبات المالك بتقرير الأرباح — مستخرجة حرفياً من
/// `profit_report_screen.dart` (R20-D3d؛ كانت `_DrawingsCard`).
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/profit_report_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/profit_report_view_model.dart';

/// مسحوبات المالك — بند مستقل خارج المصاريف (تقديم خافت).
class ProfitReportDrawingsCard extends StatelessWidget {
  const ProfitReportDrawingsCard({
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
    return FinCard(
      key: const Key('profit_drawings_card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.profitOwnerSection,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          AmountText(
            amount: report.ownerDrawings,
            sign: report.ownerDrawings > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: state.decimals,
          ),
        ],
      ),
    );
  }
}
