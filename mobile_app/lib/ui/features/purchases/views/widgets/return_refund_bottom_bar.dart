/// الشريط السفلي لطور بنود المرتجع — قيمة المرتجع الحية + زر الترحيل
/// (R19-D3c — مستخرج حرفياً من `returns_screen.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../view_models/returns_view_model.dart';
import 'return_refund_sheet.dart';

/// الشريط السفلي لطور البنود — قيمة المرتجع الحية + زر الترحيل.
class ReturnRefundBottomBar extends StatelessWidget {
  const ReturnRefundBottomBar({
    super.key,
    required this.vm,
    required this.isSale,
  });

  final ReturnFlowVm vm;
  final bool isSale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final state = vm.state;
    final refundTotal = state.refundTotal;
    final canPost = state.hasSelection && !state.posting;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: colors.cardBorder, width: 1)),
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
                  Expanded(
                    child: Text(
                      l10n.retRefundTotalLabel,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  AmountText(
                    amount: refundTotal,
                    size: AmountSize.large,
                    decimals: refundTotal == refundTotal.truncateToDouble()
                        ? 0
                        : 2,
                  ),
                  if (state.selected?.currencyCode != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      state.selected!.currencyCode!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('ret_post_button'),
                onPressed: canPost ? () => _openRefundSheet(context) : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                icon: const Icon(Icons.undo_rounded),
                label: Text(l10n.retPostButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRefundSheet(BuildContext context) async {
    // النموذج الحقيقي (بيع/شراء) لاستدعاء الترحيل الصحيح.
    final SaleReturnViewModel? saleVm = isSale
        ? context.read<SaleReturnViewModel>()
        : null;
    final PurchaseReturnViewModel? purchaseVm = isSale
        ? null
        : context.read<PurchaseReturnViewModel>();
    final state = vm.state;
    final selected = state.selected;
    if (selected == null || (saleVm == null && purchaseVm == null)) return;
    final l10n = AppLocalizations.of(context)!;
    final partyLabel =
        selected.partyName ??
        (isSale ? l10n.sellCashCustomer : l10n.purSupplierRequired);
    final refundTotal = state.refundTotal;

    final posted = await showReturnRefundSheet(
      context,
      refundTotal: refundTotal,
      decimals: 2,
      currencyCode: selected.currencyCode,
      partyLabel: partyLabel,
      cashOnly: !selected.hasParty,
      onConfirm: (cash, method) => saleVm != null
          ? saleVm.post(refundCash: cash, method: method)
          : purchaseVm!.post(refundCash: cash, method: method),
    );
    if (posted) {
      await vm.startNewReturn();
    }
  }
}
