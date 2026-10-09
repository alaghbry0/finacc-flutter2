/// StatTile — DS-19: بلاطة إحصائية (عنوان صغير + رقم كبير + دلالة اتجاه).
///
/// تُستخدم في بطاقات الداشبورد الأربع (مبيعات اليوم، أرباح اليوم، فواتير
/// اليوم، صافي الصندوق — FR-09-01).
library;

import 'package:flutter/material.dart';

import '../../../../domain/services/numerals.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'amount_text.dart';
import 'numerals_scope.dart';

/// بلاطة إحصائية للداشبورد.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.sign = FinSign.neutral,
    this.decimals = 2,
    this.isCount = false,
    this.onTap,
  });

  /// التسمية الصغيرة.
  final String label;

  /// القيمة (مبلغ أو عدد).
  final double value;

  /// أيقونة البلاطة — علامة غير لونية مرافقة للدلالة (§6.1).
  final IconData icon;

  /// دلالة المبلغ (إيجابي/سلبي/محايد).
  final FinSign sign;

  /// منازل عشرية للمبالغ.
  final int decimals;

  /// عرض كعدّد صرف (بلا فواصل عشرية) — لعدّاد الفواتير.
  final bool isCount;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final tileColor = switch (sign) {
      FinSign.incoming => colors.positiveContainer,
      FinSign.outgoing => colors.negativeContainer,
      FinSign.neutral => scheme.surfaceContainerLow,
    };
    final iconColor = switch (sign) {
      FinSign.incoming => colors.onPositiveContainer,
      FinSign.outgoing => colors.onNegativeContainer,
      FinSign.neutral => scheme.onSurfaceVariant,
    };
    // لون الخط الدلالي العلوي — هوية لكل بلاطة دون ضجيج.
    final accent = switch (sign) {
      FinSign.incoming => colors.positive,
      FinSign.outgoing => colors.negative,
      FinSign.neutral => scheme.primary.withValues(alpha: 0.75),
    };
    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 19, color: iconColor),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isCount)
                      // عدّد صرف (عدد الفواتير) بأرقام النظام الحي
                      // (UX-2b: كان toInt().toString() غربياً ثابتاً بينما
                      // الجوار يحترم display.numerals عبر NumeralsScope).
                      Text(
                        NumeralsScope.of(context)
                            ? Numerals.toArabicIndic(value.toInt().toString())
                            : value.toInt().toString(),
                        style: FinText.amountLarge(
                          Theme.of(context).colorScheme.onSurface,
                        ),
                      )
                    else
                      AmountText(
                        amount: value,
                        sign: sign,
                        size: AmountSize.large,
                        decimals: decimals,
                        showSignMarker: sign != FinSign.neutral,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // شريط دلالي علوي رفيع (3px) بتدرج متلاشٍ نحو اليسار.
              Positioned(
                top: 0,
                right: 0,
                left: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [accent, accent.withValues(alpha: 0.0)],
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
