/// صفوف تفاصيل عرض السعر (معلومة/مبلغ/شريحة الفاتورة المحوَّلة) —
/// مستخرجة من quotation_detail_screen (R20-D3b: نقل حرفي بلا أي تغيير
/// سلوكي).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';

class QuotationInfoRow extends StatelessWidget {
  const QuotationInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          // درع الفيض: القيمة الطويلة تُقتطع بلطف بدل فيض الصف.
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class QuotationAmountRow extends StatelessWidget {
  const QuotationAmountRow({
    super.key,
    required this.label,
    required this.value,
    this.sign = FinSign.neutral,
  });

  final String label;
  final double value;
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
          AmountText(
            amount: value,
            sign: sign,
            decimals: value == value.truncateToDouble() ? 0 : 2,
          ),
        ],
      ),
    );
  }
}

/// شريحة «حوّل إلى فاتورة رقم INV-…» (P2-5) — قابلة للنقر وتفتح تفاصيل
/// الفاتورة المحوَّلة إليها (context.go للمسار القائم).
class QuotationConvertedInvoiceChip extends StatelessWidget {
  const QuotationConvertedInvoiceChip({
    super.key,
    required this.invoiceId,
    required this.invoiceNo,
  });

  final int invoiceId;
  final String invoiceNo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Material(
      color: colors.positiveContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('quotation_converted_invoice_chip'),
        onTap: () => context.go('/sell/invoices/$invoiceId'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: colors.onPositiveContainer,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.sellQuotationConvertedTo(invoiceNo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onPositiveContainer,
                    fontWeight: FontWeight.w800,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: colors.onPositiveContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
