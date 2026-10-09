/// HubHeroCard — بطاقة البطولة للمحاور (W3/R17-b — تدقيق R16 §2.1
/// عائلة #10): أيقونة 52×52 داخل تدرج + عنوان/وصف داخل FinCard بشريط
/// تمييز ذهبي. كانت نسخاً يدوية بكل محاور الوحدات (البيع/المشتريات/
/// الأطراف/النقدية/التقارير/المخزون/الجرد/الوردية ×2) فاستُخرجت واحدة
/// معلمية بلا أي تغيير بصري:
/// - [iconTint]/[iconColor]: قاعدة تدرج الأيقونة ولونها (بطاقة الوردية
///   الحية خضراء بدل لون الهوية).
/// - [below]: فتحة محتوى أسفل صف البطولة بعرض البطاقة (مبالغ صافي
///   النقدية بالمحور، معادلة الوردية) — المتصل يحتفظ بمسافاته.
/// - [underSubtitle]: فتحة داخل عمود النص أسفل الوصف (مستودع الجرد).
/// عند غياب الفتحتين تُطابق البطاقة حرفياً البطولات البسيطة القائمة.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'fin_card.dart';

/// بطاقة بطولة المحور — أيقونة داخل تدرج + عنوان ووصف بلمسة ذهبية.
class HubHeroCard extends StatelessWidget {
  const HubHeroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent,
    this.iconTint,
    this.iconColor,
    this.below,
    this.underSubtitle,
  });

  final IconData icon;
  final String title;

  /// وصف البطولة (Widget — يسمح بأرقام جدولية وتنسيقات خاصة).
  final Widget subtitle;

  /// شريط التمييز العلوي — ذهبي افتراضياً (الوردية الحية خضراء).
  final Color? accent;

  /// لون قاعدة تدرج أيقونة البطولة — لون الهوية افتراضياً.
  final Color? iconTint;

  /// لون الأيقونة نفسها — onPrimary افتراضياً.
  final Color? iconColor;

  /// محتوى أسفل صف البطولة بعرض البطاقة (null = بطولة بسيطة).
  final Widget? below;

  /// محتوى داخل عمود النص أسفل الوصف (null = بلا محتوى إضافي).
  final Widget? underSubtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final tint = iconTint ?? scheme.primary;
    final heroRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tint, Color.lerp(tint, Colors.black, 0.25)!],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: iconColor ?? scheme.onPrimary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              subtitle,
              ?underSubtitle,
            ],
          ),
        ),
      ],
    );
    return FinCard(
      accent: accent ?? colors.gold,
      child: below == null
          ? heroRow
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [heroRow, below!],
            ),
    );
  }
}
