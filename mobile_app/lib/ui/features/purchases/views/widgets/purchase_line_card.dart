/// بطاقة سطر شراء واحدة — qty stepper + تكلفة الوحدة + خصم سطر + إجمالي
/// السطر الحي + الرصيد الحالي (معلوماتي) + **دفعة واردة** (رقم + صلاحية)
/// للأصناف المتتبعة + حذف بسحب.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/models/purchase.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/purchase_cart_view_model.dart';
import 'purchase_incoming_batch_section.dart';
import 'purchase_widgets.dart';

/// بطاقة سطر شراء واحدة — qty stepper + تكلفة الوحدة + خصم سطر + إجمالي
/// السطر الحي + الرصيد الحالي (معلوماتي) + **دفعة واردة** (رقم + صلاحية)
/// للأصناف المتتبعة + حذف بسحب.
class PurchaseLineCard extends StatelessWidget {
  const PurchaseLineCard({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseCartViewModel>();
    final state = vm.state;
    if (index >= state.lines.length) return const SizedBox.shrink();
    final line = state.lines[index];
    final pricedLine = vm.pricedCart?.lines[index];
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final netFinal = pricedLine?.netFinal ?? line.qty * line.unitCost;

    return Dismissible(
      key: ValueKey('purchase_line_${line.productId}_$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => vm.removeLine(index),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: colors.negativeContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_rounded, color: colors.onNegativeContainer),
      ),
      child: FinCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (line.isService ? scheme.tertiary : scheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    line.isService
                        ? Icons.miscellaneous_services_rounded
                        : Icons.inventory_2_rounded,
                    size: 19,
                    color: line.isService ? scheme.tertiary : scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (line.currentStock != null)
                        Text(
                          l10n.purLineStock(purQtyText(line.currentStock!)),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontFeatures: FinText.tabularNums,
                              ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(
                      amount: netFinal,
                      decimals: netFinal == netFinal.truncateToDouble() ? 0 : 2,
                    ),
                    Text(
                      l10n.sellLineTotal,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // R16-a — بونص الشراء: حقل «كمية مجانية» صغير بجانب الكمية
            // **دائم التوفر للإدخال** (لا بوابة إعدادات)؛ وحين وجوده تعرض
            // الشارة «+N مجاني». السعر والخصم بسطر مستقل أسفلها — صف
            // الكمية + الشارة + التكلفة + الخصم معاً يفيض على 390dp
            // (نفس خلل الكاشير الموثّق بـ UX-4-finish).
            Row(
              children: [
                PurchaseQtyStepper(
                  qty: line.qty,
                  onChanged: (qty) => vm.setQty(index, qty),
                  // R17-a — نقرة قيمة الكمية: تحرير رقمي فوري بنفس قيود
                  // setQty (> 0) — الكاشير يكتب 7 أو 2.5 مباشرة.
                  onValueTap: () async {
                    final value = await showPurchaseNumberEditSheet(
                      context,
                      title: l10n.purchaseQtyEditTitle(line.name),
                      initial: line.qty,
                      confirmLabel: l10n.commonConfirm,
                      allowZero: false,
                      decimals: 3,
                      icon: Icons.edit_outlined,
                    );
                    if (value != null && value > 0) {
                      vm.setQty(index, value);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _PurchaseBonusChip(
                  freeQty: line.freeQty,
                  onTap: () async {
                    final value = await showPurchaseNumberEditSheet(
                      context,
                      title: l10n.purBonusEditTitle(line.name),
                      initial: line.freeQty,
                      confirmLabel: l10n.commonConfirm,
                      decimals: 3,
                      icon: Icons.redeem_outlined,
                    );
                    if (value != null) {
                      vm.setFreeQty(index, value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                _CostButton(
                  cost: line.unitCost,
                  onTap: () async {
                    final value = await showPurchaseNumberEditSheet(
                      context,
                      title: l10n.purEditCostTitle(line.name),
                      initial: line.unitCost,
                      confirmLabel: l10n.commonConfirm,
                      icon: Icons.sell_outlined,
                    );
                    if (value != null) {
                      vm.setUnitCost(index, value);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _LineDiscountChip(
                  type: line.discountType,
                  value: line.discountValue,
                  onTap: () async {
                    final result = await showPurchaseDiscountEditSheet(
                      context,
                      title: l10n.sellLineDiscountTitle(line.name),
                      initialType: line.discountType,
                      initialValue: line.discountValue,
                    );
                    if (result != null) {
                      vm.setLineDiscount(index, result.$1, result.$2);
                    }
                  },
                ),
              ],
            ),
            if (!line.isService && line.trackBatches) ...[
              const SizedBox(height: 10),
              PurchaseIncomingBatchSection(index: index),
            ],
          ],
        ),
      ),
    );
  }
}

/// حقل الكمية المجانية (بونص) الصغير بجوار الكمية (R16-a) — **دائم
/// التوفر للإدخال**: «بونص» عند الصفر و«+N مجاني» عند وجوده؛ نقرة تفتح
/// محرر الرقم السفلي (الصفر يمسح). البونص لا يدخل المستحق للمورد —
/// المستلم الكلي (qty + freeQty) يدخل المخزون ويخفّض WAC.
class _PurchaseBonusChip extends StatelessWidget {
  const _PurchaseBonusChip({required this.freeQty, required this.onTap});

  final double freeQty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final hasBonus = freeQty > 0.000001;
    final label = hasBonus
        ? l10n.bonusQtyChipValue(purQtyText(freeQty))
        : l10n.bonusQtyChipEmpty;
    return InkWell(
      key: const Key('pur_line_bonus_chip'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hasBonus
              ? colors.positiveContainer
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.redeem_rounded,
              size: 15,
              color: hasBonus ? colors.onPositiveContainer : null,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: hasBonus ? colors.onPositiveContainer : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر تكلفة الوحدة — قابل للنقر للتعديل.
class _CostButton extends StatelessWidget {
  const _CostButton({required this.cost, required this.onTap});

  final double cost;
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
              amount: cost,
              decimals: cost == cost.truncateToDouble() ? 0 : 2,
            ),
            Text(
              l10n.purUnitCostLabel,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineDiscountChip extends StatelessWidget {
  const _LineDiscountChip({
    required this.type,
    required this.value,
    required this.onTap,
  });

  final PurchaseDiscountType type;
  final double value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final label = value <= 0
        ? l10n.sellLineDiscountNone
        : type == PurchaseDiscountType.percent
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
