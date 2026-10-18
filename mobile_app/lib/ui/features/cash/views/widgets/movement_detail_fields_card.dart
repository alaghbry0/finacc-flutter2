/// بطاقة حقول تفاصيل حركة الصندوق (التاريخ/الصندوق/السند/الطرف/الفئة/
/// السعران/فرق الصرف/الوصف) — مستخرجة حرفياً من `movement_detail_sheet.dart`
/// (R20-D3d؛ كان جسم بطاقة الحقول و`_DetailRow` و`_RateRow` الخاصان بها).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import 'cash_format.dart';

/// بطاقة حقول الحركة — كل سطر تسمية/قيمة بتنسيق جدولي، وفرق الصرف
/// بإشارته الملوّنة، والوصف عند وجوده.
class MovementDetailFieldsCard extends StatelessWidget {
  const MovementDetailFieldsCard({super.key, required this.movement});

  final CashMovementRow movement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailRow(
            label: l10n.cashMovementFieldDate,
            value: cashFormatDate(movement.txDate),
          ),
          _DetailRow(
            label: l10n.cashMovementFieldBox,
            value: '${movement.cashboxName} (${movement.currencyCode})',
          ),
          if (movement.toCashboxName != null)
            _DetailRow(
              label: l10n.cashMovementFieldTo,
              value: movement.toCashboxName!,
            ),
          if (movement.voucherNo != null)
            _DetailRow(
              label: l10n.cashMovementFieldVoucher,
              value: movement.voucherNo!,
            ),
          if (movement.customerName != null)
            _DetailRow(
              label: l10n.cashMovementFieldParty,
              value: movement.customerName!,
            ),
          if (movement.supplierName != null)
            _DetailRow(
              label: l10n.cashMovementFieldParty,
              value: movement.supplierName!,
            ),
          if (movement.expenseCategoryName != null)
            _DetailRow(
              label: l10n.cashMovementFieldCategory,
              value: movement.expenseCategoryName!,
            ),
          _RateRow(
            label: l10n.cashMovementFieldRate,
            value: movement.exchangeRate,
          ),
          if (movement.settlementRate != null)
            _RateRow(
              label: l10n.cashMovementFieldSettlement,
              value: movement.settlementRate!,
            ),
          if ((movement.fxGainLoss.abs()) > 0.005)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.cashMovementFieldFx,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  AmountText(
                    amount: movement.fxGainLoss,
                    sign: movement.fxGainLoss > 0
                        ? FinSign.incoming
                        : FinSign.outgoing,
                  ),
                ],
              ),
            ),
          if (movement.description != null &&
              movement.description!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.cashMovementFieldDescription,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    movement.description!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: FinText.tabularNums,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Text(
            AmountText.format(value, 4),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: FinText.tabularNums,
            ),
          ),
        ],
      ),
    );
  }
}
