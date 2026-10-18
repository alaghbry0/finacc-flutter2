/// سطور بطاقات تقرير الأرباح (عنوان القسم وسطر البند) — مستخرجة
/// حرفياً من `profit_report_screen.dart` (R20-D3d؛ كانت `_SectionLabel`
/// و`_ProfitRow`).
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';

/// عنوان قسم داخل بطاقة البنود.
class ProfitReportSectionLabel extends StatelessWidget {
  const ProfitReportSectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: scheme.primary),
      ),
    );
  }
}

/// سطر بند واحد: التسمية + المبلغ بإشارته الملوّنة (+/−).
class ProfitReportRow extends StatelessWidget {
  const ProfitReportRow({
    super.key,
    required this.label,
    required this.amount,
    required this.sign,
    required this.decimals,
    this.strong = false,
    this.trailing,
  });

  final String label;
  final double amount;
  final FinSign sign;
  final int decimals;

  /// سطر مجمع قوي (صافي المبيعات/التكلفة) — عريض بفاصل علوي.
  final bool strong;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: strong ? 8 : 2, bottom: 2),
      child: Column(
        children: [
          if (strong)
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: strong
                        ? Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w800)
                        : Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                ?trailing,
                AmountText(
                  amount: amount.abs(),
                  sign: sign,
                  size: strong ? AmountSize.large : AmountSize.row,
                  decimals: decimals,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
