/// FinDateText — التواريخ القصيرة للعرض بأرقام النظام الحي
/// (R19-D2: توحيد ٩ نسخ متطابقة من `_fmtDate`/`partyFormatDate` عبر
/// تقارير المبيعات/الأعمار/حركة الصنف/ملخص المخزون/الأرباح وشريط
/// الفترات وواجهات الأطراف — مصدر واحد).
///
/// الصيغة `يوم/شهر/سنة` **بلا حشو صفري** (5/7/2026) على خلاف صيغ
/// `dd/MM/yyyy` المحشوة الخاصة ببعض الشاشات — لا تخلط بينهما.
library;

import 'package:flutter/material.dart';

import '../../../../domain/services/numerals.dart';
import 'numerals_scope.dart';

/// أدوات تنسيق التواريخ القصيرة بنظام أرقام السياق (`display.numerals`).
abstract final class FinDateText {
  /// تاريخ `يوم/شهر/سنة` بنظام أرقام السياق الحي.
  static String date(BuildContext context, DateTime date) {
    final plain = '${date.day}/${date.month}/${date.year}';
    return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
  }

  /// تاريخ ووقت `يوم/شهر/سنة ساعة:دقيقة` (الوقت بحشو ثنائي) بنظام
  /// أرقام السياق الحي.
  static String dateTime(BuildContext context, DateTime date) {
    final plain =
        '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
  }
}
