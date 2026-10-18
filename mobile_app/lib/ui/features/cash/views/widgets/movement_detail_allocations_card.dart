/// بطاقة تخصيصات حركة الصندوق (الفواتير المسددة/المخصصة) — مستخرجة
/// حرفياً من `movement_detail_sheet.dart` (R20-D3d؛ كان جسم بطاقة
/// التخصيصات).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';

/// بطاقة التخصيصات: رقم الفاتورة + نوعها + المبلغ المخصص بعملته.
class MovementDetailAllocationsCard extends StatelessWidget {
  const MovementDetailAllocationsCard({super.key, required this.allocations});

  final List<CashAllocationLine> allocations;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.cashMovementAllocationsTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          for (final allocation in allocations)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allocation.invoiceNo,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: FinText.tabularNums,
                              ),
                        ),
                        Text(
                          allocation.invoiceTypeCode == 'sale'
                              ? l10n.cashAllocSaleInvoice
                              : l10n.cashAllocPurchaseInvoice,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  AmountText(
                    amount: allocation.allocatedAmount,
                    showSignMarker: false,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    allocation.currencyCode,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
