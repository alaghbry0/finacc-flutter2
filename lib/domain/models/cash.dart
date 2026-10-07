/// نماذج النقدية — الوحدة 04 (SRS v1.5 §5.3 + FR-04): الصناديق وأرصدتها
/// الحية بكل عملة على حدة، حركات الصندوق وسجلاتها، مسودات السندات
/// والحركات السريعة، وإيصالات الترحيل.
///
/// **القاعدة المركزية (5.4-7 / FR-08-11): لا تُخلط العملات أبداً** — رصيد
/// كل صندوق مجموعة رصيد لكل عملة على حدة («دلاء عملة»)، وصافي النقدية
/// يُعرض سطراً مستقلاً لكل عملة بعملتها لا في رقم مجمّع.
library;

/// نوع حركة الصندوق — قيم `cash_tx.tx_type` حرفياً (CHECK المخطط).
enum CashTxType {
  receipt('receipt'),
  payment('payment'),
  expense('expense'),
  ownerDraw('owner_draw'),
  capitalIn('capital_in'),
  boxTransfer('box_transfer'),
  bankDeposit('bank_deposit'),
  bankWithdraw('bank_withdraw'),
  opening('opening');

  const CashTxType(this.code);

  /// القيمة المخزَّنة في العمود.
  final String code;

  /// يحل قيمة العمود — أو `null` لقيمة غير معروفة (أنواع V1.1 المؤجلة).
  static CashTxType? tryParse(String? code) {
    if (code == null) return null;
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }

  /// هل الحركة ذات ساقين (صندوق مصدر + صندوق هدف)؟
  bool get isTwoLegged =>
      this == boxTransfer || this == bankDeposit || this == bankWithdraw;

  /// هل الحركة تُرشد لقيمة موجبة على الصندوق (`cashbox_id`)؟
  /// (الساق الواردة للهدف تُحسب دائماً موجبة على الهدف — انظر المستودع.)
  bool get isInflowOnMainBox =>
      this == receipt || this == capitalIn || this == opening;
}

/// فئة مصروف — جدول `expense_category` (FR-04-05).
class ExpenseCategoryInfo {
  const ExpenseCategoryInfo({
    required this.id,
    required this.name,
    required this.isArchived,
    required this.isProtected,
  });

  final int id;
  final String name;
  final bool isArchived;

  /// فئة نظامية لا تُؤرشف («رواتب» — بديل وحدة الموظفين المؤجلة).
  final bool isProtected;

  factory ExpenseCategoryInfo.fromRow(Map<String, Object?> row) =>
      ExpenseCategoryInfo(
        id: row['id'] as int,
        name: row['name'] as String,
        isArchived: (row['is_archived'] as int? ?? 0) == 1,
        isProtected: (row['is_protected'] as int? ?? 0) == 1,
      );
}

/// صندوق — جدول `cashbox` (FR-04-01).
class CashboxInfo {
  const CashboxInfo({
    required this.id,
    required this.name,
    required this.currencyId,
    required this.currencyCode,
    required this.isDefault,
    required this.isArchived,
  });

  final int id;
  final String name;
  final int currencyId;
  final String currencyCode;
  final bool isDefault;
  final bool isArchived;

  factory CashboxInfo.fromRow(Map<String, Object?> row) => CashboxInfo(
    id: row['id'] as int,
    name: row['name'] as String,
    currencyId: row['currency_id'] as int,
    currencyCode: (row['currency_code'] as String?) ?? '',
    isDefault: (row['is_default'] as int? ?? 0) == 1,
    isArchived: (row['is_archived'] as int? ?? 0) == 1,
  );
}

/// دلو عملة واحد داخل صندوق — رصيد تلك العملة في ذلك الصندوق.
class CashCurrencyBucket {
  const CashCurrencyBucket({
    required this.currencyId,
    required this.currencyCode,
    required this.amount,
  });

  final int currencyId;
  final String currencyCode;

  /// الرصيد الحي (قد يكون سالباً — FR-04-09).
  final double amount;
}

/// صندوق برصيده الحي — الرصيد الأصلي بعملة الصندوق + دلاء العملات
/// الأخرى الواصلة إليه من حركات بعملة مختلفة (فصل العملات 5.4-7).
class CashboxWithBalance {
  const CashboxWithBalance({
    required this.box,
    required this.nativeBalance,
    required this.foreignBuckets,
  });

  final CashboxInfo box;

