/// نموذج عرض نموذج الصنف (إضافة/تعديل) — FR-01-01/02/16:
/// توليد EAN-13 بمعاينة، أسعار بكل العملات النشطة، الصنف الخدمي بلا
/// حقول مخزون، والفئات/الوحدات بإضافة فورية من الحوار.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/item_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/item.dart';
import '../../../../domain/services/barcode_ean13.dart';

/// أخطاء التحقق القابلة للترجمة (تُعرض فوق زر الحفظ).
enum ItemFormError {
  /// الاسم فارغ.
  nameRequired,

  /// سعر التكلفة غير صحيح.
  costInvalid,

  /// حد إعادة الطلب غير صحيح.
  minStockInvalid,

  /// الكمية الافتتاحية غير صحيحة.
  openingQtyInvalid,

  /// أحد أسعار البيع غير صحيح.
  priceInvalid,

  /// لا مخزن افتراضي (تعذر الحفظ).
  noWarehouse,

  /// لا مستخدم مدير (تعذر الحفظ).
  noUser,
}

/// حالة النموذج — قيم الحقول كنصوص كما يكتبها المستخدم.
class ItemFormState {
  const ItemFormState({
    required this.loading,
    required this.editMode,
    this.original,
    required this.currencies,
    required this.categories,
    required this.units,
    required this.priceTexts,
    this.warehouseId,
    this.userId,
    this.name = '',
    this.barcode = '',
    this.categoryId,
    this.unitId,
    this.costText = '',
    this.minStockText = '',
    this.openingQtyText = '',
    this.notes = '',
    this.isService = false,
    this.trackBatches = false,
    this.saving = false,
    this.validationError,
    this.repoError,
    this.saved = false,
    this.loadError,
  });

  final bool loading;

  /// وضع التعديل (يخفي الكمية الافتتاحية ويعرض ملاحظة الشرح).
  final bool editMode;

  /// الصنف الأصلي في وضع التعديل.
  final Item? original;

  /// العملات النشطة — الأساسية أولاً (ترتيب المستودع).
  final List<Currency> currencies;

  final List<ItemCategory> categories;
  final List<ItemUnit> units;

  /// نص سعر البيع لكل عملة (معرّف العملة → النص).
  final Map<int, String> priceTexts;

  final int? warehouseId;
  final int? userId;

  final String name;
  final String barcode;
  final int? categoryId;
  final int? unitId;
  final String costText;
  final String minStockText;
  final String openingQtyText;
  final String notes;
  final bool isService;
  final bool trackBatches;

  final bool saving;
  final ItemFormError? validationError;

  /// خطأ المستودع (عربي جاهز — SnackBar).
  final String? repoError;

  /// نجاح الحفظ — الشاشة تُغلق بناءً عليه.
  final bool saved;

  /// فشل تحميل بيانات النموذج.
  final Object? loadError;

  Currency? get baseCurrency => currencies.isEmpty ? null : currencies.first;

  static const ItemFormState initial = ItemFormState(
    loading: true,
    editMode: false,
    currencies: <Currency>[],
    categories: <ItemCategory>[],
    units: <ItemUnit>[],
    priceTexts: <int, String>{},
  );
}

class ItemFormViewModel extends ChangeNotifier {
  ItemFormViewModel({
    required ItemRepository itemRepo,
    required CompanyRepository companyRepo,
    Item? editItem,
    int? editId,
  }) : _items = itemRepo,
       _companies = companyRepo,
       _editItemId = editItem?.id ?? editId,
       _initialOriginal = editItem;

  final ItemRepository _items;
  final CompanyRepository _companies;

  /// معرّف الصنف في وضع التعديل (من الكائن أو مباشرة).
  final int? _editItemId;

  /// الصنف الأصلي إن أُعطي مباشرة (تفاصيله الكاملة تُحمَّل عبر المعرّف).
  final Item? _initialOriginal;

  ItemFormState _state = ItemFormState.initial;
  ItemFormState get state => _state;

