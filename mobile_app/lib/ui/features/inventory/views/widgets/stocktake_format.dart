/// مساعدات تنسيق الجرد المشتركة بين مكونات الشاشة (تاريخ/كمية/تفاوت).
library;

import '../../../../../domain/core/numbers.dart';

/// تفاوت عشري مقارنات الكميات (نفس تعريف المستودع).
const double stocktakeQtyEps = 0.0005;

/// تاريخ `يوم/شهر/سنة` بأرقام بسيطة (نمط شاشة الوردية).
String stocktakeFormatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// كمية بثلاث منازل (NUMERIC(12,3)) — نص بلا فواصل آلاف لحقول الإدخال
/// (يفوّض إلى `formatNum` بمصدر الحقيقة الموحد — خرج مطابق حرفياً).
String stocktakeQty(double value) => formatNum(value);

DateTime? stocktakeTryParseIso(String? iso) =>
    iso == null ? null : DateTime.tryParse(iso);