  /// الرصيد بعملة الصندوق نفسها (دلو عملة الصندوق).
  final double nativeBalance;

  /// دلاء العملات الأخرى داخل الصندوق (فارغ غالباً).
  final List<CashCurrencyBucket> foreignBuckets;

  /// مجموع كل الدلاء محوّلاً؟ — **لا**: كل عملة تُعرض بعملتها حصراً.
  bool get isNegative => nativeBalance < -0.0001;
}

/// سطر صافي النقدية لعملة واحدة (بطاقة المحور البطلة).
class CashNetLine {
  const CashNetLine({
    required this.currencyId,
    required this.currencyCode,
    required this.amount,
    required this.isBase,
  });

  final int currencyId;
  final String currencyCode;
  final double amount;
  final bool isBase;
}

/// صف حركة صندوق للسجل — كل حقول `cash_tx` مع أسماء المراجع.
class CashMovementRow {
  const CashMovementRow({
    required this.id,
    required this.txTypeCode,
    required this.cashboxId,
    required this.cashboxName,
    required this.currencyId,
    required this.currencyCode,
    required this.amount,
    required this.exchangeRate,
    required this.settlementRate,
    required this.fxGainLoss,
    required this.voucherNo,
    required this.txDate,
    required this.isVoided,
    required this.reversalOf,
    this.toCashboxId,
    this.toCashboxName,
    this.refType,
    this.refId,
    this.expenseCategoryId,
    this.expenseCategoryName,
    this.customerId,
    this.customerName,
    this.supplierId,
    this.supplierName,
    this.description,
  });

  final int id;
  final String txTypeCode;
  final int cashboxId;
  final String cashboxName;
  final int currencyId;
  final String currencyCode;
  final double amount;
  final double exchangeRate;
  final double? settlementRate;
  final double fxGainLoss;
  final String? voucherNo;
  final DateTime txDate;
  final bool isVoided;
  final int? reversalOf;
  final int? toCashboxId;
  final String? toCashboxName;
  final String? refType;
  final int? refId;
  final int? expenseCategoryId;
  final String? expenseCategoryName;
  final int? customerId;
  final String? customerName;
  final int? supplierId;
  final String? supplierName;
  final String? description;

  CashTxType? get type => CashTxType.tryParse(txTypeCode);

  /// هل هذه حركة معاكسة (سطر إبطال لحركة أخرى)؟
  bool get isReversal => reversalOf != null;

  /// هل يجوز إبطالها من وحدة النقدية؟ (الحركات المرتبطة بمستندات
  /// أخرى — تحصيلات الإصدار وردود المرتجعات — تُبطل عبر مستنداتها.)
  bool get isVoidable =>
      !isVoided &&
      !isReversal &&
      (refType == null ||
          refType == 'on_account' ||
          refType == 'transfer' ||
          (refType == 'invoice' && refId == null));
}

/// تفاصيل حركة واحدة — الصف + تخصيصاته على الفواتير.
class CashMovementDetail {
  const CashMovementDetail({required this.movement, required this.allocations});

  final CashMovementRow movement;

  /// تخصيصات payment_allocation (سندات مخصصة على فواتير) — قد تكون فارغة.
  final List<CashAllocationLine> allocations;
}

/// سطر تخصيص سند على فاتورة.
class CashAllocationLine {
  const CashAllocationLine({
    required this.invoiceId,
    required this.invoiceNo,
    required this.invoiceTypeCode,
    required this.issuedAt,
    required this.allocatedAmount,
    required this.currencyCode,
  });

  final int invoiceId;
  final String invoiceNo;

  /// doc_type للفاتورة (sale/purchase).
  final String invoiceTypeCode;
  final DateTime issuedAt;
  final double allocatedAmount;
  final String currencyCode;
}

/// فاتورة مفتوحة (غير مسددة) للتخصيص FIFO — FR-04-03 / قاعدة 5.4-6.
class OpenInvoiceLine {
  const OpenInvoiceLine({
    required this.invoiceId,
    required this.invoiceNo,
    required this.issuedAt,
    required this.dueAmount,
    required this.voucherAllocated,
  });

  final int invoiceId;
  final String invoiceNo;
  final DateTime issuedAt;

  /// `invoice.due_amount` كما هو بالقاعدة.
  final double dueAmount;

  /// ما خصّصته سندات القبض/الصرف المرقمة عليه سابقاً (فوق due_amount
  /// لأن التخصيص يحدّث الدفتر — انظر المستودع).
  final double voucherAllocated;

