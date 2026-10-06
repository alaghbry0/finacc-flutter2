/// نموذج عرض لوحة التحكم — FR-09-01 (البلاطات الأربع + رسم 30 يوماً +
/// تنبيهات المخزون) من القاعدة الحقيقية، مع حالات تحميل/خطأ كاملة.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/dashboard_repository.dart';

class DashboardState {
  const DashboardState({
    required this.loading,
    required this.stats,
    required this.series,
    required this.lowStock,
    this.error,
    this.lastUpdated,
  });

  final bool loading;
  final DashboardTodayStats stats;
  final List<DailySalesPoint> series;
  final int lowStock;
  final Object? error;

  /// لحظة آخر تحميل ناجح (شارة «آخر تحديث»).
  final DateTime? lastUpdated;

  static const DashboardState initial = DashboardState(
    loading: true,
    stats: DashboardTodayStats(
      sales: 0,
      profit: 0,
      invoiceCount: 0,
      netCash: 0,
    ),
    series: <DailySalesPoint>[],
    lowStock: 0,
  );
}

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required DashboardRepository repository,
    CompanyRepository? companyRepository,
  }) : _repo = repository,
       _companyRepo = companyRepository;

  final DashboardRepository _repo;
  final CompanyRepository? _companyRepo;

  DashboardState _state = DashboardState.initial;
  String? _companyName;
  String? _adminName;
  String? _currencyCode;

  DashboardState get state => _state;
  String? get companyName => _companyName;
  String? get adminName => _adminName;

  /// رمز العملة الأساسية (YER/SAR/… — لفقاعة الرسم البياني).
  String? get currencyCode => _currencyCode;

  /// تحميل كامل (يُستدعى عند بناء الشاشة وعند السحب للتحديث).
  Future<void> load({String? companyName, String? adminName}) async {
    _companyName = companyName ?? _companyName;
    _adminName = adminName ?? _adminName;
    _state = DashboardState(
      loading: true,
      stats: _state.stats,
      series: _state.series,
      lowStock: _state.lowStock,
    );
    notifyListeners();
    try {
      final now = DateTime.now();
      final stats = await _repo.todayStats(now);
      final series = await _repo.last30DaysSales(now);
      final lowStock = await _repo.lowStockCount();
      if (_currencyCode == null && _companyRepo != null) {
        _currencyCode = (await _companyRepo.findBaseCurrency())?.code;
      }
      _state = DashboardState(
        loading: false,
        stats: stats,
        series: series,
        lowStock: lowStock,
        lastUpdated: DateTime.now(),
      );
    } catch (error) {
      _state = DashboardState(
        loading: false,
        stats: _state.stats,
        series: _state.series,
        lowStock: _state.lowStock,
        error: error,
      );
    }
    notifyListeners();
  }
}
