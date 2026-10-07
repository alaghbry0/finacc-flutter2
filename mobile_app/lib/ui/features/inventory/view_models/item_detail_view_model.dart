/// نموذج عرض بطاقة الصنف — التفاصيل الكاملة + الدفعات (FEFO) + العملات
/// النشطة (لعرض الأسعار بمنازلها) + الأرشفة (FR-01-15: الأرشفة بدل
/// الحذف مع بقاء التاريخ كاملاً).
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/batch_repository.dart';
import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/item_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/batch.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/item.dart';

/// حالة بطاقة الصنف.
class ItemDetailState {
  const ItemDetailState({
    required this.loading,
    required this.notFound,
    this.detail,
    required this.batches,
    required this.currencies,
    this.userId,
    this.archiving = false,
    this.archived = false,
    this.archiveError,
    this.error,
  });

  final bool loading;

  /// الصنف غير موجود (معرّف خاطئ أو محذوف من القاعدة).
  final bool notFound;

  final ItemFullDetail? detail;

  /// الدفعات النشطة مرتبة FEFO (فارغة لغير المتتبعين).
  final List<BatchInfo> batches;

  /// العملات النشطة — لمنازل عرض الأسعار.
  final List<Currency> currencies;

  /// المدير الحالي — لقيد الأرشفة.
  final int? userId;

  final bool archiving;

  /// نجحت الأرشفة (أو كان مؤرشفاً أصلاً — تُخفى أزرار الأرشفة).
  final bool archived;

  /// خطأ الأرشفة (عربي من المستودع — SnackBar).
  final String? archiveError;

  final Object? error;

  Item? get item => detail?.item;

  /// منازل العملة بمعرّفها (2 افتراضياً).
  int decimalsFor(int currencyId) {
    for (final currency in currencies) {
      if (currency.id == currencyId) return currency.decimals;
    }
    return 2;
  }

  static const ItemDetailState initial = ItemDetailState(
    loading: true,
    notFound: false,
    batches: <BatchInfo>[],
    currencies: <Currency>[],
  );
}

class ItemDetailViewModel extends ChangeNotifier {
  ItemDetailViewModel({
    required ItemRepository itemRepo,
    required BatchRepository batchRepo,
    required CompanyRepository companyRepo,
    required int itemId,
  }) : _items = itemRepo,
       _batches = batchRepo,
       _companies = companyRepo,
       _targetItemId = itemId;

  final ItemRepository _items;
  final BatchRepository _batches;
  final CompanyRepository _companies;
  final int _targetItemId;

  ItemDetailState _state = ItemDetailState.initial;
  ItemDetailState get state => _state;

  /// تحميل البطاقة: التفاصيل + العملات + المدير (+ الدفعات للمتتبعين).
  Future<void> load() async {
    _state = ItemDetailState(
      loading: true,
      notFound: false,
      batches: const <BatchInfo>[],
      currencies: _state.currencies,
      userId: _state.userId,
    );
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _items.detail(_targetItemId),
        _companies.listActiveCurrencies(),
        _companies.findAdminUserId(),
      ]);
      final detail = results[0] as ItemFullDetail?;
      if (detail == null) {
        _state = ItemDetailState(
          loading: false,
          notFound: true,
          batches: const <BatchInfo>[],
          currencies: results[1] as List<Currency>,
          userId: results[2] as int?,
        );
        notifyListeners();
        return;
      }
      final batches = detail.item.trackBatches
          ? await _batches.batchesForProduct(_targetItemId)
          : const <BatchInfo>[];
      _state = ItemDetailState(
        loading: false,
        notFound: false,
        detail: detail,
        batches: batches,
        currencies: results[1] as List<Currency>,
        userId: results[2] as int?,
        archived: detail.item.isArchived,
      );
    } catch (error) {
      _state = ItemDetailState(
        loading: false,
        notFound: false,
        batches: const <BatchInfo>[],
        currencies: _state.currencies,
        userId: _state.userId,
        error: error,
      );
    }
    notifyListeners();
  }

  /// أرشفة الصنف (FR-01-15) — بديل الحذف، يُبقي التاريخ كاملاً.
  Future<bool> archive() async {
    if (_state.archiving || _state.archived) return false;
    final userId = _state.userId;
    if (userId == null) return false;
    _state = ItemDetailState(
      loading: _state.loading,
      notFound: _state.notFound,
      detail: _state.detail,
      batches: _state.batches,
      currencies: _state.currencies,
      userId: userId,
      archived: _state.archived,
      archiving: true,
      archiveError: null,
    );
    notifyListeners();
    final result = await _items.archiveItem(_targetItemId, userId: userId);
    switch (result) {
      case Ok<void, String>():
        _state = ItemDetailState(
          loading: _state.loading,
          notFound: _state.notFound,
          detail: _state.detail,
          batches: _state.batches,
          currencies: _state.currencies,
          userId: userId,
          archived: true,
        );
        notifyListeners();
        return true;
      case final Err<void, String> err:
        _state = ItemDetailState(
          loading: _state.loading,
          notFound: _state.notFound,
          detail: _state.detail,
          batches: _state.batches,
          currencies: _state.currencies,
          userId: userId,
          archived: _state.archived,
          archiveError: err.error,
        );
        notifyListeners();
        return false;
    }
  }
}
