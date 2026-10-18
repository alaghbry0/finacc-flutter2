/// مساعدات الأعداد المشتركة — دقة الكميات وصياغة الأرقام في الرسائل
/// وحقول الإدخال (R18-D2: توحيد النسخ المكررة من `_num` و`_qtyEpsilon`
/// و`_roundQty` عبر المستودعات ونماذج العرض — مصدر واحد للحقيقة).
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

/// نص عرض للرقم (بلا كسور زائدة) — لتعبئة الحقول مسبقاً: العدد الصحيح
/// بلا «.0» والكسري بكامل دقته بلا تقريب (على خلاف [formatNum] التي
/// تقرب لثلاث منازل للرسائل). R20-D2: توحيد ثلاث نسخ متطابقة حرفياً
/// كانت خاصة (نموذج نموذج الصنف ونموذج نموذج الطرف وشاشة أسعار الصرف).
String numToText(double value) {
  if (value == value.truncateToDouble() && value.abs() < 1e15) {
    return value.truncate().toString();
  }
  return value.toString();
}
