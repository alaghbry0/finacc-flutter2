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
///
/// (R20-D3b: الأنواع النقية في `returns_state.dart` والحسابات النقية في
/// `returns_helpers.dart` — تُصدَّر الأولى من هنا فبقيت استيرادات
/// المستدعين كما هي؛ هذا الملف: سطح التنسيق — الإخطار والمستودعات
/// والساعة.)
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/purchase_repository.dart';
import '../../../../data/repositories/return_repository.dart';
import '../../../../data/repositories/sale_repository.dart';
import '../../../../domain/core/result.dart';
import 'returns_helpers.dart';
import 'returns_state.dart';

export 'returns_state.dart';

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
    _state = returnFlowStateWith(_state, filterQuery: query);
    notifyListeners();
  }

  /// اختيار الفاتورة الأصلية → تحميل بنودها القابلة للإرجاع.
  @override
  Future<void> selectInvoice(int invoiceId) async {
    final invoice = _state.invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) return;
    _state = returnFlowStateWith(
      _state,
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
      _state = returnFlowStateWith(
        _state,
        lines: [for (final line in lines) ReturnUiLine(line: line)],
        linesLoading: false,
      );
    } catch (error) {
      _state = returnFlowStateWith(
        _state,
        linesLoading: false,
        linesError: error,
      );
    }
    notifyListeners();
  }

  /// العودة لقائمة الفواتير (من طور البنود).
  @override
  void backToInvoices() {
    if (_state.phase != ReturnPhase.pickingLines) return;
    _state = returnFlowStateWith(
      _state,
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
    _state = returnFlowStateWith(_state, lines: lines, postError: null);
    notifyListeners();
  }

  /// **ترحيل مرتجع البيع (SRN)** — نجاح: إيصال + عودة لقائمة الفواتير
  /// عند «مرتجع جديد»؛ فشل: رسالة الرفض والاختيار محفوظ.
  Future<Result<ReturnPostedReceipt, String>> post({
    required double refundCash,
    required ReturnRefundMethod method,
  }) async {
    final rejection = saleReturnPrePostCheck(_state, method);
    if (rejection != null) {
      return Err<ReturnPostedReceipt, String>(rejection);
    }
    _state = returnFlowStateWith(_state, posting: true, postError: null);
    notifyListeners();
    final selected = _state.selected!;
    final chosen = _state.selectedLines;
    final result = await _returns.postSaleReturn(
      buildSaleReturnDraft(
        selected: selected,
        chosen: chosen,
        refundCash: refundCash,
        method: method,
        now: DateTime.now(),
      ),
      userId: _userId ?? 1,
    );
    if (result.isOk) {
      _state = returnFlowStateWith(
        _state,
        phase: ReturnPhase.done,
        posting: false,
        receipt: result.valueOrNull,
        postError: null,
      );
    } else {
      _state = returnFlowStateWith(
        _state,
        posting: false,
        postError: result.errorOrNull,
      );
    }
    notifyListeners();
    return result;
  }

  /// «مرتجع جديد» — عودة لقائمة الفواتير بإعادة تحميل (المتاح تغيّر).
  @override
  Future<void> startNewReturn() async {
    _state = returnFlowStateWith(
      _state,
      phase: ReturnPhase.pickingInvoice,
      lines: const <ReturnUiLine>[],
      receipt: null,
      postError: null,
    );
    notifyListeners();
    await load();
  }
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
    _state = returnFlowStateWith(_state, filterQuery: query);
    notifyListeners();
  }

  @override
  Future<void> selectInvoice(int invoiceId) async {
    final invoice = _state.invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) return;
    _state = returnFlowStateWith(
      _state,
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
      _state = returnFlowStateWith(
        _state,
        lines: [for (final line in lines) ReturnUiLine(line: line)],
        linesLoading: false,
      );
    } catch (error) {
      _state = returnFlowStateWith(
        _state,
        linesLoading: false,
        linesError: error,
      );
    }
    notifyListeners();
  }

  @override
  void backToInvoices() {
    if (_state.phase != ReturnPhase.pickingLines) return;
    _state = returnFlowStateWith(
      _state,
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
    _state = returnFlowStateWith(_state, lines: lines, postError: null);
    notifyListeners();
  }

  /// **ترحيل مرتجع الشراء (PRN)** — نجاح: إيصال؛ فشل: رسالة الرفض
  /// والاختيار محفوظ (المحرك يرفض ما لا يغطيه المخزون 5.4-5).
  Future<Result<ReturnPostedReceipt, String>> post({
    required double refundCash,
    required ReturnRefundMethod method,
  }) async {
    final rejection = purchaseReturnPrePostCheck(_state);
    if (rejection != null) {
      return Err<ReturnPostedReceipt, String>(rejection);
    }
    _state = returnFlowStateWith(_state, posting: true, postError: null);
    notifyListeners();
    final selected = _state.selected!;
    final chosen = _state.selectedLines;
    final result = await _returns.postPurchaseReturn(
      buildPurchaseReturnDraft(
        selected: selected,
        chosen: chosen,
        refundCash: refundCash,
        method: method,
        now: DateTime.now(),
      ),
      userId: _userId ?? 1,
    );
    if (result.isOk) {
      _state = returnFlowStateWith(
        _state,
        phase: ReturnPhase.done,
        posting: false,
        receipt: result.valueOrNull,
        postError: null,
      );
    } else {
      _state = returnFlowStateWith(
        _state,
        posting: false,
        postError: result.errorOrNull,
      );
    }
    notifyListeners();
    return result;
  }

  @override
  Future<void> startNewReturn() async {
    _state = returnFlowStateWith(
      _state,
      phase: ReturnPhase.pickingInvoice,
      clearSelected: true,
      lines: const <ReturnUiLine>[],
      receipt: null,
      postError: null,
    );
    notifyListeners();
    await load();
  }
}
