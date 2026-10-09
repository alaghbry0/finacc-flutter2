/// نماذج الشراء والمرتجعات المرتبطة — جداول `invoice` / `invoice_item`
/// بـ `doc_type` ∈ {'purchase','sale_return','purchase_return'} (§5.3 / FR-02-07 /
/// FR-02-08) — المرحلة 5.
///
/// القواعد الملزمة هنا:
/// - **الذرّية** (قاعدة 5.4-4): ترحيل الشراء/المرتجع كله داخل Transaction
///   واحدة في `PurchaseRepository.postPurchase` و`ReturnRepository` — هذه
///   النماذج مدخلات/مخرجات نقية فقط.
/// - **WAC بالعملة الأساسية** (قاعدة 5.4-3 + تعليق المخطط على
///   `product.cost_price`): تكلفة الوحدة الفعلية تُحسب بعملة الفاتورة في
///   `PurchasePricing` (`unitCostEffective`) ثم تُحوَّل للعملة الأساسية بسعر
///   يوم الشراء داخل المستودع (AC-03: «التكلفة سُجّلت بسعر يوم الشراء») —
///   `invoice_item.line_cost` و`invoice.cost_total` يخزنان **بالعملة
///   الأساسية** دائماً (نفس اصطلاح `sale_repository`) بينما `unit_price` /
///   `line_total` بعملة الفاتورة.
/// - **فصل العملات** (قاعدة 5.4-7 / FR-08-11): كل مبلغ مقيد بعملة
///   الفاتورة ولا يُخلط أبداً.
/// - **الدقة** (قاعدة 5.4-9): مبالغ الظهر بمنزلتين (القرش)، والتكاليف/WAC
///   بأربع منازل — انظر `purchase_pricing.dart` للتقريب الموثق.
///
/// ملاحظة معمارية: `exchangeRate`/`rateIsFallback` **نتيجة** سياسة
/// FR-08-09 يحسبها المحرك وقت الحفظ، لذا تسكن في `PurchasePostedReceipt`
/// لا في المسودة (نفس قرار `sale.dart`).
library;

/// نوع الخصم — نسبة مئوية أو مبلغ ثابت (FR-02-05 / FR-02-08).
enum PurchaseDiscountType {
  percent('percent'),
  amount('amount');

  const PurchaseDiscountType(this.code);

  /// الرمز كما يُخزَّن في أعمدة الفاتورة.
  final String code;
}

/// نوع الدفع المعلن لفاتورة الشراء (FR-02-03 باتجاه الشراء) — يطابق
/// عمود `invoice.pay_status`.
enum PurchasePaymentMethod {
  cash('cash'),
  credit('credit'),
  mixed('mixed');

  const PurchasePaymentMethod(this.code);

  /// الرمز كما يُخزَّن في عمود `pay_status`.
  final String code;
}

/// سطر شراء واحد — مدخل فاتورة المشتريات قبل التسعير.
class PurchaseLine {
  const PurchaseLine({
    required this.productId,
    required this.qty,
    required this.unitCost,
    this.lineDiscountType = PurchaseDiscountType.amount,
    this.lineDiscountValue = 0,
    this.freeQty = 0,
    this.notes,
    this.batchNo,
    this.expiryDate,
  });

  /// الصنف (product.id) — الخدمي مسموح (بلا مخزون ولا WAC).
  final int productId;

  /// الكمية المدفوعة للمورد (> 0 — NUMERIC(12,3)).
  final double qty;

  /// الكمية المجانية/بونص من المورد (≥ 0 — NUMERIC(12,3)، موجة R16-a).
  ///
  /// **القرار التحاسبي الموثّق** (قرار المالك R16-a — مرآة البيع):
  /// المستلم الكلي = `qty + freeQty` (الدفعة الواردة وstock_level
  /// وحركة المخزون بالكلي) وWAC = إجمالي التكلفة ÷ المستلم الكلي —
  /// **البونص يخفّض التكلفة الوحدوية** (شراء 10+2 مجاني بتكلفة 1200
  /// → دفعة 12 وحدة بوحدة تكلفة 100). المبلغ المستحق للمورد من `qty`
  /// حصراً — هذا الحقل لا يدخل أي حساب تسعير هنا إطلاقاً
  /// (`PurchasePricing` يقرأ `qty` وحدها؛ يستهلكه المستودع بالمخزون).
  final double freeQty;

