/// إيصال النجاح بعد الترحيل — بطاقة INV/الإجمالي/المدفوع/الباقي/المتبقي.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import 'pay_status_chip.dart';

/// إيصال النجاح بعد الترحيل — INV/الإجمالي/المدفوع/الباقي/المتبقي آجلاً
/// + شارة السعر التقديري عند fallback (FR-02-20) + زرا «طباعة الفاتورة»
/// و«مشاركة/واتساب» الفوريان (P0-2 — يفتحان معاينة PDF للفاتورة
/// المرحّلة؛ يخفيان عند off أو غياب المستدعي).
class PostedReceiptCard extends StatelessWidget {
  const PostedReceiptCard({
    super.key,
    required this.receipt,
    this.currencyCode,
    this.onPrint,
    this.onShare,
  });

  final SalePostedReceipt receipt;
  final String? currencyCode;

  /// فتح معاينة الطباعة (زر الطباعة) — null = إخفاء الزرين.
  final VoidCallback? onPrint;

  /// فتح معاينة المشاركة/واتساب — null = إخفاء الزرين.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final showPrintActions = onPrint != null && onShare != null;
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
                      l10n.sellReceiptSuccessTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      receipt.invoiceNo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: FinText.tabularNums,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PayStatusChip(method: receipt.payStatus, dense: false),
            ],
          ),
          if (receipt.rateIsFallback) ...[
            const SizedBox(height: 12),
            FallbackRateBadge(dense: false),
          ],
          const SizedBox(height: 14),
          _ReceiptRow(
            label: l10n.sellReceiptTotal,
            value: receipt.totals.grandTotal,
          ),
          _ReceiptRow(
            label: l10n.sellReceiptPaidCash,
            value: receipt.totals.grandTotal - receipt.remainingCredit,
            sign: FinSign.incoming,
          ),
          if (receipt.changeDue > 0)
            _ReceiptRow(
              label: l10n.sellReceiptChangeDue,
              value: receipt.changeDue,
              sign: FinSign.outgoing,
              highlight: colors.warning,
            ),
          if (receipt.remainingCredit > 0)
            _ReceiptRow(
              label: l10n.sellReceiptRemainingCredit,
              value: receipt.remainingCredit,
              sign: FinSign.outgoing,
              highlight: colors.warning,
            ),
          // P0-2: أزرار الطباعة/المشاركة الفورية داخل بطاقة الإيصال —
          // أقصر مسار للطباعة (كان 5-6 خطوات عبر قائمة الفواتير).
          if (showPrintActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('sell_receipt_print_button'),
                    onPressed: onPrint,
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: Text(l10n.sellFixPrintInvoice),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('sell_receipt_share_button'),
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(l10n.sellFixShareInvoice),
                  ),
                ),
              ],
            ),
          ],
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
