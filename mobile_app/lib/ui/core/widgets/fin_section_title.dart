/// FinSectionTitle — عنوان قسم موحد (W4/R17-b — تدقيق R16 §2.1 عائلة
/// #13): أيقونة داخل حاوية مصبوغة 28×28 + نص عريض، مع trailing اختياري.
/// كانت أربعة تطبيقات خاصة (InventorySectionTitle وPartiesSectionTitle
/// و_SectionHeader بمركز التقارير و_SectionTitle بالإعدادات) فوحّدت
/// واحدة بالنواة بالنمط السائد (الحاوية المصبوغة)؛ أقسام مركز التقارير
/// اعتمدت النمط الموحد بترقيم أسطرها الأصلي محفوظاً بحشو المكالمة.
library;

import 'package:flutter/material.dart';

import '../theme/fin_tokens.dart';

/// عنوان قسم داخل الشاشات — أيقونة داخل حاوية مصبوغة + نص عريض.
class FinSectionTitle extends StatelessWidget {
  const FinSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;

  /// عنصر ذيل اختياري (شارة عدّاد أو زر) بنهاية السطر.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(FinRadius.chip),
          ),
          child: Icon(icon, size: 16, color: scheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
