/// نماذج البيع (POS) — جداول `invoice` / `invoice_item` بـ `doc_type='sale'`
/// (§5.3 / وحدة FR-02) — المرحلة 4.
///
/// القواعد الملزمة هنا:
/// - **الذرّية** (قاعدة 5.4-4): الترحيل كله داخل Transaction واحدة في
///   `SaleRepository.postSale` — هذه النماذج مدخلات/مخرجات نقية فقط.
/// - **منع السالب المخزوني** (قاعدة 5.4-5): خط أحمر — الفحص داخل
///   المستودع لا هنا.
/// - **فصل العملات** (قاعدة 5.4-7 / FR-08-11): كل مبلغ مقيد بعملة
///   الفاتورة ولا يُخلط أبداً.
/// - **الدقة** (قاعدة 5.4-9): مبالغ الظهر بمنزلتين (القرش)، والتكاليف/WAC
///   بأربع منازل — انظر `sale_pricing.dart` للتقريب الموثق.
///
/// ملاحظة معمارية: `exchangeRate`/`rateIsFallback` **نتيجة** سياسة
/// FR-08-09 يحسبها المحرك وقت الحفظ (لا يثق بقيمة من الواجهة — AC-13:
/// «لا يوجد أي مسار يحفظ بسعر 1»)، لذا تسكن في `SalePostedReceipt` لا في
/// المسودة.
library;

/// نوع الخصم — نسبة مئوية أو مبلغ ثابت (FR-02-05).
enum SaleDiscountType {
  percent('percent'),
  amount('amount');

  const SaleDiscountType(this.code);

  /// الرمز المخزَّن/المستخدم في الواجهات.
  final String code;
}

/// نوع الدفع المعلن للفاتورة (FR-02-03) — يطابق عمود `invoice.pay_status`.
enum SalePaymentMethod {
  cash('cash'),
  credit('credit'),
  mixed('mixed');

  const SalePaymentMethod(this.code);

  /// الرمز كما يُخزَّن في عمود `pay_status`.
  final String code;
}

/// سطر سلة بيع واحد — مدخل الكاشير قبل التسعير.
class CartLine {
  const CartLine({
    required this.productId,
    required this.qty,
    required this.unitPrice,
    this.lineDiscountType = SaleDiscountType.amount,
    this.lineDiscountValue = 0,
    this.freeQty = 0,
    this.notes,
  });

  /// الصنف (product.id) — الخدمي مسموح (بلا مخزون).
  final int productId;

  /// الكمية (> 0 — NUMERIC(12,3)).
  final double qty;

  /// الكمية المجانية/بونص (≥ 0 — NUMERIC(12,3)، موجة UX-4).
  ///
  /// **القرار التحاسبي الملزم** (UX-audit-invoice §3): المنصرف الكلي
  /// = `qty + freeQty` (المخزون/الدفعات/COGS على الكلي) والإيراد من
  /// `qty` حصراً — هذا الحقل لا يدخل أي حساب تسعير هنا إطلاقاً
  /// (`SalePricing` يقرأ `qty` وحدها؛ يستهلكه المستودع بالمخزون).
  final double freeQty;

  /// سعر الوحدة بعملة الفاتورة (≥ 0).
  final double unitPrice;

  /// نوع خصم السطر: نسبة ٪ أو مبلغ.
  final SaleDiscountType lineDiscountType;

  /// قيمة الخصم (٪ ضمن 0–100، أو مبلغ ≥ 0).
  final double lineDiscountValue;

  /// ملاحظة السطر (تُخزَّن في `invoice_item.notes`).
  final String? notes;
}

/// إجماليات السلة — ناتج `SalePricing.priceCart` (كلها بمنزلتين).
class CartTotals {
  const CartTotals({
    required this.subtotal,
    required this.lineDiscountsTotal,
    required this.invoiceDiscount,
    required this.grandTotal,
    required this.itemsCount,
  });

  /// Σ(qty × unitPrice) قبل أي خصم.
  final double subtotal;

  /// Σ خصومات الأسطر.
  final double lineDiscountsTotal;

  /// خصم رأس الفاتورة (الموزَّع pro-rata على الأسطر).
  final double invoiceDiscount;

