/// صفوف تفاصيل فاتورة الشراء (R19-D3c — مستخرجة حرفياً من
/// `purchases_list_screen.dart` بلا أي تغيير دلالة): معلومة/بند/مبلغ.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../../domain/models/purchase.dart';
import 'purchase_format.dart';

class PurchaseInfoRow extends StatelessWidget {
  const PurchaseInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class PurchaseItemRow extends StatelessWidget {
  const PurchaseItemRow({super.key, required this.item});

  final PurchaseInvoiceItemLine item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.lineDesc ?? l10n.sellDetailUnknownItem,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.sellDetailQtyLabel} ${purQtyText(item.qty)} × '
                  '${AmountText.format(item.unitCost, _decimals(item.unitCost))}'
                  '${item.discountAmount > 0 ? ' · ${l10n.sellDetailDiscountLabel} ${AmountText.format(item.discountAmount, 2)}' : ''}'
                  // R16-a: البونص يظهر بجوار الكمية «+N مجاني» عند
                  // وجوده فقط (ديناميكي بلا أي إعدادات).
                  '${item.freeQty > 0.000001 ? ' · ${l10n.bonusDetailSuffix(purQtyText(item.freeQty))}' : ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
                if ((item.notes ?? '').isNotEmpty)
                  Text(
                    item.notes!,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colors.gold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AmountText(
                amount: item.lineTotal,
                decimals: _decimals(item.lineTotal),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int _decimals(double value) =>
      value == value.truncateToDouble() ? 0 : 2;
}

class PurchaseAmountRow extends StatelessWidget {
  const PurchaseAmountRow({
    super.key,
    required this.label,
    required this.value,
    this.sign = FinSign.neutral,
  });

  final String label;
  final double value;
  final FinSign sign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          AmountText(
            amount: value,
            sign: sign,
            decimals: value == value.truncateToDouble() ? 0 : 2,
          ),
        ],
      ),
    );
  }
}
