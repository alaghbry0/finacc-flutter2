/// إيصال نجاح ترحيل المرتجع — SRN/PRN/الفاتورة الأصلية/قيمة الرد نقدياً
/// ومن الحساب + شارة السعر التقديري عند fallback (FR-02-20) — مستخرج من
/// return_refund_sheet (R20-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/return_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';

class PostedReturnReceiptCard extends StatelessWidget {
  const PostedReturnReceiptCard({super.key, required this.receipt});

  final ReturnPostedReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final docLabel = receipt.docType == 'SRN'
        ? l10n.retSaleTitle
        : l10n.retPurchaseTitle;
    return FinCard(
      accent: colors.positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.positiveContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: colors.onPositiveContainer,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.retReceiptSuccessTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${receipt.docNo} · $docLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: FinText.tabularNums,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (receipt.originalInvoiceNo != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.retReceiptOriginal(receipt.originalInvoiceNo!),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: FinText.tabularNums,
              ),
            ),
          ],
          if (receipt.rateIsFallback) ...[
            const SizedBox(height: 12),
            StatusChip(
              label: l10n.sellFallbackRateBadge,
              tone: ChipTone.warning,
              icon: Icons.price_change_rounded,
            ),
          ],
          const SizedBox(height: 14),
          _ReceiptRow(
            label: l10n.retRefundTotalLabel,
            value: receipt.refundTotal,
          ),
          _ReceiptRow(
            label: l10n.retReceiptRefundCash,
            value: receipt.refundCash,
            sign: FinSign.outgoing,
          ),
          if (receipt.refundCredit > 0)
            _ReceiptRow(
              label: l10n.retReceiptRefundCredit,
              value: receipt.refundCredit,
              sign: FinSign.outgoing,
            ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
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
      padding: const EdgeInsets.symmetric(vertical: 3),
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
