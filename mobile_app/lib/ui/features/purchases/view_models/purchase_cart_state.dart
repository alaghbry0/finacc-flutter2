/// حالة فاتورة الشراء الحية الخالصة — أنواع البيانات ونسخ الحالة
/// (R19-D3c — نُزعت من `purchase_cart_view_model.dart` بنقل حرفي بلا أي
/// تغيير دلالة: المورد والسطر والحالة كيانات نقية، و`purchaseCartStateWith`
/// هي مساعد النسخ المحدَّثة (علامة «أبقِ القيمة الحالية» للحقول القابلة
/// للتصفير). الملف يُصدَّر من `purchase_cart_view_model.dart` فبقيت
/// استيرادات المستدعين كما هي.
library;

import '../../../../domain/models/company.dart';
import '../../../../domain/models/purchase.dart';

/// علامة «أبقِ القيمة الحالية» للحقول القابلة للتصفير في
/// [purchaseCartStateWith].
const Object purchaseCartKeep = Object();

/// مورد فاتورة الشراء — إلزامي (لا مورد مجهول في الشراء).
class CartSupplier {
  const CartSupplier({required this.id, required this.name, this.phone});

  final int id;
  final String name;
  final String? phone;
}

/// سطر شراء حي — صورة الصنف لحظة إضافته + حقوله القابلة للتحرير،
/// وحقول الدفعة الواردة (رقم الدفعة + الصلاحية) للأصناف المتتبعة،
/// والكمية المجانية/بونص من المورد (R16-a).
class PurchaseCartUiLine {
  const PurchaseCartUiLine({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitCost,
    required this.discountType,
    required this.discountValue,
    required this.currentStock,
    required this.isService,
    required this.trackBatches,
    this.freeQty = 0,
    this.batchNo = '',
    this.expiryDate,
  });

  final int productId;
  final String name;

  /// الكمية المدفوعة للمورد (> 0 دائماً — القيم غير الصالحة ترفض).
  final double qty;

  /// الكمية المجانية/بونص من المورد (≥ 0 — R16-a): الحقل دائم التوفر
  /// بمحرر السطر؛ لا تدخل أي تسعير — المستلم الكلي (qty + freeQty)
  /// يُحسب مخزونياً وقت الترحيل (البونص يخفّض WAC).
  final double freeQty;

  /// تكلفة الوحدة بعملة الفاتورة كما في فاتورة المورد (≥ 0).
  final double unitCost;

  final PurchaseDiscountType discountType;
  final double discountValue;

  /// الرصيد الحالي بالمخزن (معلوماتي — الوارد يُضاف فوقه، لا سقف للشراء).
  final double? currentStock;

  final bool isService;

  /// يتتبع الدفعات؟ → رقم الدفعة إلزامي قبل الترحيل.
  final bool trackBatches;

  /// رقم الدفعة الواردة (فارغ = لم يُدخل بعد).
  final String batchNo;

  /// صلاحية الدفعة الواردة (إلزامية مع رقم الدفعة).
  final DateTime? expiryDate;

  PurchaseCartUiLine copyWith({
    double? qty,
    double? freeQty,
    double? unitCost,
    PurchaseDiscountType? discountType,
    double? discountValue,
    String? batchNo,
    DateTime? expiryDate,
  }) => PurchaseCartUiLine(
    productId: productId,
    name: name,
    qty: qty ?? this.qty,
    freeQty: freeQty ?? this.freeQty,
    unitCost: unitCost ?? this.unitCost,
    discountType: discountType ?? this.discountType,
    discountValue: discountValue ?? this.discountValue,
    currentStock: currentStock,
    isService: isService,
    trackBatches: trackBatches,
    batchNo: batchNo ?? this.batchNo,
    expiryDate: expiryDate ?? this.expiryDate,
  );

  PurchaseLine toPurchaseLine() => PurchaseLine(
    productId: productId,
    qty: qty,
    unitCost: unitCost,
    lineDiscountType: discountType,
    lineDiscountValue: discountValue,
    freeQty: freeQty,
    batchNo: batchNo.trim().isEmpty ? null : batchNo.trim(),
    expiryDate: batchNo.trim().isEmpty ? null : expiryDate,
  );
}

/// حالة فاتورة الشراء الحية الكاملة.
class PurchaseCartState {
  const PurchaseCartState({
    required this.loading,
    this.error,
    required this.currencies,
    this.baseCurrency,
    this.currencyId,
    this.todayRate,
    required this.rateKnown,
    this.supplier,
    this.warehouseId,
    required this.lines,
    required this.invoiceDiscountType,
    required this.invoiceDiscountValue,
    required this.posting,
    this.postError,
    this.notice,
    this.nextInvoiceNo,
    this.fxGateRequired = false,
    this.lastReceipt,
  });

