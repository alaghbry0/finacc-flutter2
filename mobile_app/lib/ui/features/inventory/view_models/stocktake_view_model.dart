/// نموذج شاشة الجرد الفعلي (FR-01-08 — الشريحة 10): كشف الجرد للمخزن
/// المحدد (دفتري + مقيس) مع الملخص الحي، والعدّ الجزئي جائز — البنود
/// غير المعدودة **تُتجاوز** من الترحيل (لا سطر ولا حركة ولا مساس
/// برصيدها — قرار موثق: إدخال فارغ = «لم يُعدّ بعد»)، والاعتماد يمرّ
/// عبر المستودع الذرّي ثم يُعيد تحميل الكشف نظيفاً. المنطق كله هنا —
/// الشاشة عرض وإدخال.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/stocktake_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/company.dart' show Currency;

/// ناتج اعتماد الجرد — بيانات حوار النجاح (لقطة ما قبل الترحيل).
class StocktakePosted {
  const StocktakePosted({
    required this.id,
    required this.countedAt,
    required this.diffsCount,
    required this.netDiffValue,
  });

  /// معرّف الجرد المُرحَّل.
  final int id;

  /// تاريخ العدّ الموقَّع (بتاريخ المستخدم).
  final DateTime countedAt;

  /// عدد أسطر الفروقات.
  final int diffsCount;

  /// صافي أثر الجرد المالي (بالعملة الأساسية).
  final double netDiffValue;
}

/// حالة شاشة الجرد — skeleton/error/ready بنمط المستودعات القائمة.
class StocktakeState {
  const StocktakeState({
    required this.loading,
    required this.warehouses,
    required this.warehouseId,
    required this.warehouseName,
    required this.lines,
    required this.history,
    required this.countedBy,
    required this.countedAt,
    required this.notes,
    required this.query,
    required this.baseCurrencyCode,
    required this.baseCurrencyDecimals,
    required this.posting,
    this.error,
  });

  /// الحالة الابتدائية — تحميل أولي.
  static const StocktakeState initial = StocktakeState(
    loading: true,
    warehouses: <StocktakeWarehouse>[],
    warehouseId: null,
    warehouseName: null,
    lines: <StocktakeLineDraft>[],
    history: <StocktakeHistoryRow>[],
    countedBy: '',
    countedAt: null,
    notes: '',
    query: '',
    baseCurrencyCode: '',
    baseCurrencyDecimals: 2,
    posting: false,
  );

  final bool loading;

  /// المخازن غير المؤرشفة (الافتراضي أولاً) — لاختيار «المخزن المحدد».
  final List<StocktakeWarehouse> warehouses;

  /// المخزن الجاري جرده (null قبل الحل أو عند غياب المخازن).
  final int? warehouseId;

  /// اسم المخزن الجاري جرده (للبطاقة البطلة).
  final String? warehouseName;

  /// أسطر الكشف (كل الأصناف — العدّ فيها اختياري).
  final List<StocktakeLineDraft> lines;

  /// سجل عمليات الجرد الأخيرة للمخزن.
  final List<StocktakeHistoryRow> history;

  /// اسم الجانِد (التوقيع — مُعبَّأ باسم المدير).
  final String countedBy;

  /// تاريخ العدّ (null = اليوم افتراضياً عند العرض).
  final DateTime? countedAt;

  /// ملاحظات الجرد (اختيارية).
  final String notes;

  /// بحث الاسم على أسطر الكشف (تصفية عرضية صرفة).
  final String query;

  /// رمز العملة الأساسية (قيم الفروقات بها).
  final String baseCurrencyCode;

  /// منازل العملة الأساسية (YER = 0).
  final int baseCurrencyDecimals;

  /// جارٍ ترحيل الجرد؟ (يعطّل الإدخال والاعتماد).
  final bool posting;

  /// خطأ التحميل (لا أخطاء الإجراءات — تلك تُعاد Result من post).
  final Object? error;

  /// الأسطر الظاهرة بعد تطبيق بحث الاسم.
  List<StocktakeLineDraft> get visibleLines {
    final q = query.trim();
    if (q.isEmpty) return lines;
    return lines.where((line) => line.name.contains(q)).toList();
  }

  /// ملخص الجرد الجاري (القيم بالعملة الأساسية).
  StocktakeSummary get summary => StocktakeSummary.of(lines);
}

