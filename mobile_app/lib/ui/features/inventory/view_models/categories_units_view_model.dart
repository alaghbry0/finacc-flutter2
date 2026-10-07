/// نموذج عرض «الفئات والوحدات» — شجرة فئات بمستويين (FR-01-05) ووحدات
/// بمعامل تحويل (FR-13-06) مع إضافة فورية من الحوارات.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/item_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/item.dart';

/// حالة شاشة الفئات والوحدات.
class CategoriesUnitsState {
  const CategoriesUnitsState({
    required this.loading,
    required this.categories,
    required this.units,
    this.error,
  });

  final bool loading;
  final List<ItemCategory> categories;
  final List<ItemUnit> units;

  final Object? error;

  /// الفئات الجذرية مرتبة مع أبنائها (شجرة العرض).
  List<ItemCategory> get roots => categories.where((c) => c.isRoot).toList();

  /// أبناء فئة جذرية معينة.
  List<ItemCategory> childrenOf(int parentId) =>
      categories.where((c) => c.parentId == parentId).toList();

  static const CategoriesUnitsState initial = CategoriesUnitsState(
    loading: true,
    categories: <ItemCategory>[],
    units: <ItemUnit>[],
  );
}

class CategoriesUnitsViewModel extends ChangeNotifier {
  CategoriesUnitsViewModel({required ItemRepository itemRepo})
    : _items = itemRepo;

  final ItemRepository _items;

  CategoriesUnitsState _state = CategoriesUnitsState.initial;
  CategoriesUnitsState get state => _state;

  /// تحميل الفئات والوحدات معاً.
  Future<void> load() async {
    _state = CategoriesUnitsState(
      loading: true,
      categories: _state.categories,
      units: _state.units,
    );
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _items.listCategories(),
        _items.listUnits(),
      ]);
      _state = CategoriesUnitsState(
        loading: false,
        categories: results[0] as List<ItemCategory>,
        units: results[1] as List<ItemUnit>,
      );
    } catch (error) {
      _state = CategoriesUnitsState(
        loading: false,
        categories: _state.categories,
        units: _state.units,
        error: error,
      );
    }
    notifyListeners();
  }

  /// ينشئ فئة (جذر أو فرعاً لأم جذرية) — يعيد خطأ المستودع أو null.
  Future<String?> addCategory(String name, {int? parentId}) async {
    final result = await _items.createCategory(name, parentId: parentId);
    switch (result) {
      case final Ok<int, String> _:
        await load();
        return null;
      case final Err<int, String> err:
        return err.error;
    }
  }

  /// ينشئ وحدة بمعامل تحويل — يعيد خطأ المستودع أو null.
  Future<String?> addUnit(String name, {required double factor}) async {
    final result = await _items.createUnit(name, factor: factor);
    switch (result) {
      case final Ok<int, String> _:
        await load();
        return null;
      case final Err<int, String> err:
        return err.error;
    }
  }
}
