/// مساعدات تقرير الأرباح والخسائر — مستخرجة حرفياً من
/// `profit_report_screen.dart` (R20-D3d؛ كانت `_signOf` و`_fmtPlainDate`).
library;

import '../../../../core/theme/app_colors.dart';

/// إشارة العرض من قيمة موقّعة (صفر = محايد).
FinSign profitReportSignOf(double value) {
  if (value > 0.005) return FinSign.incoming;
  if (value < -0.005) return FinSign.outgoing;
  return FinSign.neutral;
}

/// تاريخ `يوم/شهر/سنة` بأرقام غربية — لرسالة المشاركة خارج التطبيق
/// (واتساب لا يعرف نظام أرقام العرض الحي).
String profitReportPlainDate(DateTime date) =>
    '${date.day}/${date.month}/${date.year}';
