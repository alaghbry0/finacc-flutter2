/// مساعدات تنسيق شراء (R19-D3a — مستخرجة حرفياً من `purchase_widgets.dart`
/// بلا أي تغيير دلالة).
library;

import '../../../../core/widgets/amount_text.dart';

/// نص كمية معروض بأرقام جدولية (المتاح: N).
String purQtyText(double qty) =>
    AmountText.format(qty, qty == qty.truncateToDouble() ? 0 : 3);

/// ينسّق تاريخاً للعرض `يوم/شهر/سنة` بأرقام جدولية بسيطة.
String purFormatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

/// ينسّق تاريخ صلاحية `سنة-شهر-يوم` (صيغة الدفعات بالقاعدة).
String purFormatIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// ينسّق وقتاً 12 ساعة مع ص/م.
String purFormatTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  final period = date.hour < 12 ? 'ص' : 'م';
  return '${hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')} $period';
}
