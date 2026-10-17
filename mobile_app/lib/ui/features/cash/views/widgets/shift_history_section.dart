/// قسم «آخر الورديات» — نقر وردية مقفلة يفتح تقرير PDF.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../data/repositories/shift_repository.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/shift_view_model.dart';
import 'shift_format.dart';
import 'shift_pdf.dart';

class ShiftHistorySection extends StatelessWidget {
  const ShiftHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShiftViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            l10n.shiftHistoryTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (state.recent.isEmpty)
          EmptyState(
            icon: Icons.history_rounded,
            title: l10n.shiftHistoryTitle,
            message: l10n.shiftHistoryEmpty,
            compact: true,
          )
        else
          for (final shift in state.recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ShiftHistoryCard(shift: shift),
            ),
      ],
    );
  }
}

/// بطاقة وردية مقفلة في السجل — نطاقها + المتوقع/المعدود/الفرق الملوّن.
class _ShiftHistoryCard extends StatelessWidget {
  const _ShiftHistoryCard({required this.shift});

  final ShiftRow shift;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShiftViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final box = vm.state.boxFor(shift.cashboxId);
    final decimals = shiftDecimals(box?.box.currencyCode);
    final opened = shiftTryParseIso(shift.openedAt)?.toLocal();
    final closed = shiftTryParseIso(shift.closedAt)?.toLocal();

    return FinCard(
      padding: const EdgeInsets.all(14),
      onTap: () => openShiftPdf(context, vm: vm, shift: shift),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  opened == null
                      ? box?.box.name ?? ''
                      : '${shiftFormatDateTime(opened)}'
                            '${closed == null ? '' : ' ← ${shiftFormatDateTime(closed)}'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if ((box?.box.currencyCode ?? '').isNotEmpty)
                Text(
                  box!.box.currencyCode,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _HistoryAmount(
                  label: l10n.shiftExpectedLabel,
                  amount: shift.expected ?? 0,
                  decimals: decimals,
                ),
              ),
              Expanded(
                child: _HistoryAmount(
                  label: l10n.shiftCountedLabel,
                  amount: shift.counted ?? 0,
                  decimals: decimals,
                ),
              ),
              Expanded(
                child: _HistoryAmount(
                  label: l10n.shiftDifferenceLabel,
                  amount: shift.difference ?? 0,
                  decimals: decimals,
                  emphasizeDifference: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// عمود مبلغ داخل بطاقة السجل.
class _HistoryAmount extends StatelessWidget {
  const _HistoryAmount({
    required this.label,
    required this.amount,
    required this.decimals,
    this.emphasizeDifference = false,
  });

  final String label;
  final double amount;
  final int decimals;
  final bool emphasizeDifference;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final diff = emphasizeDifference
        ? (amount > 0.005
              ? FinSign.incoming
              : amount < -0.005
              ? FinSign.outgoing
              : FinSign.neutral)
        : FinSign.neutral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        AmountText(
          amount: emphasizeDifference ? amount.abs() : amount,
          decimals: decimals,
          sign: diff,
          showSignMarker: false,
        ),
        if (emphasizeDifference)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              amount > 0.005
                  ? AppLocalizations.of(context)!.shiftSurplus
                  : amount < -0.005
                  ? AppLocalizations.of(context)!.shiftDeficit
                  : AppLocalizations.of(context)!.shiftMatched,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: switch (diff) {
                  FinSign.incoming => colors.positive,
                  FinSign.outgoing => colors.negative,
                  FinSign.neutral => scheme.onSurfaceVariant,
                },
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}
