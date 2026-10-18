/// أنواع حالة تدفق المرتجعات المرتبطة (SRN/PRN) النقية — مستخرجة من
/// returns_view_model (R20-D3b: نقل حرفي بلا أي تغيير سلوكي؛ تُصدَّر من
/// ملف المتحكم فبقيت استيرادات المستدعين كما هي).
library;

import '../../../../data/repositories/return_repository.dart';
import '../../../../domain/services/purchase_pricing.dart';

/// ملخص فاتورة أصلية موحَّد (بيع أو شراء) لواجهة اختيار المرتجع.
class ReturnableInvoice {
  const ReturnableInvoice({
    required this.id,
    required this.invoiceNo,
    required this.issuedAt,
    required this.partyName,
    required this.hasParty,
    required this.total,
    required this.currencyCode,
  });

  final int id;
  final String invoiceNo;
  final DateTime issuedAt;

  /// اسم العميل/المورد (أو «عميل نقدي» عند الغياب).
  final String? partyName;

  /// هل للفاتورة الأصلية طرف مسجَّل؟ (بيعة نقدي مجهولة = false → رد نقدي
  /// حصراً في SRN).
  final bool hasParty;

  final double total;
  final String? currencyCode;
}

/// سطر مرتجع في الواجهة — `ReturnableLine` + الكمية المختارة.
class ReturnUiLine {
  const ReturnUiLine({required this.line, this.selectedQty = 0});

  final ReturnableLine line;
  final double selectedQty;

  /// قيمة رد هذا السطر (تقدير العرض — المحرك يحسبSnapshot الدقيق).
  double get lineRefund => roundMoney(selectedQty * line.unitPriceEffective);

  bool get hasSelection => selectedQty > 0;
}

/// أطوار تدفق المرتجع.
enum ReturnPhase { pickingInvoice, pickingLines, done }

/// الواجهة الموحَّدة لتدفق المرتجع (بيع أو شراء) — تخدمها أقسام الواجهة
/// المشتركة في الشاشتين دون تكرار.
abstract interface class ReturnFlowVm {
  /// الحالة الحالية للتدفق.
  ReturnFlowState get state;

  /// تصفية قائمة الفواتير الأصلية.
  void setFilter(String query);

  /// اختيار فاتورة أصلية وتحميل بنودها القابلة للإرجاع.
  Future<void> selectInvoice(int invoiceId);

  /// العودة لقائمة الفواتير.
  void backToInvoices();

  /// تعديل كمية إرجاع بند بالفهرس.
  void setQty(int index, double qty);

  /// «مرتجع جديد» — إعادة تحميل القائمة بعد نجاح.
  Future<void> startNewReturn();
}

/// الحالة المشتركة لتدفق المرتجع (بيع أو شراء).
class ReturnFlowState {
  const ReturnFlowState({
    required this.phase,
    required this.loading,
    required this.invoices,
    required this.filterQuery,
    this.selected,
    required this.lines,
    this.linesLoading = false,
    this.linesError,
    required this.posting,
    this.postError,
    this.receipt,
    this.error,
  });

  final ReturnPhase phase;
  final bool loading;

  /// قائمة الفواتير الأصلية المكتملة (طور الاختيار).
  final List<ReturnableInvoice> invoices;
  final String filterQuery;

  /// الفاتورة الأصلية المختارة.
  final ReturnableInvoice? selected;

  /// بنودها القابلة للإرجاع مع الكميات المختارة.
  final List<ReturnUiLine> lines;
  final bool linesLoading;
  final Object? linesError;

  final bool posting;
  final String? postError;

  /// إيصال آخر مرتجع مُرحَّل.
  final ReturnPostedReceipt? receipt;

  final Object? error;

  /// قيمة المرتجع الحالية (Σ الكميات المختارة × صافي وحدتها).
  double get refundTotal =>
      roundMoney(lines.fold(0.0, (sum, l) => sum + l.lineRefund));

  /// هل اختيرت كميات للإرجاع؟
  bool get hasSelection => lines.any((l) => l.hasSelection);

  /// البنود المختارة فقط.
  List<ReturnUiLine> get selectedLines => [
    for (final l in lines)
      if (l.hasSelection) l,
  ];

  static const ReturnFlowState initial = ReturnFlowState(
    phase: ReturnPhase.pickingInvoice,
    loading: true,
    invoices: <ReturnableInvoice>[],
    filterQuery: '',
    lines: <ReturnUiLine>[],
    posting: false,
  );
}
