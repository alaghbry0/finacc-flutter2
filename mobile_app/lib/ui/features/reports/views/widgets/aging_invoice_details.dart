/// تفاصيل الفواتير المفتوحة بسطر عميل الأعمار (R19-D3a — مستخرجة
/// حرفياً من `aging_report_screen.dart` بلا أي تغيير دلالة؛ كانت
/// `_InvoiceDetails` و`_InvoiceDetailRow` و`_DaysBadge`).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../data/repositories/debt_aging_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import 'aging_format.dart';

/// تفاصيل الفواتير المفتوحة — سطر لكل فاتورة: الرقم، الاستحقاق، شريحة
/// الأيام الملوّنة بحسب دلوها، والمتبقي.
class AgingInvoiceDetails extends StatelessWidget {
  const AgingInvoiceDetails({
    super.key,
    required this.details,
    required this.decimals,
  });

  final List<AgingInvoiceDetail> details;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Divider(height: 1, color: colors.divider),
          for (var i = 0; i < details.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: colors.divider.withValues(alpha: 0.5)),
            AgingInvoiceDetailRow(
              key: Key('aging_detail_${details[i].invoiceId}'),
              detail: details[i],
              decimals: decimals,
              dueDateLabel: l10n.agingDueDateLabel,
            ),
          ],
        ],
      ),
    );
  }
}

class AgingInvoiceDetailRow extends StatelessWidget {
  const AgingInvoiceDetailRow({
    super.key,
    required this.detail,
    required this.decimals,
    required this.dueDateLabel,
  });

  final AgingInvoiceDetail detail;
  final int decimals;
  final String dueDateLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = detail.daysPastDue;
    final bucketIndex = days <= 30
        ? 0
        : days <= 60
        ? 1
        : days <= 90
        ? 2
        : 3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.invoiceNo,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$dueDateLabel: ${agingFormatDate(context, detail.dueDate ?? detail.issuedAt)}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AgingDaysBadge(days: days, bucketIndex: bucketIndex),
          const SizedBox(width: 10),
          AmountText(amount: detail.dueAmount, decimals: decimals),
        ],
      ),
    );
  }
}

/// شريحة أيام التأخير — النص حامل المعنى واللون تدرّج الدلاء (§6.1).
class AgingDaysBadge extends StatelessWidget {
  const AgingDaysBadge({
    super.key,
    required this.days,
    required this.bucketIndex,
  });

  final int days;
  final int bucketIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = days < 0
        ? agingBucketColor(context, 0)
        : agingBucketColor(context, bucketIndex);
    final label = days < 0
        ? l10n.agingDueInDays(-days)
        : days == 0
        ? l10n.agingDueToday
        : l10n.agingDaysOverdue(days);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
