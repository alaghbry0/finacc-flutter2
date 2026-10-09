/// CountBadge — شارة عدّاد موحدة (W5/R17-b — تدقيق R16 §2.1 عائلة #15):
/// رقم بأرقام جدولية (بنظام أرقام العرض الحي) داخل كبسولة مصبوغة.
/// كانت نسختين حرفياً متطابقتين (`CountBadge` بشاشات المخزون
/// و`PartiesCountBadge` بشاشات الأطراف) فاستُخرجت واحدة بالنواة بلا
/// أي تغيير بصري أو سلوكي.
library;

import 'package:flutter/material.dart';

import '../../../domain/services/numerals.dart';
import 'numerals_scope.dart';

/// شارة عدّاد — رقم بأرقام جدولية داخل كبسولة مصبوغة.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final arabicIndic = NumeralsScope.of(context);
    final text = arabicIndic ? Numerals.toArabicIndic('$count') : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
