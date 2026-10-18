/// حالة سلة الكاشير الخالصة — أنواع البيانات ونسخ الحالة (R19-D3a).
///
/// نُزعت من `sell_cart_view_model.dart` بنقل حرفي بلا أي تغيير دلالة:
/// العميل والسطر والحالة كيانات نقية، و`sellCartStateWith` هي مساعد النسخ
/// المحدَّثة (علامة «أبقِ القيمة الحالية» للحقول القابلة للتصفير)،
/// و`sellCartQtyText` تنسيق الكمية لرسائل الرفض. الملف يُصدَّر من
/// `sell_cart_view_model.dart` فبقيت استيرادات المستدعين كما هي.
library;

import '../../../../domain/core/numbers.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/sale.dart';

/// علامة «أبقِ القيمة الحالية» للحقول القابلة للتصفير في [sellCartStateWith].
const Object sellCartKeep = Object();

/// عميل السلة — محدد بالاسم، أو نقدي مجهول (id = null).
class CartCustomer {
  const CartCustomer({
    required this.name,
    this.id,
    this.phone,
    this.creditLimit,
  });

  final int? id;
  final String name;
  final String? phone;

  /// حد الائتمان (null = بلا حد — FR-03-01).
  final double? creditLimit;

  /// عميل نقدي مجهول؟
  bool get isCash => id == null;
}

/// سطر سلة الواجهة — صورة الصنف لحظة إضافته + حقوله القابلة للتحرير.
class CartUiLine {
  const CartUiLine({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.discountType,
    required this.discountValue,
    required this.availableQty,
    required this.isService,
    this.barcode,
    this.costPrice = 0,
    this.freeQty = 0,
  });

  final int productId;
  final String name;
  final String? barcode;

  /// الكمية (> 0 دائماً — القيم غير الصالحة ترفض قبل الدخول).
  final double qty;

  /// الكمية المجانية/بونص (≥ 0 — موجة UX-4؛ دائم التوفر منذ R16-a):
  /// تُدخل من محرر السطر الموحّد (BottomSheet بنقرة على صف السطر).
  /// لا تدخل أي تسعير — المنصرف الكلي (qty + freeQty) يُحسب مخزونياً
  /// وقت الترحيل.
  final double freeQty;

  /// سعر الوحدة بعملة الفاتورة (≥ 0).
  final double unitPrice;

  final SaleDiscountType discountType;
  final double discountValue;

  /// المتاح بالمخزن المحدد لحظة الإضافة (null للخدمي — لا مخزون له).
  final double? availableQty;

  final bool isService;

  /// تكلفة الوحدة بالعملة الأساسية لحظة الإضافة (UX-2a — كشف البيع تحت
  /// التكلفة `invoicing.discount_below_margin`).
  final double costPrice;

  /// تجاوز الكمية للمتاح؟ (FR-02-02 — تحذير بصري بلون تحذيري).
  /// UX-4: المقارنة بالمنصرف الكلي (مدفوع + مجاني) — البونص يخرج من
  /// المخزون مثل المدفوع.
  bool get exceedsAvailable =>
      availableQty != null && qty + freeQty > availableQty! + qtyEpsilon;

  CartUiLine copyWith({
    double? qty,
    double? freeQty,
    double? unitPrice,
    SaleDiscountType? discountType,
    double? discountValue,
  }) => CartUiLine(
    productId: productId,
    name: name,
    barcode: barcode,
    qty: qty ?? this.qty,
    freeQty: freeQty ?? this.freeQty,
    unitPrice: unitPrice ?? this.unitPrice,
    discountType: discountType ?? this.discountType,
    discountValue: discountValue ?? this.discountValue,
    availableQty: availableQty,
    isService: isService,
    costPrice: costPrice,
  );

  CartLine toCartLine() => CartLine(
    productId: productId,
    qty: qty,
    unitPrice: unitPrice,
    lineDiscountType: discountType,
    lineDiscountValue: discountValue,
    freeQty: freeQty,
  );
}

