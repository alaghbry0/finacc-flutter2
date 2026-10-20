/// صف طرف واحد بنمط Simple Invoice Manager (V5) — من النموذج الأولي
/// `screen-clients`: دائرة حرف أول (38px خلفية `#CFD8DC`) + الاسم عريضاً
/// + الهاتف أحادي المسافة، والطرف المقابل: رمز العملة فوق الرصيد الملوّن
/// بعلامته غير اللونية. سحب للأرشفة كما في القائمة الأصلية (FR-03-09).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../domain/models/party.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/party_kind.dart';
import 'parties_widgets.dart';

/// صف عميل/مورد بنمط SIM — أبيض بفاصل سفلي 1px.
class SimClientRow extends StatelessWidget {
  const SimClientRow({
    super.key,
    required this.row,
    required this.kind,
    required this.showArchivedBadge,
    required this.decimals,
    required this.onArchive,
  });

  final PartyBalance row;

  /// نوع الطرف — لمسار التفاصيل ولون الصورة.
  final PartyKind kind;

  /// إظهار شارة «مؤرشف» (تصفية المؤرشفين).
  final bool showArchivedBadge;

  final int decimals;

  /// يؤكد وينفّذ الأرشفة — يعيد true إذا أُزيل السطر.
  final Future<bool> Function() onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey('sim_party_row_${row.partyId}_${row.currencyCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: FinColors.of(context).negativeContainer,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.archive_rounded,
              color: FinColors.of(context).onNegativeContainer,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.partiesSwipeArchiveLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: FinColors.of(context).onNegativeContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) => onArchive(),
      onDismissed: (_) {},
      child: InkWell(
        onTap: () => context.go(
          kind == PartyKind.customer
              ? '/parties/customers/${row.partyId}'
              : '/parties/suppliers/${row.partyId}',
        ),
        child: Container(
          color: scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          foregroundDecoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? scheme.outlineVariant.withValues(alpha: 0.4)
                    : const Color(0xFFF0F0F0),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InitialAvatar(kind: kind, name: row.name),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
                    const SizedBox(height: 3),
                    if ((row.phone ?? '').isNotEmpty)
                      PartyPhoneText(
                        row.phone!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Text(
                        l10n.partiesNoPhone,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // رمز العملة فوق المبلغ — LTR بأرقام جدولية.
                  Text(
                    row.currencyCode,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  PartyBalanceText(
                    balance: row.balance,
                    decimals: decimals,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// دائرة الحرف الأول — 38px بخلفية `#CFD8DC` (فاتح) وحرف عريض.
class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.kind, required this.name});

  final PartyKind kind;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final bg = isDark
        ? scheme.surfaceContainerHighest
        : const Color(0xFFCFD8DC);
    final fg = isDark ? scheme.onSurface : const Color(0xFF455A64);
    final initial = name.trim();
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: initial.isEmpty
            ? Icon(
                kind == PartyKind.customer
                    ? Icons.person_rounded
                    : Icons.local_shipping_rounded,
                size: 20,
                color: fg,
              )
            : Text(
                initial.characters.first,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
