/// معاينة حية لحركة سريعة — مستخرجة حرفياً من `quick_movement_sheet.dart`
/// (R20-D3d؛ كانت `_MovementPreview`): رصيد المصدر بعد الحركة + تحذير
/// السالب (FR-04-09) + وصول المبلغ المحوّل للهدف عند اختلاف العملتين.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../view_models/quick_movement_view_model.dart';

/// معاينة حية: رصيد المصدر بعد الحركة + تحذير السالب (FR-04-09) +
/// وصول المبلغ المحوّل للهدف عند اختلاف العملتين.
class QuickMovementPreview extends StatelessWidget {
  const QuickMovementPreview({
    super.key,
    required this.vm,
    required this.projected,
    required this.willGoNegative,
  });

  final QuickMovementViewModel vm;
  final double? projected;
  final bool willGoNegative;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final targetAmount = vm.projectedTargetAmount;
    final target = vm.selectedTargetBox;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (projected != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.functions_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.cashQmProjectedSource,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                AmountText(
                  amount: projected!.abs(),
                  // DS-18: علامة غير لونية إلزامية — رصيد متوقع سالب يظهر
                  // «−2,500.00» لا «2,500.00» بحمراء فقط (إصلاح جولة 13).
                  sign: projected! < 0 ? FinSign.outgoing : FinSign.neutral,
                ),
                const SizedBox(width: 4),
                Text(
                  vm.selectedBox?.box.currencyCode ?? '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: projected! < 0 ? colors.negative : null,
                  ),
                ),
              ],
            ),
          ),
        if (targetAmount != null && target != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.currency_exchange_rounded,
                  size: 16,
                  color: colors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.cashQmArrivesAtTarget(
                      AmountText.format(targetAmount, 2),
                      target.box.name,
                      target.box.currencyCode,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        // تحذير بصري متحرك — لا منع أبداً (FR-04-09).
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: willGoNegative
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.negativeContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colors.negative,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.cashQmNegativeWarning,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onNegativeContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
