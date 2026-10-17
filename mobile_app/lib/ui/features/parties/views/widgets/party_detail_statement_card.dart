/// بطاقة كشف الحساب لتفاصيل الطرف — عناصر التحكم بالعملة والفترة +
/// الرصيد النهائي + الخط الزمني للقيود برصيد رأسي متحرك.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/party_detail_view_model.dart';
import 'parties_widgets.dart';
import 'party_detail_period_chips.dart';
import 'party_detail_statement_body.dart';

/// بطاقة كشف الحساب — عناصر التحكم بالعملة والفترة + الرصيد النهائي +
/// الخط الزمني للقيود برصيد رأسي متحرك.
class PartyDetailStatementCard extends StatelessWidget {
  const PartyDetailStatementCard({super.key, required this.state});

  final PartyDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.read<PartyDetailViewModel>();
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            key: const Key('party_detail_currency'),
            initialValue: state.statementCurrencyId,
            onChanged: (value) {
              if (value != null) unawaited(vm.setStatementCurrency(value));
            },
            decoration: InputDecoration(
              labelText: l10n.partyDetailStatementCurrency,
              prefixIcon: const Icon(Icons.currency_exchange_rounded),
            ),
            items: [
              for (final currency in state.currencies)
                DropdownMenuItem<int>(
                  value: currency.id,
                  child: Text('${currency.name} (${currency.code})'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          PartyDetailPeriodControls(state: state),
          const SizedBox(height: 14),
          if (state.loadingStatement)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PartyDetailStatementBody(state: state),
        ],
      ),
    );
  }
}

/// أدوات الفترة — من/إلى + رقائق سريعة (الكل/هذا الشهر/هذه السنة).
class PartyDetailPeriodControls extends StatelessWidget {
  const PartyDetailPeriodControls({super.key, required this.state});

  final PartyDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.read<PartyDetailViewModel>();
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final thisYear = DateTime(now.year, 1, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: PartyDetailDateChip(
                key: const Key('party_detail_from_date'),
                icon: Icons.event_rounded,
                label: l10n.partyDetailStatementFrom,
                text: state.from == null
                    ? l10n.partyDetailPeriodAll
                    : partyFormatDate(context, state.from),
                onTap: () => unawaited(_pickFrom(context, vm)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PartyDetailDateChip(
                key: const Key('party_detail_to_date'),
                icon: Icons.event_available_rounded,
                label: l10n.partyDetailStatementTo,
                text: partyFormatDate(context, state.to),
                onTap: () => unawaited(_pickTo(context, vm)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              PartyDetailQuickChip(
                label: l10n.partyDetailPeriodAll,
                selected: state.from == null,
                onTap: () => unawaited(vm.clearPeriod()),
              ),
              const SizedBox(width: 8),
              PartyDetailQuickChip(
                label: l10n.partyDetailPeriodThisMonth,
                selected: _sameDay(state.from, thisMonth),
                onTap: () => unawaited(vm.setFrom(thisMonth)),
              ),
              const SizedBox(width: 8),
              PartyDetailQuickChip(
                label: l10n.partyDetailPeriodThisYear,
                selected: _sameDay(state.from, thisYear),
                onTap: () => unawaited(vm.setFrom(thisYear)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  static Future<void> _pickFrom(
    BuildContext context,
    PartyDetailViewModel vm,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.state.from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      await vm.setFrom(DateTime(picked.year, picked.month, picked.day));
    }
  }

  static Future<void> _pickTo(
    BuildContext context,
    PartyDetailViewModel vm,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.state.to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      await vm.setTo(DateTime(picked.year, picked.month, picked.day));
    }
  }
}
