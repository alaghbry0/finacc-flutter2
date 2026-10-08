/// نماذج عرض تقارير الحركة والمبيعات (الشريحة 10 — FR-09-03/04/06):
/// ثلاثة نماذج، واحد لكل شاشة، بنمط `profit_report_view_model` نفسه:
/// فترة مسبقة/مخصصة عبر `PeriodPresetBar`، حالة ثابتة، سحب للتحديث
/// يُبقي التقرير القديم، وعملة الأساس (رمزها ومنازلها) مرة واحدة
/// يُخفق حلّها دون إسقاط التقرير.
///
/// - `ItemMovementViewModel`: صنف محدد ([productId]) + فترة — لا تقرير
///   قبل اختيار الصنف (حالة «اختر صنفاً»).
/// - `StockSummaryViewModel`: فترة فقط.
/// - `SalesByViewModel`: فترة + بعد التجميع (عميل/فئة/صنف/يوم).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/movement_reports_repository.dart';
import '../views/widgets/period_preset_bar.dart';

/// مخبوء عملة الأساس (رمز + منازل) — مشترك للنماذج الثلاثة. يُحل مرة
/// واحدة؛ الفشل لا يُسقط التقرير (عرض بمنازل 2 وبلا رمز).
class _BaseCurrencyCache {
  _BaseCurrencyCache(this._repo);

  final CompanyRepository? _repo;

  String code = '';
  int decimals = 2;
  bool resolved = false;

  Future<void> resolve() async {
    if (resolved) return;
    final repo = _repo;
    if (repo != null) {
      try {
        final currency = await repo.findBaseCurrency();
        if (currency != null) {
          code = currency.code;
          decimals = currency.decimals;
        }
      } catch (_) {
        // عرض بلا رمز عملة — التقرير نفسه لا يتأثر.
      }
    }
    resolved = true;
  }
}

// ─────────────────────────────────────────────────────────────────────
// FR-09-03 — حركة صنف
// ─────────────────────────────────────────────────────────────────────

/// حالة شاشة حركة صنف.
class ItemMovementState {
  const ItemMovementState({
    required this.loading,
    this.error,
    this.productId,
    this.period = ReportPeriod.month,
    this.from,
    this.to,
    this.report,
    this.currencyCode = '',
    this.decimals = 2,
  });

  final bool loading;
  final Object? error;

  /// الصنف المحدد (null = لم يُختر بعد — بطاقة الاختيار البطلة).
  final int? productId;

  final ReportPeriod period;
  final DateTime? from;
  final DateTime? to;

  /// التقرير المحمّل (قديم قد يبقى أثناء التحديث).
  final ItemMovementReport? report;

  final String currencyCode;
  final int decimals;

  /// لا صنف محدد — الواجهة تعرض بطاقة الاختيار (ليست حالة فراغ).
  bool get needsProduct => !loading && error == null && productId == null;

  /// صنف محدد بلا أي حركة في الفترة (احتفالية — رأس البطاقة يبقى).
  bool get isEmpty =>
      !loading &&
      error == null &&
      productId != null &&
      report != null &&
      report!.rows.isEmpty;
}

/// نموذج عرض حركة صنف — التحميل مشروط بوجود الصنف.
class ItemMovementViewModel extends ChangeNotifier {
  ItemMovementViewModel({
    required MovementReportsRepository movementRepo,
    CompanyRepository? companyRepo,
    int? productId,
    DateTime? reference,
    ReportPeriod initialPeriod = ReportPeriod.month,
  }) : _repo = movementRepo,
       _currency = _BaseCurrencyCache(companyRepo),
       _now = reference,
       _state = ItemMovementState(
         loading: productId != null,
         productId: productId,
         period: initialPeriod,
       );

  final MovementReportsRepository _repo;
  final _BaseCurrencyCache _currency;

  /// لحظة «الآن» (قابلة للحقن — الاختبارات).
  final DateTime? _now;

  ItemMovementState _state;
  ItemMovementState get state => _state;

  String get currencyCode => _currency.code;
  int get decimals => _currency.decimals;

  DateTime _nowValue() => _now ?? DateTime.now();

