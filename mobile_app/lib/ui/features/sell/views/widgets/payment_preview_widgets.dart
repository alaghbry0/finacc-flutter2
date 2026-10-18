/// رأس ومعاينة التسوية بنافذة الدفع — مستخرجة من payment_sheet
/// (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';

/// رأس النافذة — الصافي كبير + رمز العملة + العميل.
class PaymentTotalHeader extends StatelessWidget {
  const PaymentTotalHeader({
    super.key,
    required this.grandTotal,
    required this.decimals,
    required this.currencyCode,
    required this.customerName,
  });

  final double grandTotal;
  final int decimals;
  final String? currencyCode;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Column(
      children: [
        Text(
          l10n.sellPayNetTotalLabel,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AmountText(
              amount: grandTotal,
              size: AmountSize.display,
              decimals: decimals == 0 ? 0 : 2,
            ),
            if (currencyCode != null && currencyCode!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                currencyCode!,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: colors.gold, fontWeight: FontWeight.w800),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          customerName ?? l10n.sellPayWalkInCustomer,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// معاينة التسوية الحية — المدفوع نقداً / الباقي للعميل / المتبقي آجلاً.
class PaymentSettlementPreview extends StatelessWidget {
  const PaymentSettlementPreview({
    super.key,
    required this.grandTotal,
    required this.decimals,
    required this.netPaid,
    required this.changeDue,
    required this.remainingCredit,
  });

  final double grandTotal;
  final int decimals;
  final double netPaid;
  final double changeDue;
  final double remainingCredit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final d = decimals == 0 ? 0 : 2;
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          PaymentPreviewRow(
            label: l10n.sellPayNetPaid,
            value: netPaid,
            decimals: d,
            color: colors.positive,
          ),
          if (changeDue > 0)
            PaymentPreviewRow(
              label: l10n.sellReceiptChangeDue,
              value: changeDue,
              decimals: d,
              color: colors.warning,
              bold: true,
            ),
          if (remainingCredit > 0)
            PaymentPreviewRow(
              label: l10n.sellReceiptRemainingCredit,
              value: remainingCredit,
              decimals: d,
              color: colors.warning,
            ),
          if (changeDue <= 0 && remainingCredit <= 0)
            PaymentPreviewRow(
              label: l10n.sellPaySettledFully,
              value: null,
              decimals: d,
              color: colors.positive,
            ),
        ],
      ),
    );
  }
}

class PaymentPreviewRow extends StatelessWidget {
  const PaymentPreviewRow({
    super.key,
    required this.label,
    required this.value,
    required this.decimals,
    required this.color,
    this.bold = false,
  });

  final String label;
  final double? value;
  final int decimals;
  final Color color;
  final bool bold;

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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
          if (value != null)
            AmountText(
              amount: value!,
              decimals: decimals,
              showSignMarker: false,
            )
          else
            Icon(Icons.check_circle_rounded, size: 20, color: color),
        ],
      ),
    );
  }
}