/// نموذج عرض الجرد الفعلي.
///
/// **بقاء المسودة (P0-1a)**: `load()` لا يفرغ الأسطر بعد الآن — إعادة
/// التحميل لنفس المخزن (تنشيط المسار/عودة من القفل) تُرحّل الأعداد
/// المُدخلة والتوقيع والملاحظات إلى الأسطر الجديدة وتحدّث البيانات
/// المرجعية فقط (الأسماء/الدفتري/تكلفة اللقطة)، بينما تبديل المخزن
/// يفتح كشفاً نظيفاً (العدّ لا ينتقل بين المخازن — قرار موثّق).
class StocktakeViewModel extends ChangeNotifier {
  StocktakeViewModel({
    required StocktakeRepository stocktakeRepo,
    required UserRepository userRepo,
    required CompanyRepository companyRepo,
    int? warehouseId,
  }) : _stocktakes = stocktakeRepo,
       _users = userRepo,
       _companies = companyRepo,
       _preferredWarehouseId = warehouseId;

  final StocktakeRepository _stocktakes;
  final UserRepository _users;
  final CompanyRepository _companies;

  /// المخزن المطلوب من المنادي (null = الافتراضي).
  final int? _preferredWarehouseId;

  StocktakeState _state = StocktakeState.initial;
  StocktakeState get state => _state;

  int? _userId;

  /// المخزن المختار حالياً (يبدأ من المطلوب من المنادي ثم قابل للتبديل).
  int? _selectedWarehouseId;

  /// طلب تبديل مخزن معلّق — التحميل القادم يفتح كشفاً نظيفاً (العدّ لا
  /// ينتقل بين المخازن) بينما إعادة تحميل نفس المخزن تحفظ المسودة.
  bool _switchingWarehouse = false;

  /// طلب مسودة نظيفة بعد ترحيل الجرد — الأعداد المُرحَّلة لا تُرحَّل
  /// للكشف التالي (كانت مطبّقة على الأرصدة).
  bool _freshDraftPending = false;

  /// معرّف المستخدم المنفّذ (created_by وقيد التدقيق).
  int? get userId => _userId;

