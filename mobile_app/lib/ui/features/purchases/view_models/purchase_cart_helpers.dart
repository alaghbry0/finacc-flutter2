/// حسابات فاتورة الشراء الحية النقية (R19-D3c — نُزعت من
/// `purchase_cart_view_model.dart` بنقل حرفي بلا أي تغيير دلالة):
/// التسعير الحي وفحص البنود وفحوص ما قبل الترحيل وخريطة المسودة — كلها
/// نقية فوق `PurchaseCartState` بلا أي وصول قاعدة، والمتحكم يطبّق أثر
/// بوابة FX (FR-08-09) بنفس ترتيب الإخطار الأصلي.
library;

import '../../../../domain/models/purchase.dart';
import '../../../../domain/services/purchase_pricing.dart';
import 'purchase_cart_state.dart';

/// أسطر الشراء (خرائط `PurchaseCartUiLine` → `PurchaseLine` للترحيل).
List<PurchaseLine> purchaseCartLines(PurchaseCartState state) => [
  for (final line in state.lines) line.toPurchaseLine(),
];

/// الفاتورة المُسعَّرة الآن — null عند الفراغ أو عدم قابلية التسعير.
PricedPurchaseCart? purchaseCartPricedCart(PurchaseCartState state) {
  if (state.lines.isEmpty) return null;
  try {
    return PurchasePricing.priceCart(
      purchaseCartLines(state),
      invoiceDiscountType: state.invoiceDiscountType,
      invoiceDiscountValue: state.invoiceDiscountValue,
    );
  } on StateError {
    return null;
  }
}

/// خطأ التحقق الحالي (كميات/تكاليف/خصومات/صافٍ > 0/دفعات واردة) —
/// null عند السلامة.
String? purchaseCartError(PurchaseCartState state) {
  if (state.lines.isEmpty) return null;
  final failure = PurchasePricing.validateCart(
    purchaseCartLines(state),
    invoiceDiscountType: state.invoiceDiscountType,
    invoiceDiscountValue: state.invoiceDiscountValue,
  );
  if (failure != null) return failure;
  // قرار المحرك 4: الواجهة تُلزم رقم الدفعة للأصناف المتتبعة (رصيد
  // المتتبع بلا دفعة لا يظهر متاحاً للبيع).
  for (final line in state.lines) {
    if (!line.isService && line.trackBatches && line.batchNo.trim().isEmpty) {
      return 'الصنف «${line.name}» يتتبع الدفعات — أدخل رقم الدفعة '
          'وتاريخ صلاحيتها في سطره قبل الترحيل.';
    }
  }
  return null;
}

/// نتيجة فحوص ما قبل الترحيل (نقية) — [failure] رسالة الرفض أو null،
/// و[fxGateRequired] يطلب من المتحكم فتح بوابة إدخال سعر اليوم.
class PurchaseCartPrePostCheck {
  const PurchaseCartPrePostCheck(this.failure, {this.fxGateRequired = false});

  final String? failure;
  final bool fxGateRequired;
}

/// فحوص ما قبل الترحيل (بترتيب رسائل واضح للمستخدم) — بترتيب الرسائل
/// نفسه حرفياً كما كان بالمتحكم، مع فصل أثر بوابة FX (FR-08-09) كعلم
/// يطبّقه المتحكم قبل إعادة الرسالة — بلا أي تغيير دلالة.
PurchaseCartPrePostCheck purchaseCartPrePostCheck(
  PurchaseCartState state,
  double paidCash,
  PurchasePaymentMethod method,
) {
  if (state.lines.isEmpty) {
    return const PurchaseCartPrePostCheck(
      'أضف بنداً واحداً على الأقل إلى فاتورة الشراء قبل الترحيل.',
    );
  }
  final cartFailure = purchaseCartError(state);
  if (cartFailure != null) {
    return PurchaseCartPrePostCheck(cartFailure);
  }
  final supplier = state.supplier;
  if (supplier == null) {
    return const PurchaseCartPrePostCheck(
      'اختر المورد أولاً — لا شراء بلا مورد.',
    );
  }
  final currency = state.selectedCurrency;
  if (currency == null) {
    return const PurchaseCartPrePostCheck('اختر عملة الفاتورة أولاً.');
  }
  if (!currency.isBase && !state.rateKnown) {
    // FR-08-09: منع الحفظ + طلب فتح بوابة إدخال سعر اليوم.
    return PurchaseCartPrePostCheck(
      'لا يوجد سعر صرف لعملة ${currency.code} بتاريخ اليوم — '
      'أدخل سعر اليوم أولاً ثم أكمل الترحيل.',
      fxGateRequired: true,
    );
  }
  final total = purchaseCartPricedCart(state)?.totals.grandTotal ?? 0;
  return PurchaseCartPrePostCheck(
    PurchasePricing.validatePayment(total, paidCash, method),
  );
}

/// بناء مسودة الترحيل من الحالة الحالية — null عند نقص المورد/العملة/
/// المخزن (المورد إلزامي في الشراء — لا مورد مجهول).
PurchaseDraft? buildPurchaseDraftFromCart(
  PurchaseCartState state, {
  required double paidCash,
  required PurchasePaymentMethod method,
  required DateTime now,
}) {
  final currencyId = state.currencyId;
  final warehouseId = state.warehouseId;
  final supplier = state.supplier;
  if (currencyId == null || warehouseId == null || supplier == null) {
    return null;
  }
  return PurchaseDraft(
    supplierId: supplier.id,
    currencyId: currencyId,
    lines: purchaseCartLines(state),
    invoiceDiscountType: state.invoiceDiscountType,
    invoiceDiscountValue: state.invoiceDiscountValue,
    paidCash: paidCash,
    paymentMethod: method,
    warehouseId: warehouseId,
    issuedAt: now,
  );
}
