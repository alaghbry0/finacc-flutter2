/// نماذج عرض المرتجعات المرتبطة (SRN/PRN — FR-02-07/08) — اختيار الفاتورة
/// الأصلية ثم البنود والكميات ثم اتجاه رد القيمة ثم الترحيل الذرّي عبر
/// `ReturnRepository`.
///
/// خطوط حمراء مطبَّقة هنا (مرآة المحرك):
/// - **الارتباط الحصري**: لا مرتجع حر — يبدأ من فاتورة أصلية مكتملة.
/// - **سقف الكميات لكل بند**: المتاح = الأصلي − ما أُرجع سابقاً (الواجهة
///   تحدّ الكمية والحراسة تعاد داخل المعاملة).
/// - **مرتجع البيع عن فاتورة نقدي مجهول**: رد نقدي حصراً (لا حساب يُخصم
///   منه — قرار المحرك 6 بالبيع).
/// - **المبلغ النقدي ≤ قيمة المرتجع** (لا رد زائد).
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/purchase_repository.dart';
import '../../../../data/repositories/return_repository.dart';
import '../../../../data/repositories/sale_repository.dart';
import '../../../../domain/core/result.dart';
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

/// نموذج مرتجع البيع (SRN) — من فاتورة بيع مكتملة.
class SaleReturnViewModel extends ChangeNotifier implements ReturnFlowVm {
  SaleReturnViewModel({
    required SaleRepository saleRepo,
    required ReturnRepository returnRepo,
    this.preselectedInvoiceId,
  }) : _sales = saleRepo,
       _returns = returnRepo;

  final SaleRepository _sales;
  final ReturnRepository _returns;

  /// فاتورة مسبقة الاختيار (وصول من تفاصيل فاتورة البيع).
  final int? preselectedInvoiceId;

  ReturnFlowState _state = ReturnFlowState.initial;

  @override
  ReturnFlowState get state => _state;

  int? _userId;

  /// يبدأ التدفق: قائمة الفواتير + مستخدم التنفيذ (مع اختيار مسبق إن
  /// وُجهت الشاشة من تفاصيل فاتورة).
  Future<void> load({Future<int?> Function()? userIdLoader}) async {
    if (userIdLoader != null) {
      _userId = await userIdLoader();
    }
    _state = ReturnFlowState.initial;
    notifyListeners();
    try {
      final invoices = await _sales.recentSales(limit: 100);
      final candidates = <ReturnableInvoice>[
        for (final invoice in invoices)
          if (invoice.status == 'completed')
            ReturnableInvoice(
              id: invoice.id,
              invoiceNo: invoice.invoiceNo,
              issuedAt: invoice.issuedAt,
              partyName: invoice.customerName,
              hasParty: invoice.customerId != null,
              total: invoice.total,
              currencyCode: invoice.currencyCode,
            ),
      ];
      _state = ReturnFlowState(
        phase: ReturnPhase.pickingInvoice,
        loading: false,
        invoices: candidates,
        filterQuery: _state.filterQuery,
        lines: const <ReturnUiLine>[],
        posting: false,
      );
      notifyListeners();
      final preselect = preselectedInvoiceId;
      if (preselect != null) {
        await selectInvoice(preselect);
      }
    } catch (error) {
      _state = ReturnFlowState(
        phase: ReturnPhase.pickingInvoice,
        loading: false,
        invoices: const <ReturnableInvoice>[],
        filterQuery: _state.filterQuery,
        lines: const <ReturnUiLine>[],
        posting: false,
        error: error,
      );
      notifyListeners();
    }
  }

  @override
  void setFilter(String query) {
    if (query == _state.filterQuery) return;
    _state = _copy(filterQuery: query);
    notifyListeners();
  }

