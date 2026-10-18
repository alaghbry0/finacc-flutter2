/// مساعدات سلة الكاشير النقية (R19-D3a) — حسابات وتحقق وخَرائط بلا حالة.
///
/// نُزعت من `sell_cart_view_model.dart` بنقل حرفي بلا أي تغيير دلالة:
/// التسعير الحي (السلة/المُسعَّرة/خطأ التحقق/أسطر تحت التكلفة)، فحوص ما
/// قبل الترحيل (بترتيب رسائل واضح — وعلم بوابة FX FR-08-09 يطبّقه
/// المتحكم قبل إعادة الرسالة)، خَرائط مسودات الترحيل وعرض السعر، بناء
/// سطر من لقطة الصنف، وحاضنة التحميل الأولى (سياسات + عملات). دوال
/// حرة بعوامل صريحة على نمط R18-D3 — لا تغيير أي سلوك أو رسالة.
library;

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/core/numbers.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/item.dart';
import '../../../../domain/models/quotation.dart';
import '../../../../domain/models/sale.dart';
import '../../../../domain/services/sale_pricing.dart';
import 'sell_cart_state.dart';

/// أسطر السلة بصيغة الترحيل (CartLine).
List<CartLine> sellCartLines(SellCartState state) => [
  for (final line in state.lines) line.toCartLine(),
];

/// السلة المُسعَّرة الآن — null عند الفراغ أو عدم قابلية التسعير.
PricedCart? sellCartPricedCart(SellCartState state) {
  if (state.lines.isEmpty) return null;
  try {
    return SalePricing.priceCart(
      sellCartLines(state),
      invoiceDiscountType: state.invoiceDiscountType,
      invoiceDiscountValue: state.invoiceDiscountValue,
    );
  } on StateError {
    return null;
  }
}

/// خطأ التحقق الحالي (كميات/أسعار/خصومات/صافٍ > 0) — null عند السلامة.
String? sellCartError(SellCartState state) => state.lines.isEmpty
    ? null
    : SalePricing.validateCart(
        sellCartLines(state),
        invoiceDiscountType: state.invoiceDiscountType,
        invoiceDiscountValue: state.invoiceDiscountValue,
      );

/// أسطر السلة المباعة تحت التكلفة (UX-2a — لافتة تحذير بالكاشير عند
/// تفعيل `invoicing.discount_below_margin`): يقارن صافي السطر بعد كل
/// الخصومات بتكلفة الكمية — حكراً على عملة الأساس (التكلفة المحفوظة
/// بالأساس؛ فاتورة بعملة أخرى تُترك بلا تحذير كاذب).
List<String> sellCartBelowCostLineNames(SellCartState state) {
  if (!state.warnBelowMargin || state.lines.isEmpty) {
    return const <String>[];
  }
  final pricedLines = sellCartPricedCart(state)?.lines;
  if (pricedLines == null || pricedLines.length != state.lines.length) {
    return const <String>[];
  }
  final baseId = state.baseCurrency?.id;
  if (baseId == null || state.currencyId != baseId) {
    return const <String>[];
  }
  final names = <String>[];
  for (var i = 0; i < state.lines.length; i++) {
    final line = state.lines[i];
    if (line.isService || line.costPrice <= 0) continue;
    final costTotal = line.costPrice * line.qty;
    if (pricedLines[i].netFinal < costTotal - qtyEpsilon) {
      names.add(line.name);
    }
  }
  return names;
}

/// نتيجة فحوص ما قبل الترحيل (نقية) — [failure] رسالة الرفض أو null،
/// و[fxGateRequired] يطلب من المتحكم فتح بوابة إدخال سعر اليوم.
class SellCartPrePostCheck {
  const SellCartPrePostCheck(this.failure, {this.fxGateRequired = false});

  final String? failure;
  final bool fxGateRequired;
}

