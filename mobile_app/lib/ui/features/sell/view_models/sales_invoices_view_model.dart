/// نموذج قائمة فواتير المبيعات — آخر الفواتير (recentSales) + بحث نصي
/// محلي بسيط (رقم/عميل) + تحميل تفاصيل فاتورة.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/sale_repository.dart';
import '../../../../domain/models/sale.dart';

class SalesInvoicesState {
  const SalesInvoicesState({
    required this.loading,
    required this.invoices,
    required this.filterQuery,
    this.error,
  });

  final bool loading;
  final List<SaleInvoiceSummary> invoices;
  final String filterQuery;
  final Object? error;

  /// النتائج بعد تطبيق بحث المستخدم (رقم الفاتورة أو اسم العميل).
  List<SaleInvoiceSummary> get visible {
    final query = filterQuery.trim();
    if (query.isEmpty) return invoices;
    return [
      for (final invoice in invoices)
        if (invoice.invoiceNo.contains(query) ||
            (invoice.customerName ?? '').contains(query))
          invoice,
    ];
  }

  static const SalesInvoicesState initial = SalesInvoicesState(
    loading: true,
    invoices: <SaleInvoiceSummary>[],
    filterQuery: '',
  );
}

class SalesInvoicesViewModel extends ChangeNotifier {
  SalesInvoicesViewModel({required SaleRepository saleRepo})
    : _sales = saleRepo;

  final SaleRepository _sales;

  SalesInvoicesState _state = SalesInvoicesState.initial;
  SalesInvoicesState get state => _state;

  Future<void> load() async {
    _state = SalesInvoicesState(
      loading: true,
      invoices: const <SaleInvoiceSummary>[],
      filterQuery: _state.filterQuery,
    );
    notifyListeners();
    try {
      final invoices = await _sales.recentSales(limit: 100);
      _state = SalesInvoicesState(
        loading: false,
        invoices: invoices,
        filterQuery: _state.filterQuery,
      );
    } catch (error) {
      _state = SalesInvoicesState(
        loading: false,
        invoices: const <SaleInvoiceSummary>[],
        filterQuery: _state.filterQuery,
        error: error,
      );
    }
    notifyListeners();
  }

  void setFilter(String query) {
    if (query == _state.filterQuery) return;
    _state = SalesInvoicesState(
      loading: _state.loading,
      invoices: _state.invoices,
      filterQuery: query,
      error: _state.error,
    );
    notifyListeners();
  }

  /// تفاصيل فاتورة (للشاشة التفصيلية) — null إن لم توجد.
  Future<SaleInvoiceDetail?> detail(int invoiceId) =>
      _sales.invoiceDetail(invoiceId);
}

/// نموذج شاشة تفاصيل فاتورة البيع.
class SaleInvoiceDetailState {
  const SaleInvoiceDetailState({
    required this.loading,
    this.detail,
    this.error,
    this.voiding = false,
    this.voidError,
  });

  final bool loading;
  final SaleInvoiceDetail? detail;
  final Object? error;

  /// إبطال جارٍ الآن (زر مزدوج الضغط ممنوع).
  final bool voiding;

  /// رسالة فشل آخر إبطال (تُعرض كما هي — رسائل المستودع عربية جاهزة).
  final String? voidError;

  static const SaleInvoiceDetailState initial = SaleInvoiceDetailState(
    loading: true,
  );
}

class SaleInvoiceDetailViewModel extends ChangeNotifier {
  SaleInvoiceDetailViewModel({
    required SaleRepository saleRepo,
    required CompanyRepository companyRepo,
    required this.invoiceId,
  }) : _sales = saleRepo,
       _companies = companyRepo;

  final SaleRepository _sales;

  /// مستودع المنشأة — `findAdminUserId` (صلاحية المدير FR-02-15: V1
  /// بمدير واحد والقفل بـ PIN المدير، فالجلسة مديرية حصراً؛ غيابه يرفض).
  final CompanyRepository _companies;
  final int invoiceId;

  SaleInvoiceDetailState _state = SaleInvoiceDetailState.initial;
  SaleInvoiceDetailState get state => _state;

  Future<void> load() async {
    _state = SaleInvoiceDetailState.initial;
    notifyListeners();
    try {
      final detail = await _sales.invoiceDetail(invoiceId);
      _state = SaleInvoiceDetailState(loading: false, detail: detail);
    } catch (error) {
      _state = SaleInvoiceDetailState(loading: false, error: error);
    }
    notifyListeners();
  }

  /// **إبطال الفاتورة** (FR-02-15 — المدير حصراً): يستدعي محرك المستودع
  /// (معاملة عكسية كاملة) ثم يعيد تحميل التفاصيل لتظهر بحالة «ملغاة».
  ///
  /// يعيد true عند النجاح؛ عند الفشل تُخزَّن رسالة المستودع في
  /// `state.voidError` وتُعرض كما هي (نمط رسائل المستودعات القائم).
  Future<bool> voidInvoice({String? reason}) async {
    if (_state.voiding) return false;
    _state = SaleInvoiceDetailState(
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
        _state = SaleInvoiceDetailState(
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
      final result = await _sales.voidInvoice(
        invoiceId,
        userId: adminId,
        reason: reason,
      );
      if (result.isOk) {
        // إعادة التحميل: التفاصيل تعرض الحالة «ملغاة» بلا أزرار إبطال.
        await load();
        return true;
      }
      _state = SaleInvoiceDetailState(
        loading: false,
        detail: _state.detail,
        voiding: false,
        voidError: result.errorOrNull,
      );
      notifyListeners();
      return false;
    } catch (error) {
      _state = SaleInvoiceDetailState(
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
