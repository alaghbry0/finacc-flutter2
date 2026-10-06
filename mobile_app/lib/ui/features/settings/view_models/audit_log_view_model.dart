/// نموذج عرض سجل التدقيق — قراءة صفحة بعد صفحة (FR-12-04 عرض فقط)
/// مع تصفية اختيارية بالتصنيف وشارات عدّادات لكل تصنيف.
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
    required this.filter,
    required this.counts,
    this.error,
  });

  final bool loading;
  final List<AuditEvent> events;
  final int totalCount;

  /// التصفية الحالية (null = الكل).
  final AuditCategory? filter;

  /// عدّادات التصنيفات لشارات التصفية.
  final Map<AuditCategory, int> counts;

  final Object? error;

  static const AuditLogState initial = AuditLogState(
    loading: true,
    events: <AuditEvent>[],
    totalCount: 0,
    filter: null,
    counts: <AuditCategory, int>{},
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

  /// التحميل الأول (أو إعادة التحديث) بالتصفية الحالية.
  Future<void> load() async {
    _state = AuditLogState(
      loading: true,
      events: const <AuditEvent>[],
      totalCount: _state.totalCount,
      filter: _state.filter,
      counts: _state.counts,
    );
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _repo.page(limit: _pageSize, offset: 0, category: _state.filter),
        _repo.counts(),
      ]);
      final page = results[0] as AuditPage;
      _state = AuditLogState(
        loading: false,
        events: page.events,
        totalCount: page.totalCount,
        filter: _state.filter,
        counts: results[1] as Map<AuditCategory, int>,
      );
    } catch (error) {
      _state = AuditLogState(
        loading: false,
        events: const <AuditEvent>[],
        totalCount: 0,
        filter: _state.filter,
        counts: _state.counts,
        error: error,
      );
    }
    notifyListeners();
  }

  /// تثبيت تصنيف التصفية وإعادة التحميل (null = الكل).
  Future<void> setFilter(AuditCategory? category) async {
    if (category == _state.filter) return;
    _state = AuditLogState(
      loading: true,
      events: const <AuditEvent>[],
      totalCount: _state.totalCount,
      filter: category,
      counts: _state.counts,
    );
    notifyListeners();
    await load();
  }

  /// تحميل الصفحة التالية (زر «المزيد») بالتصفية الحالية.
  Future<void> loadMore() async {
    if (_loadingMore || !_state.hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await _repo.page(
        limit: _pageSize,
        offset: _state.events.length,
        category: _state.filter,
      );
      _state = AuditLogState(
        loading: false,
        events: [..._state.events, ...page.events],
        totalCount: page.totalCount,
        filter: _state.filter,
        counts: _state.counts,
      );
    } catch (_) {
      // فشل «المزيد» لا يمسح المحمّل — المحاولة تبقى متاحة.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}
