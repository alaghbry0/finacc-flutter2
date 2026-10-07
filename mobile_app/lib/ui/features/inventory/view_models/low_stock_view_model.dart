/// نموذج عرض «أصناف تنفذ قريباً» — عتبة قابلة للضبط (افتراضياً 5 وفق
/// دليل الشاشات) مع بحث بالاسم على النتائج المحمّلة (شاشة 04).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/item_repository.dart';
import '../../../../domain/models/item.dart';

/// عتبة العرض الافتراضية (دليل الشاشات 02/04: الحد الأدنى = 5).
const double lowStockDefaultThreshold = 5;

/// حالة شاشة الأصناف النافدة.
class LowStockState {
  const LowStockState({
    required this.loading,
    required this.threshold,
    required this.query,
    required this.items,
    this.error,
  });

  final bool loading;

  /// العتبة الحالية — يُعرض كل صنف إجماليه ≤ منها.
  final double threshold;

  /// بحث الاسم على النتائج (تصفية عرضية صرفة — لا استعلام جديد).
  final String query;

  final List<ItemStockInfo> items;

  final Object? error;

  /// النتائج الظاهرة بعد تطبيق بحث الاسم.
  List<ItemStockInfo> get visible {
    final q = query.trim();
    if (q.isEmpty) return items;
    return items.where((info) => info.item.name.contains(q)).toList();
  }

  static const LowStockState initial = LowStockState(
    loading: true,
    threshold: lowStockDefaultThreshold,
    query: '',
    items: <ItemStockInfo>[],
  );
}

class LowStockViewModel extends ChangeNotifier {
  LowStockViewModel({required ItemRepository itemRepo}) : _items = itemRepo;

  final ItemRepository _items;

  LowStockState _state = LowStockState.initial;
  LowStockState get state => _state;

  Timer? _thresholdDebounce;

  /// تغيير العتبة من حقل النص (تأجيل 300ms ثم إعادة التحميل).
  void onThresholdChanged(String text) {
    final value = double.tryParse(text.trim());
    if (value == null || value < 0 || value == _state.threshold) return;
    _thresholdDebounce?.cancel();
    _thresholdDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(setThreshold(value));
    });
  }

  /// تثبيت العتبة فوراً وإعادة التحميل.
  Future<void> setThreshold(double value) async {
    if (value < 0 || value == _state.threshold && !_state.loading) return;
    _thresholdDebounce?.cancel();
    _state = LowStockState(
      loading: true,
      threshold: value,
      query: _state.query,
      items: const <ItemStockInfo>[],
    );
    notifyListeners();
    await _reload();
  }

  /// بحث الاسم — تصفية عرضية فورية بلا استعلام.
  void setQuery(String query) {
    if (query == _state.query) return;
    _state = LowStockState(
      loading: _state.loading,
      threshold: _state.threshold,
      query: query,
      items: _state.items,
      error: _state.error,
    );
    notifyListeners();
  }

  /// التحميل الأول بالعتبة الحالية.
  Future<void> load() async {
    _state = LowStockState(
      loading: true,
      threshold: _state.threshold,
      query: _state.query,
      items: const <ItemStockInfo>[],
    );
    notifyListeners();
    await _reload();
  }

  Future<void> _reload() async {
    try {
      final items = await _items.lowStockItems(
        minThresholdOverride: _state.threshold,
      );
      _state = LowStockState(
        loading: false,
        threshold: _state.threshold,
        query: _state.query,
        items: items,
      );
    } catch (error) {
      _state = LowStockState(
        loading: false,
        threshold: _state.threshold,
        query: _state.query,
        items: const <ItemStockInfo>[],
        error: error,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _thresholdDebounce?.cancel();
    super.dispose();
  }
}
