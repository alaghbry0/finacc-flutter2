/// منتقي عملة فاتورة الشراء (R19-D3a — مستخرج حرفياً من
/// `purchase_widgets.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/company.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';

/// منتقي عملة فاتورة الشراء — رقائق أفقية (الأساس أولاً) مع سعر اليوم.
class PurchaseCurrencyPickerRow extends StatelessWidget {
  const PurchaseCurrencyPickerRow({
    super.key,
    required this.currencies,
    required this.selectedId,
    required this.todayRate,
    required this.onSelect,
  });

  final List<PurchaseCurrencyOption> currencies;
  final int? selectedId;
  final double? todayRate;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < currencies.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _CurrencyChip(
              option: currencies[i],
              selected: currencies[i].id == selectedId,
              rate: currencies[i].id == selectedId ? todayRate : null,
              baseLabel: l10n.sellCurrencyBaseTag,
              missingLabel: l10n.sellCurrencyNoRate,
              onTap: () => onSelect(currencies[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

/// خيار عملة للمنتقي.
class PurchaseCurrencyOption {
  const PurchaseCurrencyOption({
    required this.id,
    required this.code,
    required this.isBase,
    required this.rateKnown,
  });

  final int id;
  final String code;
  final bool isBase;
  final bool rateKnown;

  factory PurchaseCurrencyOption.fromCurrency(
    Currency currency, {
    required bool rateKnown,
  }) => PurchaseCurrencyOption(
    id: currency.id,
    code: currency.code,
    isBase: currency.isBase,
    rateKnown: rateKnown,
  );
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.option,
    required this.selected,
    required this.rate,
    required this.baseLabel,
    required this.missingLabel,
    required this.onTap,
  });

  final PurchaseCurrencyOption option;
  final bool selected;
  final double? rate;
  final String baseLabel;
  final String missingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final borderColor = !option.isBase && !option.rateKnown
        ? colors.warning.withValues(alpha: 0.8)
        : selected
        ? scheme.primary.withValues(alpha: 0.55)
        : scheme.outlineVariant.withValues(alpha: 0.5);
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: selected ? 1.4 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                option.code,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
              if (option.isBase) ...[
                const SizedBox(width: 6),
                Text(
                  baseLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ] else if (rate != null && rate! > 0) ...[
                const SizedBox(width: 6),
                Text(
                  AmountText.format(rate!, 4),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFeatures: FinText.tabularNums,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ] else if (selected && !option.rateKnown) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: colors.warning,
                ),
                const SizedBox(width: 3),
                Text(
                  missingLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