  /// التحميل الأول — يهيئ نطاق الفترة (الشهر افتراضياً) ويجلب إن وجد
  /// صنف محدد، وإلا يستقر في حالة «اختر صنفاً».
  Future<void> load() => _load(keepReport: false);

  /// تحديث (سحب للأسفل) — يُبقي التقرير القديم ظاهراً أثناء الجلب.
  Future<void> refresh() => _load(keepReport: true);

  /// اختيار صنف (من نافذة المنتقي) — يحمّل حركته على الفترة الجارية.
  Future<void> setProduct(int productId) async {
    if (productId == _state.productId && _state.report != null) return;
    _state = ItemMovementState(
      loading: true,
      productId: productId,
      period: _state.period,
      from: _state.from,
      to: _state.to,
      currencyCode: _currency.code,
      decimals: _currency.decimals,
    );
    notifyListeners();
    await _ensureRangeThenFetch();
  }

  /// فترة مسبقة (custom يُعالج عبر [setCustomRange] بعد منتقي التاريخ
  /// الذي يفتحه الشريط بنفسه — نفس اصطلاح نموذج الأرباح).
  Future<void> setPeriod(ReportPeriod period) async {
    if (period == ReportPeriod.custom) return;
    if (period == _state.period && _state.from != null) return;
    final range = computePeriodRange(period, _nowValue());
    await _apply(
      period: period,
      from: range.start,
      to: range.end,
      keepReport: false,
    );
  }

  /// مدى مخصص من منتقي التاريخ.
  Future<void> setCustomRange(DateTime from, DateTime to) async {
    await _apply(
      period: ReportPeriod.custom,
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      keepReport: false,
    );
  }

  Future<void> _load({required bool keepReport}) async {
    await _ensureRangeThenFetch(keepReport: keepReport);
  }

  /// يضمن وجود نطاق فترة (أول تحميل) ثم يجلب إن وُجد صنف.
  Future<void> _ensureRangeThenFetch({bool keepReport = false}) async {
    var from = _state.from;
    var to = _state.to;
    if (from == null || to == null) {
      final range = computePeriodRange(_state.period, _nowValue());
      from = range.start;
      to = range.end;
    }
    await _apply(
      period: _state.period,
      from: from,
      to: to,
      keepReport: keepReport,
    );
  }

