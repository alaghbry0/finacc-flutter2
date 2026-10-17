/// أنواع التدفق الداخلية لمحرك المرتجعات — خطأ التدفق + علامات
/// الأنماط + حاويات البيانات الخاصة. مُستخرجة من return_repository.dart
/// ضمن تقسيم R18-D3a (أسماء داخلية فقط — لا تُصدَّر من الواجهة).

/// فشل تدفق داخلي برسالة عربية نظيفة — رميه داخل المعاملة يتراجعها
/// كاملة (لا `return Err` داخلها أبداً بعد أول كتابة).
library;

class ReturnFlowError implements Exception {
  const ReturnFlowError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// علامة مرجع البند الأصلي داخل `invoice_item.notes` (القرار 1) —
/// تُقرأ/تُكتب بصيغة «أصل البند #&lt;id&gt;».
final RegExp originItemPattern = RegExp(r'أصل البند #(\d+)');

/// صيغة ملاحظة حركة الدفعة — نفس صيغة `sale_repository` حرفياً (القرار 3).
final RegExp batchNotePattern = RegExp(
  r'رقم الدفعة (.+?) \(تنتهي (\d{4}-\d{2}-\d{2})\)',
);

// ─────────────────────────────────────────────────────────────────────
// أنواع داخلية
// ─────────────────────────────────────────────────────────────────────

/// معلومات صنف داخل مستودع المرتجعات.
class ReturnProductInfo {
  const ReturnProductInfo({
    required this.id,
    required this.name,
    required this.isService,
    required this.trackBatches,
  });
  final int id;
  final String name;
  final bool isService;
  final bool trackBatches;
}

/// قيمة بنود المرتجع المحسوبة (Snapshot).
class ReturnValuedLines {
  const ReturnValuedLines({
    required this.subtotal,
    required this.discountTotal,
    required this.refundTotal,
    required this.costTotal,
    required this.lineTotals,
    required this.discounts,
  });
  final double subtotal;
  final double discountTotal;
  final double refundTotal;
  final double costTotal;
  final List<double> lineTotals;
  final List<double> discounts;
}

/// حصة/سعة دفعة — رقم الدفعة وتاريخ صلاحيتها بصيغة القاعدة (YYYY-MM-DD).
class ReturnBatchCap {
  ReturnBatchCap({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.qty,
  });
  final int batchId;
  final String batchNumber;
  final String expiryDate;
  double qty;
}
