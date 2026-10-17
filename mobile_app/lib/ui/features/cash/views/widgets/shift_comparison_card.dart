/// بطاقة المقارنة الحية: المتوقع مقابل المعدود + شارة الفرق الملوّنة.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';

class ShiftComparisonCard extends StatelessWidget {
  const ShiftComparisonCard({
    super.key,
    required this.expected,
    required this.counted,
    required this.difference,
    required this.decimals,
    this.currencyCode,
  });

  final double expected;
  final double? counted;
  final double? difference;
  final int decimals;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final diff = difference;
    final badgeColor = diff == null
        ? scheme.surfaceContainerLow
        : diff > 0.005
        ? colors.positiveContainer
        : diff < -0.005
        ? colors.negativeContainer
        : scheme.surfaceContainerLow;
    final badgeText = diff == null
        ? '—'
        : diff > 0.005
        ? l10n.shiftSurplus
        : diff < -0.005
        ? l10n.shiftDeficit
        : l10n.shiftMatched;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _CompareColumn(
                  label: l10n.shiftExpectedLabel,
                  amount: expected,
                  decimals: decimals,
                  currencyCode: currencyCode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompareColumn(
                  label: l10n.shiftCountedLabel,
                  amount: counted,
                  decimals: decimals,
                  currencyCode: currencyCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.shiftDifferenceLabel}:',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              if (diff != null)
                AmountText(
                  amount: diff.abs(),
                  decimals: decimals,
                  sign: diff > 0.005
                      ? FinSign.incoming
                      : diff < -0.005
                      ? FinSign.outgoing
                      : FinSign.neutral,
                  showSignMarker: false,
                )
              else
                Text(
                  '—',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontFeatures: FinText.tabularNums),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// عمود مقارنة (تسمية + مبلغ أو شرطة).
class _CompareColumn extends StatelessWidget {
  const _CompareColumn({
    required this.label,
    required this.amount,
    required this.decimals,
    this.currencyCode,
  });

  final String label;
  final double? amount;
  final int decimals;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (amount == null)
              Text('—', style: Theme.of(context).textTheme.titleMedium)
            else
              Flexible(
                child: AmountText(
                  amount: amount!,
                  size: AmountSize.large,
                  decimals: decimals,
                ),
              ),
            if (amount != null && (currencyCode ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6),
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
      ],
    );
  }
}