  /// تكلفة الوحدة **بعملة الفاتورة** كما في فاتورة المورد (≥ 0).
  final double unitCost;

  /// نوع خصم السطر: نسبة ٪ أو مبلغ.
  final PurchaseDiscountType lineDiscountType;

  /// قيمة الخصم (٪ ضمن 0–100، أو مبلغ ≥ 0).
  final double lineDiscountValue;

  /// ملاحظة السطر (تُخزَّن في `invoice_item.notes`).
  final String? notes;

  /// رقم الدفعة الواردة (اختياري — للصنف المتتبع للدفعات فقط، FR-01-10).
  final String? batchNo;

  /// تاريخ انتهاء صلاحية الدفعة الواردة — **إلزامي مع [batchNo]**
  /// (عمود `batch.expiry_date` NOT NULL).
  final DateTime? expiryDate;
}

/// إجماليات فاتورة الشراء — ناتج `PurchasePricing.priceCart` (بمنزلتين).
class PurchaseTotals {
  const PurchaseTotals({
    required this.subtotal,
    required this.lineDiscountsTotal,
    required this.invoiceDiscount,
    required this.grandTotal,
    required this.itemsCount,
  });

  /// Σ(qty × unitCost) قبل أي خصم.
  final double subtotal;

  /// Σ خصومات الأسطر.
  final double lineDiscountsTotal;

  /// خصم رأس الفاتورة (الموزَّع pro-rata على البنود — قاعدة 5.4-3).
  final double invoiceDiscount;

  /// الصافي المستحق للمورد = subtotal − lineDiscountsTotal − invoiceDiscount.
  final double grandTotal;

  /// عدد أسطر الفاتورة (ليس مجموع الكميات).
  final int itemsCount;

  /// إجمالي الخصم الفعلي (أسطر + رأس).
  double get totalDiscount => lineDiscountsTotal + invoiceDiscount;
}

/// سطر شراء مُسعَّر — ناتج التسعير النقي لسطر واحد (قبل الكتابة).
class PricedPurchaseLine {
  const PricedPurchaseLine({
    required this.line,
    required this.gross,
    required this.lineDiscountAmount,
    required this.netAfterLineDiscount,
    required this.invoiceDiscountAllocated,
    required this.netFinal,
    required this.unitCostEffective,
  });

  /// السطر الأصلي.
  final PurchaseLine line;

  /// gross = round2(qty × unitCost).
  final double gross;

  /// خصم السطر المحسوب (٪ → round2(gross×pct/100) / مبلغ كما هو).
  final double lineDiscountAmount;

  /// صافي السطر بعد خصمه فقط.
  final double netAfterLineDiscount;

  /// نصيب السطر من خصم رأس الفاتورة (توزيع pro-rata — قاعدة 5.4-3).
  final double invoiceDiscountAllocated;

  /// الصافي النهائي = netAfterLineDiscount − invoiceDiscountAllocated
  /// (= `invoice_item.line_total` المخزَّن بعملة الفاتورة).
  final double netFinal;

  /// **تكلفة الوحدة الفعلية بعد كل الخصومات** = round4(netFinal / qty)
  /// بعملة الفاتورة — هذا ما يدخل WAC بعد تحويله للعملة الأساسية بسعر
  /// يوم الشراء (قاعدة 5.4-3: «شراء 10 وحدات @100 بخصم رأس 10% →
  /// التكلفة 90 لا 100»).
  final double unitCostEffective;

