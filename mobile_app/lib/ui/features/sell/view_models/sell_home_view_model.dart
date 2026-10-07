/// نموذج محور البيع (/sell) — بطاقة بطلة: مبيعات اليوم وصافي الصندوق
/// (DashboardRepository بعملة الأساس) + آخر الفواتير للعدّاد السريع.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/dashboard_repository.dart';
import '../../../../data/repositories/sale_repository.dart';
import '../../../../domain/models/sale.dart';

class SellHomeState {
  const SellHomeState({
    required this.loading,
    this.stats,
    required this.recentInvoices,
    this.error,
  });

  final bool loading;
  final DashboardTodayStats? stats;
  final List<SaleInvoiceSummary> recentInvoices;
  final Object? error;

  static const SellHomeState initial = SellHomeState(
    loading: true,
    recentInvoices: <SaleInvoiceSummary>[],
  );
}

class SellHomeViewModel extends ChangeNotifier {
  SellHomeViewModel({
    required DashboardRepository dashboardRepo,
    required SaleRepository saleRepo,
  }) : _dashboard = dashboardRepo,
       _sales = saleRepo;

  final DashboardRepository _dashboard;
  final SaleRepository _sales;

  SellHomeState _state = SellHomeState.initial;
  SellHomeState get state => _state;

  Future<void> load() async {
    _state = SellHomeState.initial;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _dashboard.todayStats(DateTime.now()),
        _sales.recentSales(limit: 5),
      ]);
      _state = SellHomeState(
        loading: false,
        stats: results[0] as DashboardTodayStats,
        recentInvoices: results[1]! as List<SaleInvoiceSummary>,
      );
    } catch (error) {
      _state = SellHomeState(
        loading: false,
        recentInvoices: const <SaleInvoiceSummary>[],
        error: error,
      );
    }
    notifyListeners();
  }
}
