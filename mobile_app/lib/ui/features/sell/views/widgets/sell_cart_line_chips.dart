/// رقائق سطر السلة: شارة الكمية المجانية (بونص — R16-a)، زر السعر،
/// ورقاقة خصم السطر.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import 'sell_widgets.dart';

/// شارة الكمية المجانية (بونص — R16-a): «+N مجاني» **تظهر حصراً عند
/// freeQty>0** (ديناميكية بلا أي إعدادات — لا وجود لها حين لا بونص)؛
/// نقرة تفتح محرر السطر الموحّد (الصفر يمسح البونص هناك).
class SellBonusQtyChip extends StatelessWidget {
  const SellBonusQtyChip({
    super.key,
    required this.freeQty,
    required this.onTap,
  });

  final double freeQty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return InkWell(
      key: const Key('sell_line_bonus_chip'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.positiveContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.redeem_rounded,
              size: 15,
              color: colors.onPositiveContainer,
            ),
            const SizedBox(width: 4),
            Text(
              l10n.bonusQtyChipValue(sellQtyText(freeQty)),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.onPositiveContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellPriceButton extends StatelessWidget {
  const SellPriceButton({super.key, required this.price, required this.onTap});

  final double price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmountText(
              amount: price,
              decimals: price == price.truncateToDouble() ? 0 : 2,
            ),
            Text(
              l10n.sellUnitPriceLabel,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class SellLineDiscountChip extends StatelessWidget {
  const SellLineDiscountChip({
    super.key,
    required this.type,
    required this.value,
    required this.onTap,
  });

  final SaleDiscountType type;
  final double value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final label = value <= 0
        ? l10n.sellLineDiscountNone
        : type == SaleDiscountType.percent
        ? l10n.sellLineDiscountPercent(value.toStringAsFixed(0))
        : l10n.sellLineDiscountAmount(value.toStringAsFixed(2));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value > 0
              ? colors.negativeContainer
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value > 0 ? Icons.discount_rounded : Icons.add_rounded,
              size: 15,
              color: value > 0 ? colors.onNegativeContainer : null,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: value > 0 ? colors.onNegativeContainer : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