  /// الخصم الفعلي الكلي للسطر (يُخزَّن في `invoice_item.discount_amount`
  /// بحيث Σ(discount_amount) + Σ(line_total) = subtotal بالضبط).
  double get effectiveDiscount => lineDiscountAmount + invoiceDiscountAllocated;
}

/// نتيجة تسعير فاتورة شراء كاملة (نقية — بلا قاعدة بيانات).
class PricedPurchaseCart {
  const PricedPurchaseCart({required this.lines, required this.totals});

  /// الأسطر المُسعَّرة بنفس ترتيب الفاتورة.
  final List<PricedPurchaseLine> lines;

  /// الإجماليات.
  final PurchaseTotals totals;
}

/// مسوّدة فاتورة شراء — مدخل `PurchaseRepository.postPurchase`.
///
/// [paidCash] المبلغ النقدي المدفوع للمورد فوراً (0 = آجل كامل؛ يجب أن
/// يكون ≤ الصافي — الشراء لا يعرف «الباقي» بخلاف البيع). [paymentMethod]
/// تعلان المستخدم ويجب أن يطابق الأرقام (التحقق في `PurchasePricing`).
class PurchaseDraft {
  const PurchaseDraft({
    required this.supplierId,
    required this.currencyId,
    required this.lines,
    this.invoiceDiscountType = PurchaseDiscountType.amount,
    this.invoiceDiscountValue = 0,
    this.paidCash = 0,
    this.paymentMethod = PurchasePaymentMethod.cash,
    required this.warehouseId,
    this.notesInternal,
    this.notesPrinted,
    required this.issuedAt,
    this.supplierInvoiceRef,
  });

  /// المورد (**إلزامي للشراء** — `invoice.supplier_id`).
  final int supplierId;

  /// عملة الفاتورة (سعرها يُحسب وقت الحفظ وفق FR-08-09).
  final int currencyId;

  /// أسطر الشراء (≥ 1).
  final List<PurchaseLine> lines;

  /// خصم رأس الفاتورة (نسبة/مبلغ) — يوزَّع pro-rata **قبل تحديث WAC**
  /// (قاعدة 5.4-3 / FR-02-08).
  final PurchaseDiscountType invoiceDiscountType;
  final double invoiceDiscountValue;

  /// المبلغ النقدي المدفوع فوراً (0 = آجل كامل).
  final double paidCash;

  /// نوع الدفع المعلن (cash/credit/mixed — FR-02-03).
  final PurchasePaymentMethod paymentMethod;

  /// المخزن الذي يُضاف إليه المخزون (invoice.warehouse_id).
  final int warehouseId;

  /// ملاحظة داخلية لا تطبع (FR-02-16) — يُسبَق بمرجع فاتورة المورد إن وُجد.
  final String? notesInternal;

  /// ملاحظة خارجية تُطبع (FR-02-16).
  final String? notesPrinted;

  /// تاريخ الإصدار (يوم العمل — يحدد سعر الصرف وسنة الترقيم).
  final DateTime issuedAt;

  /// رقم فاتورة المورد الورقي إن وُجد — **لا عمود مخصص له في المخطط
  /// المجمد**، فيُخزَّن كبادئة موثَّقة داخل `notes_internal` بصيغة
  /// «فاتورة المورد: <الرقم>» (طلب عمود مخصص مسجَّل للمنسّق).
  final String? supplierInvoiceRef;
}

/// إيصال فاتورة شراء مُرحَّلة — مخرج `postPurchase`.
class PurchasePostedReceipt {
  const PurchasePostedReceipt({
    required this.invoiceId,
    required this.docNo,
    required this.totals,
    required this.payStatus,
    required this.exchangeRate,
    required this.rateIsFallback,
    this.remainingCredit = 0,
  });

  /// معرّف صف الفاتورة.
  final int invoiceId;

  /// الرقم الكامل `PUR-YYYY-NNNNN` (قاعدة 5.4-1).
  final String docNo;

  /// الإجماليات المخزَّنة (بعملة الفاتورة).
  final PurchaseTotals totals;

