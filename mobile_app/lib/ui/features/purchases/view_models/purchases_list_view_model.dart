/// نموذج قائمة فواتير الشراء — آخر المشتريات (recentPurchases) + بحث نصي
/// محلي بسيط (رقم/مورد) + تحميل تفاصيل فاتورة شراء.
library;

import 'package:flutter/foundation.dart';

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
  const PurchaseDetailState({required this.loading, this.detail, this.error});

  final bool loading;
  final PurchaseInvoiceDetail? detail;
  final Object? error;

  static const PurchaseDetailState initial = PurchaseDetailState(loading: true);
}

class PurchaseDetailViewModel extends ChangeNotifier {
  PurchaseDetailViewModel({
    required PurchaseRepository purchaseRepo,
    required this.invoiceId,
  }) : _purchases = purchaseRepo;

  final PurchaseRepository _purchases;
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
}
