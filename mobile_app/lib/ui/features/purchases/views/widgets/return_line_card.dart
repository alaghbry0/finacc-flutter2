/// بطاقة بند قابل للإرجاع بالمرتجع (R19-D3c — مستخرجة حرفياً من
/// `returns_screen.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/returns_view_model.dart';
import 'purchase_format.dart';
import 'purchase_qty_stepper.dart';

/// بطاقة بند قابل للإرجاع — الاسم + الكمية الأصلية/المرجعة/المتاحة +
/// مدرّج كمية الإرجاع (0..المتاح) + قيمة رد السطر عند الاختيار.
class ReturnLineCard extends StatelessWidget {
  const ReturnLineCard({
    super.key,
    required this.line,
    required this.onChanged,
  });

  final ReturnUiLine line;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final data = line.line;
    final selected = line.hasSelection;

    return FinCard(
      padding: const EdgeInsets.all(12),
      accent: selected ? colors.gold : null,
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
                  color: (selected ? scheme.primary : scheme.tertiary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  selected ? Icons.undo_rounded : Icons.inventory_2_outlined,
                  size: 19,
                  color: selected ? scheme.primary : scheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.lineDesc ?? l10n.sellDetailUnknownItem,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${l10n.retOriginalQty(purQtyText(data.originalQty))}'
                      '${data.returnedQty > 0 ? ' · ${l10n.retReturnedQty(purQtyText(data.returnedQty))}' : ''}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                    Text(
                      l10n.retAvailableQty(purQtyText(data.availableQty)),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: data.availableQty > 0
                            ? scheme.onSurfaceVariant
                            : colors.negative,
                        fontWeight: FontWeight.w700,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(
                      amount: line.lineRefund,
                      decimals:
                          line.lineRefund == line.lineRefund.truncateToDouble()
                          ? 0
                          : 2,
                    ),
                    Text(
                      l10n.retLineRefundLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
            ],
          ),
          if (data.availableQty > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                PurchaseQtyStepper(
                  qty: line.selectedQty,
                  min: 0,
                  onChanged: onChanged,
                ),
                const Spacer(),
                Text(
                  l10n.retQtyLabel,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
