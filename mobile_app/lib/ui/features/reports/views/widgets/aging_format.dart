/// مساعدات عرض تقرير أعمار الديون (R19-D3a — مستخرجة حرفياً من
/// `aging_report_screen.dart` بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_date_text.dart';

/// تاريخ للعرض `يوم/شهر/سنة` بنظام أرقام السياق الحي — «—» عند الغياب.
String agingFormatDate(BuildContext context, DateTime? date) =>
    date == null ? '—' : FinDateText.date(context, date);

/// لون الدلو بتدرّج دلالي أخضر ← كهرماني ← برتقالي ← أحمر (رموز
/// FinColors نقطتا النهاية — الوضعان فاتح/داكن مدعومان).
Color agingBucketColor(BuildContext context, int bucket) {
  final colors = FinColors.of(context);
  return switch (bucket) {
    0 => colors.positive,
    1 => colors.warning,
    2 => Color.lerp(colors.warning, colors.negative, 0.55)!,
    _ => colors.negative,
  };
}
