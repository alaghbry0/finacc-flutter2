/// مساعدات المال المشتركة — تقريب القرش والتكلفة وقاعدة 5.4-9
/// (R19-D2: توحيد النسختين المتطابقتين من `roundMoney`/`roundCost`/
/// `moneyEpsilon` بين محرّكي تسعير البيع والشراء — مصدر واحد).
///
/// كل الدوال نقية بلا I/O؛ يصدّرها `sale_pricing.dart` و
/// `purchase_pricing.dart` معاً فتبقى استيرادات المستدعين كما هي.
library;

/// تفاوت عشري مقبول في مقارنات المال (نصف قرش).
const double moneyEpsilon = 0.005;

/// يقرب مبلغاً ظاهرياً إلى منزلتين (القرش — قاعدة 5.4-9).
double roundMoney(double value) => _roundTo(value, 0.01);

/// يقرب تكلفة/WAC إلى أربع منازل (قاعدة 5.4-9 — دقة التكاليف).
double roundCost(double value) => _roundTo(value, 0.0001);

/// تقريب عشري موحّد: أقرب مضاعف لـ [step] (النصف بعيداً عن الصفر —
/// السلوك المحاسبي المعتاد)، مع تمرير NaN/∞ كما هي لتلتقطها التحققات.
///
/// التنفيذ: (القيمة × مقلوب الخطوة) تُقرَّب لعدد صحيح ثم تُقسم عليه —
/// القسمة الأخيرة **مقرَّبة صحيحاً** فتعيد «المضاعف القانوني» الأقرب
/// للقيمة العشرية (تجنّب تراكم ضجيج الضرب بـ 0.01 الثنائي).
double _roundTo(double value, double step) {
  if (value.isNaN || value.isInfinite) return value;
  final inverse = 1 / step;
  return (value * inverse).round() / inverse;
}
