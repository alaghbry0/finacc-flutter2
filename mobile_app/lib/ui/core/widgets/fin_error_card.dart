/// FinErrorCard — بطاقة الخطأ الحمراء الموحدة (W1/R17-b — تدقيق R16 §2.1
/// عائلة #1): رسالة الرفض العربية كاملة (لا تُختصر) بأيقونة وشريط سلبي.
/// كانت أربع نسخ حرفية متطابقة (`_ErrorCard` بأوراق دفع البيع/الشراء
/// والمرتجع + `CashErrorCard` بالنقدية) فاستُخرجت واحدة بالنواة بلا أي
/// تغيير بصري أو سلوكي.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'fin_card.dart';

/// بطاقة خطأ داخل النوافذ والنماذج — رسالة الرفض كاملة بحمراء.
class FinErrorCard extends StatelessWidget {
  const FinErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return FinCard(
      padding: const EdgeInsets.all(14),
      accent: colors.negative,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.negative, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
