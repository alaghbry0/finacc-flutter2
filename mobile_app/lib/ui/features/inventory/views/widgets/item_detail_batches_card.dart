/// بطاقة الدفعات — مرتبة FEFO مع رقائق أيام ملونة وكميات.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/fin_section_title.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../view_models/item_detail_view_model.dart';
import 'inventory_widgets.dart';
import 'item_detail_format.dart';

class ItemDetailBatchesCard extends StatelessWidget {
  const ItemDetailBatchesCard({super.key, required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final arabicIndic = NumeralsScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(
          icon: Icons.layers_rounded,
          title: l10n.itemDetailBatchesSection,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: state.batches.isEmpty
              ? Text(
                  l10n.itemDetailNoBatches,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                )
              : Column(
                  children: [
                    for (final batch in state.batches)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.layers_rounded,
                                size: 17,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MonoText(
                                    batch.batchNumber,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    itemDetailFormatDate(
                                      batch.expiryDate,
                                      arabicIndic,
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 5),
                                  ExpiryDaysChip(days: batch.daysToExpiry),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                AmountText(amount: batch.qty, decimals: 0),
                                Text(
                                  l10n.batchesQtyLabel,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
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
}
