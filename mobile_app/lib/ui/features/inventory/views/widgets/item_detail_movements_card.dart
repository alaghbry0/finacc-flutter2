/// بطاقة الحركات — نوع + كمية موقَّعة + رصيد بعدها + تاريخ.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/fin_section_title.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/item_detail_view_model.dart';
import 'item_detail_format.dart';

class ItemDetailMovementsCard extends StatelessWidget {
  const ItemDetailMovementsCard({super.key, required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final arabicIndic = NumeralsScope.of(context);
    final movements = state.detail!.recentMovements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(
          icon: Icons.receipt_long_rounded,
          title: l10n.itemDetailMovementsSection,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: movements.isEmpty
              ? Text(
                  l10n.itemDetailNoMovements,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                )
              : Column(
                  children: [
                    for (final movement in movements)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            StatusChip(
                              label: _movementLabel(
                                l10n,
                                movement.movementType,
                              ),
                              tone: movement.qty >= 0
                                  ? ChipTone.positive
                                  : ChipTone.negative,
                              dense: true,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: AmountText(
                                          amount: movement.qty.abs(),
                                          sign: movement.qty >= 0
                                              ? FinSign.incoming
                                              : FinSign.outgoing,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${l10n.itemDetailRemainingLabel}: ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                      Flexible(
                                        child: Builder(
                                          builder: (context) {
                                            final remaining =
                                                movement.remainingAfter ?? 0;
                                            final decimals =
                                                remaining ==
                                                    remaining.truncateToDouble()
                                                ? 0
                                                : 2;
                                            return Text(
                                              AmountText.formatFor(
                                                context,
                                                remaining,
                                                decimals,
                                              ),
                                              style: FinText.amountRow(
                                                scheme.onSurfaceVariant,
                                              ).copyWith(fontSize: 13),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    itemDetailFormatDate(
                                      movement.movedAt.toLocal(),
                                      arabicIndic,
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: colors.gold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  static String _movementLabel(AppLocalizations l10n, String type) =>
      switch (type) {
        'opening' => l10n.itemMovementOpening,
        'purchase' => l10n.itemMovementPurchase,
        'sale' => l10n.itemMovementSale,
        'sale_return' => l10n.itemMovementSaleReturn,
        'purchase_return' => l10n.itemMovementPurchaseReturn,
        'stocktake_adjust' => l10n.itemMovementStocktakeAdjust,
        'manual_adjust' => l10n.itemMovementManualAdjust,
        'transfer_in' => l10n.itemMovementTransferIn,
        'transfer_out' => l10n.itemMovementTransferOut,
        _ => l10n.itemMovementUnknown,
      };
}
