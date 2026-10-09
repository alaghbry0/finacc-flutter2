/// InfoNote — بطاقة ملاحظة معلوماتية خفيفة موحدة (W5/R17-b — تدقيق R16
/// §2.1 عائلة #14): أيقونة ذهبية (أو تحذيرية) + نص خافت داخل FinCard.
/// كانت نسختين (`InfoNoteCard` بشاشات المخزون و`PartiesInfoNote` بشاشات
/// الأطراف — والثانية بنبرة تحذيرية اختيارية) فوُحّدت واحدة بالنواة
/// تحافظ على المعاملَين بلا أي تغيير بصري.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'fin_card.dart';

/// بطاقة ملاحظة معلوماتية خفيفة (شرح/تأجيل) داخل الشاشات.
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.icon,
    required this.message,
    this.warning = false,
  });

  final IconData icon;
  final String message;

  /// نبرة تحذيرية (كهرمانية) بدل الذهبية الافتراضية.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: warning ? colors.warning : colors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
