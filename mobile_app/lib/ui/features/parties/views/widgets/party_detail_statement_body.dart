/// جسم كشف حساب الطرف — الرصيد النهائي و«رصيد ماضٍ» والخط الزمني
/// للقيود برصيد رأسي متحرك بأيقونات دلالية لكل قيد.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/party.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../view_models/party_detail_view_model.dart';
import 'parties_widgets.dart';

/// جسم الكشف — الرصيد النهائي + «رصيد ماضٍ» + الخط الزمني للقيود.
class PartyDetailStatementBody extends StatelessWidget {
  const PartyDetailStatementBody({super.key, required this.state});

  final PartyDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statement = state.statement;
    if (statement == null) {
      return Text(
        l10n.partyDetailNoEntries,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final decimals = state.statementDecimals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.from != null) ...[
          PartyDetailCarryInRow(
            label: l10n.partyDetailCarryInBalance,
            amount: statement.openingBalance,
            decimals: decimals,
          ),
          const SizedBox(height: 12),
        ],
        PartyDetailFinalBalanceHeader(
          label: l10n.partyDetailFinalBalance,
          code: statement.currencyCode,
          amount: statement.finalBalance,
          decimals: decimals,
        ),
        const SizedBox(height: 14),
        if (statement.entries.isEmpty)
          Text(
            l10n.partyDetailNoEntries,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (var i = 0; i < statement.entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PartyDetailStatementEntryRow(
                key: Key('statement_entry_$i'),
                entry: statement.entries[i],
                decimals: decimals,
              ),
            ),
      ],
    );
  }
}

/// رأس الرصيد النهائي — بطاقة داخل البطاقة بلون دلالي ومبلغ ضخم.
class PartyDetailFinalBalanceHeader extends StatelessWidget {
  const PartyDetailFinalBalanceHeader({
    super.key,
    required this.label,
    required this.code,
    required this.amount,
    required this.decimals,
  });

  final String label;
  final String code;
  final double amount;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CurrencyCodePill(code: code),
          const SizedBox(width: 8),
          PartyBalanceText(
            balance: amount,
            decimals: decimals,
            size: AmountSize.large,
            showChip: false,
          ),
        ],
      ),
    );
  }
}

/// سطر «رصيد ماضٍ» عند تحديد بداية فترة.
class PartyDetailCarryInRow extends StatelessWidget {
  const PartyDetailCarryInRow({
    super.key,
    required this.label,
    required this.amount,
    required this.decimals,
  });

  final String label;
  final double amount;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.history_rounded, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        PartyBalanceText(balance: amount, decimals: decimals, showChip: false),
      ],
    );
  }
}

/// قيد واحد في الخط الزمني — أيقونة دلالية + تاريخ ونوع ورقم المستند +
/// المبلغ الموقَّع + الرصيد الرأسي بعد القيد.
class PartyDetailStatementEntryRow extends StatelessWidget {
  const PartyDetailStatementEntryRow({
    super.key,
    required this.entry,
    required this.decimals,
  });

  final StatementEntry entry;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final isDebit = entry.amount > 0;
    final amountColor = entry.amount == 0
        ? scheme.onSurfaceVariant
        : (isDebit ? colors.negative : colors.positive);
    final iconColor =
        entry.code == StatementEntryCode.receipt ||
            entry.code == StatementEntryCode.payment
        ? colors.positive
        : entry.code == StatementEntryCode.opening ||
              entry.code == StatementEntryCode.carryIn
        ? colors.gold
        : scheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            statementEntryIcon(entry.code),
            size: 17,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      statementEntryLabel(l10n, entry.code),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${isDebit ? '+' : '−'}'
                      '${AmountText.formatFor(context, entry.amount.abs(), decimals)}',
                      style: FinText.amountRow(amountColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${partyFormatDate(context, entry.date)}'
                '${entry.docNo != null ? ' · ${entry.docNo}' : ''}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.statementBalanceColumn,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                AmountText.formatFor(context, entry.runningBalance, decimals),
                style: FinText.amountRow(scheme.onSurface)
                    .copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
