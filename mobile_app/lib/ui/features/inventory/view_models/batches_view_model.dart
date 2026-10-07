/// نموذج عرض «الدفعات وتواريخ الصلاحية» — سلالم العدّادات (FR-09-15)
/// وقائمة الدفعات المنتهية والمنتهية خلال 90 يوماً مع أسماء الأصناف.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/batch_repository.dart';
import '../../../../domain/models/batch.dart';

/// مفاتيح سلالم الصلاحية (تطابق مفاتيح مستودع `expiryBuckets`).
enum ExpiryBucket { all, expired, d30, d60, d90 }

/// حالة شاشة الدفعات.
class BatchesState {
  const BatchesState({
    required this.loading,
    required this.selected,
    required this.buckets,
    required this.alerts,
    this.error,
  });

  final bool loading;

  /// السلم المحدد (null-style: `all` = الكل).
  final ExpiryBucket selected;

  /// عدّادات السلالم من المستودع.
  final Map<String, int> buckets;

  /// كل التنبيهات (منتهية + ≤90 يوماً) مرتبة بالأقرب انتهاءً.
  final List<BatchExpiryAlert> alerts;

  final Object? error;

  int bucketCount(ExpiryBucket bucket) => switch (bucket) {
    ExpiryBucket.all => _total,
    ExpiryBucket.expired => buckets['expired'] ?? 0,
    ExpiryBucket.d30 => buckets['30'] ?? 0,
    ExpiryBucket.d60 => buckets['60'] ?? 0,
    ExpiryBucket.d90 => buckets['90'] ?? 0,
  };

  int get _total =>
      (buckets['expired'] ?? 0) +
      (buckets['30'] ?? 0) +
      (buckets['60'] ?? 0) +
      (buckets['90'] ?? 0);

  /// تنبيهات السلم المحدد فقط.
  List<BatchExpiryAlert> get visible => switch (selected) {
    ExpiryBucket.all => alerts,
    ExpiryBucket.expired => alerts.where((a) => a.daysToExpiry < 0).toList(),
    ExpiryBucket.d30 =>
      alerts.where((a) => a.daysToExpiry >= 0 && a.daysToExpiry <= 30).toList(),
    ExpiryBucket.d60 =>
      alerts
          .where((a) => a.daysToExpiry >= 31 && a.daysToExpiry <= 60)
          .toList(),
    ExpiryBucket.d90 =>
      alerts
          .where((a) => a.daysToExpiry >= 61 && a.daysToExpiry <= 90)
          .toList(),
  };

  static const BatchesState initial = BatchesState(
    loading: true,
    selected: ExpiryBucket.all,
    buckets: <String, int>{},
    alerts: <BatchExpiryAlert>[],
  );
}

class BatchesViewModel extends ChangeNotifier {
  BatchesViewModel({required BatchRepository batchRepo}) : _batches = batchRepo;

  final BatchRepository _batches;

  BatchesState _state = BatchesState.initial;
  BatchesState get state => _state;

  /// تحميل السلالم والتنبيهات (90 يوماً + المنتهية).
  Future<void> load() async {
    _state = BatchesState(
      loading: true,
      selected: _state.selected,
      buckets: _state.buckets,
      alerts: const <BatchExpiryAlert>[],
    );
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _batches.expiryBuckets(),
        _batches.expiryAlerts(withinDays: 90),
      ]);
      _state = BatchesState(
        loading: false,
        selected: _state.selected,
        buckets: results[0] as Map<String, int>,
        alerts: results[1] as List<BatchExpiryAlert>,
      );
    } catch (error) {
      _state = BatchesState(
        loading: false,
        selected: _state.selected,
        buckets: _state.buckets,
        alerts: const <BatchExpiryAlert>[],
        error: error,
      );
    }
    notifyListeners();
  }

  /// اختيار سلم (تصفية عرضية فورية — بلا استعلام جديد).
  void setBucket(ExpiryBucket bucket) {
    if (bucket == _state.selected) return;
    _state = BatchesState(
      loading: _state.loading,
      selected: bucket,
      buckets: _state.buckets,
      alerts: _state.alerts,
      error: _state.error,
    );
    notifyListeners();
  }
}
