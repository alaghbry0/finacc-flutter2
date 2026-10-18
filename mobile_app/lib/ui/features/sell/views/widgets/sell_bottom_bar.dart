/// الشريط السفلي الثابت للكاشير — ملخص حي + خصم الفاتورة + الدفع +
/// عرض السعر.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/models/sale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../view_models/sell_cart_view_model.dart';
import 'sell_widgets.dart';

class SellBottomBar extends StatelessWidget {
  const SellBottomBar({
    super.key,
    required this.onAddItem,
    required this.onPay,
    required this.onSaveQuotation,
    required this.onInvoiceDiscount,
  });

  final VoidCallback onAddItem;
  final VoidCallback onPay;
  final VoidCallback onSaveQuotation;
  final VoidCallback onInvoiceDiscount;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellCartViewModel>();
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final priced = vm.pricedCart;
    final hasError = vm.cartError != null;
    final canPay =
        !state.posting &&
        state.lines.isNotEmpty &&
        !hasError &&
        state.warehouseId != null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: colors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wrap لا Row: زرا «إضافة صنف/خصم الفاتورة» يلتفان لسطر ثانٍ
              // عند الشاشات الضيقة أو خطوط أعرض بدل فيض أفقي.
              //
              // UX-2a — `sale.show_discounts` = off: زر خصم الفاتورة يختفي
              // (نفس إخفاء خصم السطر أعلاه).
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: onAddItem,
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 20,
                      ),
                      label: Text(l10n.sellAddItem),
                    ),
                  ),
                  if (state.showDiscounts)
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: onInvoiceDiscount,
                        icon: Icon(
                          state.invoiceDiscountValue > 0
                              ? Icons.discount_rounded
                              : Icons.percent_rounded,
                          size: 20,
                          color: state.invoiceDiscountValue > 0
                              ? colors.negative
                              : null,
                        ),
                        label: Text(
                          state.invoiceDiscountValue > 0
                              ? (state.invoiceDiscountType ==
                                        SaleDiscountType.percent
                                    ? l10n.sellInvoiceDiscountPercent(
                                        state.invoiceDiscountValue
                                            .toStringAsFixed(0),
                                      )
                                    : l10n.sellInvoiceDiscountAmount(
                                        state.invoiceDiscountValue
                                            .toStringAsFixed(2),
                                      ))
                              : l10n.sellInvoiceDiscountButton,
                        ),
                      ),
                    ),
                ],
              ),
              if (priced != null) ...[
                const SizedBox(height: 8),
                CartTotalsPanel(
                  totals: priced.totals,
                  currencyCode: state.selectedCurrency?.code,
                ),
              ],
              if (hasError) ...[
                const SizedBox(height: 8),
                Text(
                  vm.cartError!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.negative,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: canPay ? onPay : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        textStyle: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      icon: const Icon(Icons.payments_rounded),
                      label: Text(
                        priced == null
                            ? l10n.sellPayButton
                            : l10n.sellPayButtonWithTotal(
                                AmountText.formatFor(
                                  context,
                                  priced.totals.grandTotal,
                                  priced.totals.grandTotal ==
                                          priced.totals.grandTotal
                                              .truncateToDouble()
                                      ? 0
                                      : 2,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          state.lines.isEmpty || hasError || state.posting
                          ? null
                          : onSaveQuotation,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      icon: const Icon(Icons.request_quote_rounded, size: 20),
                      label: Text(l10n.sellSaveQuotation),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
