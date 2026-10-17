/// مساعدات الأعداد المشتركة — دقة الكميات وصياغة الأرقام في الرسائل
/// (R18-D2: توحيد النسخ المكررة من `_num` و`_qtyEpsilon` و`_roundQty`
/// عبر المستودعات ونماذج العرض — مصدر واحد للحقيقة).
library;

/// تفاوت الكميات المقبول في المقارنات (دقة أعمدة NUMERIC(12,3)).
const double qtyEpsilon = 0.000001;

/// تقريب إلى ثلاث منازل عشرية (دقة أعمدة NUMERIC(12,3)).
double roundTo3(double value) => (value * 1000).round() / 1000;

/// يصيغ رقماً للعرض في الرسائل بلا أصفار زائدة.
String formatNum(double v) {
  if (v.isNaN || v.isInfinite) {
    return v.toString();
  }
  final rounded = roundTo3(v);
  if (rounded == rounded.round()) {
    return rounded.toInt().toString();
  }
  return rounded.toStringAsFixed(3);
}