  /// تحميل بيانات النموذج: العملات والفئات والوحدات والمخزن والمستخدم
  /// (+ التفاصيل الكاملة في وضع التعديل — تعبئة مسبقة بالأسعار).
  Future<void> load() async {
    final editId = _editItemId;
    final editMode = editId != null;
    _state = ItemFormState(
      loading: true,
      editMode: editMode,
      currencies: _state.currencies,
      categories: _state.categories,
      units: _state.units,
      priceTexts: _state.priceTexts,
    );
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _companies.listActiveCurrencies(),
        _items.listCategories(),
        _items.listUnits(),
        _companies.findDefaultWarehouseId(),
        _companies.findAdminUserId(),
        if (editId != null) _items.detail(editId),
      ]);
      final currencies = results[0] as List<Currency>;
      final categories = results[1] as List<ItemCategory>;
      final units = results[2] as List<ItemUnit>;
      final warehouseId = results[3] as int?;
      final userId = results[4] as int?;
      final detail = editId == null ? null : results[5] as ItemFullDetail?;
      final item = detail?.item ?? _initialOriginal;

      if (editMode && item != null) {
        // تعبئة مسبقة كاملة — أسعار التجزئة من التفاصيل (بلا كمية افتتاحية).
        final prices = <int, String>{
          for (final line in detail?.prices ?? const <ItemPriceLine>[])
            if (line.priceLevel == 'retail')
              line.currencyId: _numToText(line.price),
        };
        _state = ItemFormState(
          loading: false,
          editMode: true,
          original: item,
          currencies: currencies,
          categories: categories,
          units: units,
          priceTexts: prices,
          warehouseId: warehouseId,
          userId: userId,
          name: item.name,
          barcode: item.barcode ?? '',
          categoryId: item.categoryId,
          unitId: item.unitId,
          costText: _numToText(item.costPrice),
          minStockText: _numToText(item.minStock),
          notes: item.notes ?? '',
          isService: item.isService,
          trackBatches: item.trackBatches,
        );
      } else {
        _state = ItemFormState(
          loading: false,
          editMode: editMode,
          currencies: currencies,
          categories: categories,
          units: units,
          priceTexts: const <int, String>{},
          warehouseId: warehouseId,
          userId: userId,
        );
      }
    } catch (error) {
      _state = ItemFormState(
        loading: false,
        editMode: editMode,
        currencies: _state.currencies,
        categories: _state.categories,
        units: _state.units,
        priceTexts: _state.priceTexts,
        loadError: error,
      );
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────
  // محدِّثات الحقول
  // ─────────────────────────────────────────────────────────────────────

  void setName(String value) => _mutate(name: value);

  void setBarcode(String value) => _mutate(barcode: value.trim());

  void setCategory(int? value) => _mutate(categoryId: value);

  void setUnit(int? value) => _mutate(unitId: value);

  void setCostText(String value) => _mutate(costText: value);

  void setMinStockText(String value) => _mutate(minStockText: value);

  void setOpeningQtyText(String value) => _mutate(openingQtyText: value);

  void setNotes(String value) => _mutate(notes: value);

  void setPriceText(int currencyId, String value) {
    _mutate(priceTexts: {..._state.priceTexts, currencyId: value});
  }

  /// الصنف الخدمي يخفي حقول المخزون (FR-01-16) ويلغي تتبع الدفعات.
  void setIsService(bool value) => _mutate(
    isService: value,
    trackBatches: value ? false : _state.trackBatches,
  );

  void setTrackBatches(bool value) => _mutate(trackBatches: value);

  /// توليد باركود EAN-13 داخلي (نطاق المتجر 200–299 — FR-01-02).
  void generateBarcode() {
    _mutate(barcode: const Ean13Generator().generate());
  }

  // ─────────────────────────────────────────────────────────────────────
  // إضافة فئة/وحدة فورية من الحوار
  // ─────────────────────────────────────────────────────────────────────

  /// ينشئ فئة جذرية وينتقيها — يعيد خطأ المستودع العربي أو null.
  Future<String?> addCategory(String name) async {
    final result = await _items.createCategory(name);
    switch (result) {
      case final Ok<int, String> ok:
        final categories = await _items.listCategories();
        _mutate(categories: categories, categoryId: ok.value);
        return null;
      case final Err<int, String> err:
        return err.error;
    }
  }

  /// ينشئ وحدة (بمعامل تحويل) وينتقيها — يعيد خطأ المستودع أو null.
  Future<String?> addUnit(String name, {double factor = 1}) async {
    final result = await _items.createUnit(name, factor: factor);
    switch (result) {
      case final Ok<int, String> ok:
        final units = await _items.listUnits();
        _mutate(units: units, unitId: ok.value);
        return null;
      case final Err<int, String> err:
        return err.error;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // الحفظ
  // ─────────────────────────────────────────────────────────────────────

  /// يتحقق ثم ينفّذ الإنشاء/التعديل الذرّي — يعيد true عند النجاح.
  Future<bool> save() async {
    if (_state.saving || _state.saved) return false;

    final name = _state.name.trim();
    if (name.isEmpty) {
      _mutate(validationError: ItemFormError.nameRequired);
      return false;
    }
    final cost = double.tryParse(_state.costText.trim());
    if (_state.costText.trim().isEmpty || cost == null || cost < 0) {
      _mutate(validationError: ItemFormError.costInvalid);
      return false;
    }
    final minStock = _parseOptional(_state.minStockText);
    if (minStock == null || minStock < 0) {
      _mutate(validationError: ItemFormError.minStockInvalid);
      return false;
    }
    final openingQty = _parseOptional(_state.openingQtyText);
    if (openingQty == null || openingQty < 0) {
      _mutate(validationError: ItemFormError.openingQtyInvalid);
      return false;
    }

    final prices = <ItemPrice>[];
    for (final currency in _state.currencies) {
      final text = _state.priceTexts[currency.id]?.trim() ?? '';
      if (text.isEmpty) continue;
      final price = double.tryParse(text);
      if (price == null || price < 0) {
        _mutate(validationError: ItemFormError.priceInvalid);
        return false;
      }
      prices.add(ItemPrice(currencyId: currency.id, price: price));
    }

    if (!_state.editMode && _state.warehouseId == null) {
      _mutate(validationError: ItemFormError.noWarehouse);
      return false;
    }
    if (_state.userId == null) {
      _mutate(validationError: ItemFormError.noUser);
      return false;
    }

    final draft = ItemDraft(
      name: name,
      barcode: _state.barcode.trim().isEmpty ? null : _state.barcode.trim(),
      categoryId: _state.categoryId,
      unitId: _state.unitId,
      costPrice: cost,
      minStock: minStock,
      isService: _state.isService,
      trackBatches: _state.trackBatches,
      notes: _state.notes.trim().isEmpty ? null : _state.notes.trim(),
      openingQty: _state.editMode ? 0 : openingQty,
      prices: prices,
    );

    _mutate(saving: true, clearValidationError: true, clearRepoError: true);
    final result = _state.editMode
        ? await _items.updateItem(
            _state.original!.id,
            draft,
            userId: _state.userId!,
          )
        : await _items.createItem(
            draft,
            warehouseId: _state.warehouseId!,
            userId: _state.userId!,
          );
    // (create يعيد Result<int> وupdate يعيد Result<Item> — يوحّدهما التحليل
    // إلى Result<Object>؛ يكفي التمييز بين Ok/Err دون تخصيص النوع).
    switch (result) {
      case Ok<Object, String>():
        _mutate(saving: false, saved: true);
        return true;
      case final Err<Object, String> err:
        _mutate(saving: false, repoError: err.error);
        return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // مساعدات خاصة
  // ─────────────────────────────────────────────────────────────────────

  /// يعدّل حقولاً محددة ويبقي البقية — ويمسح أي خطأ تحقق سابق.
  void _mutate({
    String? name,
    String? barcode,
    int? categoryId,
    bool clearCategory = false,
    int? unitId,
    bool clearUnit = false,
    String? costText,
    String? minStockText,
    String? openingQtyText,
    String? notes,
    Map<int, String>? priceTexts,
    bool? isService,
    bool? trackBatches,
    List<ItemCategory>? categories,
    List<ItemUnit>? units,
    bool? saving,
    ItemFormError? validationError,
    bool clearValidationError = false,
    String? repoError,
    bool clearRepoError = false,
    bool? saved,
  }) {
    _state = ItemFormState(
      loading: _state.loading,
      editMode: _state.editMode,
      original: _state.original,
      currencies: _state.currencies,
      categories: categories ?? _state.categories,
      units: units ?? _state.units,
      priceTexts: priceTexts ?? _state.priceTexts,
      warehouseId: _state.warehouseId,
      userId: _state.userId,
      name: name ?? _state.name,
      barcode: barcode ?? _state.barcode,
      categoryId: clearCategory ? null : (categoryId ?? _state.categoryId),
      unitId: clearUnit ? null : (unitId ?? _state.unitId),
      costText: costText ?? _state.costText,
      minStockText: minStockText ?? _state.minStockText,
      openingQtyText: openingQtyText ?? _state.openingQtyText,
      notes: notes ?? _state.notes,
      isService: isService ?? _state.isService,
      trackBatches: trackBatches ?? _state.trackBatches,
      saving: saving ?? _state.saving,
      validationError: clearValidationError
          ? null
          : (validationError ?? _state.validationError),
      repoError: clearRepoError ? null : (repoError ?? _state.repoError),
      saved: saved ?? _state.saved,
      loadError: _state.loadError,
    );
    notifyListeners();
  }

  /// يقرأ رقماً اختيارياً — الفارغ = 0، وغير الرقمي = null (خطأ).
  static double? _parseOptional(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return double.tryParse(trimmed);
  }

  /// نص عرض للرقم (بلا كسور زائدة) — لتعبئة الحقول مسبقاً.
  static String _numToText(double value) {
    if (value == value.truncateToDouble() && value.abs() < 1e15) {
      return value.truncate().toString();
    }
    return value.toString();
  }
}
