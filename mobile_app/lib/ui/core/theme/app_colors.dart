/// التوكنز اللونية الدلالية — SRS §6.1 (الدلالات الإدراكية الملزمة).
///
/// القاعدة: الوارد/القبض/الربح = إيجابية، الصادر/الدفع = سلبية، الآجل/
/// المستحق = تحذيرية، المعلّق/المسودة = محايدة — **لكل دلالة لونية علامة
/// غير لونية مرافقة** (سهم/إشارة/نص حالة — ComponentBehavior).
///
/// البذرة الرسمية: `0xFF00695C` (Deep Teal) بوضعين فاتح/داكن مع لمسة
/// ذهبية رفيعة للتفاصيل الفاخرة. كل الأزواج النصية تتحقق ≥ 4.5:1
/// (يفحصها اختبار `ui/theme_contrast_test.dart` — بوابة DS-30).
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

  /// التوكنز الفاتحة.
  static const FinColors light = FinColors(
    brightness: Brightness.light,
    positive: Color(0xFF0E7A4E),
    onPositive: Colors.white,
    positiveContainer: Color(0xFFD7F2E4),
    onPositiveContainer: Color(0xFF07381F),
    negative: Color(0xFFB3261E),
    onNegative: Colors.white,
    negativeContainer: Color(0xFFFBE4E1),
    onNegativeContainer: Color(0xFF410E0B),
    warning: Color(0xFF9A6200),
    onWarning: Colors.white,
    warningContainer: Color(0xFFFCEFD8),
    onWarningContainer: Color(0xFF332405),
    neutral: Color(0xFF5B6B65),
    neutralContainer: Color(0xFFE5EBE8),
    onNeutralContainer: Color(0xFF232B27),
    gold: Color(0xFFA87A2C),
    scaffoldAccent: Color(0xFFE8F2ED),
    cardBorder: Color(0xFFDCE7E1),
    divider: Color(0xFFE3ECE7),
    skeletonBase: Color(0xFFE7EEEA),
    skeletonHighlight: Color(0xFFF5F9F7),
    successGlow: Color(0x330E7A4E),
    whatsappContainer: Color(0xFFD7F2E4),
    onWhatsappContainer: Color(0xFF075E54),
  );

  /// التوكنز الداكنة (Premium Deep — خلفية خضراء عميقة لا سوداء صرفة).
  static const FinColors dark = FinColors(
    brightness: Brightness.dark,
    positive: Color(0xFF6FDCAE),
    onPositive: Color(0xFF003826),
    positiveContainer: Color(0xFF113528),
    onPositiveContainer: Color(0xFFA6EFD0),
    negative: Color(0xFFF2A3A0),
    onNegative: Color(0xFF4A0E0C),
    negativeContainer: Color(0xFF3C1D1C),
    onNegativeContainer: Color(0xFFF7CBC8),
    warning: Color(0xFFE9C26A),
    onWarning: Color(0xFF3A2B06),
    warningContainer: Color(0xFF39300F),
    onWarningContainer: Color(0xFFF6E2AE),
    neutral: Color(0xFFA9BCB4),
    neutralContainer: Color(0xFF1E2B27),
    onNeutralContainer: Color(0xFFD6E3DD),
    gold: Color(0xFFD5B678),
    scaffoldAccent: Color(0xFF0F211C),
    cardBorder: Color(0xFF24413A),
    divider: Color(0xFF1E332D),
    skeletonBase: Color(0xFF16241F),
    skeletonHighlight: Color(0xFF1E302A),
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

/// نتيجة الحساب المالي باتجاهه — العلامة غير اللونية الملزمة (§6.1).
enum FinSign {
  /// وارد/قبض (+).
  incoming,

  /// صادر/دفع (−).
  outgoing,

  /// محايد (بلا علامة).
  neutral,
}
