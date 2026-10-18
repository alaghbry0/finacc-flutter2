/// مساعدات تنسيق مشتركة لواجهات البيع — تواريخ/أوقات/كميات بأرقام
/// جدولية + تسوية الدفع + تحليل أرقام حقول نوافذ التحرير.
///
/// R20-D1: `sellFormatDate` و`sellQtyText` (صيغ ثابتة الأرقام الغربية)
/// انتقلا إلى البيت المحايد `ui/core/widgets/fin_format_helpers.dart`
/// لأن بيت الطباعة الموحد يحتاجهما ولا يستورد ميزة — ويُصدَّران من
/// هنا فلم يتغير مستورد تاريخي واحد.
library;

import '../../../../../domain/services/sale_pricing.dart';

export '../../../../core/widgets/fin_format_helpers.dart';

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
