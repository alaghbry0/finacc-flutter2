/// نماذج عروض الأسعار — جداول `quotation` / `quotation_item`
/// (§5.3 / FR-02-11) — المرحلة 4.
///
/// عرض السعر **مستند غير ملزم**: يُرقَّم `QTE-YYYY-NNNNN` ذرّياً ولا يلمس
/// مخزوناً ولا صندوقاً ولا أرصدة إطلاقاً. التحويل إلى فاتورة
/// (`QuotationRepository.convertToInvoice`) ينفَّذ داخل معاملة الفاتورة
/// نفسها عبر `SaleDraft.fromQuotationId` (FR-02-11 / AC-17).
///
/// ملاحظة مخطط: جدول `quotation` بلا عمود `rate_is_fallback` ولا
/// `converted_at` (المخطط مجمّد §5.3) — لذا يُوثَّق الاستخدام الاحتياطي
/// للسعر في `updated_at`/التدقيق، وشارة FR-02-20 تظهر على الفاتورة
/// المحوَّلة لا على العرض نفسه.
library;

import 'sale.dart';

/// حالة عرض السعر — عمود `quotation.status` (CHECK بالقيم الخمس).
///
/// ملاحظة مخطط مجمّد: لا قيمة `cancelled` في CHECK الجدول — الإلغاء
/// (بيد البائع) يُخزّن كـ [rejected] كأقرب دلالة متاحة، وطلب هجرة
/// لإضافة `cancelled` مرفوع للمنسّق (انظر worklog-parts/6-b.md).
enum QuotationStatus {
  draft('draft'),
  sent('sent'),
  converted('converted'),
  expired('expired'),
  rejected('rejected');

  const QuotationStatus(this.code);

  /// الرمز كما يُخزَّن.
  final String code;

  factory QuotationStatus.fromCode(String code) =>
      QuotationStatus.values.firstWhere((s) => s.code == code);

  /// هل يقبل التحويل إلى فاتورة؟ (draft أو sent فقط).
  bool get convertible =>
      this == QuotationStatus.draft || this == QuotationStatus.sent;

  /// هل يقبل الإلغاء؟ (draft أو sent فقط).
  bool get cancellable => convertible;
}

/// سطر عرض سعر — نفس بنية `CartLine` (تسعير مشترك عبر `SalePricing`).
class QuotationLine {
  const QuotationLine({
    required this.productId,
    required this.qty,
    required this.unitPrice,
    this.lineDiscountType = SaleDiscountType.amount,
    this.lineDiscountValue = 0,
    this.notes,
  });

  final int productId;

  /// الكمية (> 0).
  final double qty;

  /// سعر الوحدة المعروض (≥ 0).
  final double unitPrice;

  final SaleDiscountType lineDiscountType;
  final double lineDiscountValue;
  final String? notes;
}

/// مسوّدة عرض سعر — مدخل `QuotationRepository.createQuotation`.
class QuotationDraft {
  const QuotationDraft({
    this.customerId,
    required this.currencyId,
    required this.warehouseId,
    required this.lines,
    this.invoiceDiscountType = SaleDiscountType.amount,
    this.invoiceDiscountValue = 0,
    this.validUntil,
    this.notesInternal,
    this.notesPrinted,
    required this.issuedAt,
  });

  /// العميل (null = عرض لعميل نقدي).
  final int? customerId;

  /// العملة (سعر صرف يومها يُثبَّت على العرض — Snapshot FR-08-05).
  final int currencyId;

  /// المخزن المقصح للمستند (لا يُخصم منه شيء قبل التحويل).
  final int warehouseId;

  /// الأسطر (≥ 1).
  final List<QuotationLine> lines;

  /// خصم رأس العرض (نسبة/مبلغ) — يوزَّع pro-rata مثل الفاتورة.
  final SaleDiscountType invoiceDiscountType;
  final double invoiceDiscountValue;

  /// تاريخ انتهاء صلاحية العرض (FR-02-11).
  final DateTime? validUntil;

  final String? notesInternal;
  final String? notesPrinted;

  /// تاريخ الإصدار.
  final DateTime issuedAt;
}

/// سطر عرض سعر مقروء — صف من `quotation_item`.
class QuotationItemLine {
  const QuotationItemLine({
    required this.productId,
    required this.lineDesc,
    required this.qty,
    required this.unitPrice,
    required this.discountPercent,
    required this.discountAmount,
    required this.lineTotal,
    this.batchId,
    this.notes,
  });

  final int? productId;
  final String? lineDesc;
  final double qty;
  final double unitPrice;

