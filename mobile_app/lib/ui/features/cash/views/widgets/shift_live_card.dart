/// بطاقة الوردية الحية — الفتح والافتتاحي والوارد/الصادر/المتوقع.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/hub_hero_card.dart';
import '../../view_models/shift_view_model.dart';
import 'shift_close_sheet.dart';
import 'shift_format.dart';

class ShiftLiveCard extends StatelessWidget {
  const ShiftLiveCard({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShiftViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final state = vm.state;
    final current = state.current!;
    final box = state.boxFor(current.cashboxId);
    final decimals = shiftDecimals(box?.box.currencyCode);
    final opened = shiftTryParseIso(current.openedAt);

    return HubHeroCard(
      icon: Icons.timelapse_rounded,
      title: l10n.shiftLiveTitle,
      subtitle: Text(
        '${box?.box.name ?? ''}'
        '${opened == null ? '' : ' · ${l10n.shiftOpenedAtLabel}: '
                  '${shiftFormatDateTime(opened.toLocal())}'}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontFeatures: FinText.tabularNums,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      accent: colors.positive,
      iconTint: colors.positive,
      iconColor: colors.onPositiveContainer,
      // معادلة الوردية أسفل صف البطولة بفتحة below (W3/R17-b).
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          _SummaryRow(
            label: l10n.shiftOpeningCountLabel,
            amount: current.openingCount ?? 0,
            decimals: decimals,
            currencyCode: box?.box.currencyCode,
          ),
          _SummaryRow(
            label: l10n.shiftRunningIn,
            amount: state.equation.totalIn,
            decimals: decimals,
            currencyCode: box?.box.currencyCode,
            sign: FinSign.incoming,
          ),
          _SummaryRow(
            label: l10n.shiftRunningOut,
            amount: state.equation.totalOut,
            decimals: decimals,
            currencyCode: box?.box.currencyCode,
            sign: FinSign.outgoing,
          ),
          const Divider(height: 20, thickness: 0.8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.shiftExpectedSoFar,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    AmountText(
                      amount: state.expectedSoFar,
                      size: AmountSize.large,
                      decimals: decimals,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                box?.box.currencyCode ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.gold,
                  fontWeight: FontWeight.w800,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.shiftAutoRefreshNote,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => unawaited(showShiftCloseSheet(context, vm)),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: colors.negative,
              foregroundColor: colors.onNegativeContainer,
              textStyle: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            child: Text(l10n.shiftCloseButton),
          ),
        ],
      ),
    );
  }
}

/// سطر ملخص «تسمية + مبلغ» داخل البطاقة الحية.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.decimals,
    this.currencyCode,
    this.sign = FinSign.neutral,
  });

  final String label;
  final double amount;
  final int decimals;
  final String? currencyCode;
  final FinSign sign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          AmountText(amount: amount, decimals: decimals, sign: sign),
          if ((currencyCode ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                currencyCode!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