/// حالة سلة الكاشير الكاملة.
class SellCartState {
  const SellCartState({
    required this.loading,
    this.error,
    required this.currencies,
    this.baseCurrency,
    this.currencyId,
    this.todayRate,
    required this.rateKnown,
    this.customer,
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
    this.overAvailPolicy = 'warn',
    this.showDiscounts = true,
    this.warnBelowMargin = false,
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

  final CartCustomer? customer;
  final int? warehouseId;

  final List<CartUiLine> lines;

  final SaleDiscountType invoiceDiscountType;
  final double invoiceDiscountValue;

  /// ترحيل جارٍ الآن (قفل الأزرار).
  final bool posting;

  /// رسالة رفض آخر ترحيل (تُعرض بوضوح — السلة لا تُفقد).
  final String? postError;

  /// إشعار عابر (باركود غير موجود مثلاً) — يُمسح بعد العرض.
  final String? notice;

  /// رقم INV القادم (معاينة — الترقيم الحقيقي ذرّي داخل المعاملة).
  final String? nextInvoiceNo;

  /// طلب فتح نافذة إدخال سعر اليوم (FR-08-09) — يُستهلك بـ clearFxGate.
  final bool fxGateRequired;

  /// إيصال آخر فاتورة مرحّلة (نجاح — «فاتورة جديدة» تفرّغ السلة).
  final SalePostedReceipt? lastReceipt;

  /// سياسة البيع فوق المتاح (UX-2a — `sale.over_avail_policy`):
  /// `warn` = تحذير بصري فقط (سلوك v0.x)، `block` = منع الترحيل.
  final String overAvailPolicy;

  /// إظهار عناصر الخصم بالكاشير (UX-2a — `sale.show_discounts`).
  final bool showDiscounts;

  /// تحذير البيع تحت التكلفة مفعّل؟ (UX-2a —
  /// `invoicing.discount_below_margin`).
  final bool warnBelowMargin;

  Currency? get selectedCurrency {
    for (final currency in currencies) {
      if (currency.id == currencyId) return currency;
    }
    return null;
  }

  bool get isCustomerSelected => customer != null && customer!.id != null;

  static const SellCartState initial = SellCartState(
    loading: true,
    currencies: <Currency>[],
    rateKnown: true,
    lines: <CartUiLine>[],
    invoiceDiscountType: SaleDiscountType.amount,
    invoiceDiscountValue: 0,
    posting: false,
  );
}

/// نسخة حالة محدَّثة — للحقول القابلة للتصفير (customer/postError/notice/
/// todayRate/lastReceipt): حذف الوسيطة أو تمرير null يصفّرها، وتمرير
/// [sellCartKeep] يبقيها. بقية الحقول: حذف الوسيطة يبقيها.
SellCartState sellCartStateWith(
  SellCartState state, {
  bool? loading,
  List<Currency>? currencies,
  Object? baseCurrency = sellCartKeep,
  int? currencyId,
  Object? todayRate = sellCartKeep,
  bool? rateKnown,
  Object? customer = sellCartKeep,
  int? warehouseId,
  List<CartUiLine>? lines,
  SaleDiscountType? invoiceDiscountType,
  double? invoiceDiscountValue,
  bool? posting,
  Object? postError = sellCartKeep,
  Object? notice = sellCartKeep,
  String? nextInvoiceNo,
  bool? fxGateRequired,
  Object? lastReceipt = sellCartKeep,
  String? overAvailPolicy,
  bool? showDiscounts,
  bool? warnBelowMargin,
}) => SellCartState(
  loading: loading ?? state.loading,
  error: state.error,
  currencies: currencies ?? state.currencies,
  baseCurrency: identical(baseCurrency, sellCartKeep)
      ? state.baseCurrency
      : baseCurrency as Currency?,
  currencyId: currencyId ?? state.currencyId,
  todayRate: identical(todayRate, sellCartKeep)
      ? state.todayRate
      : todayRate as double?,
  rateKnown: rateKnown ?? state.rateKnown,
  customer: identical(customer, sellCartKeep)
      ? state.customer
      : customer as CartCustomer?,
  warehouseId: warehouseId ?? state.warehouseId,
  lines: lines ?? state.lines,
  invoiceDiscountType: invoiceDiscountType ?? state.invoiceDiscountType,
  invoiceDiscountValue: invoiceDiscountValue ?? state.invoiceDiscountValue,
  posting: posting ?? state.posting,
  postError: identical(postError, sellCartKeep)
      ? state.postError
      : postError as String?,
  notice: identical(notice, sellCartKeep) ? state.notice : notice as String?,
  nextInvoiceNo: nextInvoiceNo ?? state.nextInvoiceNo,
  fxGateRequired: fxGateRequired ?? state.fxGateRequired,
  lastReceipt: identical(lastReceipt, sellCartKeep)
      ? state.lastReceipt
      : lastReceipt as SalePostedReceipt?,
  overAvailPolicy: overAvailPolicy ?? state.overAvailPolicy,
  showDiscounts: showDiscounts ?? state.showDiscounts,
  warnBelowMargin: warnBelowMargin ?? state.warnBelowMargin,
);

/// نص كمية للرسائل (نفس نمط sellQtyText بلا استيراد طبقة العرض).
String sellCartQtyText(double qty) => qty == qty.truncateToDouble()
    ? qty.truncate().toString()
    : qty.toStringAsFixed(3);