  /// الصافي = subtotal − lineDiscountsTotal − invoiceDiscount (> 0).
  final double grandTotal;

  /// عدد أسطر السلة (ليس مجموع الكميات).
  final int itemsCount;

  /// إجمالي الخصم الفعلي (أسطر + رأس).
  double get totalDiscount => lineDiscountsTotal + invoiceDiscount;
}

/// سطر مُسعَّر — ناتج التسعير النقي لسطر واحد (قبل الكتابة في القاعدة).
class PricedCartLine {
  const PricedCartLine({
    required this.line,
    required this.gross,
    required this.lineDiscountAmount,
    required this.netAfterLineDiscount,
    required this.invoiceDiscountAllocated,
    required this.netFinal,
  });

  /// السطر الأصلي.
  final CartLine line;

  /// gross = round2(qty × unitPrice).
  final double gross;

  /// خصم السطر المحسوب (٪ → round2(gross×pct/100) / مبلغ كما هو).
  final double lineDiscountAmount;

  /// صافي السطر بعد خصمه فقط.
  final double netAfterLineDiscount;

  /// نصيب السطر من خصم رأس الفاتورة (توزيع pro-rata — قاعدة 5.4-3).
  final double invoiceDiscountAllocated;

  /// الصافي النهائي = netAfterLineDiscount − invoiceDiscountAllocated
  /// (= `invoice_item.line_total` المخزَّن).
  final double netFinal;

  /// الخصم الفعلي الكلي للسطر (يُخزَّن في `invoice_item.discount_amount`
  /// بحيث Σ(discount_amount) + Σ(line_total) = subtotal بالضبط).
  double get effectiveDiscount => lineDiscountAmount + invoiceDiscountAllocated;
}

/// نتيجة تسعير سلة كاملة (نقية — بلا قاعدة بيانات).
class PricedCart {
  const PricedCart({required this.lines, required this.totals});

  /// الأسطر المُسعَّرة بنفس ترتيب السلة.
  final List<PricedCartLine> lines;

  /// الإجماليات.
  final CartTotals totals;
}

/// مسوّدة فاتورة بيع — مدخل `SaleRepository.postSale`.
///
/// [paidCash] المبلغ النقدي المُستلَم (قد يزيد عن الصافي فيصبح الباقي
/// `changeDue` لا ديناً ولا دخلاً للصندوق). [paymentMethod] تعلان
/// الكاشير ويجب أن يطابق الأرقام (التحقق في `SalePricing`).
class SaleDraft {
  const SaleDraft({
    this.customerId,
    required this.currencyId,
    required this.lines,
    this.invoiceDiscountType = SaleDiscountType.amount,
    this.invoiceDiscountValue = 0,
    this.paidCash = 0,
    this.paymentMethod = SalePaymentMethod.cash,
    required this.warehouseId,
    this.notesInternal,
    this.notesPrinted,
    required this.issuedAt,
    this.fromQuotationId,
  });

  /// العميل (null = عميل نقدي مجهول).
  final int? customerId;

  /// عملة الفاتورة (سعرها يُحسب وقت الحفظ وفق FR-08-09).
  final int currencyId;

  /// أسطر السلة (≥ 1).
  final List<CartLine> lines;

  /// خصم رأس الفاتورة (نسبة/مبلغ) — يوزَّع pro-rata.
  final SaleDiscountType invoiceDiscountType;
  final double invoiceDiscountValue;

  /// المبلغ النقدي المدفوع فوراً (0 = آجل كامل).
  final double paidCash;

  /// نوع الدفع المعلن (cash/credit/mixed — FR-02-03).
  final SalePaymentMethod paymentMethod;

  /// المخزن الذي يُخصم منه المخزون (invoice.warehouse_id).
  final int warehouseId;

  /// ملاحظة داخلية لا تطبع (FR-02-16).
  final String? notesInternal;

  /// ملاحظة خارجية تُطبع (FR-02-16).
  final String? notesPrinted;

  /// تاريخ الإصدار (يوم العمل — يحدد سعر الصرف وسنة الترقيم).
  final DateTime issuedAt;

