/// بطاقة المخزون — الإجمالي + حد الطلب بمؤشر تقدم ملون + توزيع المخازن.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/fin_section_title.dart';
import '../../view_models/item_detail_view_model.dart';

class ItemDetailStockCard extends StatelessWidget {
  const ItemDetailStockCard({super.key, required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final detail = state.detail!;
    final item = detail.item;
    final total = detail.totalQty;

    final progressColor = total <= 0
        ? colors.negative
        : (total <= item.minStock ? colors.warning : colors.positive);
    final ratio = item.minStock <= 0
        ? (total > 0 ? 1.0 : 0.0)
        : (total / item.minStock).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(
          icon: Icons.inventory_rounded,
          title: l10n.itemDetailStockSection,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.itemDetailTotalLabel,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        AmountText(
                          amount: total,
                          size: AmountSize.large,
                          decimals: total == total.truncateToDouble() ? 0 : 2,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.itemDetailMinStockLabel,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 2),
                      AmountText(
                        amount: item.minStock,
                        decimals:
                            item.minStock == item.minStock.truncateToDouble()
                            ? 0
                            : 2,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    color: progressColor,
                  ),
                ),
              ),
              if (detail.stockByWarehouse.isNotEmpty) ...[
                const SizedBox(height: 14),
                Divider(
                  color: Theme.of(context).colorScheme.outlineVariant
                      .withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                for (final warehouse in detail.stockByWarehouse)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.store_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            warehouse.warehouseName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        AmountText(amount: warehouse.qty, decimals: 0),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