  final bool loading;
  final Object? error;

  /// العملات النشطة (الأساس أولاً).
  final List<Currency> currencies;
  final Currency? baseCurrency;

  /// عملة الفاتورة المحددة (الأساس افتراضياً).
  final int? currencyId;

  /// سعر اليوم للعملة المحددة (null للأساس أو عند الغياب).
  final double? todayRate;

  /// هل سعر اليوم معروف للعملة المحددة؟ (الأساس = true دائماً).
  final bool rateKnown;

  final CartSupplier? supplier;
  final int? warehouseId;

  final List<PurchaseCartUiLine> lines;

  final PurchaseDiscountType invoiceDiscountType;
  final double invoiceDiscountValue;

  /// ترحيل جارٍ الآن (قفل الأزرار).
  final bool posting;

  /// رسالة رفض آخر ترحيل (تُعرض بوضوح — الفاتورة لا تُفقد).
  final String? postError;

  /// إشعار عابر — يُمسح بعد العرض.
  final String? notice;

  /// رقم PUR القادم (معاينة — الترقيم الحقيقي ذرّي داخل المعاملة).
  final String? nextInvoiceNo;

  /// طلب فتح نافذة إدخال سعر اليوم (FR-08-09).
  final bool fxGateRequired;

  /// إيصال آخر فاتورة شراء مُرحَّلة (نجاح — «شراء جديد» يفرّغ الفاتورة).
  final PurchasePostedReceipt? lastReceipt;

  Currency? get selectedCurrency {
    for (final currency in currencies) {
      if (currency.id == currencyId) return currency;
    }
    return null;
  }

  static const PurchaseCartState initial = PurchaseCartState(
    loading: true,
    currencies: <Currency>[],
    rateKnown: true,
    lines: <PurchaseCartUiLine>[],
    invoiceDiscountType: PurchaseDiscountType.amount,
    invoiceDiscountValue: 0,
    posting: false,
  );
}

/// نسخة حالة محدَّثة — للحقول القابلة للتصفير (supplier/postError/notice/
/// todayRate/lastReceipt): حذف الوسيطة أو تمرير null يصفّرها، وتمرير
/// [purchaseCartKeep] يبقيها. بقية الحقول: حذف الوسيطة يبقيها.
PurchaseCartState purchaseCartStateWith(
  PurchaseCartState state, {
  bool? loading,
  List<Currency>? currencies,
  Object? baseCurrency = purchaseCartKeep,
  int? currencyId,
  Object? todayRate = purchaseCartKeep,
  bool? rateKnown,
  Object? supplier = purchaseCartKeep,
  int? warehouseId,
  List<PurchaseCartUiLine>? lines,
  PurchaseDiscountType? invoiceDiscountType,
  double? invoiceDiscountValue,
  bool? posting,
  Object? postError = purchaseCartKeep,
  Object? notice = purchaseCartKeep,
  String? nextInvoiceNo,
  bool? fxGateRequired,
  Object? lastReceipt = purchaseCartKeep,
}) => PurchaseCartState(
  loading: loading ?? state.loading,
  error: state.error,
  currencies: currencies ?? state.currencies,
  baseCurrency: identical(baseCurrency, purchaseCartKeep)
      ? state.baseCurrency
      : baseCurrency as Currency?,
  currencyId: currencyId ?? state.currencyId,
  todayRate: identical(todayRate, purchaseCartKeep)
      ? state.todayRate
      : todayRate as double?,
  rateKnown: rateKnown ?? state.rateKnown,
  supplier: identical(supplier, purchaseCartKeep)
      ? state.supplier
      : supplier as CartSupplier?,
  warehouseId: warehouseId ?? state.warehouseId,
  lines: lines ?? state.lines,
  invoiceDiscountType: invoiceDiscountType ?? state.invoiceDiscountType,
  invoiceDiscountValue: invoiceDiscountValue ?? state.invoiceDiscountValue,
  posting: posting ?? state.posting,
  postError: identical(postError, purchaseCartKeep)
      ? state.postError
      : postError as String?,
  notice: identical(notice, purchaseCartKeep)
      ? state.notice
      : notice as String?,
  nextInvoiceNo: nextInvoiceNo ?? state.nextInvoiceNo,
  fxGateRequired: fxGateRequired ?? state.fxGateRequired,
  lastReceipt: identical(lastReceipt, purchaseCartKeep)
      ? state.lastReceipt
      : lastReceipt as PurchasePostedReceipt?,
);
