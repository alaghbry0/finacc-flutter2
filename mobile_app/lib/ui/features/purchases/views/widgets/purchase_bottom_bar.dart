/// الشريط السفلي الثابت لفاتورة الشراء — ملخص حي + خصم الفاتورة + زر
/// الترحيل الضخم.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/models/purchase.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../view_models/purchase_cart_view_model.dart';
import 'purchase_widgets.dart';

/// الشريط السفلي الثابت — ملخص حي + خصم الفاتورة + زر الترحيل الضخم.
class PurchaseBottomBar extends StatelessWidget {
  const PurchaseBottomBar({
    super.key,
    required this.onAddItem,
    required this.onPost,
    required this.onInvoiceDiscount,
  });

  final VoidCallback onAddItem;
  final VoidCallback onPost;
  final VoidCallback onInvoiceDiscount;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseCartViewModel>();
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final priced = vm.pricedCart;
    final hasError = vm.cartError != null;
    final supplierMissing = state.supplier == null;
    final canPost =
        !state.posting &&
        state.lines.isNotEmpty &&
        !hasError &&
        !supplierMissing;

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
              Row(
                children: [
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      key: const Key('pur_add_item_button'),
                      onPressed: onAddItem,
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 20,
                      ),
                      label: Text(l10n.purAddItem),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                                      PurchaseDiscountType.percent
                                  ? l10n.sellInvoiceDiscountPercent(
                                      state.invoiceDiscountValue
                                          .toStringAsFixed(0),
                                    )
                                  : l10n.sellInvoiceDiscountAmount(
                                      state.invoiceDiscountValue
                                          .toStringAsFixed(2),
                                    ))
                            : l10n.purInvoiceDiscountButton,
                      ),
                    ),
                  ),
                ],
              ),
              if (priced != null) ...[
                const SizedBox(height: 8),
                PurchaseTotalsPanel(
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
              if (supplierMissing) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.purSupplierRequired,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('pur_post_button'),
                onPressed: canPost ? onPost : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                icon: const Icon(Icons.local_shipping_rounded),
                label: Text(
                  priced == null
                      ? l10n.purPayButton
                      : l10n.purPayButtonWithTotal(
                          AmountText.formatFor(
                            context,
                            priced.totals.grandTotal,
                            priced.totals.grandTotal ==
                                    priced.totals.grandTotal.truncateToDouble()
                                ? 0
                                : 2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