  /// اختيار الفاتورة الأصلية → تحميل بنودها القابلة للإرجاع.
  @override
  Future<void> selectInvoice(int invoiceId) async {
    final invoice = _state.invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) return;
    _state = _copy(
      phase: ReturnPhase.pickingLines,
      selected: invoice,
      lines: const <ReturnUiLine>[],
      linesLoading: true,
      linesError: null,
      postError: null,
    );
    notifyListeners();
    try {
      final lines = await _returns.saleReturnableLines(invoiceId);
      _state = _copy(
        lines: [for (final line in lines) ReturnUiLine(line: line)],
        linesLoading: false,
      );
    } catch (error) {
      _state = _copy(linesLoading: false, linesError: error);
    }
    notifyListeners();
  }

  /// العودة لقائمة الفواتير (من طور البنود).
  @override
  void backToInvoices() {
    if (_state.phase != ReturnPhase.pickingLines) return;
    _state = _copy(
      phase: ReturnPhase.pickingInvoice,
      clearSelected: true,
      lines: const <ReturnUiLine>[],
      postError: null,
    );
    notifyListeners();
  }

  /// تعديل كمية إرجاع بند (0 ≤ qty ≤ المتاح).
  @override
  void setQty(int index, double qty) {
    if (index < 0 || index >= _state.lines.length) return;
    if (qty.isNaN || qty.isInfinite || qty < 0) return;
    final available = _state.lines[index].line.availableQty;
    if (qty > available) {
      qty = available;
    }
    final lines = [..._state.lines];
    lines[index] = ReturnUiLine(
      line: lines[index].line,
      selectedQty: qty == 0 ? 0 : qty,
    );
    _state = _copy(lines: lines, postError: null);
    notifyListeners();
  }

  /// **ترحيل مرتجع البيع (SRN)** — نجاح: إيصال + عودة لقائمة الفواتير
  /// عند «مرتجع جديد»؛ فشل: رسالة الرفض والاختيار محفوظ.
  Future<Result<ReturnPostedReceipt, String>> post({
    required double refundCash,
    required ReturnRefundMethod method,
  }) async {
    if (_state.posting) {
      return const Err<ReturnPostedReceipt, String>(
        'ترحيل جارٍ بالفعل — لحظات ويكتمل.',
      );
    }
    final selected = _state.selected;
    if (selected == null) {
      return const Err<ReturnPostedReceipt, String>(
        'اختر الفاتورة الأصلية أولاً.',
      );
    }
    final chosen = _state.selectedLines;
    if (chosen.isEmpty) {
      return const Err<ReturnPostedReceipt, String>(
        'اختر كمية إرجاع لبند واحد على الأقل.',
      );
    }
    // فاتورة نقدي مجهولة: لا حساب عميل يُخصم منه → رد نقدي حصراً.
    if (!selected.hasParty && method != ReturnRefundMethod.cash) {
      return const Err<ReturnPostedReceipt, String>(
        'الفاتورة الأصلية بلا عميل مسجَّل (بيع نقدي مجهول) — لا حساب '
        'يُخصم منه؛ اختر الرد النقدي من الصندوق.',
      );
    }
    _state = _copy(posting: true, postError: null);
    notifyListeners();
    final result = await _returns.postSaleReturn(
      SaleReturnDraft(
        originalInvoiceId: selected.id,
        lines: [
          for (final l in chosen)
            ReturnLineInput(
              invoiceItemId: l.line.invoiceItemId,
              qty: l.selectedQty,
            ),
        ],
        refundCash: refundCash,
        refundMethod: method,
        issuedAt: DateTime.now(),
      ),
      userId: _userId ?? 1,
    );
    if (result.isOk) {
      _state = _copy(
        phase: ReturnPhase.done,
        posting: false,
        receipt: result.valueOrNull,
        postError: null,
      );
    } else {
      _state = _copy(posting: false, postError: result.errorOrNull);
    }
    notifyListeners();
    return result;
  }

  /// «مرتجع جديد» — عودة لقائمة الفواتير بإعادة تحميل (المتاح تغيّر).
  @override
  Future<void> startNewReturn() async {
    _state = _copy(
      phase: ReturnPhase.pickingInvoice,
      selected: null,
      lines: const <ReturnUiLine>[],
      receipt: null,
      postError: null,
    );
    notifyListeners();
    await load();
  }

  /// علامة «أبقِ القيمة الحالية» للحقول القابلة للتصفير في `_copy`.
  static const Object _keep = Object();

  ReturnFlowState _copy({
    ReturnPhase? phase,
    bool? loading,
    List<ReturnableInvoice>? invoices,
    String? filterQuery,
    ReturnableInvoice? selected,
    bool clearSelected = false,
    List<ReturnUiLine>? lines,
    bool? linesLoading,
    Object? linesError = _keep,
    bool? posting,
    Object? postError = _keep,
    Object? receipt = _keep,
    Object? error = _keep,
  }) => ReturnFlowState(
    phase: phase ?? _state.phase,
    loading: loading ?? _state.loading,
    invoices: invoices ?? _state.invoices,
    filterQuery: filterQuery ?? _state.filterQuery,
    selected: clearSelected ? null : (selected ?? _state.selected),
    lines: lines ?? _state.lines,
    linesLoading: linesLoading ?? _state.linesLoading,
    linesError: identical(linesError, _keep) ? _state.linesError : linesError,
    posting: posting ?? _state.posting,
    postError: identical(postError, _keep)
        ? _state.postError
        : postError as String?,
    receipt: identical(receipt, _keep)
        ? _state.receipt
        : receipt as ReturnPostedReceipt?,
    error: identical(error, _keep) ? _state.error : error,
  );
}

