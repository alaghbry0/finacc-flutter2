/// نموذج نافذة «اختر الصنف للشراء» — بحث فوري مؤجَّل بالاسم/الباركود مع
/// المخزون الحالي وآخر تكلفة WAC (عرض معلوماتي — لا سقف كمية في الشراء).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/item_repository.dart';
import '../../../../domain/models/item.dart';

/// حجم دفعة نتائج المنتقي (20 — مثل منتقي الكاشير).
const int purchasePickerPageSize = 20;

class PurchaseItemPickerState {
  const PurchaseItemPickerState({
    required this.loading,
    required this.results,
    required this.query,
    this.error,
  });

  final bool loading;
  final List<ItemStockInfo> results;
  final String query;
  final Object? error;

  static const PurchaseItemPickerState initial = PurchaseItemPickerState(
    loading: true,
    results: <ItemStockInfo>[],
    query: '',
  );
}

class PurchaseItemPickerViewModel extends ChangeNotifier {
  PurchaseItemPickerViewModel({required ItemRepository itemRepo})
    : _items = itemRepo;

  final ItemRepository _items;

  PurchaseItemPickerState _state = PurchaseItemPickerState.initial;
  PurchaseItemPickerState get state => _state;

  Timer? _debounce;

  /// بحث الكتابة — تأجيل 200ms مثل بقية المنتقيات.
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
    _state = PurchaseItemPickerState(
      loading: true,
      results: const <ItemStockInfo>[],
      query: trimmed,
    );
    notifyListeners();
    try {
      final results = await _items.searchItems(
        trimmed,
        limit: purchasePickerPageSize,
      );
      _state = PurchaseItemPickerState(
        loading: false,
        results: results,
        query: trimmed,
      );
    } catch (error) {
      _state = PurchaseItemPickerState(
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
