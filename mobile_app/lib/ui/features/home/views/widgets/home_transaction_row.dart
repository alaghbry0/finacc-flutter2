/// صف المعاملة — نمط Simple Invoice Manager (V3):
/// كتلة التاريخ (يوم بارز فوق شهر مختصر) في جهة البداية، ثم اسم الطرف
/// ورقم المستند وشارة الحالة (StatusChip — نص دائماً)، والمبالغ في
/// جهة النهاية باتجاه LTR (الأرقام الغربية بعمود مستقيم).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/transactions_home_view_model.dart';

/// صف معاملة واحدة في قائمة مركز المعاملات (يستهلك [HomeTransactionRow]).
class HomeTransactionTile extends StatelessWidget {
  const HomeTransactionTile({super.key, required this.row, this.fallbackParty});

  /// بيانات الصف.
  final HomeTransactionRow row;

  /// نص بديل عند غياب اسم الطرف (عميل نقدي).
  final String? fallbackParty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final localeName = l10n.localeName;

    final party = row.partyName ?? fallbackParty ?? '';

    return InkWell(
      key: ValueKey('home_row_${row.docNo}_${row.id}'),
      onTap: () => context.go(row.detailRoute),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // كتلة التاريخ — ثابتة العرض فتستقيم القائمة.
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    '${row.date.day}',
                    style: FinText.withTabularDigits(
                      Theme.of(context).textTheme.titleMedium!,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    DateFormat.MMM(localeName).format(row.date),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // الطرف + رقم المستند + الشارة.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    party,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        row.docNo,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (row.badge != HomeBadge.none)
                        _badgeChip(context, l10n),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // المبالغ — LTR دائماً (عمود أرقام مستقيم).
            Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _amount(row.total),
                    style: FinText.withTabularDigits(
                      Theme.of(context).textTheme.titleSmall!,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (row.dueAmount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${l10n.homeRowDueLabel} ${_amount(row.dueAmount)}',
                        style: FinText.withTabularDigits(
                          Theme.of(context).textTheme.bodySmall!,
                        ).copyWith(
                          fontSize: 11,
                          color: FinColors.of(context).warning,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// شارة الحالة بنبرة دلالية (DS-26: نص + لون معاً).
  Widget _badgeChip(BuildContext context, AppLocalizations l10n) {
    final (label, tone) = switch (row.badge) {
      HomeBadge.paid => (l10n.homeFilterPaid, ChipTone.positive),
      HomeBadge.partial => (l10n.homeFilterPartial, ChipTone.warning),
      HomeBadge.unpaid => (l10n.homeFilterUnpaid, ChipTone.brand),
      HomeBadge.draft => (l10n.homeQuotationBadgeDraft, ChipTone.neutral),
      HomeBadge.sent => (l10n.homeQuotationBadgeSent, ChipTone.brand),
      HomeBadge.converted => (
        l10n.homeQuotationBadgeConverted,
        ChipTone.positive,
      ),
      HomeBadge.expired => (l10n.homeQuotationBadgeExpired, ChipTone.warning),
      HomeBadge.rejected => (l10n.homeQuotationBadgeRejected, ChipTone.negative),
      HomeBadge.none => (l10n.homeVoucherFallback, ChipTone.neutral),
    };
    return StatusChip(label: label, tone: tone, dense: true);
  }

  String _amount(double value) {
    final decimals = row.currencyCode == 'YER' ? 0 : 2;
    final text = AmountText.format(value, decimals);
    return row.currencyCode == null ? text : '$text ${row.currencyCode}';
  }
}
