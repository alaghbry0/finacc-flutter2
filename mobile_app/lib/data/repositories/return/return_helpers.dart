/// مساعدات المرتجعات النقية (تحقق/تقييم/صياغة أخطاء) — بلا أي I/O.
/// مُستخرجة من return_repository.dart ضمن تقسيم R18-D3a.

/// تحقق نقي من بنود المرتجع (كميات وأرقام).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/numbers.dart';
import '../../../domain/services/purchase_pricing.dart';
import 'return_flow_types.dart';
import 'return_models.dart';

String? validateReturnLines(List<ReturnLineInput> lines) {
  if (lines.isEmpty) {
    return 'أضف بنداً واحداً على الأقل إلى المرتجع.';
  }
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final no = i + 1;
    if (line.qty.isNaN || line.qty.isInfinite) {
      return 'كمية البند $no غير صالحة — أدخل رقماً سليماً.';
    }
    if (line.qty <= 0) {
      return 'كمية البند $no يجب أن تكون أكبر من صفر.';
    }
  }
  return null;
}

/// قيمة بنود المرتجع Snapshot من البنود الأصلية (القرار 6):
/// gross = round2(qty_ret × unit_price الأصلي)، خصم تناسبي،
/// line_total = gross − الخصم — والتكلفة الأصلية منقولة تناسبياً
/// **بتكلفة الوحدة على المنصرف الكلي** (البونص داخل line_cost —
/// القرار 8 برأس الملف).
ReturnValuedLines valueReturnLines(
  Map<int, Map<String, Object?>> origItems,
  List<ReturnLineInput> lines,
) {
  var subtotal = 0.0;
  var discountTotal = 0.0;
  var refundTotal = 0.0;
  var costTotal = 0.0;
  final lineTotals = <double>[];
  final discounts = <double>[];
  for (final line in lines) {
    final item = origItems[line.invoiceItemId]!;
    final origQty = (item['qty'] as num?)?.toDouble() ?? 1;
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
    final origDiscount = (item['discount_amount'] as num?)?.toDouble() ?? 0;
    final origLineCost = (item['line_cost'] as num?)?.toDouble() ?? 0;

    final gross = roundMoney(line.qty * unitPrice);
    final discount = roundMoney(line.qty * origDiscount / origQty);
    final lineTotal = roundMoney(gross - discount);
    final lineCost = roundCost(
      line.qty * roundCost(origLineCost / dispatchedDivisor(item)),
    );

    lineTotals.add(lineTotal);
    discounts.add(discount);
    subtotal = roundMoney(subtotal + gross);
    discountTotal = roundMoney(discountTotal + discount);
    refundTotal = roundMoney(refundTotal + lineTotal);
    costTotal = roundCost(costTotal + lineCost);
  }
  return ReturnValuedLines(
    subtotal: subtotal,
    discountTotal: discountTotal,
    refundTotal: refundTotal,
    costTotal: costTotal,
    lineTotals: lineTotals,
    discounts: discounts,
  );
}

/// يتحقق من اتجاه رد القيمة مقابل الأرقام (القرار 2) — مرآة نمط
/// `PurchasePricing.validatePayment` بصياغة المرتجع.
String? validateRefundDirection(
  double refundTotal,
  double refundCash,
  ReturnRefundMethod declared,
) {
  if (refundCash.isNaN || refundCash.isInfinite || refundCash < 0) {
    return 'المبلغ النقدي المرتجع لا يمكن أن يكون سالباً.';
  }
  if (refundCash > refundTotal + moneyEpsilon) {
    return 'المبلغ النقدي المرتجع ($refundCash) يتجاوز قيمة المرتجع '
        '($refundTotal) — المرتجع لا يقبل الرد الزائد؛ اترك الباقي على '
        'الحساب.';
  }
  final derived = deriveRefundMethod(refundTotal, refundCash);
  if (derived == declared) return null;
  switch (declared) {
    case ReturnRefundMethod.cash:
      return 'الرد النقدي يتطلب رد قيمة المرتجع كاملة نقداً '
          '($refundTotal) — أو اختر الخصم من الحساب/المختلط.';
    case ReturnRefundMethod.credit:
      return 'الخصم من الحساب يتطلب عدم إدخال أي مبلغ نقدي — المدخل '
          '$refundCash.';
    case ReturnRefundMethod.mixed:
      return 'الرد المختلط يتطلب مبلغاً نقدياً بين صفر وقيمة المرتجع '
          '($refundTotal) حصراً — المدخل $refundCash.';
  }
}