/// فحوص ما قبل الترحيل (بترتيب رسائل واضح للمستخدم) — بترتيب الرسائل
/// نفسه حرفياً كما كان بالمتحكم، مع فصل أثر بوابة FX (FR-08-09) كعلم
/// يطبّقه المتحكم قبل إعادة الرسالة — بلا أي تغيير دلالة.
SellCartPrePostCheck sellCartPrePostCheck(
  SellCartState state,
  double paidCash,
  SalePaymentMethod method,
) {
  if (state.lines.isEmpty) {
    return const SellCartPrePostCheck(
      'أضف بنداً واحداً على الأقل إلى الفاتورة قبل الدفع.',
    );
  }
  final cartFailure = sellCartError(state);
  if (cartFailure != null) {
    return SellCartPrePostCheck(cartFailure);
  }
  final currency = state.selectedCurrency;
  if (currency == null) {
    return const SellCartPrePostCheck('اختر عملة الفاتورة أولاً.');
  }
  if (!currency.isBase && !state.rateKnown) {
    // FR-08-09: منع الحفظ + طلب فتح بوابة إدخال سعر اليوم.
    return SellCartPrePostCheck(
      'لا يوجد سعر صرف لعملة ${currency.code} بتاريخ اليوم — '
      'أدخل سعر اليوم أولاً ثم أكمل الدفع.',
      fxGateRequired: true,
    );
  }
  final total = sellCartPricedCart(state)?.totals.grandTotal ?? 0;
  final payFailure = SalePricing.validatePayment(total, paidCash, method);
  if (payFailure != null) {
    return SellCartPrePostCheck(payFailure);
  }
  // UX-2a — `sale.over_avail_policy` = block: أي سطر يتجاوز المتاح يمنع
  // الترحيل من هنا (warn = سلوك v0.x: تحذير بصري فقط والمستودع حارس
  // أخير برسالته الخاصة).
  if (state.overAvailPolicy == 'block') {
    for (final line in state.lines) {
      if (line.exceedsAvailable) {
        return SellCartPrePostCheck(
          'لا يمكن الترحيل: كمية «${line.name}» تتجاوز المتاح '
          '(${sellCartQtyText(line.availableQty!)}) — سياسة «منع البيع فوق '
          'المتاح» مفعّلة من تفضيلات البيع. خفّض الكمية أو عوّض '
          'المخزون أولاً.',
        );
      }
    }
  }
  // عميل نقدي مجهول: نقدي كامل حصراً (الآجل يحتاج حساباً معروفاً).
  final settlement = SalePricing.settlePayment(total, paidCash);
  if (settlement.remainingCredit > moneyEpsilon && !state.isCustomerSelected) {
    return const SellCartPrePostCheck(
      'البيع الآجل يتطلب اختيار عميل أولاً — العميل النقدي المجهول '
      'يسدد نقداً كاملاً فقط.',
    );
  }
  return const SellCartPrePostCheck(null);
}

/// بناء مسودة الترحيل من الحالة الحالية — null عند نقص العملة/المخزن.
SaleDraft? buildSaleDraftFromCart(
  SellCartState state, {
  required double paidCash,
  required SalePaymentMethod method,
  required DateTime now,
}) {
  final currencyId = state.currencyId;
  final warehouseId = state.warehouseId;
  if (currencyId == null || warehouseId == null) return null;
  return SaleDraft(
    customerId: state.customer?.id,
    currencyId: currencyId,
    lines: sellCartLines(state),
    invoiceDiscountType: state.invoiceDiscountType,
    invoiceDiscountValue: state.invoiceDiscountValue,
    paidCash: paidCash,
    paymentMethod: method,
    warehouseId: warehouseId,
    issuedAt: now,
  );
}

/// بناء مسودة عرض السعر من الحالة الحالية (FR-02-11 / P2-5) — نفس
/// ترتيب نداءات الساعة الأصلية (الصلاحية الافتراضية ثم الإصدار).
QuotationDraft buildQuotationDraftFromCart(
  SellCartState state, {
  DateTime? validUntil,
  required DateTime Function() clock,
  required Duration defaultValidity,
}) => QuotationDraft(
  customerId: state.customer?.id,
  currencyId: state.currencyId!,
  warehouseId: state.warehouseId!,
  lines: [
    for (final line in state.lines)
      QuotationLine(
        productId: line.productId,
        qty: line.qty,
        unitPrice: line.unitPrice,
        lineDiscountType: line.discountType,
        lineDiscountValue: line.discountValue,
      ),
  ],
  invoiceDiscountType: state.invoiceDiscountType,
  invoiceDiscountValue: state.invoiceDiscountValue,
  // P2-5: الصلاحية الافتراضية عند غياب صلاحية صريحة.
  validUntil: validUntil ?? clock().add(defaultValidity),
  issuedAt: clock(),
);

