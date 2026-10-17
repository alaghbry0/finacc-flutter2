/// بطاقة سطر سلة واحدة — qty stepper + سعر قابل للتعديل + خصم سطر +
/// إجمالي السطر الحي + «المتاح: N» بتحذير التجاوز (FR-02-02) + حذف بسحب.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/sell_cart_view_model.dart';
import 'sell_cart_line_chips.dart';
import 'sell_widgets.dart';

class SellCartLineCard extends StatelessWidget {
  const SellCartLineCard({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellCartViewModel>();
    final state = vm.state;
    if (index >= state.lines.length) return const SizedBox.shrink();
    final line = state.lines[index];
    final pricedLine = vm.pricedCart?.lines[index];
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final netFinal = pricedLine?.netFinal ?? line.qty * line.unitPrice;

    return Dismissible(
      key: ValueKey('cart_line_${line.productId}'),
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
        // R16-a: نقرة صف السطر تفتح محرر السطر الموحّد (الكمية/الكمية
        // المجانية/السعر/الخصم) — عناصر التحكم الداخلية (الدرّج/السعر/
        // الخصم) تسبق هذه النقرة داخل ساحة الإيماءات.
        onTap: () => _openLineEditor(context, vm, index),
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
                    borderRadius: BorderRadius.circular(FinRadius.control),
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
                      if (line.availableQty != null)
                        Text(
                          line.exceedsAvailable
                              ? l10n.sellLineOverAvailable(
                                  sellQtyText(line.availableQty!),
                                )
                              : l10n.sellLineAvailable(
                                  sellQtyText(line.availableQty!),
                                ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: line.exceedsAvailable
                                    ? colors.negative
                                    : scheme.onSurfaceVariant,
                                fontWeight: line.exceedsAvailable
                                    ? FontWeight.w800
                                    : FontWeight.w400,
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
                    AmountText(amount: netFinal, decimals: _decimals(netFinal)),
                    Text(
                      l10n.sellLineTotal,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Builder(
              // R16-a — ثورة الكميات المجانية: شارة «(+N مجاني)» تظهر
              // **حصراً عندما freeQty>0** (ديناميكياً بلا أي شرط إعدادات)،
              // وحين تظهر ينتقل السعر (ومعه الخصم عند إظهار الخصومات)
              // لسطر مستقل — صف الكمية + الشارة + السعر معاً يفيض 35px
              // على 390dp (خلل كشفه اختبار UX-4-finish)؛ بلا بونص يبقى
              // الصف الواحد كما اليوم حرفياً. إدخال البونص دائم التوفر
              // بمحرر السطر الموحّد (نقرة على صف السطر).
              builder: (context) {
                Future<void> editDiscount() async {
                  final result = await showDiscountEditSheet(
                    context,
                    title: l10n.sellLineDiscountTitle(line.name),
                    initialType: line.discountType,
                    initialValue: line.discountValue,
                  );
                  if (result != null) {
                    vm.setLineDiscount(index, result.$1, result.$2);
                  }
                }

                Future<void> editQty() async {
                  // R17-a — نقرة قيمة الكمية: تحرير رقمي فوري (نقرة واحدة +
                  // كتابة) بدل فتح محرر السطر الكامل — نفس قيود setQty
                  // (> 0 ورقم سليم) وتجاوز المتاح يبقى بسياسة التفضيلات
                  // (warn بصرياً / block عند الترحيل) كما بمحرر السطر.
                  final value = await showNumberEditSheet(
                    context,
                    title: l10n.sellQtyEditTitle(line.name),
                    initial: line.qty,
                    confirmLabel: l10n.commonConfirm,
                    allowZero: false,
                    decimals: 3,
                    icon: Icons.edit_outlined,
                  );
                  if (value != null && value > 0) {
                    vm.setQty(index, value);
                  }
                }

                Future<void> editPrice() async {
                  final value = await showNumberEditSheet(
                    context,
                    title: l10n.sellEditPriceTitle(line.name),
                    initial: line.unitPrice,
                    confirmLabel: l10n.commonConfirm,
                    icon: Icons.sell_outlined,
                  );
                  if (value != null) {
                    vm.setUnitPrice(index, value);
                  }
                }

                final priceButton = SellPriceButton(
                  price: line.unitPrice,
                  onTap: editPrice,
                );
                final discountChip = SellLineDiscountChip(
                  type: line.discountType,
                  value: line.discountValue,
                  onTap: editDiscount,
                );
                final hasBonus = line.freeQty > 0.000001;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        QtyStepper(
                          qty: line.qty,
                          onChanged: (qty) => vm.setQty(index, qty),
                          onValueTap: editQty,
                        ),
                        // الشارة الديناميكية: عند وجود بونص حصراً — نقرة
                        // تفتح محرر السطر (الحقل دائم التوفر هناك).
                        if (hasBonus) ...[
                          const SizedBox(width: 8),
                          SellBonusQtyChip(
                            freeQty: line.freeQty,
                            onTap: () => _openLineEditor(context, vm, index),
                          ),
                        ],
                        if (!hasBonus) ...[
                          const Spacer(),
                          priceButton,
                          // UX-2a — `sale.show_discounts` = off: خصم السطر
                          // يختفي (الكاشير المبسّط بلا خصومات) والحسابات
                          // مستمرة كالمعتاد.
                          if (state.showDiscounts) ...[
                            const SizedBox(width: 8),
                            discountChip,
                          ],
                        ],
                      ],
                    ),
                    // مع البونص: السعر والخصم بسطر مستقل — السعر بنهاية
                    // الصف (نفس موضعه دائماً) والخصم بجواره.
                    if (hasBonus) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Spacer(),
                          priceButton,
                          if (state.showDiscounts) ...[
                            const SizedBox(width: 8),
                            discountChip,
                          ],
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// يفتح محرر السطر الموحّد (R16-a): الكمية/الكمية المجانية/السعر/الخصم
  /// — الدخول من نقرة صف السطر أو شارة البونص، وحقل البونص دائم التوفر
  /// هناك بلا أي بوابة.
  Future<void> _openLineEditor(
    BuildContext context,
    SellCartViewModel vm,
    int index,
  ) async {
    final state = vm.state;
    if (index < 0 || index >= state.lines.length) return;
    final line = state.lines[index];
    final l10n = AppLocalizations.of(context)!;
    final result = await showSellLineEditSheet(
      context,
      title: l10n.sellLineEditTitle(line.name),
      initialQty: line.qty,
      initialFreeQty: line.freeQty,
      initialPrice: line.unitPrice,
      initialDiscountType: line.discountType,
      initialDiscountValue: line.discountValue,
    );
    if (result == null) return;
    final (qty, freeQty, price, discountType, discountValue) = result;
    if (qty != line.qty) {
      vm.setQty(index, qty);
    }
    if (freeQty != line.freeQty) {
      vm.setFreeQty(index, freeQty);
    }
    if (price != line.unitPrice) {
      vm.setUnitPrice(index, price);
    }
    if (discountType != line.discountType ||
        discountValue != line.discountValue) {
      vm.setLineDiscount(index, discountType, discountValue);
    }
  }

  static int _decimals(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}