/// يستنتج اتجاه الرد من الأرقام: نقدي عند رد الكامل، على الحساب عند
/// الصفر، مختلط بينهما.
ReturnRefundMethod deriveRefundMethod(double refundTotal, double refundCash) {
  if (refundCash <= moneyEpsilon) return ReturnRefundMethod.credit;
  if (refundCash >= refundTotal - moneyEpsilon) {
    return ReturnRefundMethod.cash;
  }
  return ReturnRefundMethod.mixed;
}

/// يفصل الرد: الجزء النقدي + الجزء المخصوم من حساب الطرف.
({double netCash, double credit, ReturnRefundMethod method}) settleRefund(
  double refundTotal,
  double refundCash,
) {
  final netCash = roundMoney(
    refundCash < refundTotal ? refundCash : refundTotal,
  );
  final credit = roundMoney(refundTotal - netCash);
  return (
    netCash: netCash,
    credit: credit,
    method: deriveRefundMethod(refundTotal, refundCash),
  );
}

/// المتاح للإرجاع مع تثبيت التجاذب العددي (لا سالب أبداً).
double availableForReturn(double originalQty, double returnedQty) {
  final available = originalQty - returnedQty;
  if (available <= 0) return 0;
  if (roundTo3(available) <= 0) return 0;
  return available;
}

/// مقسوم تكلفة الوحدة الأصلية = المنصرف الكلي (qty + free_qty) —
/// البونص وحدات خرجت وتكلفتها داخل line_cost (القرار 8 برأس الملف).
/// حارس القسمة: المجموع ≤ 0 يعيد 1 (صف شاذ نظري).
double dispatchedDivisor(Map<String, Object?> origItem) {
  final qty = (origItem['qty'] as num?)?.toDouble() ?? 0;
  final free = (origItem['free_qty'] as num?)?.toDouble() ?? 0;
  final total = qty + free;
  return total > 0 ? total : 1;
}

Map<int, double> sumByOriginMarker(List<Map<String, Object?>> rows) {
  final sums = <int, double>{};
  for (final row in rows) {
    final match = originItemPattern.firstMatch((row['notes'] as String?) ?? '');
    if (match == null) continue;
    final id = int.parse(match.group(1)!);
    sums[id] = (sums[id] ?? 0) + ((row['qty'] as num?)?.toDouble() ?? 0);
  }
  return sums;
}

/// يصوغ خطأ قاعدة البيانات بكلمات المستخدم (نمط المستودعات القائمة).
String describeReturnDbError(DatabaseException e) {
  if (e.isUniqueConstraintError()) {
    final text = e.toString();
    if (text.contains('invoice_no')) {
      return 'تعارض في رقم المرتجع — أعد الحفظ';
    }
    if (text.contains('payment_allocation')) {
      return 'تخصيص مدفوعات مكرر لنفس السند والمرتجع';
    }
    return 'قيمة مكررة تخالف قيد التفرد في القاعدة';
  }
  if (isCheckFailure(e)) {
    final text = e.toString();
    if (text.contains('stock_level')) {
      return 'المخزون لا يسمح بهذه الكمية (رصيد سالب ممنوع)';
    }
    if (text.contains('due_amount') || text.contains('paid_amount')) {
      return 'مبالغ الرد غير متسقة مع قيمة المرتجع';
    }
    return 'قيمة تخالف قيد سلامة محاسبي في القاعدة';
  }
  return 'تعذر حفظ المرتجع في القاعدة: $e';
}

/// هل الخطأ خرقاً لقيد CHECK؟
bool isCheckFailure(DatabaseException e) =>
    e.toString().toUpperCase().contains('CHECK');
