/// التوكنز اللونية الدلالية — SRS §6.1 (الدلالات الإدراكية الملزمة).
///
/// القاعدة: الوارد/القبض/الربح = إيجابية، الصادر/الدفع = سلبية، الآجل/
/// المستحق = تحذيرية، المعلّق/المسودة = محايدة — **لكل دلالة لونية علامة
/// غير لونية مرافقة** (سهم/إشارة/نص حالة — ComponentBehavior).
///
/// **V3 — هوية Simple Invoice Manager**: البذرة صارت `0xFF1976D2`
/// (أزرق Material) والتوكنز أعيدت معايرتها إلى لوحة النموذج الأولي
/// المرفق من المالك: أخضر «مدفوع» #2E7D32 على #E8F5E9، برتقالي
/// «جزئي» #A05000 على #FFF3E0، رمادي مزرق #546E7A على #ECEFF1 —
/// كل الأزواج النصية تتحقق ≥ 4.5:1 (يفحصها اختبار
/// `ui/theme_contrast_test.dart` — بوابة DS-30).
library;

import 'package:flutter/material.dart';

/// مجموعة توكنز دلالية كاملة لوضع واحد.
class FinColors {
  const FinColors({
    required this.brightness,
    required this.positive,
    required this.onPositive,
    required this.positiveContainer,
    required this.onPositiveContainer,
    required this.negative,
    required this.onNegative,
    required this.negativeContainer,
    required this.onNegativeContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.neutral,
    required this.neutralContainer,
    required this.onNeutralContainer,
    required this.gold,
    required this.scaffoldAccent,
    required this.cardBorder,
    required this.divider,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.successGlow,
    required this.whatsappContainer,
    required this.onWhatsappContainer,
  });

  final Brightness brightness;

  /// دلالة إيجابية (وارد/قبض/ربح).
  final Color positive;
  final Color onPositive;
  final Color positiveContainer;
  final Color onPositiveContainer;

  /// دلالة سلبية (صادر/دفع/خصم).
  final Color negative;
  final Color onNegative;
  final Color negativeContainer;
  final Color onNegativeContainer;

  /// دلالة تحذيرية (آجل/مستحق/متأخر).
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  /// دلالة محايدة (معلّق/مسودة).
  final Color neutral;
  final Color neutralContainer;
  final Color onNeutralContainer;

  /// اللمسة الذهبية الفاخرة (تفاصيل كبيرة/أيقونات — ليست نصاً صغيراً).
  final Color gold;

  /// توهج زخرفي خافت للبطاقات البارزة (وضع داكن).
  final Color scaffoldAccent;

  /// حد البطاقة.
  final Color cardBorder;

  /// الفواصل الرقيقة.
  final Color divider;

  /// قاعدة الهيكل العظمي (LoadingState — DS-32).
  final Color skeletonBase;
  final Color skeletonHighlight;

  /// توهج النجاح الناعم (تأكيد فتح القفل).
  final Color successGlow;

  /// لمسة واتساب (زر المشاركة بالمعاينة) — زوج حاوية/نص بوضعين
  /// (UX-2b): كانت ألواناً فاتحة ثابتة لا تتكيف مع الداكن.
  final Color whatsappContainer;
  final Color onWhatsappContainer;

  /// التوكنز الفاتحة — لوحة Simple Invoice Manager (V3).
  static const FinColors light = FinColors(
    brightness: Brightness.light,
    positive: Color(0xFF2E7D32),
    onPositive: Colors.white,
    positiveContainer: Color(0xFFE8F5E9),
    onPositiveContainer: Color(0xFF1B5E20),
    negative: Color(0xFFB3261E),
    onNegative: Colors.white,
    negativeContainer: Color(0xFFFBE4E1),
    onNegativeContainer: Color(0xFF410E0B),
    warning: Color(0xFFA05000),
    onWarning: Colors.white,
    warningContainer: Color(0xFFFFF3E0),
    onWarningContainer: Color(0xFF4A2B00),
    neutral: Color(0xFF546E7A),
    neutralContainer: Color(0xFFECEFF1),
    onNeutralContainer: Color(0xFF26323B),
    gold: Color(0xFFA87A2C),
    scaffoldAccent: Color(0xFFE8F1F8),
    cardBorder: Color(0xFFD9E2EA),
    divider: Color(0xFFE3EAF0),
    skeletonBase: Color(0xFFE7EDF2),
    skeletonHighlight: Color(0xFFF5F8FA),
    successGlow: Color(0x332E7D32),
    whatsappContainer: Color(0xFFD7F2E4),
    onWhatsappContainer: Color(0xFF075E54),
  );

  /// التوكنز الداكنة (أزرق ليلي عميق فوق الأسود الصرف — عائلة البذرة).
  static const FinColors dark = FinColors(
    brightness: Brightness.dark,
    positive: Color(0xFF6FDCAE),
    onPositive: Color(0xFF003826),
    positiveContainer: Color(0xFF123528),
    onPositiveContainer: Color(0xFFA6EFD0),
    negative: Color(0xFFF2A3A0),
    onNegative: Color(0xFF4A0E0C),
    negativeContainer: Color(0xFF3C1D1C),
    onNegativeContainer: Color(0xFFF7CBC8),
    warning: Color(0xFFE9C26A),
    onWarning: Color(0xFF3A2B06),
    warningContainer: Color(0xFF39300F),
    onWarningContainer: Color(0xFFF6E2AE),
    neutral: Color(0xFFA3B4C2),
    neutralContainer: Color(0xFF1E2830),
    onNeutralContainer: Color(0xFFD7E0E8),
    gold: Color(0xFFD5B678),
    scaffoldAccent: Color(0xFF101B24),
    cardBorder: Color(0xFF233240),
    divider: Color(0xFF1D2A35),
    skeletonBase: Color(0xFF151F28),
    skeletonHighlight: Color(0xFF1E2B36),
    successGlow: Color(0x336FDCAE),
    whatsappContainer: Color(0xFF113528),
    onWhatsappContainer: Color(0xFFA6EFD0),
  );

  /// يختار التوكنز حسب سطوع الثيم الحالي.
  static FinColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? FinColors.dark
        : FinColors.light;
  }
}

/// ألوان الهوية الثابتة — لا تتكيف مع الوضعين الفاتح/الداكن (هوية بصرية
/// مجمدة): صبغة ظل البطاقات الفاتحة ودرجات القطعة النقدية في شعار FinAcc.
abstract final class FinBrandColors {
  /// صبغة الظل الناعم متعدد الطبقات للبطاقات في الوضع الفاتح
  /// (FinCard — أزرق ليلي عميق شبه أسود يُلطَّف بشفافية).
  static const Color cardShadow = Color(0xFF0A2338);

  /// بداية تدرّج القطعة النقدية الذهبية في شعار FinAcc.
  static const Color coinHighlight = Color(0xFFE7CB8C);

  /// نهاية تدرّج القطعة النقدية الذهبية في شعار FinAcc.
  static const Color coinDeep = Color(0xFFC79A3E);

  /// حدّ القطعة النقدية ورمز الريال المبسط في شعار FinAcc.
  static const Color coinEdge = Color(0xFF8F6A22);
}

/// نتيجة الحساب المالي باتجاهه — العلامة غير اللونية الملزمة (§6.1).
enum FinSign {
  /// وارد/قبض (+).
  incoming,

  /// صادر/دفع (−).
  outgoing,

  /// محايد (بلا علامة).
  neutral,
}