  /// خصم السطر النسبي المخزَّن (0 إن كان مبلغاً).
  final double discountPercent;

  /// الخصم الفعلي الكلي (سطر + نصيب رأس العرض).
  final double discountAmount;

  /// الصافي النهائي للسطر.
  final double lineTotal;

  final int? batchId;
  final String? notes;

  factory QuotationItemLine.fromRow(Map<String, Object?> row) =>
      QuotationItemLine(
        productId: row['product_id'] as int?,
        lineDesc: row['line_desc'] as String?,
        qty: (row['qty'] as num?)?.toDouble() ?? 0,
        unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
        discountPercent: (row['discount_percent'] as num?)?.toDouble() ?? 0,
        discountAmount: (row['discount_amount'] as num?)?.toDouble() ?? 0,
        lineTotal: (row['line_total'] as num?)?.toDouble() ?? 0,
        batchId: row['batch_id'] as int?,
        notes: row['notes'] as String?,
      );
}

/// رأس عرض سعر مقروء — صف من `quotation`.
class Quotation {
  const Quotation({
    required this.id,
    required this.quotationNo,
    required this.status,
    required this.issuedAt,
    this.validUntil,
    this.customerId,
    required this.warehouseId,
    required this.currencyId,
    required this.exchangeRate,
    this.convertedInvoiceId,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    this.notesInternal,
    this.notesPrinted,
    this.updatedAt,
  });

  final int id;

  /// الرقم الكامل `QTE-YYYY-NNNNN`.
  final String quotationNo;

  final QuotationStatus status;

  /// لحظة الإصدار (UTC كما في القاعدة).
  final DateTime issuedAt;

  /// تاريخ انتهاء الصلاحية (تاريخ فقط `YYYY-MM-DD` أو null).
  final DateTime? validUntil;

  final int? customerId;
  final int warehouseId;
  final int currencyId;

  /// Snapshot سعر الصرف وقت الإنشاء.
  final double exchangeRate;

  /// الفاتورة الناتجة عند التحويل (status=converted).
  final int? convertedInvoiceId;

  /// Σ(qty × price) قبل الخصومات.
  final double subtotal;

  /// إجمالي الخصم الفعلي (أسطر + رأس) — نفس دلالة invoice.discount_amount.
  final double discountAmount;

  /// صافي العرض.
  final double total;

  final String? notesInternal;
  final String? notesPrinted;

  /// آخر تحديث (UTC) — يُستعمل لحظة التحويل لغياب converted_at بالمخطط.
  final DateTime? updatedAt;

  factory Quotation.fromRow(Map<String, Object?> row) => Quotation(
    id: row['id'] as int,
    quotationNo: row['quotation_no'] as String,
    status: QuotationStatus.fromCode(row['status'] as String),
    issuedAt: DateTime.parse(row['issued_at'] as String),
    validUntil: row['valid_until'] == null
        ? null
        : DateTime.tryParse(row['valid_until'] as String),
    customerId: row['customer_id'] as int?,
    warehouseId: row['warehouse_id'] as int,
    currencyId: row['currency_id'] as int,
    exchangeRate: (row['exchange_rate'] as num?)?.toDouble() ?? 1,
    convertedInvoiceId: row['converted_invoice_id'] as int?,
    subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
    discountAmount: (row['discount_amount'] as num?)?.toDouble() ?? 0,
    total: (row['total'] as num?)?.toDouble() ?? 0,
    notesInternal: row['notes_internal'] as String?,
    notesPrinted: row['notes_printed'] as String?,
    updatedAt: row['updated_at'] == null
        ? null
        : DateTime.tryParse(row['updated_at'] as String),
  );
}

/// تفاصيل عرض كامل للعرض: الرأس + البنود + أسماء العميل/العملة.
class QuotationDetail {
  const QuotationDetail({
    required this.quotation,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.currencyCode,
  });

  final Quotation quotation;
  final List<QuotationItemLine> items;
  final String? customerName;
  final String? customerPhone;
  final String? currencyCode;
}

/// سطر ملخص عرض في القائمة.
class QuotationSummary {
  const QuotationSummary({
    required this.id,
    required this.quotationNo,
    required this.issuedAt,
    this.validUntil,
    this.customerId,
    this.customerName,
    this.currencyCode,
    required this.total,
    required this.status,
    this.convertedInvoiceId,
  });

  final int id;
  final String quotationNo;
  final DateTime issuedAt;
  final DateTime? validUntil;
  final int? customerId;
  final String? customerName;
  final String? currencyCode;
  final double total;
  final QuotationStatus status;
  final int? convertedInvoiceId;
}
