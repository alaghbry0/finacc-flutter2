/// منظومة الخطوط — Almarai (المراعي) SRS §0.3 + DS-18n (أرقام جدولية).
///
/// - خط موحد بجميع الأوزان الأربعة مضمناً محلياً (`assets/fonts/almarai/`).
/// - **الأرقام الجدولية إلزامية لكل مبلغ** (DS-18n): أرقام Almarai
///   تناسبية وبلا feature `tnum` (تدقيق UX-audit-visual)، لذا تستعمل
///   أنماط المبالغ الخط المرافق **NotoSansArabic** (أرقام جدولية
///   افتراضياً بنظامَي الأرقام 0-9 و٠-٩) بعائلة أساسية مع سلسلة fallback
///   مرتّبة تنتهي بـ Almarai — هوية النصوص العربية تبقى Almarai حصراً.
/// - الحد الأدنى المطلق 12px (جمهور يشمل كبار السن — §6.2).
library;

import 'package:flutter/material.dart';

/// أنماط النص المالية والتطبيقية.
class FinText {
  const FinText._();

  /// اسم عائلة الخط الرسمي (مضمن في pubspec).
  static const String fontFamily = 'Almarai';

  /// عائلة الخط المرافق للأرقام الجدولية — UX-2b (DS-18n).
  ///
  /// Noto Sans Arabic (OFL): أرقام جدولية افتراضياً في كل أوزانه
  /// (نفس عرض كل رقم) وبنظامَي الأرقام معاً، فتستقيم الأعمدة والمبالغ
  /// الحية (999→1000) بلا ارتجاج. لا يُستعمل إلا لأنماط المبالغ.
  static const String tabularFontFamily = 'NotoSansArabic';

  /// سلسلة fallback المرتبة لأنماط المبالغ: الرقم يُرسم من العائلة
  /// الجدولية، وكل غليف ينقصها يسقط إلى Almarai فيبقى الطابع موحداً.
  ///
  /// الترتيب حاسم: لو تصدّر Almarai القائمة لما تغيّر شيء أبداً — محرك
  /// Flutter يختار أول عائلة تغطي الغليف، وأرقام Almarai موجودة (لكن
  /// تناسبية)؛ لذا يجب أن تتصدّر العائلة الجدولية هنا.
  static const List<String> amountFontFallback = <String>[fontFamily];

  /// يحوّل أي نمط إلى نمط أرقام جدولية (للمبالغ الحية خارج AmountText).
  ///
  /// يُطبّق على الأنماط المنسوخة من الثيم — الأرقام تُرسم من
  /// [tabularFontFamily] وكل ما ينقصها يسقط إلى Almarai.
  static TextStyle withTabularDigits(TextStyle style) => style.copyWith(
    fontFamily: tabularFontFamily,
    fontFamilyFallback: amountFontFallback,
  );

  /// خاصية الأرقام الجدولية (tabular-nums) — DS-18n.
  ///
  /// تُبقى للتوافق مع الأنماط التي تصدّرها Almarai: لا feature `tnum`
  /// فيها فلا أثر (سلوك اليوم)، بينما مع [tabularFontFamily] تؤكد
  /// الجدولية (TNUM متوفر في Noto Sans Arabic).
  static const List<FontFeature> tabularNums = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// نمط المبلغ الضخم (رأس PaymentSheet/الداشبورد) — أرقام جدولية.
  static TextStyle amountDisplay(Color color) => TextStyle(
    fontFamily: tabularFontFamily,
    fontFamilyFallback: amountFontFallback,
    fontWeight: FontWeight.w800,
    fontSize: 34,
    height: 1.15,
    color: color,
    fontFeatures: tabularNums,
  );

  /// نمط المبلغ الكبير في البطاقات.
  static TextStyle amountLarge(Color color) => TextStyle(
    fontFamily: tabularFontFamily,
    fontFamilyFallback: amountFontFallback,
    fontWeight: FontWeight.w800,
    fontSize: 22,
    height: 1.2,
    color: color,
    fontFeatures: tabularNums,
  );

  /// نمط مبلغ سطر القائمة (ListRow ≥ 64dp — DS-22).
  static TextStyle amountRow(Color color) => TextStyle(
    fontFamily: tabularFontFamily,
    fontFamilyFallback: amountFontFallback,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 1.2,
    color: color,
    fontFeatures: tabularNums,
  );

  /// تسمية صغيرة فوق المبلغ.
  static TextStyle amountLabel(Color color) => TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.3,
    letterSpacing: 0.2,
    color: color,
  );

  /// يبني TextTheme كاملاً فوق Almarai (Material 3).
  static TextTheme build(ColorScheme scheme) {
    final base = TextStyle(fontFamily: fontFamily);
    return TextTheme(
      displaySmall: base.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 36,
        height: 1.15,
        color: scheme.onSurface,
      ),
      headlineMedium: base.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        height: 1.2,
        color: scheme.onSurface,
      ),
      headlineSmall: base.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        height: 1.25,
        color: scheme.onSurface,
      ),
      titleLarge: base.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        height: 1.3,
        color: scheme.onSurface,
      ),
      titleMedium: base.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        height: 1.4,
        color: scheme.onSurface,
      ),
      titleSmall: base.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        height: 1.4,
        color: scheme.onSurface,
      ),
      bodyLarge: base.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodyMedium: base.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodySmall: base.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 1.5,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: base.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        height: 1.2,
        color: scheme.onSurface,
      ),
      labelMedium: base.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 13,
        height: 1.3,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: base.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 1.3,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