  /// خيط الذرّية لتحويل عرض سعر: عند ضبطه تُحدَّث الفاتورة
  /// (`invoice.quotation_id`) ويُعلَّم العرض `converted` **داخل معاملة
  /// postSale نفسها** — فشل أي طرف يرجع الكل (FR-02-11 / AC-17).
  final int? fromQuotationId;
}

/// إيصال فاتورة مُرحَّلة — مخرج `postSale` النهائي للكاشير.
class SalePostedReceipt {
  const SalePostedReceipt({
    required this.invoiceId,
    required this.invoiceNo,
    required this.totals,
    required this.payStatus,
    required this.exchangeRate,
    required this.rateIsFallback,
    this.changeDue = 0,
    this.remainingCredit = 0,
  });

  /// معرّف صف الفاتورة.
  final int invoiceId;

  /// الرقم الكامل `INV-YYYY-NNNNN`.
  final String invoiceNo;

  /// الإجماليات المخزَّنة (بعملة الفاتورة).
  final CartTotals totals;

  /// حالة الدفع المخزَّنة (cash/credit/mixed).
  final SalePaymentMethod payStatus;

  /// سعر الصرف المطبَّق (Snapshot — 1 للعملة الأساسية).
  final double exchangeRate;

  /// هل السعر احتياطي (آخر سعر معروف — شارة FR-02-20)؟
  final bool rateIsFallback;

  /// الباقي للعميل = paidCash − grandTotal عند الدفع الزائد — **يخرجه
  /// الكاشير يدوياً ولا يدخل الصندوق ولا الدين**.
  final double changeDue;

  /// الجزء الآجل = grandTotal − المدفوع الصافي (دين على العميل بعملة
  /// الفاتورة — `invoice.due_amount`).
  final double remainingCredit;
}

// ─────────────────────────────────────────────────────────────────────
// نماذج القراءة (شاشات: تفاصيل الفاتورة / آخر المبيعات / إجماليات الفترة)
// ─────────────────────────────────────────────────────────────────────

/// بند فاتورة مبيعات مقروء — صف من `invoice_item` مع اسم الصنف.
class SaleInvoiceItemLine {
  const SaleInvoiceItemLine({
    required this.productId,
    required this.lineDesc,
    required this.qty,
    required this.unitPrice,
    required this.discountPercent,
    required this.discountAmount,
    required this.lineTotal,
    required this.lineCost,
    this.freeQty = 0,
    this.unitName,
    this.batchId,
    this.notes,
  });

  final int? productId;

  /// وصف السطر (اسم الصنف لحظة البيع).
  final String? lineDesc;

  final double qty;
  final double unitPrice;

  /// الكمية المجانية/بونص المرفقة بالسطر (≥ 0 — عمود `free_qty` هجرة
  /// v5، موجة UX-4): المنصرف الكلي = qty + freeQty. غياب العمود بصفوف
  /// قديمة القاعدة = 0 (بلا بونص — سلوك ما قبل الترقية).
  final double freeQty;

  /// اسم وحدة البيع (عرض فقط — عمود الوحدة بقوالب الطباعة UX-3؛
  /// `invoice_item.unit_id` موجود بالمخطط منذ v1 ولم يكن يُقرأ).
  final String? unitName;

  /// خصم السطر النسبي (0 إن كان الخصم مبلغاً).
  final double discountPercent;

  /// الخصم الفعلي الكلي للسطر (سطر + نصيبه من رأس الفاتورة).
  final double discountAmount;

  /// الصافي النهائي للسطر.
  final double lineTotal;

  /// تكلفة السطر = qty × WAC لحظة البيع (قاعدة 5.4-3).
  final double lineCost;

  /// الدفعة الأساسية المستهلكة (FEFO — null لغير المتتبع).
  final int? batchId;

  final String? notes;

