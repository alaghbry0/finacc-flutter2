/// إيصال نجاح ترحيل فاتورة الشراء (R19-D3a — مستخرج حرفياً من
/// `purchase_widgets.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/purchase.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import 'purchase_pay_status_chip.dart';

/// إيصال نجاح ترحيل فاتورة الشراء — PUR/الإجمالي/المدفوع/المتبقي آجلاً
/// + شارة السعر التقديري عند fallback (FR-02-20).
class PostedPurchaseReceiptCard extends StatelessWidget {
  const PostedPurchaseReceiptCard({
    super.key,
    required this.receipt,
    this.currencyCode,
  });

  final PurchasePostedReceipt receipt;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
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
                      l10n.purReceiptSuccessTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      receipt.docNo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: FinText.tabularNums,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PurchasePayStatusChip(method: receipt.payStatus, dense: false),
            ],
          ),
          if (receipt.rateIsFallback) ...[
            const SizedBox(height: 12),
            const PurchaseFallbackRateBadge(dense: false),
          ],
          const SizedBox(height: 14),
          _ReceiptRow(
            label: l10n.sellReceiptTotal,
            value: receipt.totals.grandTotal,
          ),
          _ReceiptRow(
            label: l10n.sellReceiptPaidCash,
            value: receipt.totals.grandTotal - receipt.remainingCredit,
            sign: FinSign.outgoing,
          ),
          if (receipt.remainingCredit > 0)
            _ReceiptRow(
              label: l10n.purReceiptSupplierCredit,
              value: receipt.remainingCredit,
              sign: FinSign.outgoing,
              highlight: colors.warning,
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
    this.highlight,
  });

  final String label;
  final double value;
  final FinSign sign;
  final Color? highlight;

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
