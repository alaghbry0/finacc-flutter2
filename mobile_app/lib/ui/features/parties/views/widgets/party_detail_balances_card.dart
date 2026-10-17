/// بطاقة الأرصدة لتفاصيل الطرف — سطر لكل عملة على حدة، والنقر على سطر
/// يختار عملة الكشف.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/models/party.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/party_detail_view_model.dart';
import 'parties_widgets.dart';

/// بطاقة الأرصدة — سطر لكل عملة (قد تكون واحدة صفرياً)؛ النقر على سطر
/// يختار عملة الكشف.
class PartyDetailBalancesCard extends StatelessWidget {
  const PartyDetailBalancesCard({super.key, required this.state});

  final PartyDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    if (state.balances.isEmpty) {
      return FinCard(
        child: Text(
          l10n.partyDetailBalancesEmpty,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < state.balances.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            PartyDetailBalanceRow(
              row: state.balances[i],
              selected:
                  _currencyIdOfCode(state, state.balances[i].currencyCode) ==
                  state.statementCurrencyId,
              decimals: state.decimalsFor(state.balances[i].currencyCode),
              onTap: () => _selectCurrency(
                context,
                _currencyIdOfCode(state, state.balances[i].currencyCode),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static int? _currencyIdOfCode(PartyDetailState state, String code) {
    for (final currency in state.currencies) {
      if (currency.code == code) return currency.id;
    }
    return null;
  }

  static void _selectCurrency(BuildContext context, int? currencyId) {
    final vm = context.read<PartyDetailViewModel>();
    if (currencyId != null) {
      unawaited(vm.setStatementCurrency(currencyId));
    }
  }
}

/// سطر رصيد بعملة واحدة — النقر يجعلها عملة الكشف.
class PartyDetailBalanceRow extends StatelessWidget {
  const PartyDetailBalanceRow({
    super.key,
    required this.row,
    required this.selected,
    required this.decimals,
    required this.onTap,
  });

  final PartyBalance row;
  final bool selected;
  final int decimals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.30)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: scheme.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            CurrencyCodePill(code: row.currencyCode),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                partyFormatDate(context, row.lastPaymentDate),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PartyBalanceText(balance: row.balance, decimals: decimals),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle_rounded, size: 16, color: colors.gold),
            ],
          ],
        ),
      ),
    );
  }
}
