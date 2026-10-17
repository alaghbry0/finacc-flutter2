/// خط الإجماليات الحي للكاشير — المجموع/خصم الأسطر/خصم الرأس/الصافي
/// (§6.5).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';

/// خط الإجماليات الحي — المجموع/خصم الأسطر/خصم الرأس/الصافي (§6.5).
class CartTotalsPanel extends StatelessWidget {
  const CartTotalsPanel({
    super.key,
    required this.totals,
    required this.currencyCode,
  });

  final CartTotals totals;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final decimals = totals.grandTotal == totals.grandTotal.truncateToDouble()
        ? 0
        : 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TotalsRow(
          label: l10n.sellTotalsSubtotal,
          value: totals.subtotal,
          decimals: decimals,
        ),
        if (totals.lineDiscountsTotal > 0)
          _TotalsRow(
            label: l10n.sellTotalsLineDiscounts,
            value: totals.lineDiscountsTotal,
            decimals: decimals,
            color: colors.negative,
            sign: FinSign.outgoing,
          ),
        if (totals.invoiceDiscount > 0)
          _TotalsRow(
            label: l10n.sellTotalsInvoiceDiscount,
            value: totals.invoiceDiscount,
            decimals: decimals,
            color: colors.negative,
            sign: FinSign.outgoing,
          ),
        Divider(
          height: 18,
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.sellTotalsGrandTotal,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            AmountText(
              amount: totals.grandTotal,
              size: AmountSize.large,
              decimals: decimals,
            ),
          ],
        ),
      ],
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.label,
    required this.value,
    required this.decimals,
    this.color,
    this.sign = FinSign.neutral,
  });

  final String label;
  final double value;
  final int decimals;
  final Color? color;
  final FinSign sign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          AmountText(amount: value, sign: sign, decimals: decimals),
        ],
      ),
    );
  }
}
