/// AccessCard — بطاقة وصول صغيرة (W2/R17-b — تدقيق R16 §2.1 عائلة #11):
/// أيقونة مصبوغة داخل حاوية + عنوان + وصف، بنقرة تنقل. كانت نسختين
/// حرفياً متطابقتين (`_AccessCard` بمحوري البيع والمشتريات) فنُقلت
/// حرفياً إلى النواة واحدة تخدم المحاور؛ مع رقاقة عدّاد اختيارية
/// (count) لم تكن مستخدمة بعد — إضافة فوقية بلا أثر عند غيابها.
library;

import 'package:flutter/material.dart';

import 'count_badge.dart';
import 'fin_card.dart';

/// بطاقة وصول صغيرة — أيقونة مصبوغة + عنوان + وصف + رقاقة عدّاد اختيارية.
class AccessCard extends StatelessWidget {
  const AccessCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  /// شارة عدّاد اختيارية بجانب العنوان (null = بلا شارة — كما اليوم).
  final int? count;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w800),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(height: 10),
            if (count != null) ...[
              Row(
                children: [
                  Expanded(child: titleText),
                  const SizedBox(width: 6),
                  CountBadge(count: count!, color: color),
                ],
              ),
            ] else
              titleText,
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
