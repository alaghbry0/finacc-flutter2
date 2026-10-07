/// نموذج سجل حركات الصندوق (/cash/movements — FR-04-08): مرشحات
/// (صندوق/نوع/فترة/بحث) تحفظ قيمها عند إعادة التحميل (قاعدة §10)
/// + إبطال حركة (معاكسة — لا حذف) + تفاصيل حركة واحدة.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/cash_repository.dart';
import '../../../../data/repositories/company_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/cash.dart';

/// فترة التصفية الزمنية.
enum CashPeriodFilter { all, today, week, month }

class MovementsState {
  const MovementsState({
    required this.loading,
    required this.movements,
    this.error,
    this.voidingId,
  });

  final bool loading;
  final List<CashMovementRow> movements;
  final Object? error;

  /// معرّف الحركة الجاري إبطالها (تعطيل زرها أثناء التنفيذ).
  final int? voidingId;

  static const MovementsState initial = MovementsState(
    loading: true,
    movements: <CashMovementRow>[],
  );
}

class MovementsViewModel extends ChangeNotifier {
  MovementsViewModel({
    required CashRepository cashRepo,
    required CompanyRepository companyRepo,
  }) : _cash = cashRepo,
       _companies = companyRepo;

  final CashRepository _cash;
  final CompanyRepository _companies;

  MovementsState _state = MovementsState.initial;
  MovementsState get state => _state;

  int? _userId;

  // المرشحات — تُحفظ عبر عمليات إعادة التحميل.
  int? _boxFilter;
  String? _typeFilter;
  CashPeriodFilter _period = CashPeriodFilter.all;
  String _search = '';

  int? get boxFilter => _boxFilter;
  String? get typeFilter => _typeFilter;
  CashPeriodFilter get period => _period;
  String get search => _search;

  void setBoxFilter(int? boxId) {
    _boxFilter = boxId;
    notifyListeners();
  }

  void setTypeFilter(String? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setPeriod(CashPeriodFilter period) {
    _period = period;
    notifyListeners();
  }

  void onSearchChanged(String value) {
    _search = value;
    notifyListeners();
  }

  Future<void> load() async {
    _state = MovementsState(
      loading: true,
      movements: const <CashMovementRow>[],
      voidingId: _state.voidingId,
    );
    notifyListeners();
    try {
      _userId ??= await _companies.findAdminUserId();
      final now = DateTime.now();
      DateTime? from;
      switch (_period) {
        case CashPeriodFilter.all:
          from = null;
        case CashPeriodFilter.today:
          from = DateTime(now.year, now.month, now.day);
        case CashPeriodFilter.week:
          from = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 7));
        case CashPeriodFilter.month:
          from = DateTime(now.year, now.month, 1);
      }
      final movements = await _cash.journal(
        cashboxId: _boxFilter,
        txType: _typeFilter,
        from: from,
        search: _search.trim().isEmpty ? null : _search.trim(),
      );
      _state = MovementsState(loading: false, movements: movements);
    } catch (error) {
      _state = MovementsState(
        loading: false,
        movements: const <CashMovementRow>[],
        error: error,
      );
    }
    notifyListeners();
  }

  /// تفاصيل حركة واحدة (مع تخصيصاتها).
  Future<CashMovementDetail?> movementDetail(int id) =>
      _cash.movementDetail(id);

  /// **إبطال حركة** — حركة معاكسة داخل معاملة واحدة (لا حذف ولا
  /// تعديل — FR-04-08). رسالة الرفض عربية تُعرض كما هي.
  Future<Result<int, String>> voidMovement(int id, {String? reason}) async {
    _userId ??= await _companies.findAdminUserId();
    final result = await _cash.voidMovement(
      id,
      userId: _userId ?? 1,
      reason: reason,
    );
    if (result.isOk) {
      await load();
    }
    return result;
  }
}
