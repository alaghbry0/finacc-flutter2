/// إيصال نجاح الحركة السريعة — مستخرج حرفياً من `quick_movement_sheet.dart`
/// (R20-D3d؛ كان جسم `_buildReceipt` و`_ReceiptRow` الخاص به).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/quick_movement_view_model.dart';
import 'cash_widgets.dart';

/// إيصال نجاح الحركة: المبلغ الكبير + الصندوقان + وصول المحوّل للهدف
/// عند اختلاف العملتين + أزرار «حركة جديدة»/«تم».
class QuickMovementReceiptView extends StatelessWidget {
  const QuickMovementReceiptView({
    super.key,
    required this.vm,
    required this.receipt,
    required this.onStartAnother,
  });

  final QuickMovementViewModel vm;
  final QuickMovementReceipt receipt;

  /// يصفّر المدخلات ويعود للنموذج لحركة تالية.
  final VoidCallback onStartAnother;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final targetCode = vm.selectedTargetBox?.box.currencyCode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CashSheetDragHandle(),
        const SizedBox(height: 14),
        FinCard(
          accent: colors.positive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: colors.positive,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.cashQmReceiptTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AmountText(amount: receipt.amount, size: AmountSize.large),
                  const SizedBox(width: 8),
                  Text(
                    receipt.currencyCode,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ReceiptRow(
                icon: Icons.account_balance_wallet_rounded,
                label: l10n.cashQmSourceBoxLabel,
                value: receipt.sourceBoxName,
              ),
              if (receipt.targetBoxName != null)
                _ReceiptRow(
                  icon: Icons.account_balance_rounded,
                  label: l10n.cashQmTargetBoxLabel,
                  value: receipt.targetBoxName!,
                ),
              if (receipt.targetAmount != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.currency_exchange_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.cashQmReceiptArrived,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      AmountText(
                        amount: receipt.targetAmount!,
                        showSignMarker: false,
                      ),
                      if (targetCode != null && targetCode.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          targetCode,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onStartAnother,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.post_add_rounded),
          label: Text(l10n.cashQmNewMovement),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonDone),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
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
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
