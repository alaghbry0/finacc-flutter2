/// بطاقة ملخص أعمار الديون (R19-D3a — مستخرجة حرفياً من
/// `aging_report_screen.dart` بلا أي تغيير دلالة؛ كانت `_SummaryCard`
/// و`_BucketTile`).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../data/repositories/debt_aging_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import 'aging_currency_pill.dart';
import 'aging_format.dart';

/// بطاقة الملخص — شريحة «حتى تاريخ» + عدد المدينين، أربع بلاطات دلاء
/// بتدرّج أخضر ← أحمر، والإجمالي العام، ومعه الجزء غير المستحق بعد.
class AgingSummaryCard extends StatelessWidget {
  const AgingSummaryCard({
    super.key,
    required this.report,
    required this.decimals,
  });

  final AgingReport report;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final buckets = <double>[
      report.total0to30,
      report.total31to60,
      report.total61to90,
      report.total90Plus,
    ];

    return FinCard(
      accent: colors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_rounded, size: 15, color: colors.gold),
              const SizedBox(width: 5),
              // Expanded يمنع فيض الصف على الشاشات الضيقة (٣٩٠) مع شريحة
              // عدد المدينين المجاورة.
              Expanded(
                child: Text(
                  l10n.agingAsOfLabel(agingFormatDate(context, report.asOf)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: l10n.agingCustomersCount(report.customersCount),
                icon: Icons.groups_rounded,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AgingBucketTile(
                  label: l10n.agingBucket0to30,
                  amount: buckets[0],
                  color: agingBucketColor(context, 0),
                  decimals: decimals,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AgingBucketTile(
                  label: l10n.agingBucket31to60,
                  amount: buckets[1],
                  color: agingBucketColor(context, 1),
                  decimals: decimals,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AgingBucketTile(
                  label: l10n.agingBucket61to90,
                  amount: buckets[2],
                  color: agingBucketColor(context, 2),
                  decimals: decimals,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AgingBucketTile(
                  label: l10n.agingBucket90plus,
                  amount: buckets[3],
                  color: agingBucketColor(context, 3),
                  decimals: decimals,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.agingTotalLabel,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              AmountText(
                amount: report.grandTotal,
                decimals: decimals,
                size: AmountSize.large,
              ),
              const SizedBox(width: 8),
              AgingCurrencyPill(code: report.currencyCode, accent: colors.gold),
            ],
          ),
          if (report.currentNotDue > 0) ...[
            const SizedBox(height: 8),
            StatusChip(
              label:
                  '${l10n.agingNotYetDueLabel} '
                  '${AmountText.formatFor(context, report.currentNotDue, decimals)}',
              tone: ChipTone.positive,
              icon: Icons.schedule_rounded,
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// بلاطة دلو واحدة — نقطة ملوّنة + عنوان + المبلغ بلون الدلو (النص
/// نفسه علامة غير لونية حاملة للمعنى — §6.1).
class AgingBucketTile extends StatelessWidget {
  const AgingBucketTile({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.decimals,
  });

  final String label;
  final double amount;
  final Color color;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AmountText(amount: amount, decimals: decimals),
        ],
      ),
    );
  }
}
