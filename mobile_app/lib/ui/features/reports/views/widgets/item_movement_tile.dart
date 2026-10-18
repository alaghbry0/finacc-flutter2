/// صف حركة واحدة بتقرير حركة صنف (R19-D3a — مستخرج حرفياً من
/// `item_movement_screen.dart` بلا أي تغيير دلالة؛ كان `_MovementTile`
/// و`_MovementTypeChip` وفئة الاتجاه وتسمية النوع).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../data/repositories/movement_reports_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/fin_date_text.dart';
import 'item_movement_format.dart';

/// صف حركة واحد: رقاقة النوع + التاريخ + الكمية الموقّعة + شارة الباقي
/// التراكمي + تكلفة الوحدة والملاحظات.
class ItemMovementTile extends StatelessWidget {
  const ItemMovementTile({
    super.key,
    required this.row,
    required this.decimals,
  });

  final ItemMovementRow row;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final category = itemMovementCategoryOf(row.movementType);

    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ItemMovementTypeChip(type: row.movementType, category: category),
              const Spacer(),
              // شارة الباقي التراكمي — العلامة المميزة للبطاقة (FR-09-03).
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.itemMovementBalanceAfter,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        itemMovementQtyText(row.balanceAfter)
                            .replaceFirst('+', ''),
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  FinDateText.dateTime(context, row.movedAt),
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  itemMovementQtyText(row.qty),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: switch (category) {
                      ItemMovementCategory.inbound => colors.positive,
                      ItemMovementCategory.outbound => colors.negative,
                      ItemMovementCategory.returns => scheme.primary,
                      ItemMovementCategory.adjust => colors.warning,
                    },
                  ),
                ),
              ),
            ],
          ),
          if (row.notes != null && row.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              row.notes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.itemMovementUnitCost,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 4),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  AmountText.format(row.unitCost, decimals),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// فئة اتجاه الحركة — تقرّب لون الرقاقة (لا تستبدل تسمية النوع).
enum ItemMovementCategory { inbound, outbound, returns, adjust }

ItemMovementCategory itemMovementCategoryOf(String type) => switch (type) {
  'purchase' || 'opening' || 'transfer_in' => ItemMovementCategory.inbound,
  'sale' ||
  'purchase_return' ||
  'transfer_out' => ItemMovementCategory.outbound,
  'sale_return' => ItemMovementCategory.returns,
  _ => ItemMovementCategory.adjust,
};

/// رقاقة نوع الحركة — تسمية النوع ملوّنة بفئة الاتجاه (وارد أخضر /
/// صادر أحمر / مرتجع تيل / تسوية ذهبي-دافئ).
class ItemMovementTypeChip extends StatelessWidget {
  const ItemMovementTypeChip({
    super.key,
    required this.type,
    required this.category,
  });

  final String type;
  final ItemMovementCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final (bg, fg) = switch (category) {
      ItemMovementCategory.inbound => (
        colors.positiveContainer,
        colors.onPositiveContainer,
      ),
      ItemMovementCategory.outbound => (
        colors.negativeContainer,
        colors.onNegativeContainer,
      ),
      // التيل البراندي للمرتجعات (بذرة Deep Teal — §6.1).
      ItemMovementCategory.returns => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      // الزوج الدافئ الذهبي للتسويات (لا زوج نصي ذهبي في DS).
      ItemMovementCategory.adjust => (
        colors.warningContainer,
        colors.onWarningContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        itemMovementTypeLabel(l10n, type),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// تسمية نوع الحركة — مفاتيح movementType* الجديدة، واليدوي/المجهول
/// على مفتاحين قديمين موجودين أصلاً (itemMovementManualAdjust/Unknown).
String itemMovementTypeLabel(AppLocalizations l10n, String type) =>
    switch (type) {
      'purchase' => l10n.movementTypePurchase,
      'sale' => l10n.movementTypeSale,
      'sale_return' => l10n.movementTypeSaleReturn,
      'purchase_return' => l10n.movementTypePurchaseReturn,
      'stocktake_adjust' => l10n.movementTypeAdjust,
      'opening' => l10n.movementTypeOpening,
      'transfer_in' => l10n.movementTypeTransferIn,
      'transfer_out' => l10n.movementTypeTransferOut,
      'manual_adjust' => l10n.itemMovementManualAdjust,
      _ => l10n.itemMovementUnknown,
    };
