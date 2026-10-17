/// نماذج المرتجعات النقية (مدخلات/مخرجات المستودع) — مُستخرجة حرفياً
/// من return_repository.dart ضمن تقسيم R18-D3a (الواجهة العامة ثابتة).

library;

// ─────────────────────────────────────────────────────────────────────
// نماذج المرتجعات (مدخلات/مخرجات المستودع — نماذج نقية)
// ─────────────────────────────────────────────────────────────────────

/// اتجاه رد قيمة المرتجع (FR-02-07 / FR-02-08) — الرمز يطابق عمود
/// `invoice.pay_status` (cash/credit/mixed).
enum ReturnRefundMethod {
  /// رد نقدي كامل من/إلى الصندوق (SRN: صرف للعميل — PRN: قبض من المورد).
  cash('cash'),

  /// خصم كامل من حساب الطرف (SRN: رصيد العميل — PRN: دين المورد).
  credit('credit'),

  /// جزء نقدي وجزء على الحساب.
  mixed('mixed');

  const ReturnRefundMethod(this.code);
  final String code;
}

/// بند مرتجع واحد — مرجع مباشر لبند الفاتورة الأصلية + الكمية المرتجعة.
class ReturnLineInput {
  const ReturnLineInput({required this.invoiceItemId, required this.qty});

  /// بند الفاتورة الأصلية (`invoice_item.id`).
  final int invoiceItemId;

  /// الكمية المرجعة (> 0 وتقع ضمن المتبقي القابل للإرجاع).
  final double qty;
}

/// مسوّدة مرتجع بيع (SRN) — مرتبطة حصراً بفاتورة بيع أصلية.
class SaleReturnDraft {
  const SaleReturnDraft({
    required this.originalInvoiceId,
    required this.lines,
    this.refundCash = 0,
    this.refundMethod = ReturnRefundMethod.cash,
    required this.issuedAt,
    this.notesInternal,
    this.notesPrinted,
  });

  /// الفاتورة الأصلية (doc_type='sale' وحالة completed).
  final int originalInvoiceId;

  /// البنود المرتجعة (≥ 1).
  final List<ReturnLineInput> lines;

  /// المبلغ النقدي المردود فوراً (0 = كله على حساب العميل).
  final double refundCash;

  /// اتجاه رد القيمة المعلن (يجب أن يطابق الأرقام).
  final ReturnRefundMethod refundMethod;

  /// تاريخ إصدار المرتجع (يحدد سعر الصرف وسنة الترقيم).
  final DateTime issuedAt;

  final String? notesInternal;
  final String? notesPrinted;
}

/// مسوّدة مرتجع شراء (PRN) — مرتبطة حصراً بفاتورة شراء أصلية.
class PurchaseReturnDraft {
  const PurchaseReturnDraft({
    required this.originalInvoiceId,
    required this.lines,
    this.refundCash = 0,
    this.refundMethod = ReturnRefundMethod.cash,
    required this.issuedAt,
    this.notesInternal,
    this.notesPrinted,
  });

  /// الفاتورة الأصلية (doc_type='purchase' وحالة completed).
  final int originalInvoiceId;

  final List<ReturnLineInput> lines;

  /// المبلغ النقدي المسترد فوراً من المورد (0 = كله خصم من دينه).
  final double refundCash;

  final ReturnRefundMethod refundMethod;
  final DateTime issuedAt;
  final String? notesInternal;
  final String? notesPrinted;
}

/// إيصال مرتجع مُرحَّل — مخرج postSaleReturn/postPurchaseReturn.
class ReturnPostedReceipt {
  const ReturnPostedReceipt({
    required this.invoiceId,
    required this.docNo,
    required this.docType,
    required this.originalInvoiceId,
    required this.originalInvoiceNo,
    required this.refundTotal,
    required this.refundCash,
    required this.refundCredit,
    required this.payStatus,
    required this.exchangeRate,
    required this.rateIsFallback,
  });

  /// معرّف صف الفاتورة المرتجعة.
  final int invoiceId;

  /// الرقم الكامل `SRN-YYYY-NNNNN` / `PRN-YYYY-NNNNN`.
  final String docNo;

  /// 'SRN' أو 'PRN'.
  final String docType;

  final int originalInvoiceId;
  final String? originalInvoiceNo;

  /// قيمة المرتجع بعملة الفاتورة الأصلية.
  final double refundTotal;

  /// الجزء النقدي المردود الآن.
  final double refundCash;

  /// الجزء المخصوم من حساب الطرف (`invoice.due_amount`).
  final double refundCredit;

  /// حالة الرد المخزَّنة (cash/credit/mixed).
  final ReturnRefundMethod payStatus;

  final double exchangeRate;
  final bool rateIsFallback;
}

/// بند قابل للإرجاع — سطر جاهز لواجهة اختيار المرتجع لاحقاً.
class ReturnableLine {
  const ReturnableLine({
    required this.invoiceItemId,
    required this.productId,
    required this.lineDesc,
    required this.originalQty,
    required this.returnedQty,
    required this.availableQty,
    required this.unitPrice,
    required this.unitPriceEffective,
    required this.unitCostSnapshot,
    this.batchId,
  });

  /// بند الفاتورة الأصلية — مفتاح `ReturnLineInput.invoiceItemId`.
  final int invoiceItemId;
  final int? productId;
  final String? lineDesc;

  /// الكمية الأصلية (المباعة أو المشتراة).
  final double originalQty;

  /// ما أُرجع منها سابقاً (مرتجعات مكتملة).
  final double returnedQty;

  /// المتاح للإرجاع = originalQty − returnedQty.
  final double availableQty;

  /// سعر/تكلفة الوحدة الأصلية بعملة الفاتورة (`unit_price`).
  final double unitPrice;

  /// صافي ما دُفع عن الوحدة بعملة الفاتورة (line_total/qty) — أساس الرد.
  final double unitPriceEffective;

  /// تكلفة الوحدة Snapshot بالعملة الأساسية (line_cost/qty) — أساس
  /// تقييم حركة المخزون للمرتجع.
  final double unitCostSnapshot;

  /// الدفعة الأصلية للبند (للمشتريات المتتبعة).
  final int? batchId;
}
