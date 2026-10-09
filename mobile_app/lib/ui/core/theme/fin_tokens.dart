/// توكنات التصميم المادية — UX-2b (خريطة الاتساق البصري من تدقيق
/// UX-audit-visual §2).
///
/// قيم الشاشة الموحدة (SRS §0.3 + DS):
/// - **الفراغات** `FinSpacing`: سلّم 4/8/12/16/20/24/32 — هوامش الشاشة
///   الأفقية 20، فراغ رأسي للقوائم تحت الرؤوس 8 وقاعها 32 (وقاع 96 عند
///   وجود FAB.extended متراكب فوق القائمة).
/// - **الأنصاف** `FinRadius`: بطاقات 16 / أزرار وحقول 12 / حوارات 20 /
///   أوراق سفلية 24 / عناصر داخلية دقيقة 8 — لا قيم شاذة بينها (9/11/13
///   صحّحت إلى أقرب توكن).
/// - **الحركة** `FinMotion`: 420ms الموحّدة بمنحنى easeOutCubic للدخول
///   المتدرج والانتقالات الكبيرة، و220ms للتغذية الراجعة الدقيقة
///   (تحديد/تبديل) — منع التذبذب الشاذ.
///
/// الاستعمال: استبدل القيم الحرفية الشاذة بهذه التوكنات في الشاشات
/// المحورية؛ القيم القياسية الموجودة أصلاً (10/14 للمسات الدقيقة) تبقى
/// كما هي إن لم تُوثَّق شاذة.
library;

import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:flutter/widgets.dart' show BorderRadius;

/// سلّم الفراغات الموحد (dp).
abstract final class FinSpacing {
  /// 4 — فراغات دقيقة داخل العناصر المتراصة.
  static const double xs = 4;

  /// 8 — فراغ القوائم تحت الحقول/الرؤوس، وفاصل الشارات.
  static const double sm = 8;

  /// 12 — فراغ بين البطاقات الصغيرة.
  static const double md = 12;

  /// 16 — حشو البطاقات الأساسي.
  static const double lg = 16;

  /// 20 — هوامش الشاشة الأفقية.
  static const double xl = 20;

  /// 24 — فراغ الأقسام الكبيرة.
  static const double xxl = 24;

  /// 32 — قاع القوائم أسفل الرؤوس (ونهاية الشاشة).
  static const double bottom = 32;

  /// 96 — قاع القوائم عند وجود FAB.extended متراكب فوق المحتوى.
  static const double fabClearance = 96;
}

/// أنصاف الأقطار الموحدة (dp) — §0.3.
abstract final class FinRadius {
  /// 8 — شرائح وشارات وعناصر داخلية دقيقة.
  static const double chip = 8;

  /// 12 — أزرار وحقول إدخال وحاويات أيقونات (DS-29).
  static const double control = 12;

  /// 16 — البطاقات (FinCard/StatTile).
  static const double card = 16;

  /// 20 — الحوارات.
  static const double dialog = 20;

  /// 24 — الأوراق السفلية (bottom sheets).
  static const double sheet = 24;

  /// زاوية بطاقة جاهزة.
  static BorderRadius get cardBorder => BorderRadius.circular(card);

  /// زاوية زر/حقل جاهزة.
  static BorderRadius get controlBorder => BorderRadius.circular(control);

  /// زاوية شريحة جاهزة.
  static BorderRadius get chipBorder => BorderRadius.circular(chip);
}

/// حركة التطبيق الموحدة — 420ms بمنحنى خروج ناعم.
abstract final class FinMotion {
  /// 420ms — المدة المعيارية للدخول المتدرج والانتقالات.
  static const Duration standard = Duration(milliseconds: 420);

  /// 220ms — التغذية الراجعة الدقيقة (تحديد/تبديل/وميض).
  static const Duration fast = Duration(milliseconds: 220);

  /// المنحنى المعياري — خروج مكعب ناعم (لا ارتداد في الحركات الكبيرة).
  static const Curve curve = Curves.easeOutCubic;
}