  factory SaleInvoiceItemLine.fromRow(Map<String, Object?> row) =>
      SaleInvoiceItemLine(
        productId: row['product_id'] as int?,
        lineDesc: row['line_desc'] as String?,
        qty: (row['qty'] as num?)?.toDouble() ?? 0,
        unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
        freeQty: (row['free_qty'] as num?)?.toDouble() ?? 0,
        unitName: row['unit_name'] as String?,
        discountPercent: (row['discount_percent'] as num?)?.toDouble() ?? 0,
        discountAmount: (row['discount_amount'] as num?)?.toDouble() ?? 0,
        lineTotal: (row['line_total'] as num?)?.toDouble() ?? 0,
        lineCost: (row['line_cost'] as num?)?.toDouble() ?? 0,
        batchId: row['batch_id'] as int?,
        notes: row['notes'] as String?,
      );
}

/// رأس فاتورة مبيعات مقروء — صف من `invoice` حيث doc_type='sale'.
class SaleInvoice {
  const SaleInvoice({
    required this.id,
    required this.invoiceNo,
    required this.payStatus,
    required this.status,
    required this.issuedAt,
    this.quotationId,
    this.customerId,
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
  final SalePaymentMethod payStatus;

  /// completed / draft / void (آلة الحالات 5.4-2).
  final String status;

  /// لحظة الإصدار (UTC كما في القاعدة).
  final DateTime issuedAt;

  /// عرض السعر المصدر إن وُجد (تحويل FR-02-11).
  final int? quotationId;

  final int? customerId;
  final int warehouseId;
  final int? cashboxId;
  final int currencyId;

  /// Snapshot سعر الصرف (FR-08-05).
  final double exchangeRate;

  /// شارة «سعر صرف تقديري» (FR-02-20).
  final bool rateIsFallback;

  final double subtotal;
  final double discountAmount;
  final double total;
  final double totalBase;
  final double paidAmount;
  final double dueAmount;
  final double costTotal;
  final String? notesInternal;
  final String? notesPrinted;

  factory SaleInvoice.fromRow(Map<String, Object?> row) => SaleInvoice(
    id: row['id'] as int,
    invoiceNo: row['invoice_no'] as String,
    payStatus: SalePaymentMethod.values.firstWhere(
      (m) => m.code == (row['pay_status'] as String),
    ),
    status: row['status'] as String,
    issuedAt: DateTime.parse(row['issued_at'] as String),
    quotationId: row['quotation_id'] as int?,
    customerId: row['customer_id'] as int?,
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

/// تفاصيل فاتورة كاملة للعرض: الرأس + البنود + أسماء العميل/العملة.
class SaleInvoiceDetail {
  const SaleInvoiceDetail({
    required this.invoice,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.currencyCode,
    this.currencySymbol,
  });

  final SaleInvoice invoice;
  final List<SaleInvoiceItemLine> items;
  final String? customerName;
  final String? customerPhone;
  final String? currencyCode;
  final String? currencySymbol;
}

/// سطر ملخص فاتورة في قائمة آخر المبيعات.
class SaleInvoiceSummary {
  const SaleInvoiceSummary({
    required this.id,
    required this.invoiceNo,
    required this.issuedAt,
    this.customerId,
    this.customerName,
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
  final int? customerId;
  final String? customerName;
  final String? currencyCode;
  final double total;
  final double paidAmount;
  final double dueAmount;
  final SalePaymentMethod payStatus;
  final String status;
}

/// إجماليات مبيعات فترة (للداشبورد/التقارير اللاحقة — بالعملة الأساسية
/// عبر `total_base` كما في DashboardRepository).
class SalesPeriodTotals {
  const SalesPeriodTotals({
    required this.invoiceCount,
    required this.salesBase,
    required this.costTotal,
    required this.cashCollected,
  });

  /// عدد فواتير البيع المكتملة في الفترة.
  final int invoiceCount;

  /// Σ total_base (مبيعات بالعملة الأساسية).
  final double salesBase;

  /// Σ cost_total (COGS بالعملة الأساسية — مكتمل).
  final double costTotal;

  /// Σ مبالغ سندات القبض المرتبطة بفواتير الفترة (اختياري للعرض).
  final double cashCollected;

  /// صافي ربح الفترة التقريبي (مبيعات − تكلفة) — الشكل الكامل الملزم
  /// لصيغة الربح في تقرير FR-09-02 لا يُحسب هنا.
  double get grossProfit => salesBase - costTotal;
}
