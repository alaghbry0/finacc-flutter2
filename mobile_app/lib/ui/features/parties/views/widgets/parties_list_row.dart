/// سطر طرف واحد بقائمة الأطراف — سحب للأرشفة (بلا حركات فقط) + بطاقة
/// بالنوع والرصيد — مستخرج من parties_list_screen (R20-D3b: نقل حرفي
/// بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../domain/models/party.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/party_kind.dart';
import 'parties_widgets.dart';

/// سطر طرف واحد — سحب للأرشفة (بلا حركات فقط) + بطاقة بالنوع والرصيد.
class PartiesListRow extends StatelessWidget {
  const PartiesListRow({
    super.key,
    required this.row,
    required this.kind,
    required this.showArchivedBadge,
    required this.decimals,
    required this.onArchive,
  });

  final PartyBalance row;

  /// نوع الطرف — للأيقونة ومسار التفاصيل.
  final PartyKind kind;

  /// إظهار شارة «مؤرشف» (في تصفية المؤرشفين).
  final bool showArchivedBadge;

  final int decimals;

  /// يؤكد وينفّذ الأرشفة — يعيد true إذا أُزيل السطر.
  final Future<bool> Function() onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Dismissible(
      key: ValueKey('party_row_${row.partyId}_${row.currencyCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.negativeContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive_rounded, color: colors.onNegativeContainer),
            const SizedBox(width: 8),
            Text(
              l10n.partiesSwipeArchiveLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onNegativeContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) => onArchive(),
      onDismissed: (_) {},
      child: FinCard(
        onTap: () => context.go(
          kind == PartyKind.customer
              ? '/parties/customers/${row.partyId}'
              : '/parties/suppliers/${row.partyId}',
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PartyAvatar(kind: kind, name: row.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showArchivedBadge) ...[
                        const SizedBox(width: 6),
                        StatusChip(
                          label: l10n.partiesArchivedBadge,
                          icon: Icons.archive_rounded,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if ((row.phone ?? '').isNotEmpty)
                    PartyPhoneText(row.phone!)
                  else
                    Text(
                      l10n.partiesNoPhone,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 8),
                  CurrencyCodePill(code: row.currencyCode),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PartyBalanceText(balance: row.balance, decimals: decimals),
                const SizedBox(height: 2),
                Text(
                  l10n.partiesBalanceLabel,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
