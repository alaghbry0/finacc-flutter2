/// قسم سجل عمليات الجرد — الأحدث أولاً بفرق ملوّن.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../data/repositories/stocktake_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/stocktake_view_model.dart';
import 'stocktake_format.dart';

class StocktakeHistorySection extends StatelessWidget {
  const StocktakeHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final history = vm.state.history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.stocktakeHistoryTitle),
        if (history.isEmpty)
          EmptyState(
            icon: Icons.history_rounded,
            title: l10n.stocktakeHistoryTitle,
            message: l10n.stocktakeHistoryEmpty,
            compact: true,
          )
        else
          for (final row in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryCard(row: row),
            ),
      ],
    );
  }
}

/// بطاقة جرد واحد في السجل — التاريخ + عدد البنود + الصافي الملوّن +
/// الملاحظات (باسم الجانِد).
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.row});

  final StocktakeHistoryRow row;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StocktakeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final decimals = vm.state.baseCurrencyDecimals;
    final counted = stocktakeTryParseIso(row.countedAt)?.toLocal();
    final net = row.totalDiff;
    final netSign = net > 0.005
        ? FinSign.incoming
        : net < -0.005
        ? FinSign.outgoing
        : FinSign.neutral;

    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  counted == null ? '—' : stocktakeFormatDate(counted),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ),
              Text(
                l10n.stocktakeHistoryLines(row.linesCount),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  row.notes ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AmountText(amount: net.abs(), decimals: decimals, sign: netSign),
            ],
          ),
        ],
      ),
    );
  }
}