  Future<void> _apply({
    required ReportPeriod period,
    required DateTime from,
    required DateTime to,
    required bool keepReport,
  }) async {
    _state = ItemMovementState(
      loading: _state.productId != null,
      productId: _state.productId,
      period: period,
      from: from,
      to: to,
      report: keepReport ? _state.report : null,
      currencyCode: _currency.code,
      decimals: _currency.decimals,
    );
    notifyListeners();

    final productId = _state.productId;
    if (productId == null) return; // حالة «اختر صنفاً» — لا جلب.

    await _currency.resolve();
    try {
      final report = await _repo.itemMovement(
        productId: productId,
        from: from,
        to: to,
      );
      _state = ItemMovementState(
        loading: false,
        productId: productId,
        period: period,
        from: from,
        to: to,
        report: report,
        currencyCode: _currency.code,
        decimals: _currency.decimals,
      );
    } catch (error) {
      _state = ItemMovementState(
        loading: false,
        error: error,
        productId: productId,
        period: period,
        from: from,
        to: to,
        report: _state.report,
        currencyCode: _currency.code,
        decimals: _currency.decimals,
      );
    }
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────
// FR-09-04 — ملخص حركة المخزون
// ─────────────────────────────────────────────────────────────────────

/// حالة شاشة ملخص حركة المخزون.
class StockSummaryState {
  const StockSummaryState({
    required this.loading,
    this.error,
    this.period = ReportPeriod.month,
    this.from,
    this.to,
    this.rows,
    this.currencyCode = '',
    this.decimals = 2,
  });

  final bool loading;
  final Object? error;
  final ReportPeriod period;
  final DateTime? from;
  final DateTime? to;

  /// صفوف الملخص (قديمة قد تبقى أثناء التحديث) — null قبل أول تحميل.
  final List<StockSummaryRow>? rows;

  final String currencyCode;
  final int decimals;

  /// لا حركة إطلاقاً في الفترة (الحالة الفارغة الاحتفالية).
  bool get isEmpty =>
      !loading && error == null && rows != null && rows!.isEmpty;

  /// إجمالي قيمة المخزون المتحرك بالتكلفة (رأس الشاشة).
  double get totalValueAtCost {
    var sum = 0.0;
    for (final row in rows ?? const <StockSummaryRow>[]) {
      sum += row.valueAtCost;
    }
    return sum;
  }
}

/// نموذج عرض ملخص حركة المخزون — V1 مخزن واحد (بلا مرشح مخزن).
class StockSummaryViewModel extends ChangeNotifier {
  StockSummaryViewModel({
    required MovementReportsRepository movementRepo,
    CompanyRepository? companyRepo,
    DateTime? reference,
    ReportPeriod initialPeriod = ReportPeriod.month,
  }) : _repo = movementRepo,
       _currency = _BaseCurrencyCache(companyRepo),
       _now = reference,
       _state = StockSummaryState(loading: true, period: initialPeriod);

  final MovementReportsRepository _repo;
  final _BaseCurrencyCache _currency;
  final DateTime? _now;

  StockSummaryState _state;
  StockSummaryState get state => _state;

  String get currencyCode => _currency.code;
  int get decimals => _currency.decimals;

  DateTime _nowValue() => _now ?? DateTime.now();

  Future<void> load() => _load(keepReport: false);
  Future<void> refresh() => _load(keepReport: true);

  Future<void> setPeriod(ReportPeriod period) async {
    if (period == ReportPeriod.custom) return;
    if (period == _state.period && _state.from != null) return;
    final range = computePeriodRange(period, _nowValue());
    await _apply(
      period: period,
      from: range.start,
      to: range.end,
      keepReport: false,
    );
  }

  Future<void> setCustomRange(DateTime from, DateTime to) async {
    await _apply(
      period: ReportPeriod.custom,
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      keepReport: false,
    );
  }

  Future<void> _load({required bool keepReport}) async {
    final from = _state.from;
    final to = _state.to;
    if (from == null || to == null) {
      final range = computePeriodRange(_state.period, _nowValue());
      await _apply(
        period: _state.period,
        from: range.start,
        to: range.end,
        keepReport: false,
      );
      return;
    }
    await _apply(
      period: _state.period,
      from: from,
      to: to,
      keepReport: keepReport,
    );
  }

  Future<void> _apply({
    required ReportPeriod period,
    required DateTime from,
    required DateTime to,
    required bool keepReport,
  }) async {
    _state = StockSummaryState(
      loading: true,
      period: period,
      from: from,
      to: to,
      rows: keepReport ? _state.rows : null,
      currencyCode: _currency.code,
      decimals: _currency.decimals,
    );
    notifyListeners();

    await _currency.resolve();
    try {
      final rows = await _repo.stockSummary(from: from, to: to);
      _state = StockSummaryState(
        loading: false,
        period: period,
        from: from,
        to: to,
        rows: rows,
        currencyCode: _currency.code,
        decimals: _currency.decimals,
      );
    } catch (error) {
      _state = StockSummaryState(
        loading: false,
        error: error,
        period: period,
        from: from,
        to: to,
        rows: _state.rows,
        currencyCode: _currency.code,
        decimals: _currency.decimals,
      );
    }
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────
// FR-09-06 — المبيعات حسب
// ─────────────────────────────────────────────────────────────────────

/// حالة شاشة المبيعات حسب.
class SalesByState {
  const SalesByState({
    required this.loading,
    this.error,
    this.dimension = SalesByDimension.customer,
    this.period = ReportPeriod.month,
    this.from,
    this.to,
    this.rows,
    this.currencyCode = '',
    this.decimals = 2,
  });

  final bool loading;
  final Object? error;

  /// بعد التجميع الحالي.
  final SalesByDimension dimension;

  final ReportPeriod period;
  final DateTime? from;
  final DateTime? to;

  /// صفوف التجميع (قديمة قد تبقى أثناء التحديث).
  final List<SalesByRow>? rows;

  final String currencyCode;
  final int decimals;

  /// إجمالي مبيعات الفترة بالأساس (رأس الشاشة) — مجموع الصفوف.
  double get totalSalesBase {
    var sum = 0.0;
    for (final row in rows ?? const <SalesByRow>[]) {
      sum += row.salesBase;
    }
    return sum;
  }

  /// لا مبيعات في الفترة (الحالة الفارغة الاحتفالية).
  bool get isEmpty =>
      !loading && error == null && rows != null && rows!.isEmpty;
}

/// نموذج عرض المبيعات حسب — فترة + بعد تجميع قابل للتبديل.
class SalesByViewModel extends ChangeNotifier {
  SalesByViewModel({
    required MovementReportsRepository movementRepo,
    CompanyRepository? companyRepo,
    SalesByDimension dimension = SalesByDimension.customer,
    DateTime? reference,
    ReportPeriod initialPeriod = ReportPeriod.month,
  }) : _repo = movementRepo,
       _currency = _BaseCurrencyCache(companyRepo),
       _now = reference,
       _state = SalesByState(
         loading: true,
         dimension: dimension,
         period: initialPeriod,
       );

  final MovementReportsRepository _repo;
  final _BaseCurrencyCache _currency;
  final DateTime? _now;

  SalesByState _state;
  SalesByState get state => _state;

  String get currencyCode => _currency.code;
  int get decimals => _currency.decimals;

  DateTime _nowValue() => _now ?? DateTime.now();

  Future<void> load() => _load(keepReport: false);
  Future<void> refresh() => _load(keepReport: true);

  /// تبديل بعد التجميع (العميل/الفئة/الصنف/اليوم) — يعيد التحميل.
  Future<void> setDimension(SalesByDimension dimension) async {
    if (dimension == _state.dimension && _state.rows != null) return;
    await _apply(
      dimension: dimension,
      period: _state.period,
      from: _state.from,
      to: _state.to,
      keepReport: false,
    );
  }

  Future<void> setPeriod(ReportPeriod period) async {
    if (period == ReportPeriod.custom) return;
    if (period == _state.period && _state.from != null) return;
    final range = computePeriodRange(period, _nowValue());
    await _apply(
      dimension: _state.dimension,
      period: period,
      from: range.start,
      to: range.end,
      keepReport: false,
    );
  }

  Future<void> setCustomRange(DateTime from, DateTime to) async {
    await _apply(
      dimension: _state.dimension,
      period: ReportPeriod.custom,
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      keepReport: false,
    );
  }

  Future<void> _load({required bool keepReport}) async {
    var from = _state.from;
    var to = _state.to;
    if (from == null || to == null) {
      final range = computePeriodRange(_state.period, _nowValue());
      from = range.start;
      to = range.end;
    }
    await _apply(
      dimension: _state.dimension,
      period: _state.period,
      from: from,
      to: to,
      keepReport: keepReport,
    );
  }

  Future<void> _apply({
    required SalesByDimension dimension,
    required ReportPeriod period,
    required DateTime? from,
    required DateTime? to,
    required bool keepReport,
  }) async {
    _state = SalesByState(
      loading: true,
      dimension: dimension,
      period: period,
      from: from,
      to: to,
      rows: keepReport ? _state.rows : null,
      currencyCode: _currency.code,
      decimals: _currency.decimals,
    );
    notifyListeners();

    await _currency.resolve();
    try {
      final rows = await _repo.salesBy(
        dimension: dimension,
        from: from!,
        to: to!,
      );
      _state = SalesByState(
        loading: false,
        dimension: dimension,
        period: period,
        from: from,
        to: to,
        rows: rows,
        currencyCode: _currency.code,
        decimals: _currency.decimals,
      );
    } catch (error) {
      _state = SalesByState(
        loading: false,
        error: error,
        dimension: dimension,
        period: period,
        from: from,
        to: to,
        rows: _state.rows,
        currencyCode: _currency.code,
        decimals: _currency.decimals,
      );
    }
    notifyListeners();
  }
}
