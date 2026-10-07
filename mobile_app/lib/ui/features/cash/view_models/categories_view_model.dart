/// نموذج فئات المصاريف (/cash/categories — FR-04-05): قائمة + إضافة +
/// إعادة تسمية + أرشفة («رواتب» محمية).
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/cash_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/cash.dart';

class CategoriesState {
  const CategoriesState({
    required this.loading,
    required this.categories,
    required this.archived,
    this.error,
    this.busyId,
  });

  final bool loading;
  final List<ExpenseCategoryInfo> categories;
  final List<ExpenseCategoryInfo> archived;
  final Object? error;
  final int? busyId;

  static const CategoriesState initial = CategoriesState(
    loading: true,
    categories: <ExpenseCategoryInfo>[],
    archived: <ExpenseCategoryInfo>[],
  );
}

class CategoriesViewModel extends ChangeNotifier {
  CategoriesViewModel({required CashRepository cashRepo}) : _cash = cashRepo;

  final CashRepository _cash;

  CategoriesState _state = CategoriesState.initial;
  CategoriesState get state => _state;

  Future<void> load() async {
    _state = const CategoriesState(loading: true, categories: [], archived: []);
    notifyListeners();
    try {
      final all = await _cash.listCategories(includeArchived: true);
      _state = CategoriesState(
        loading: false,
        categories: [
          for (final c in all)
            if (!c.isArchived) c,
        ],
        archived: [
          for (final c in all)
            if (c.isArchived) c,
        ],
      );
    } catch (error) {
      _state = CategoriesState(
        loading: false,
        categories: const [],
        archived: const [],
        error: error,
      );
    }
    notifyListeners();
  }

  Future<Result<ExpenseCategoryInfo, String>> add(String name) async {
    final result = await _cash.addCategory(name);
    if (result.isOk) {
      await load();
    }
    return result;
  }

  Future<Result<ExpenseCategoryInfo, String>> rename(
    int id,
    String name,
  ) async {
    final result = await _cash.renameCategory(id, name);
    if (result.isOk) {
      await load();
    }
    return result;
  }

  Future<Result<void, String>> archive(int id) async {
    final result = await _cash.archiveCategory(id);
    if (result.isOk) {
      await load();
    }
    return result;
  }

  Future<Result<void, String>> unarchive(int id) async {
    final result = await _cash.unarchiveCategory(id);
    if (result.isOk) {
      await load();
    }
    return result;
  }
}
