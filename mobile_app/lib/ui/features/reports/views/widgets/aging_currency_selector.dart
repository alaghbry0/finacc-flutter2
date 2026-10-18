/// منتقي عملة تقرير أعمار الديون (R19-D3a — مستخرج حرفياً من
/// `aging_report_screen.dart` بلا أي تغيير دلالة؛ كان `_CurrencySelector`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/aging_view_model.dart';

/// منتقي العملة — قائمة منبثقة (الأساس أولاً، بلا حالة داخلية).
class AgingCurrencySelector extends StatelessWidget {
  const AgingCurrencySelector({super.key, required this.state});

  final AgingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final selected = state.currencies
        .where((currency) => currency.id == state.currencyId)
        .firstOrNull;
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.currency_exchange_rounded,
            size: 22,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.agingCurrencyLabel,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          PopupMenuButton<int>(
            initialValue: state.currencyId,
            tooltip: l10n.agingCurrencyLabel,
            onSelected: (currencyId) => unawaited(
              context.read<AgingViewModel>().setCurrency(currencyId),
            ),
            itemBuilder: (context) => [
              for (final currency in state.currencies)
                PopupMenuItem<int>(
                  value: currency.id,
                  child: Text(
                    '${currency.name} (${currency.code})'
                    '${currency.isBase ? ' ★' : ''}',
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    selected?.code ?? '—',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