  /// حالة الدفع المخزَّنة (cash/credit/mixed).
  final PurchasePaymentMethod payStatus;

  /// سعر الصرف المطبَّق (Snapshot — 1 للعملة الأساسية).
  final double exchangeRate;

  /// هل السعر احتياطي (آخر سعر معروف — شارة FR-02-20)؟
  final bool rateIsFallback;

  /// الجزء الآجل = الصافي − المدفوع نقدياً (دين للمورد بعملة الفاتورة —
  /// `invoice.due_amount` الذي تقرأه صيغة رصيد المورد FR-03-03).
  final double remainingCredit;
}

// ─────────────────────────────────────────────────────────────────────
// نماذج القراءة (شاشات المشتريات اللاحقة: التفاصيل / آخر المشتريات)
// ─────────────────────────────────────────────────────────────────────

/// بند فاتورة شراء مقروء — صف من `invoice_item` مع اسم الصنف.
class PurchaseInvoiceItemLine {
  const PurchaseInvoiceItemLine({
    required this.productId,
    required this.lineDesc,
    required this.qty,
    required this.unitCost,
    required this.discountPercent,
    required this.discountAmount,
    required this.lineTotal,
    required this.lineCost,
    this.freeQty = 0,
    this.batchId,
    this.notes,
  });

  final int? productId;

  /// وصف السطر (اسم الصنف لحظة الشراء).
  final String? lineDesc;

  /// الكمية المدفوعة للمورد.
  final double qty;

  /// الكمية المجانية/بونص من المورد (≥ 0 — R16-a): المستلم الكلي
  /// = qty + freeQty دخل المخزون/الدفعة بWAC الكلي. غياب العمود بصفوف
  /// قديمة القاعدة = 0 (بلا بونص — سلوك ما قبل الترقية).
  final double freeQty;

  /// تكلفة الوحدة المدخلة بعملة الفاتورة (`invoice_item.unit_price`).
  final double unitCost;

  /// خصم السطر النسبي (0 إن كان الخصم مبلغاً).
  final double discountPercent;

  /// الخصم الفعلي الكلي للسطر (سطر + نصيبه من رأس الفاتورة).
  final double discountAmount;

  /// الصافي النهائي للسطر بعملة الفاتورة.
  final double lineTotal;

  /// قيمة السطر بالتكلفة **بالعملة الأساسية** (qty × تكلفة الوحدة
  /// الفعلية بعد التوزيع × سعر يوم الشراء) — Snapshot مرتجع الشراء.
  final double lineCost;

  /// الدفعة الواردة المنشأة من هذا السطر (null لغير المتتبع).
  final int? batchId;

  final String? notes;

  factory PurchaseInvoiceItemLine.fromRow(Map<String, Object?> row) =>
      PurchaseInvoiceItemLine(
        productId: row['product_id'] as int?,
        lineDesc: row['line_desc'] as String?,
        qty: (row['qty'] as num?)?.toDouble() ?? 0,
        unitCost: (row['unit_price'] as num?)?.toDouble() ?? 0,
        freeQty: (row['free_qty'] as num?)?.toDouble() ?? 0,
        discountPercent: (row['discount_percent'] as num?)?.toDouble() ?? 0,
        discountAmount: (row['discount_amount'] as num?)?.toDouble() ?? 0,
        lineTotal: (row['line_total'] as num?)?.toDouble() ?? 0,
        lineCost: (row['line_cost'] as num?)?.toDouble() ?? 0,
        batchId: row['batch_id'] as int?,
        notes: row['notes'] as String?,
      );
}

/// رأس فاتورة شراء مقروء — صف من `invoice` حيث doc_type='purchase'.
class PurchaseInvoice {
  const PurchaseInvoice({
    required this.id,
    required this.invoiceNo,
    required this.payStatus,
    required this.status,
    required this.issuedAt,
    this.supplierId,
    required this.warehouseId,
    this.cashboxId,
    required this.currencyId,
    required this.exchangeRate,
    required this.rateIsFallback,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    required this.totalBase,
    required this.paidAmount,
    required this.dueAmount,
    required this.costTotal,
    this.notesInternal,
    this.notesPrinted,
  });

