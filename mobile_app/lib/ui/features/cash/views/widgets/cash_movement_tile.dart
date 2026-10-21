/// صف حركة صندوق (المحتوى بلا إطار — يُستخدم داخل بطاقة أو قائمة):
/// أيقونة نوع ملونة + تسمية/رقم السند + التاريخ والصندوقين + مبلغ موقّع
/// ملون (وارد أخضر/صادر أحمر — §6.1) + رقائق الملغاة/الإبطال.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import 'cash_format.dart';

class CashMovementTile extends StatelessWidget {
  const CashMovementTile({
    super.key,
    required this.movement,
    this.dimmed = false,
  });

  final CashMovementRow movement;

  /// تخفيت بصري (حركة ملغاة).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final type = movement.type;
    final inflow = cashTxInflowOnMainBox(type);
    final tone = cashTxTone(scheme, colors, type);
    final sign = inflow ? FinSign.incoming : FinSign.outgoing;

    final title = cashTxLabel(l10n, type);
    final subtitle = StringBuffer(cashFormatDate(movement.txDate))
      ..write(' · ')
      ..write(movement.cashboxName);
    if (movement.toCashboxName != null) {
      subtitle
        ..write(' · ')
        ..write(l10n.cashMovementFieldTo)
        ..write(' ')
        ..write(movement.toCashboxName);
    }
    final context2 =
        movement.customerName ??
        movement.supplierName ??
        movement.expenseCategoryName ??
        movement.description;

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(cashTxIcon(type), size: 20, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // V6-C: رقم السند مرن كالعنوان — كان بلا قيد فيفيض
                    // الصف 61px عند الأسماء الطويلة (كُشف بأول تغطية ويدجت
                    // تصل لمحور النقدية بعد ترحيل سند).
                    if (movement.voucherNo != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          movement.voucherNo!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontFeatures: FinText.tabularNums,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (movement.isVoided) ...[
                      const SizedBox(width: 6),
                      StatusChipLite(
                        label: l10n.cashMovementsVoidedChip,
                        color: colors.negative,
                      ),
                    ] else if (movement.isReversal) ...[
                      const SizedBox(width: 6),
                      StatusChipLite(
                        label: l10n.cashMovementsReversalChip,
                        color: colors.neutral,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle.toString(),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontFeatures: FinText.tabularNums),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (context2 != null && context2.trim().isNotEmpty)
                  Text(
                    context2,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  AmountText(amount: movement.amount, sign: sign),
                  const SizedBox(width: 4),
                  Text(
                    movement.currencyCode,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: inflow ? colors.positive : colors.negative,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// رقاقة حالة مصغّرة (ملغاة/إبطال) — أخف من StatusChip لصفوف القوائم.
class StatusChipLite extends StatelessWidget {
  const StatusChipLite({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
