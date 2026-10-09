/// إيصال إبطال فاتورة — مخرج `voidInvoice` (FR-02-15) لمحركي البيع
/// والشراء: ملخص الحركات المعاكسة المُنشأة داخل معاملة الإبطال الواحدة
/// (للرسائل والتدقيق) — **لا حذف فيزيائي لأي شيء**.
library;

/// ملخص إبطال فاتورة مكتملة (بيع أو شراء).
class VoidInvoiceReceipt {
  const VoidInvoiceReceipt({
    required this.invoiceId,
    required this.invoiceNo,
    required this.docType,
    required this.stockMovementCount,
    required this.cashReversalCount,
    required this.voucherRefundCount,
    required this.reversedCash,
    required this.reversedQty,
  });

  /// معرّف صف الفاتورة المُبطلة (بقيت في مكانها بحالة `void`).
  final int invoiceId;

  /// الرقم الكامل `INV-YYYY-NNNNN` / `PUR-YYYY-NNNNN` (لا يُعاد أبداً).
  final String invoiceNo;

  /// `sale` أو `purchase`.
  final String docType;

  /// عدد حركات المخزون المعاكسة المُنشأة (لكل دفعة/بند).
  final int stockMovementCount;

  /// عدد حركات الصندوق المعكوسة بالكامل (سند الإصدار: `is_voided=1`
  /// + سطر معاكس موثّق بـ `reversal_of`).
  final int cashReversalCount;

  /// عدد حركات الاسترداد الحقيقية لتخصيصات سندات لاحقة (RVT/PMT)
  /// على الفاتورة المُبطلة.
  final int voucherRefundCount;

  /// إجمالي النقدي المعكوس بعملة الفاتورة (إصدار + سندات لاحقة).
  final double reversedCash;

  /// إجمالي الكمية المعادة للصندوق المخزني (بيع) أو الخارجة منه (شراء)
  /// — بالمنصرف/المستلم الكلي (qty + free_qty).
  final double reversedQty;
}
