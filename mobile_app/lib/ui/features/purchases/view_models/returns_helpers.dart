/// حسابات تدفق المرتجعات النقية (نسخ الحالة + فحوص ما قبل الترحيل +
/// بناء المسودات) — مستخرجة من returns_view_model (R20-D3b: نقل حرفي
/// بلا أي تغيير سلوكي؛ الساعة تُمرَّر معامل `now` من المتحكم).
library;

import '../../../../data/repositories/return_repository.dart';
import 'returns_state.dart';

/// علامة «أبقِ القيمة الحالية» للحقول القابلة للتصفير في
/// [returnFlowStateWith].
const Object returnFlowKeep = Object();

/// نسخ الحالة المشتركة مع تجاوز الحقول المطلوبة فقط — الجسم منقول
/// حرفياً من `_copy` بمتحكمَي المرتجعات (كانا متطابقين).
ReturnFlowState returnFlowStateWith(
  ReturnFlowState state, {
  ReturnPhase? phase,
  bool? loading,
  List<ReturnableInvoice>? invoices,
  String? filterQuery,
  ReturnableInvoice? selected,
  bool clearSelected = false,
  List<ReturnUiLine>? lines,
  bool? linesLoading,
  Object? linesError = returnFlowKeep,
  bool? posting,
  Object? postError = returnFlowKeep,
  Object? receipt = returnFlowKeep,
  Object? error = returnFlowKeep,
}) => ReturnFlowState(
  phase: phase ?? state.phase,
  loading: loading ?? state.loading,
  invoices: invoices ?? state.invoices,
  filterQuery: filterQuery ?? state.filterQuery,
  selected: clearSelected ? null : (selected ?? state.selected),
  lines: lines ?? state.lines,
  linesLoading: linesLoading ?? state.linesLoading,
  linesError: identical(linesError, returnFlowKeep)
      ? state.linesError
      : linesError,
  posting: posting ?? state.posting,
  postError: identical(postError, returnFlowKeep)
      ? state.postError
      : postError as String?,
  receipt: identical(receipt, returnFlowKeep)
      ? state.receipt
      : receipt as ReturnPostedReceipt?,
  error: identical(error, returnFlowKeep) ? state.error : error,
);

/// فحوص ما قبل ترحيل مرتجع البيع (SRN) — رسالة الرفض أو null، بترتيب
/// الرسائل نفسه حرفياً كما كان بالمتحكم.
String? saleReturnPrePostCheck(
  ReturnFlowState state,
  ReturnRefundMethod method,
) {
  if (state.posting) {
    return 'ترحيل جارٍ بالفعل — لحظات ويكتمل.';
  }
  final selected = state.selected;
  if (selected == null) {
    return 'اختر الفاتورة الأصلية أولاً.';
  }
  final chosen = state.selectedLines;
  if (chosen.isEmpty) {
    return 'اختر كمية إرجاع لبند واحد على الأقل.';
  }
  // فاتورة نقدي مجهولة: لا حساب عميل يُخصم منه → رد نقدي حصراً.
  if (!selected.hasParty && method != ReturnRefundMethod.cash) {
    return 'الفاتورة الأصلية بلا عميل مسجَّل (بيع نقدي مجهول) — لا حساب '
        'يُخصم منه؛ اختر الرد النقدي من الصندوق.';
  }
  return null;
}

/// فحوص ما قبل ترحيل مرتجع الشراء (PRN) — رسالة الرفض أو null.
String? purchaseReturnPrePostCheck(ReturnFlowState state) {
  if (state.posting) {
    return 'ترحيل جارٍ بالفعل — لحظات ويكتمل.';
  }
  final selected = state.selected;
  if (selected == null) {
    return 'اختر فاتورة الشراء الأصلية أولاً.';
  }
  final chosen = state.selectedLines;
  if (chosen.isEmpty) {
    return 'اختر كمية إرجاع لبند واحد على الأقل.';
  }
  return null;
}

/// مسودة ترحيل مرتجع البيع (SRN) — [now] يمرَّر من المتحكم (الساعة
/// ملكه — نمط sell/purchase cart الموثق).
SaleReturnDraft buildSaleReturnDraft({
  required ReturnableInvoice selected,
  required List<ReturnUiLine> chosen,
  required double refundCash,
  required ReturnRefundMethod method,
  required DateTime now,
}) => SaleReturnDraft(
  originalInvoiceId: selected.id,
  lines: [
    for (final l in chosen)
      ReturnLineInput(invoiceItemId: l.line.invoiceItemId, qty: l.selectedQty),
  ],
  refundCash: refundCash,
  refundMethod: method,
  issuedAt: now,
);

/// مسودة ترحيل مرتجع الشراء (PRN) — [now] يمرَّر من المتحكم.
PurchaseReturnDraft buildPurchaseReturnDraft({
  required ReturnableInvoice selected,
  required List<ReturnUiLine> chosen,
  required double refundCash,
  required ReturnRefundMethod method,
  required DateTime now,
}) => PurchaseReturnDraft(
  originalInvoiceId: selected.id,
  lines: [
    for (final l in chosen)
      ReturnLineInput(invoiceItemId: l.line.invoiceItemId, qty: l.selectedQty),
  ],
  refundCash: refundCash,
  refundMethod: method,
  issuedAt: now,
);
