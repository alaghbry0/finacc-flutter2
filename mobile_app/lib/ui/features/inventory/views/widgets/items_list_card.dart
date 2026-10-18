/// بطاقة صنف واحدة بقائمة الأصناف (باركود أحادي، كمية ملونة عند قرب
/// النفاد، سعر القاعدة، شارة خدمي/دفعات) — مستخرجة من items_list_screen
/// (R20-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../domain/models/item.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import 'inventory_widgets.dart';

/// بطاقة صنف واحدة.
class ItemsListCard extends StatelessWidget {
  const ItemsListCard({
    super.key,
    required this.info,
    required this.baseDecimals,
  });

  final ItemStockInfo info;
  final int baseDecimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final item = info.item;

    final lowStock =
        !item.isService &&
        (info.totalQty <= 0 || info.totalQty <= item.minStock);
    final qtyColor = lowStock ? colors.negative : scheme.onSurface;

    return FinCard(
      onTap: () => context.go('/inventory/item/${item.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (item.isService ? scheme.tertiary : scheme.primary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.isService
                  ? Icons.miscellaneous_services_rounded
                  : Icons.inventory_2_rounded,
              size: 21,
              color: item.isService ? scheme.tertiary : scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  MonoText(
                    item.barcode!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (item.isService)
                      StatusChip(
                        label: l10n.itemServiceBadge,
                        tone: ChipTone.brand,
                        dense: true,
                      ),
                    if (item.trackBatches)
                      StatusChip(
                        label: l10n.itemBatchesBadge,
                        icon: Icons.layers_rounded,
                        dense: true,
                      ),
                    if (!item.isService && info.totalQty <= 0)
                      StatusChip(
                        label: l10n.itemsListOutOfStockBadge,
                        tone: ChipTone.negative,
                        dense: true,
                      )
                    else if (lowStock && item.minStock > 0)
                      StatusChip(
                        label: l10n.itemsListLowStockBadge,
                        tone: ChipTone.warning,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _TrailingNumbers(
            info: info,
            qtyColor: qtyColor,
            baseDecimals: baseDecimals,
          ),
        ],
      ),
    );
  }
}

/// عمود الأرقام الطرفي — الكمية والسعر بالعملة الأساسية.
class _TrailingNumbers extends StatelessWidget {
  const _TrailingNumbers({
    required this.info,
    required this.qtyColor,
    required this.baseDecimals,
  });

  final ItemStockInfo info;
  final Color qtyColor;
  final int baseDecimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    if (info.item.isService) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(
            Icons.miscellaneous_services_rounded,
            size: 20,
            color: scheme.tertiary,
          ),
          const SizedBox(height: 2),
          Text(
            l10n.itemServiceBadge,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // الكمية — حمراء عند قرب النفاد/النفاد (نفس كومة نمط AmountText).
        Text(
          AmountText.formatFor(
            context,
            info.totalQty,
            _qtyDecimals(info.totalQty),
          ),
          style: FinText.amountRow(qtyColor),
        ),
        Text(
          l10n.itemsListStockLabel,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (info.retailPrice != null) ...[
          const SizedBox(height: 8),
          AmountText(amount: info.retailPrice!, decimals: baseDecimals),
          Text(
            l10n.itemsListPriceLabel,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: colors.gold, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  static int _qtyDecimals(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}
