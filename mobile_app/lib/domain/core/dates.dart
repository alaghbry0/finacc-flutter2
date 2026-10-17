/// مساعدات التواريخ المشتركة — سلوك يوم العمل بتقويم المتجر المحلي
/// (R18-D2: توحيد 12 نسخة مكررة من `_dateOnly` عبر المستودعات).
///
/// كل الدوال نقية بلا I/O وتتبع اصطلاح المشروع: التواريخ الكاملة
/// ISO-8601 بUTC، وأيام العمل تُقارن بصيغة `YYYY-MM-DD` من التقويم
/// المحلي للمتجر.
library;

/// `YYYY-MM-DD` بتاريخ التقويم المحلي ليوم العمل.
String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// يوم القيد من نص ISO (أول 10 محارف) — `YYYY-MM-DD`.
String dayOfIso(String iso) => iso.length <= 10 ? iso : iso.substring(0, 10);

/// يحلّ نص ISO كاملاً (سندات/فواتير) إلى UTC — أو `null`.
DateTime? tryParseUtc(String? iso) {
  if (iso == null) return null;
  final parsed = DateTime.tryParse(iso);
  return parsed?.toUtc();
}

/// منتصف ليل UTC ليوم التقويم من نص ISO — أو `null`.
DateTime? utcMidnightOrNull(String? iso) {
  if (iso == null) return null;
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

/// منتصف ليل UTC ليوم التقويم من [DateTime].
DateTime utcMidnightOf(DateTime d) => DateTime.utc(d.year, d.month, d.day);