  /// التحميل الكامل: المخازن + المستخدم + العملة الأساسية + كشف الجرد
  /// + السجل. المخزن: المطلوب صراحة، وإلا الافتراضي، وإلا الأول.
  /// المسودة تُحفظ لنفس المخزن (رأس الملف) — والكشف القائم يبقى ظاهراً
  /// أثناء التحديث بلا وميض skeleton.
  Future<void> load() async {
    final resetDraft = _switchingWarehouse || _freshDraftPending;
    _switchingWarehouse = false;
    _freshDraftPending = false;
    final previous = _state;
    // الكشف القائم يبقى معروضاً أثناء التحديث ما لم نبدّل المخزن أو
    // نفتح مسودة نظيفة بعد الترحيل — لا وميض skeleton عند كل تنشيط.
    final keepVisible = !resetDraft && previous.lines.isNotEmpty;
    _state = StocktakeState(
      loading: !keepVisible,
      warehouses: keepVisible
          ? previous.warehouses
          : const <StocktakeWarehouse>[],
      warehouseId: keepVisible ? previous.warehouseId : null,
      warehouseName: keepVisible ? previous.warehouseName : null,
      lines: keepVisible ? previous.lines : const <StocktakeLineDraft>[],
      history: keepVisible ? previous.history : const <StocktakeHistoryRow>[],
      countedBy: previous.countedBy,
      countedAt: previous.countedAt,
      notes: previous.notes,
      query: previous.query,
      baseCurrencyCode: previous.baseCurrencyCode,
      baseCurrencyDecimals: previous.baseCurrencyDecimals,
      posting: false,
    );
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _stocktakes.warehouses(),
        _users.adminDisplayName(),
        _companies.findAdminUserId(),
        _companies.findBaseCurrency(),
      ]);
      final warehouses = results[0]! as List<StocktakeWarehouse>;
      final userName = results[1] as String?;
      final adminId = results[2] as int?;
      final baseCurrency = results[3] as Currency?;
      _userId = adminId;

      final warehouse = _resolveWarehouse(warehouses);
      // نفس المخزن (بلا طلب تصفير) → الأعداد المُدخلة والتوقيع والملاحظات
      // تُرحّل إلى الأسطر الجديدة (تحديث مرجعي فقط — لا تصفير للمسودة).
      final sameWarehouse =
          !resetDraft &&
          warehouse != null &&
          warehouse.id == previous.warehouseId;
      final carriedCounts = sameWarehouse
          ? <int, double>{
              for (final line in previous.lines)
                if (line.countedQty != null) line.productId: line.countedQty!,
            }
          : const <int, double>{};
      final loaded = warehouse == null
          ? const <StocktakeLineDraft>[]
          : await _stocktakes.loadDraft(warehouse.id);
      final lines = [
        for (final line in loaded)
          carriedCounts.containsKey(line.productId)
              ? line.withCounted(carriedCounts[line.productId])
              : line,
      ];
      final historyRows = warehouse == null
          ? const <StocktakeHistoryRow>[]
          : await _stocktakes.history(warehouseId: warehouse.id);

      final currency = baseCurrency;
      _state = StocktakeState(
        loading: false,
        warehouses: warehouses,
        warehouseId: warehouse?.id,
        warehouseName: warehouse?.name,
        lines: lines,
        history: historyRows,
        countedBy: sameWarehouse ? previous.countedBy : (userName ?? ''),
        countedAt: sameWarehouse ? previous.countedAt : DateTime.now(),
        notes: sameWarehouse ? previous.notes : '',
        query: sameWarehouse ? previous.query : '',
        baseCurrencyCode: currency?.code ?? '',
        baseCurrencyDecimals: currency?.decimals ?? 2,
        posting: false,
      );
    } catch (error) {
      // فشل التحديث فوق كشف قائم: المسودة تبقى محفوظة في الحالة (تظهر
      // شاشة الخطأ مع إعادة المحاولة — والمسودة تُرحَّل عند نجاحها). فشل
      // التحميل الأول يُعرض نظيفاً كما كان.
      _state = keepVisible
          ? StocktakeState(
              loading: false,
              warehouses: previous.warehouses,
              warehouseId: previous.warehouseId,
              warehouseName: previous.warehouseName,
              lines: previous.lines,
              history: previous.history,
              countedBy: previous.countedBy,
              countedAt: previous.countedAt,
              notes: previous.notes,
              query: previous.query,
              baseCurrencyCode: previous.baseCurrencyCode,
              baseCurrencyDecimals: previous.baseCurrencyDecimals,
              posting: false,
              error: error,
            )
          : StocktakeState(
              loading: false,
              warehouses: const <StocktakeWarehouse>[],
              warehouseId: null,
              warehouseName: null,
              lines: const <StocktakeLineDraft>[],
              history: const <StocktakeHistoryRow>[],
              countedBy: previous.countedBy,
              countedAt: previous.countedAt ?? DateTime.now(),
              notes: previous.notes,
              query: previous.query,
              baseCurrencyCode: previous.baseCurrencyCode,
              baseCurrencyDecimals: previous.baseCurrencyDecimals,
              posting: false,
              error: error,
            );
    }
    notifyListeners();
  }

  /// يبدّل المخزن المجروف — كشف جديد نظيف (العدّ لا ينتقل بين المخازن).
  Future<void> setWarehouse(int warehouseId) async {
    if (_state.warehouseId == warehouseId || _state.loading) return;
    _selectedWarehouseId = warehouseId;
    _switchingWarehouse = true;
    await load();
  }

  /// يضبط الرصيد الفعلي لسطر — `null` يمسح العدّ (غير معدود).
  /// القيم السالبة/غير الصالحة تُتجاهل (حراسة إدخال).
  void setCounted(int productId, double? qty) {
    if (qty != null && (qty.isNaN || qty.isInfinite || qty < 0)) return;
    final lines = <StocktakeLineDraft>[];
    var changed = false;
    for (final line in _state.lines) {
      if (line.productId == productId) {
        lines.add(line.withCounted(qty));
        changed = true;
      } else {
        lines.add(line);
      }
    }
    if (!changed) return;
    _state = _copy(lines: lines);
    notifyListeners();
  }

  /// اسم الجانِد (التوقيع).
  void setCountedBy(String value) {
    if (value == _state.countedBy) return;
    _state = _copy(countedBy: value);
    notifyListeners();
  }

  /// تاريخ العدّ (بتاريخ المستخدم).
  void setCountedAt(DateTime value) {
    if (value == _state.countedAt) return;
    _state = _copy(countedAt: value);
    notifyListeners();
  }

  /// ملاحظات الجرد.
  void setNotes(String value) {
    if (value == _state.notes) return;
    _state = _copy(notes: value);
    notifyListeners();
  }

  /// بحث الاسم — تصفية عرضية فورية بلا استعلام.
  void setQuery(String value) {
    if (value == _state.query) return;
    _state = _copy(query: value);
    notifyListeners();
  }

  /// هل يجوز الاعتماد؟ — بند واحد معدود على الأقل + اسم جانِد موقَّع +
  /// لا تحميل ولا ترحيل جارٍ ولا خطأ. البنود غير المعدودة تُتجاوز
  /// (العدّ الجزئي جائز — رأس الملف).
  bool get canPost =>
      !_state.loading &&
      !_state.posting &&
      _state.error == null &&
      _state.warehouseId != null &&
      _state.lines.isNotEmpty &&
      _state.summary.countedCount >= 1 &&
      _state.countedBy.trim().isNotEmpty;

  /// **يعتمد الجرد**: يمرّر البنود المعدودة حصراً للمستودع الذرّي ثم
  /// يعيد تحميل الكشف نظيفاً. يعيد [Ok] بملخص النجاح أو [Err] عربياً.
  Future<Result<StocktakePosted, String>> post() async {
    if (_state.posting) {
      return const Err('جارٍ ترحيل الجرد بالفعل — انتظر اكتماله.');
    }
    final warehouseId = _state.warehouseId;
    if (warehouseId == null) {
      return const Err('لا مخزن محدد — اختر المخزن أولاً.');
    }
    final counter = _state.countedBy.trim();
    if (counter.isEmpty) {
      return const Err('اسم الجانِد مطلوب — الجرد يُوقَّع باسمه.');
    }
    final counted = [
      for (final line in _state.lines)
        if (line.countedQty != null)
          (line.productId, line.bookQty, line.countedQty!),
    ];
    if (counted.isEmpty) {
      return const Err('عدّ صنفاً واحداً على الأقل قبل اعتماد الجرد.');
    }

    // لقطة النجاح تُلتقط قبل الترحيل (نفس أرقام المراجعة التي رآها
    // المستخدم — والقيم المخزَّنة حتمية داخل معاملة المستودع).
    final summary = _state.summary;
    final countedAt = _state.countedAt ?? DateTime.now();
    final notes = _state.notes;

    _state = _copy(posting: true);
    notifyListeners();
    try {
      final id = await _stocktakes.post(
        warehouseId: warehouseId,
        countedAt: countedAt,
        countedBy: counter,
        notes: notes,
        lines: counted,
        userId: _userId ?? 0,
      );
      // الكشف التالي نظيف — الأعداد المُرحّلة طُبّقت على الأرصدة.
      _freshDraftPending = true;
      await load();
      return Ok<StocktakePosted, String>(
        StocktakePosted(
          id: id,
          countedAt: countedAt,
          diffsCount: summary.diffsCount,
          netDiffValue: summary.netDiffValue,
        ),
      );
    } catch (error) {
      // فشل الترحيل: يبقى الكشف كما هو (العدّ محفوظ) — المستخدم يعيد
      // المحاولة بعد معالجة السبب.
      _state = _copy(posting: false);
      notifyListeners();
      return Err<StocktakePosted, String>(error.toString());
    }
  }

  // ── السباكة الداخلية ────────────────────────────────────────────────

  /// يختار مخزن الجرد: المختار حالياً (أو المطلوب من المنادي)، وإلا
  /// الافتراضي، وإلا الأول.
  StocktakeWarehouse? _resolveWarehouse(List<StocktakeWarehouse> warehouses) {
    if (warehouses.isEmpty) return null;
    final preferred = _selectedWarehouseId ?? _preferredWarehouseId;
    if (preferred != null) {
      for (final warehouse in warehouses) {
        if (warehouse.id == preferred) return warehouse;
      }
    }
    for (final warehouse in warehouses) {
      if (warehouse.isDefault) return warehouse;
    }
    return warehouses.first;
  }

  StocktakeState _copy({
    List<StocktakeLineDraft>? lines,
    String? countedBy,
    DateTime? countedAt,
    String? notes,
    String? query,
    bool? posting,
  }) {
    return StocktakeState(
      loading: _state.loading,
      warehouses: _state.warehouses,
      warehouseId: _state.warehouseId,
      warehouseName: _state.warehouseName,
      lines: lines ?? _state.lines,
      history: _state.history,
      countedBy: countedBy ?? _state.countedBy,
      countedAt: countedAt ?? _state.countedAt,
      notes: notes ?? _state.notes,
      query: query ?? _state.query,
      baseCurrencyCode: _state.baseCurrencyCode,
      baseCurrencyDecimals: _state.baseCurrencyDecimals,
      posting: posting ?? _state.posting,
      error: _state.error,
    );
  }
}
