/// مساعدات تنسيق الجرد المشتركة بين مكونات الشاشة (تاريخ/كمية/تفاوت).
library;

/// تفاوت عشري مقارنات الكميات (نفس تعريف المستودع).
const double stocktakeQtyEps = 0.0005;

/// تاريخ `يوم/شهر/سنة` بأرقام بسيطة (نمط شاشة الوردية).
String stocktakeFormatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// كمية بثلاث منازل (NUMERIC(12,3)) — نص عربيّ بلا فواصل آلاف للحقول.
String stocktakeQty(double value) {
  final rounded = (value * 1000).round() / 1000;
  final text = rounded == rounded.truncateToDouble()
      ? rounded.truncate().toString()
      : rounded.toStringAsFixed(3);
  return text;
}

DateTime? stocktakeTryParseIso(String? iso) =>
    iso == null ? null : DateTime.tryParse(iso);
