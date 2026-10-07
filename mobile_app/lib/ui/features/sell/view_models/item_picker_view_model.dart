/// نموذج نافذة «اختر الصنف» (FR-02-02) — بحث فوري مؤجَّل بالاسم/الباركود
/// مع سعر التجزئة بعملة الفاتورة الحالية ومخزون الصنف.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/item_repository.dart';
import '../../../../domain/models/item.dart';

/// حجم دفعة نتائج المنتقي (20 — §6.5: شبكة أول 20 صنفاً).
const int pickerPageSize = 20;

class ItemPickerState {
  const ItemPickerState({
    required this.loading,
    required this.results,
    required this.query,
    this.error,
  });

  final bool loading;
  final List<ItemStockInfo> results;
  final String query;
  final Object? error;

  static const ItemPickerState initial = ItemPickerState(
    loading: true,
    results: <ItemStockInfo>[],
    query: '',
  );
}

class ItemPickerViewModel extends ChangeNotifier {
  ItemPickerViewModel({
    required ItemRepository itemRepo,
    required this.currencyId,
  }) : _items = itemRepo;

  final ItemRepository _items;

  /// عملة الفاتورة — لأسعار المنتقي بلغتها.
  final int? currencyId;

  ItemPickerState _state = ItemPickerState.initial;
  ItemPickerState get state => _state;

  Timer? _debounce;

  /// بحث الكتابة — تأجيل 200ms مثل قائمة الأصناف.
  void onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(search(query));
    });
  }

  /// بحث فوري (Enter أو مسح).
  Future<void> search(String query) async {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed == _state.query && !_state.loading) return;
    _state = ItemPickerState(
      loading: true,
      results: const <ItemStockInfo>[],
      query: trimmed,
    );
    notifyListeners();
    try {
      final results = await _items.searchItems(
        trimmed,
        limit: pickerPageSize,
        currencyIdForPrice: currencyId,
      );
      _state = ItemPickerState(
        loading: false,
        results: results,
        query: trimmed,
      );
    } catch (error) {
      _state = ItemPickerState(
        loading: false,
        results: const <ItemStockInfo>[],
        query: trimmed,
        error: error,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