  final int id;
  final String invoiceNo;

  /// cash / credit / mixed.
  final PurchasePaymentMethod payStatus;

  /// completed / draft / void (آلة الحالات 5.4-2).
  final String status;

  /// لحظة الإصدار (UTC كما في القاعدة).
  final DateTime issuedAt;

  final int? supplierId;
  final int warehouseId;
  final int? cashboxId;
  final int currencyId;

  /// Snapshot سعر الصرف (FR-08-05).
  final double exchangeRate;

  /// شارة «سعر صرف تقديري» (FR-02-20).
  final bool rateIsFallback;

  final double subtotal;
  final double discountAmount;

  /// الصافي بعملة الفاتورة.
  final double total;

  /// الصافي بالعملة الأساسية (total × exchange_rate).
  final double totalBase;

  final double paidAmount;

  /// دين المورد بعملة الفاتورة.
  final double dueAmount;

  /// قيمة المخزون الوارد بالعملة الأساسية (Σ line_cost).
  final double costTotal;

  final String? notesInternal;
  final String? notesPrinted;

  factory PurchaseInvoice.fromRow(Map<String, Object?> row) => PurchaseInvoice(
    id: row['id'] as int,
    invoiceNo: row['invoice_no'] as String,
    payStatus: PurchasePaymentMethod.values.firstWhere(
      (m) => m.code == (row['pay_status'] as String),
    ),
    status: row['status'] as String,
    issuedAt: DateTime.parse(row['issued_at'] as String),
    supplierId: row['supplier_id'] as int?,
    warehouseId: row['warehouse_id'] as int,
    cashboxId: row['cashbox_id'] as int?,
    currencyId: row['currency_id'] as int,
    exchangeRate: (row['exchange_rate'] as num?)?.toDouble() ?? 1,
    rateIsFallback: (row['rate_is_fallback'] as int? ?? 0) == 1,
    subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
    discountAmount: (row['discount_amount'] as num?)?.toDouble() ?? 0,
    total: (row['total'] as num?)?.toDouble() ?? 0,
    totalBase: (row['total_base'] as num?)?.toDouble() ?? 0,
    paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
    dueAmount: (row['due_amount'] as num?)?.toDouble() ?? 0,
    costTotal: (row['cost_total'] as num?)?.toDouble() ?? 0,
    notesInternal: row['notes_internal'] as String?,
    notesPrinted: row['notes_printed'] as String?,
  );
}

/// تفاصيل فاتورة شراء كاملة للعرض: الرأس + البنود + أسماء المورد/العملة.
class PurchaseInvoiceDetail {
  const PurchaseInvoiceDetail({
    required this.invoice,
    required this.items,
    this.supplierName,
    this.supplierPhone,
    this.currencyCode,
    this.currencySymbol,
  });

  final PurchaseInvoice invoice;
  final List<PurchaseInvoiceItemLine> items;
  final String? supplierName;
  final String? supplierPhone;
  final String? currencyCode;
  final String? currencySymbol;
}

/// سطر ملخص فاتورة شراء في قائمة آخر المشتريات.
class PurchaseInvoiceSummary {
  const PurchaseInvoiceSummary({
    required this.id,
    required this.invoiceNo,
    required this.issuedAt,
    this.supplierId,
    this.supplierName,
    this.currencyCode,
    required this.total,
    required this.paidAmount,
    required this.dueAmount,
    required this.payStatus,
    required this.status,
  });

  final int id;
  final String invoiceNo;
  final DateTime issuedAt;
  final int? supplierId;
  final String? supplierName;
  final String? currencyCode;

  /// الصافي بعملة الفاتورة.
  final double total;
  final double paidAmount;
  final double dueAmount;
  final PurchasePaymentMethod payStatus;
  final String status;
}
