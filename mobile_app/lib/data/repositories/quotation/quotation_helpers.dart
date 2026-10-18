/// مساعدات عروض الأسعار المشتركة (صياغة خطأ القاعدة) — جزء من تقسيم
/// R20-D3a لمستودع عروض الأسعار (نمط R19-D3d): منقولة حرفياً من
/// quotation_repository.dart (الخاصّية `_describeDbError` صارت عامة
/// باسم مميز لتستعملها تدفقات الإنشاء والحالة).
library;

import 'package:sqflite/sqflite.dart';

/// يصوغ خطأ قاعدة البيانات بكلمات المستخدم.
String quotationDescribeDbError(DatabaseException e) {
  if (e.isUniqueConstraintError()) {
    final text = e.toString();
    if (text.contains('quotation_no')) {
      return 'تعارض في رقم عرض السعر — أعد المحاولة';
    }
    return 'قيمة مكررة تخالف قيد التفرد في القاعدة';
  }
  if (_isCheckFailure(e)) {
    return 'قيمة حالة غير مسموح بها لعرض السعر';
  }
  return 'تعذر حفظ عرض السعر في القاعدة: $e';
}

/// هل الخطأ خرقاً لقيد CHECK؟ (لا مساعد جاهز في sqflite — نقرأ الرسالة).
bool _isCheckFailure(DatabaseException e) =>
    e.toString().toUpperCase().contains('CHECK');
