/// بطاقة الأسعار — رقاقة لكل عملة (رمز + مبلغ بمنازل العملة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/fin_section_title.dart';
import '../../view_models/item_detail_view_model.dart';

class ItemDetailPricesCard extends StatelessWidget {
  const ItemDetailPricesCard({super.key, required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final prices = state.detail!.prices
        .where((line) => line.priceLevel == 'retail')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(
          icon: Icons.sell_rounded,
          title: l10n.itemDetailPricesSection,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: prices.isEmpty
              ? Text(
                  '—',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final line in prices)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.gold.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.gold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              line.currencyCode,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            AmountText(
                              amount: line.price,
                              decimals: state.decimalsFor(line.currencyId),
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