  /// المتبقي فعلياً للتخصيص = dueAmount − voucherAllocated.
  double get remaining => dueAmount - voucherAllocated;
}

/// نوع الطرف لسند القبض/الصرف.
enum VoucherPartyType { customer, supplier }

/// مسودة سند (قبض RVT من عميل / صرف PMT لمورد) — FR-04-02/03/10.
class VoucherDraft {
  const VoucherDraft({
    required this.partyType,
    required this.partyId,
    required this.cashboxId,
    required this.amount,
    required this.currencyId,
    required this.txDate,
    required this.allocateFifo,
    this.description,
  });

  final VoucherPartyType partyType;
  final int partyId;
  final int cashboxId;

  /// المبلغ بعملة السند (عملة الصندوق أو عملة الطرف).
  final double amount;

  /// عملة السند.
  final int currencyId;
  final DateTime txDate;

  /// true = تخصيص تلقائي FIFO على أقدم الفواتير المفتوحة؛
  /// false = قبض/صرف على الحساب (`ref_type='on_account'`).
  final bool allocateFifo;
  final String? description;
}

/// إيصال سند مُرحَّل — مخرجات createVoucher.
class VoucherPostedReceipt {
  const VoucherPostedReceipt({
    required this.cashTxId,
    required this.voucherNo,
    required this.amount,
    required this.currencyCode,
    required this.allocations,
    this.fxGainLoss = 0,
  });

  final int cashTxId;

  /// الرقم الكامل `RVT-YYYY-NNNNN` / `PMT-YYYY-NNNNN`.
  final String voucherNo;
  final double amount;
  final String currencyCode;

  /// خطة التخصيص المطبقة (فارغة عند «على الحساب»).
  final List<VoucherAllocationApplied> allocations;

  /// فرق الصرف المحقق بالعملة الأساسية (صفر عند توافق العملتين).
  final double fxGainLoss;
}

/// تخصيص واحد طُبّق فعلياً من السند على فاتورة.
class VoucherAllocationApplied {
  const VoucherAllocationApplied({
    required this.invoiceId,
    required this.invoiceNo,
    required this.amount,
  });

  final int invoiceId;
  final String invoiceNo;
  final double amount;
}

/// نوع الحركة السريعة الموحدة (النموذج الذكي).
enum QuickMovementKind {
  expense('expense'),
  ownerDraw('owner_draw'),
  capitalIn('capital_in'),
  boxTransfer('box_transfer'),
  bankDeposit('bank_deposit'),
  bankWithdraw('bank_withdraw');

  const QuickMovementKind(this.code);

  /// قيمة `tx_type` المكافئة.
  final String code;

  /// هل يحتاج صندوقاً هدفاً؟
  bool get needsTargetBox =>
      this == boxTransfer || this == bankDeposit || this == bankWithdraw;
}

/// مسودة حركة سريعة (مصروف/مسحوبات/إيداع مالك/تحويل/بنكي).
class QuickMovementDraft {
  const QuickMovementDraft({
    required this.kind,
    required this.cashboxId,
    required this.amount,
    required this.txDate,
    this.toCashboxId,
    this.expenseCategoryId,
    this.description,
  });

  final QuickMovementKind kind;

  /// الصندوق المصدر (والمستقبِل للحركات ذات الساق الواحدة).
  final int cashboxId;

  /// المبلغ بعملة الصندوق المصدر.
  final double amount;
  final DateTime txDate;

  /// الصندوق الهدف للتحويل/البنكي.
  final int? toCashboxId;

  /// فئة المصروف — إلزامية للمصروف حصراً (FR-04-03).
  final int? expenseCategoryId;
  final String? description;
}

/// إيصال حركة سريعة مُرحَّلة.
class QuickMovementReceipt {
  const QuickMovementReceipt({
    required this.cashTxId,
    required this.kind,
    required this.amount,
    required this.currencyCode,
    required this.sourceBoxName,
    this.targetBoxName,
    this.targetAmount,
  });

  final int cashTxId;
  final QuickMovementKind kind;
  final double amount;
  final String currencyCode;
  final String sourceBoxName;

  /// اسم صندوق الهدف (التحويل/البنكي).
  final String? targetBoxName;

  /// المبلغ الواصل للهدف بعملته (قد يختلف عند اختلاف العملتين).
  final double? targetAmount;
}
