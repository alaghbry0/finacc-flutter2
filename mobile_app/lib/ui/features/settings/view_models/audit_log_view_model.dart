/// نموذج عرض سجل التدقيق — قراءة صفحة بعد صفحة (FR-12-04 عرض فقط).
///
/// التجميع باليوم محلياً (اليوم/أمس/تاريخ) وترقيم صفحات بمعاينة
/// «المزيد» — السجل نفسه للإضافة فقط ولا يُمحى من الواجهة إطلاقاً.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/audit_repository.dart';
import '../../../../domain/models/audit_event.dart';

/// حجم الصفحة الواحدة.
const _pageSize = 40;

/// حالة السجل المعروضة.
class AuditLogState {
  const AuditLogState({
    required this.loading,
    required this.events,
    required this.totalCount,
    this.error,
  });

  final bool loading;
  final List<AuditEvent> events;
  final int totalCount;
  final Object? error;

  static const AuditLogState initial = AuditLogState(
    loading: true,
    events: <AuditEvent>[],
    totalCount: 0,
  );

  /// هل بقي المزيد بعد الأحداث المحمّلة؟
  bool get hasMore => events.length < totalCount;
}

class AuditLogViewModel extends ChangeNotifier {
  AuditLogViewModel({required AuditRepository repository}) : _repo = repository;

  final AuditRepository _repo;

  AuditLogState _state = AuditLogState.initial;
  AuditLogState get state => _state;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  /// التحميل الأول (أو إعادة التحديث).
  Future<void> load() async {
    _state = AuditLogState(
      loading: true,
      events: const <AuditEvent>[],
      totalCount: _state.totalCount,
    );
    notifyListeners();
    try {
      final page = await _repo.page(limit: _pageSize, offset: 0);
      _state = AuditLogState(
        loading: false,
        events: page.events,
        totalCount: page.totalCount,
      );
    } catch (error) {
      _state = AuditLogState(
        loading: false,
        events: const <AuditEvent>[],
        totalCount: 0,
        error: error,
      );
    }
    notifyListeners();
  }

  /// تحميل الصفحة التالية (زر «المزيد»).
  Future<void> loadMore() async {
    if (_loadingMore || !_state.hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await _repo.page(
        limit: _pageSize,
        offset: _state.events.length,
      );
      _state = AuditLogState(
        loading: false,
        events: [..._state.events, ...page.events],
        totalCount: page.totalCount,
      );
    } catch (_) {
      // فشل «المزيد» لا يمسح المحمّل — المحاولة تبقى متاحة.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}