/// بناء سطر سلة جديد من لقطة الصنف (كمية 1 بسعر التجزئة والتكلفة).
CartUiLine cartLineFromStockInfo(ItemStockInfo info, int? warehouseId) {
  final available = info.item.isService
      ? null
      : (info.warehouseQty[warehouseId] ?? info.totalQty);
  final price = info.retailPrice ?? 0.0;
  return CartUiLine(
    productId: info.item.id,
    name: info.item.name,
    barcode: info.item.barcode,
    qty: 1,
    unitPrice: price,
    discountType: SaleDiscountType.amount,
    discountValue: 0,
    availableQty: available,
    isService: info.item.isService,
    // UX-2a: تكلفة اللقطة لكشف البيع تحت التكلفة (عملة الأساس حصراً).
    costPrice: info.item.costPrice,
  );
}

/// فهرس أول سطر للصنف (أو -1).
int sellCartLineIndexOf(SellCartState state, int productId) {
  for (var i = 0; i < state.lines.length; i++) {
    if (state.lines[i].productId == productId) return i;
  }
  return -1;
}

/// عملة بالمعرف من عملات الحالة (أو null).
Currency? sellCartCurrencyById(SellCartState state, int id) {
  for (final currency in state.currencies) {
    if (currency.id == id) return currency;
  }
  return null;
}

/// حاضنة التحميل الأولى للسلة — سياسات التخصيص (UX-2a) وعملات الشركة
/// والمخزن والمدير، بقراءة واحدة متزامنة كما كانت بترتيبها الأصلي.
class SellCartBootstrap {
  const SellCartBootstrap({
    required this.currencies,
    required this.base,
    required this.warehouseId,
    required this.userId,
    required this.overAvailPolicy,
    required this.showDiscounts,
    required this.warnBelowMargin,
  });

  final List<Currency> currencies;
  final Currency? base;
  final int? warehouseId;
  final int? userId;
  final String overAvailPolicy;
  final bool showDiscounts;
  final bool warnBelowMargin;
}

/// قراءة حاضنة التحميل — غياب مستودع الإعدادات يبقي سلوك v0.x
/// (warn/خصومات ظاهرة/بلا تحذير هامش) فلا تنكسر شاشات بلا وصول.
Future<SellCartBootstrap> loadSellCartBootstrap({
  required CompanyRepository companies,
  required SettingsRepository? settings,
}) async {
  var overAvailPolicy = 'warn';
  var showDiscounts = true;
  var warnBelowMargin = false;
  if (settings != null) {
    final policyResults = await Future.wait<Object?>([
      settings.overAvailPolicy(),
      settings.showDiscounts(),
      settings.discountBelowMargin(),
    ]);
    overAvailPolicy = policyResults[0]! as String;
    showDiscounts = policyResults[1]! as bool;
    warnBelowMargin = policyResults[2]! as bool;
  }
  final results = await Future.wait<Object?>([
    companies.listActiveCurrencies(),
    companies.findBaseCurrency(),
    companies.findDefaultWarehouseId(),
    companies.findAdminUserId(),
  ]);
  return SellCartBootstrap(
    currencies: results[0]! as List<Currency>,
    base: results[1] as Currency?,
    warehouseId: results[2] as int?,
    userId: results[3] as int?,
    overAvailPolicy: overAvailPolicy,
    showDiscounts: showDiscounts,
    warnBelowMargin: warnBelowMargin,
  );
}

/// حالة «تم التحميل» من حاضنة التحميل — سلة فارغة بعملة الأساس.
SellCartState sellCartLoadedState(
  SellCartBootstrap bootstrap,
  String? nextInvoiceNo,
) => SellCartState(
  loading: false,
  currencies: bootstrap.currencies,
  baseCurrency: bootstrap.base,
  currencyId: bootstrap.base?.id,
  rateKnown: true,
  warehouseId: bootstrap.warehouseId,
  lines: const <CartUiLine>[],
  invoiceDiscountType: SaleDiscountType.amount,
  invoiceDiscountValue: 0,
  posting: false,
  nextInvoiceNo: nextInvoiceNo,
  overAvailPolicy: bootstrap.overAvailPolicy,
  showDiscounts: bootstrap.showDiscounts,
  warnBelowMargin: bootstrap.warnBelowMargin,
);

/// حالة فشل التحميل — خطأ خام وبيئة مبدئية سليمة.
SellCartState sellCartErrorState(Object error) => SellCartState(
  loading: false,
  error: error,
  currencies: const <Currency>[],
  rateKnown: true,
  lines: const <CartUiLine>[],
  invoiceDiscountType: SaleDiscountType.amount,
  invoiceDiscountValue: 0,
  posting: false,
);
