/// نموذج عرض قائمة الأصناف — بحث فوري مؤجَّل (200ms — FR-01-04)، تصفية
/// بالفئة، وترقيم صفحات تدريجي (50 صفحة)، مع سعر التجزئة بعملة القاعدة.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/item_repository.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/item.dart';

/// حجم الصفحة الواحدة.
const int itemsPageSize = 50;

/// حالة قائمة الأصناف.
class ItemListState {
  const ItemListState({
    required this.loading,
    required this.items,
    required this.hasMore,
    required this.categories,
    required this.categoryId,
    required this.query,
    this.baseCurrency,
    this.error,
  });

  final bool loading;
  final List<ItemStockInfo> items;

  /// هل بقي المزيد بعد المحمّل؟
  final bool hasMore;

  /// فئات التصفية.
  final List<ItemCategory> categories;

  /// الفئة المحددة (null = الكل).
  final int? categoryId;

  /// نص البحث الحالي (يُطبَّق على النتائج).
  final String query;

  /// عملة القاعدة — لسعر التجزئة في البطاقات.
  final Currency? baseCurrency;

  final Object? error;

  /// العدد المعروض حالياً.
  int get shownCount => items.length;

  /// عدد كل المطابقات إن عُرف بدقة (وإلا null — يعني «{pageSize}+»).
  int? get exactTotal => hasMore ? null : items.length;

  static const ItemListState initial = ItemListState(
    loading: true,
    items: <ItemStockInfo>[],
    hasMore: false,
    categories: <ItemCategory>[],
    categoryId: null,
    query: '',
  );
}

class ItemListViewModel extends ChangeNotifier {
  ItemListViewModel({
    required ItemRepository itemRepo,
    required CompanyRepository companyRepo,
  }) : _items = itemRepo,
       _companies = companyRepo;

  final ItemRepository _items;
  final CompanyRepository _companies;

  ItemListState _state = ItemListState.initial;
  ItemListState get state => _state;

  Timer? _searchDebounce;
  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  /// البحث مع تأجيل 200ms (FR-01-04) — يستدعيه حقل البحث عند الكتابة.
  void onQueryChanged(String query) {
    if (query == _state.query) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(setQuery(query));
    });
  }

  /// تثبيت البحث فوراً (تجاوز التأجيل — الاختبارات والعودة للشاشة).
  Future<void> setQuery(String query) async {
    if (query == _state.query && !_state.loading) return;
    _searchDebounce?.cancel();
    _state = ItemListState(
      loading: true,
      items: const <ItemStockInfo>[],
      hasMore: false,
      categories: _state.categories,
      categoryId: _state.categoryId,
      query: query,
      baseCurrency: _state.baseCurrency,
    );
    notifyListeners();
    await _loadFirstPage();
  }

  /// اختيار فئة التصفية (null = الكل).
  Future<void> setCategory(int? categoryId) async {
    if (categoryId == _state.categoryId && !_state.loading) return;
    _state = ItemListState(
      loading: true,
      items: const <ItemStockInfo>[],
      hasMore: false,
      categories: _state.categories,
      categoryId: categoryId,
      query: _state.query,
      baseCurrency: _state.baseCurrency,
    );
    notifyListeners();
    await _loadFirstPage();
  }

  /// إعادة التحميل الكاملة (الفئات + عملة القاعدة + الصفحة الأولى).
  Future<void> load() async {
    _state = ItemListState(
      loading: true,
      items: const <ItemStockInfo>[],
      hasMore: false,
      categories: const <ItemCategory>[],
      categoryId: _state.categoryId,
      query: _state.query,
    );
    notifyListeners();
    try {
      final base = await _companies.findBaseCurrency();
      _state = ItemListState(
        loading: _state.loading,
        items: _state.items,
        hasMore: _state.hasMore,
        categories: await _items.listCategories(),
        categoryId: _state.categoryId,
        query: _state.query,
        baseCurrency: base,
      );
    } catch (error) {
      _state = ItemListState(
        loading: false,
        items: const <ItemStockInfo>[],
        hasMore: false,
        categories: _state.categories,
        categoryId: _state.categoryId,
        query: _state.query,
        error: error,
      );
      notifyListeners();
      return;
    }
    await _loadFirstPage();
  }

  /// تحميل الصفحة التالية (زر «المزيد»).
  Future<void> loadMore() async {
    if (_loadingMore || !_state.hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final fetched = await _items.searchItems(
        _state.query,
        categoryId: _state.categoryId,
        limit: itemsPageSize + 1,
        offset: _state.items.length,
        currencyIdForPrice: _state.baseCurrency?.id,
      );
      final hasMore = fetched.length > itemsPageSize;
      _state = ItemListState(
        loading: false,
        items: [..._state.items, ...fetched.take(itemsPageSize)],
        hasMore: hasMore,
        categories: _state.categories,
        categoryId: _state.categoryId,
        query: _state.query,
        baseCurrency: _state.baseCurrency,
      );
    } catch (_) {
      // فشل «المزيد» لا يمسح المحمّل — المحاولة تبقى متاحة.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadFirstPage() async {
    try {
      final fetched = await _items.searchItems(
        _state.query,
        categoryId: _state.categoryId,
        limit: itemsPageSize + 1,
        currencyIdForPrice: _state.baseCurrency?.id,
      );
      final hasMore = fetched.length > itemsPageSize;
      _state = ItemListState(
        loading: false,
        items: fetched.take(itemsPageSize).toList(),
        hasMore: hasMore,
        categories: _state.categories,
        categoryId: _state.categoryId,
        query: _state.query,
        baseCurrency: _state.baseCurrency,
      );
    } catch (error) {
      _state = ItemListState(
        loading: false,
        items: const <ItemStockInfo>[],
        hasMore: false,
        categories: _state.categories,
        categoryId: _state.categoryId,
        query: _state.query,
        baseCurrency: _state.baseCurrency,
        error: error,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
