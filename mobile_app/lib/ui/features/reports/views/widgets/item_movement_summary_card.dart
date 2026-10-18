/// رأس تقرير حركة صنف (R19-D3a — مستخرج حرفياً من `item_movement_screen.dart`
/// بلا أي تغيير دلالة؛ كان `_SummaryCard` و`_StatCell`).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../data/repositories/movement_reports_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/movement_reports_view_model.dart';
import 'item_movement_format.dart';

/// رأس التقرير: الصنف + رصيد ما قبل الفترة + إجماليا الوارد/الصادر +
/// التكلفة الحالية للوحدة + عدد الحركات.
class ItemMovementSummaryCard extends StatelessWidget {
  const ItemMovementSummaryCard({
    super.key,
    required this.state,
    required this.report,
    required this.onPick,
  });

  final ItemMovementState state;
  final ItemMovementReport report;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final decimals = state.decimals;

    return FinCard(
      accent: colors.gold,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 20,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  key: const Key('itemMovement_product_name'),
                  report.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l10n.itemMovementChangeProduct,
                icon: const Icon(Icons.swap_horiz_rounded),
                onPressed: onPick,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ItemMovementStatCell(
                  label: l10n.itemMovementOpeningBalance,
                  value: itemMovementQtyPlain(report.openingBalance),
                ),
              ),
              Expanded(
                child: ItemMovementStatCell(
                  label: l10n.itemMovementTotalIn,
                  value: itemMovementQtyText(report.totalIn),
                  color: colors.positive,
                ),
              ),
              Expanded(
                child: ItemMovementStatCell(
                  label: l10n.itemMovementTotalOut,
                  value: itemMovementQtyOut(report.totalOut),
                  color: colors.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.payments_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.itemMovementWacNow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              AmountText(amount: report.unitCostNow, decimals: decimals),
              if (state.currencyCode.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  state.currencyCode,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.gold),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.itemMovementMovementCount(report.rows.length),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// خلية إحصاء صغيرة (تسمية فوق قيمة).
class ItemMovementStatCell extends StatelessWidget {
  const ItemMovementStatCell({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color ?? scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