/// نموذج مرتجع الشراء (PRN) — من فاتورة شراء مكتملة.
class PurchaseReturnViewModel extends ChangeNotifier implements ReturnFlowVm {
  PurchaseReturnViewModel({
    required PurchaseRepository purchaseRepo,
    required ReturnRepository returnRepo,
    this.preselectedInvoiceId,
  }) : _purchases = purchaseRepo,
       _returns = returnRepo;

  final PurchaseRepository _purchases;
  final ReturnRepository _returns;

  /// فاتورة مسبقة الاختيار (وصول من تفاصيل فاتورة الشراء).
  final int? preselectedInvoiceId;

  ReturnFlowState _state = ReturnFlowState.initial;

  @override
  ReturnFlowState get state => _state;

  int? _userId;

  Future<void> load({Future<int?> Function()? userIdLoader}) async {
    if (userIdLoader != null) {
      _userId = await userIdLoader();
    }
    _state = ReturnFlowState.initial;
    notifyListeners();
    try {
      final invoices = await _purchases.recentPurchases(limit: 100);
      final candidates = <ReturnableInvoice>[
        for (final invoice in invoices)
          if (invoice.status == 'completed')
            ReturnableInvoice(
              id: invoice.id,
              invoiceNo: invoice.invoiceNo,
              issuedAt: invoice.issuedAt,
              partyName: invoice.supplierName,
              hasParty: invoice.supplierId != null,
              total: invoice.total,
              currencyCode: invoice.currencyCode,
            ),
      ];
      _state = ReturnFlowState(
        phase: ReturnPhase.pickingInvoice,
        loading: false,
        invoices: candidates,
        filterQuery: _state.filterQuery,
        lines: const <ReturnUiLine>[],
        posting: false,
      );
      notifyListeners();
      final preselect = preselectedInvoiceId;
      if (preselect != null) {
        await selectInvoice(preselect);
      }
    } catch (error) {
      _state = ReturnFlowState(
        phase: ReturnPhase.pickingInvoice,
        loading: false,
        invoices: const <ReturnableInvoice>[],
        filterQuery: _state.filterQuery,
        lines: const <ReturnUiLine>[],
        posting: false,
        error: error,
      );
      notifyListeners();
    }
  }

  @override
  void setFilter(String query) {
    if (query == _state.filterQuery) return;
    _state = _copy(filterQuery: query);
    notifyListeners();
  }

