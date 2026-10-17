/// مساعدات تنسيق مشتركة لواجهات البيع — تواريخ/أوقات/كميات بأرقام
/// جدولية + تسوية الدفع + تحليل أرقام حقول نوافذ التحرير.
library;

import '../../../../../domain/services/sale_pricing.dart';
import '../../../../core/widgets/amount_text.dart';

/// ينسّق تاريخاً للعرض `يوم/شهر/سنة` بأرقام جدولية بسيطة.
String sellFormatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

/// ينسّق وقتاً 12 ساعة مع ص/م.
String sellFormatTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  final period = date.hour < 12 ? 'ص' : 'م';
  return '${hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')} $period';
}

/// نص كمية معروض بأرقام جدولية (المتاح: N).
String sellQtyText(double qty) =>
    AmountText.format(qty, qty == qty.truncateToDouble() ? 0 : 3);

/// فاصل قيمة تسوية الدفع (للعرض المتكرر في PaymentSheet).
({double netPaid, double changeDue, double remainingCredit}) settlePreview(
  double grandTotal,
  double paidCash,
) {
  final settlement = SalePricing.settlePayment(grandTotal, paidCash);
  return (
    netPaid: settlement.netPaid,
    changeDue: settlement.changeDue,
    remainingCredit: settlement.remainingCredit,
  );
}

/// يحلل نص حقل رقمي من نوافذ التحرير (يقبل الفاصلة اللاتينية والعربية
/// ويتجاهل الفراغات) — null عند عدم الصلاحية.
double? parseSheetNumber(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
