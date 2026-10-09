/// نموذج قائمة فواتير الشراء — آخر المشتريات (recentPurchases) + بحث نصي
/// محلي بسيط (رقم/مورد) + تحميل تفاصيل فاتورة شراء + **إبطال فاتورة
/// الشراء** (FR-02-15 — R17-c) بصلاحية المدير.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/purchase_repository.dart';
import '../../../../domain/models/purchase.dart';

class PurchasesListState {
  const PurchasesListState({
    required this.loading,
    required this.invoices,
    required this.filterQuery,
    this.error,
  });

  final bool loading;
  final List<PurchaseInvoiceSummary> invoices;
  final String filterQuery;
  final Object? error;

  /// النتائج بعد تطبيق بحث المستخدم (رقم الفاتورة أو اسم المورد).
  List<PurchaseInvoiceSummary> get visible {
    final query = filterQuery.trim();
    if (query.isEmpty) return invoices;
    return [
      for (final invoice in invoices)
        if (invoice.invoiceNo.contains(query) ||
            (invoice.supplierName ?? '').contains(query))
          invoice,
    ];
  }

  static const PurchasesListState initial = PurchasesListState(
    loading: true,
    invoices: <PurchaseInvoiceSummary>[],
    filterQuery: '',
  );
}

class PurchasesListViewModel extends ChangeNotifier {
  PurchasesListViewModel({required PurchaseRepository purchaseRepo})
    : _purchases = purchaseRepo;

  final PurchaseRepository _purchases;

  PurchasesListState _state = PurchasesListState.initial;
  PurchasesListState get state => _state;

  Future<void> load() async {
    _state = PurchasesListState(
      loading: true,
      invoices: const <PurchaseInvoiceSummary>[],
      filterQuery: _state.filterQuery,
    );
    notifyListeners();
    try {
      final invoices = await _purchases.recentPurchases(limit: 100);
      _state = PurchasesListState(
        loading: false,
        invoices: invoices,
        filterQuery: _state.filterQuery,
      );
    } catch (error) {
      _state = PurchasesListState(
        loading: false,
        invoices: const <PurchaseInvoiceSummary>[],
        filterQuery: _state.filterQuery,
        error: error,
      );
    }
    notifyListeners();
  }

  void setFilter(String query) {
    if (query == _state.filterQuery) return;
    _state = PurchasesListState(
      loading: _state.loading,
      invoices: _state.invoices,
      filterQuery: query,
      error: _state.error,
    );
    notifyListeners();
  }
}

/// نموذج شاشة تفاصيل فاتورة الشراء.
class PurchaseDetailState {
  const PurchaseDetailState({
    required this.loading,
    this.detail,
    this.error,
    this.voiding = false,
    this.voidError,
  });

  final bool loading;
  final PurchaseInvoiceDetail? detail;
  final Object? error;

  /// إبطال جارٍ الآن (زر مزدوج الضغط ممنوع).
  final bool voiding;

  /// رسالة فشل آخر إبطال (رسائل المستودع عربية جاهزة — تُعرض كما هي).
  final String? voidError;

  static const PurchaseDetailState initial = PurchaseDetailState(loading: true);
}

class PurchaseDetailViewModel extends ChangeNotifier {
  PurchaseDetailViewModel({
    required PurchaseRepository purchaseRepo,
    required CompanyRepository companyRepo,
    required this.invoiceId,
  }) : _purchases = purchaseRepo,
       _companies = companyRepo;

  final PurchaseRepository _purchases;

  /// مستودع المنشأة — `findAdminUserId` (صلاحية المدير FR-02-15: V1
  /// بمدير واحد والقفل بـ PIN المدير، فالجلسة مديرية حصراً؛ غيابه يرفض).
  final CompanyRepository _companies;
  final int invoiceId;

  PurchaseDetailState _state = PurchaseDetailState.initial;
  PurchaseDetailState get state => _state;

  Future<void> load() async {
    _state = PurchaseDetailState.initial;
    notifyListeners();
    try {
      final detail = await _purchases.purchaseDetail(invoiceId);
      _state = PurchaseDetailState(loading: false, detail: detail);
    } catch (error) {
      _state = PurchaseDetailState(loading: false, error: error);
    }
    notifyListeners();
  }

  /// **إبطال فاتورة الشراء** (FR-02-15 — المدير حصراً): معاملة عكسية
  /// كاملة (مخزون + WAC + صندوق + رصيد المورد) ثم إعادة تحميل
  /// التفاصيل لتظهر بحالة «ملغاة».
  ///
  /// يعيد true عند النجاح؛ عند الفشل تُخزَّن رسالة المستودع في
  /// `state.voidError` وتُعرض كما هي (نمط رسائل المستودعات القائم).
  Future<bool> voidInvoice({String? reason}) async {
    if (_state.voiding) return false;
    _state = PurchaseDetailState(
      loading: _state.loading,
      detail: _state.detail,
      error: _state.error,
      voiding: true,
      voidError: null,
    );
    notifyListeners();
    try {
      final adminId = await _companies.findAdminUserId();
      if (adminId == null) {
        _state = PurchaseDetailState(
          loading: false,
          detail: _state.detail,
          voiding: false,
          voidError:
              'لا يوجد مستخدم مدير نشط — الإبطال بصلاحية المدير '
              'حصراً (FR-02-15).',
        );
        notifyListeners();
        return false;
      }
      final result = await _purchases.voidInvoice(
        invoiceId,
        userId: adminId,
        reason: reason,
      );
      if (result.isOk) {
        // إعادة التحميل: التفاصيل تعرض الحالة «ملغاة» بلا زر إبطال.
        await load();
        return true;
      }
      _state = PurchaseDetailState(
        loading: false,
        detail: _state.detail,
        voiding: false,
        voidError: result.errorOrNull,
      );
      notifyListeners();
      return false;
    } catch (error) {
      _state = PurchaseDetailState(
        loading: false,
        detail: _state.detail,
        voiding: false,
        voidError: error.toString(),
      );
      notifyListeners();
      return false;
    }
  }
}