  @override
  Future<void> selectInvoice(int invoiceId) async {
    final invoice = _state.invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) return;
    _state = _copy(
      phase: ReturnPhase.pickingLines,
      selected: invoice,
      lines: const <ReturnUiLine>[],
      linesLoading: true,
      linesError: null,
      postError: null,
    );
    notifyListeners();
    try {
      final lines = await _returns.purchaseReturnableLines(invoiceId);
      _state = _copy(
        lines: [for (final line in lines) ReturnUiLine(line: line)],
        linesLoading: false,
      );
    } catch (error) {
      _state = _copy(linesLoading: false, linesError: error);
    }
    notifyListeners();
  }

  @override
  void backToInvoices() {
    if (_state.phase != ReturnPhase.pickingLines) return;
    _state = _copy(
      phase: ReturnPhase.pickingInvoice,
      clearSelected: true,
      lines: const <ReturnUiLine>[],
      postError: null,
    );
    notifyListeners();
  }

  @override
  void setQty(int index, double qty) {
    if (index < 0 || index >= _state.lines.length) return;
    if (qty.isNaN || qty.isInfinite || qty < 0) return;
    final available = _state.lines[index].line.availableQty;
    if (qty > available) {
      qty = available;
    }
    final lines = [..._state.lines];
    lines[index] = ReturnUiLine(
      line: lines[index].line,
      selectedQty: qty == 0 ? 0 : qty,
    );
    _state = _copy(lines: lines, postError: null);
    notifyListeners();
  }

  /// **ترحيل مرتجع الشراء (PRN)** — نجاح: إيصال؛ فشل: رسالة الرفض
  /// والاختيار محفوظ (المحرك يرفض ما لا يغطيه المخزون 5.4-5).
  Future<Result<ReturnPostedReceipt, String>> post({
    required double refundCash,
    required ReturnRefundMethod method,
  }) async {
    if (_state.posting) {
      return const Err<ReturnPostedReceipt, String>(
        'ترحيل جارٍ بالفعل — لحظات ويكتمل.',
      );
    }
    final selected = _state.selected;
    if (selected == null) {
      return const Err<ReturnPostedReceipt, String>(
        'اختر فاتورة الشراء الأصلية أولاً.',
      );
    }
    final chosen = _state.selectedLines;
    if (chosen.isEmpty) {
      return const Err<ReturnPostedReceipt, String>(
        'اختر كمية إرجاع لبند واحد على الأقل.',
      );
    }
    _state = _copy(posting: true, postError: null);
    notifyListeners();
    final result = await _returns.postPurchaseReturn(
      PurchaseReturnDraft(
        originalInvoiceId: selected.id,
        lines: [
          for (final l in chosen)
            ReturnLineInput(
              invoiceItemId: l.line.invoiceItemId,
              qty: l.selectedQty,
            ),
        ],
        refundCash: refundCash,
        refundMethod: method,
        issuedAt: DateTime.now(),
      ),
      userId: _userId ?? 1,
    );
    if (result.isOk) {
      _state = _copy(
        phase: ReturnPhase.done,
        posting: false,
        receipt: result.valueOrNull,
        postError: null,
      );
    } else {
      _state = _copy(posting: false, postError: result.errorOrNull);
    }
    notifyListeners();
    return result;
  }

  @override
  Future<void> startNewReturn() async {
    _state = _copy(
      phase: ReturnPhase.pickingInvoice,
      clearSelected: true,
      lines: const <ReturnUiLine>[],
      receipt: null,
      postError: null,
    );
    notifyListeners();
    await load();
  }

  /// علامة «أبقِ القيمة الحالية» للحقول القابلة للتصفير في `_copy`.
  static const Object _keep = Object();

  ReturnFlowState _copy({
    ReturnPhase? phase,
    bool? loading,
    List<ReturnableInvoice>? invoices,
    String? filterQuery,
    ReturnableInvoice? selected,
    bool clearSelected = false,
    List<ReturnUiLine>? lines,
    bool? linesLoading,
    Object? linesError = _keep,
    bool? posting,
    Object? postError = _keep,
    Object? receipt = _keep,
    Object? error = _keep,
  }) => ReturnFlowState(
    phase: phase ?? _state.phase,
    loading: loading ?? _state.loading,
    invoices: invoices ?? _state.invoices,
    filterQuery: filterQuery ?? _state.filterQuery,
    selected: clearSelected ? null : (selected ?? _state.selected),
    lines: lines ?? _state.lines,
    linesLoading: linesLoading ?? _state.linesLoading,
    linesError: identical(linesError, _keep) ? _state.linesError : linesError,
    posting: posting ?? _state.posting,
    postError: identical(postError, _keep)
        ? _state.postError
        : postError as String?,
    receipt: identical(receipt, _keep)
        ? _state.receipt
        : receipt as ReturnPostedReceipt?,
    error: identical(error, _keep) ? _state.error : error,
  );
}
