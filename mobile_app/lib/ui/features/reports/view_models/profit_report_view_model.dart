/// نموذج عرض تقرير الأرباح والخسائر (FR-09-02 — الشريحة 10): اختيار
/// الفترة (مسبقة أو مخصصة)، تحميل التقرير وتحديثه، وعملة العرض
/// الأساسية (رمزها ومنازلها) — بنمط `aging_view_model` نفسه.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/profit_report_repository.dart';
import '../views/widgets/period_preset_bar.dart';

/// حالة شاشة تقرير الأرباح والخسائر.
class ProfitReportState {
  const ProfitReportState({
    required this.loading,
    this.error,
    this.period = ReportPeriod.month,
    this.from,
    this.to,
    this.report,
    this.loadedAt,
    this.currencyCode = '',
    this.decimals = 2,
  });

  final bool loading;
  final Object? error;

  /// الفترة المحددة (مسبقة أو مخصصة).
  final ReportPeriod period;

  /// بداية المدى (شاملة) — محسوبة من الفترة أو من اختيار المستخدم.
  final DateTime? from;

  /// نهاية المدى (شاملة).
  final DateTime? to;

  /// التقرير المحمّل (قديم قد يبقى أثناء التحديث).
  final ProfitReport? report;

  /// لحظة آخر تحميل ناجح (ميتا التقرير).
  final DateTime? loadedAt;

  /// رمز العملة الأساسية للعرض ('' عند تعذّر جلبها).
  final String currencyCode;

  /// منازل العملة الأساسية (YER = 0).
  final int decimals;

  /// لا حركة إطلاقاً في الفترة (الحالة الفارغة الاحتفالية).
  bool get isEmpty =>
      !loading && error == null && report != null && !report!.hasAnyActivity;
}

/// نموذج عرض تقرير الأرباح — ChangeNotifier بنمط وحدة التقارير.
class ProfitReportViewModel extends ChangeNotifier {
  ProfitReportViewModel({
    required ProfitReportRepository profitRepo,
    CompanyRepository? companyRepo,
    DateTime? reference,
    ReportPeriod initialPeriod = ReportPeriod.month,
  }) : _repo = profitRepo,
       _companies = companyRepo,
       _now = reference,
       _state = ProfitReportState(loading: true, period: initialPeriod);

  final ProfitReportRepository _repo;

  /// مستودع العملات (رمز العملة الأساسية ومنازلها) — اختياري.
  final CompanyRepository? _companies;

  /// لحظة «الآن» (قابلة للحقن — الاختبارات).
  final DateTime? _now;

  ProfitReportState _state;
  ProfitReportState get state => _state;

  /// العملة الأساسية مخبوءة بعد أول جلب ناجح.
  String _currencyCode = '';
  int _decimals = 2;
  bool _currencyResolved = false;

  DateTime _nowValue() => _now ?? DateTime.now();

  /// التحميل الأول — يحسب نطاق الفترة الابتدائية إن لم يوجد.
  Future<void> load() => _load(keepReport: false);

  /// تحديث (سحب للأسفل) — يُبقي التقرير القديم ظاهراً أثناء الجلب.
  Future<void> refresh() => _load(keepReport: true);

  /// اختيار فترة مسبقة — يحسب نطاقها من «الآن» المحقون ويعيد التحميل.
  /// (custom لا يُعالج هنا — المدى يأتي عبر [setCustomRange] بعد
  /// منتقي التاريخ الذي يفتحه الشريط بنفسه).
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

  /// مدى مخصص من منتقي التاريخ — يصبح الفترة الحالية ويعيد التحميل.
  Future<void> setCustomRange(DateTime from, DateTime to) async {
    await _apply(
      period: ReportPeriod.custom,
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      keepReport: false,
    );
  }

  Future<void> _apply({
    required ReportPeriod period,
    required DateTime from,
    required DateTime to,
    required bool keepReport,
  }) async {
    _state = ProfitReportState(
      loading: true,
      period: period,
      from: from,
      to: to,
      report: keepReport ? _state.report : null,
      loadedAt: keepReport ? _state.loadedAt : null,
      currencyCode: _state.currencyCode,
      decimals: _state.decimals,
    );
    notifyListeners();
    await _fetch();
  }

  Future<void> _load({required bool keepReport}) async {
    final currentFrom = _state.from;
    final currentTo = _state.to;
    if (currentFrom == null || currentTo == null) {
      // أول تحميل — نطاق الفترة الابتدائية (الشهر افتراضياً).
      final range = computePeriodRange(_state.period, _nowValue());
      await _apply(
        period: _state.period,
        from: range.start,
        to: range.end,
        keepReport: false,
      );
      return;
    }
    _state = ProfitReportState(
      loading: true,
      period: _state.period,
      from: currentFrom,
      to: currentTo,
      report: keepReport ? _state.report : null,
      loadedAt: keepReport ? _state.loadedAt : null,
      currencyCode: _state.currencyCode,
      decimals: _state.decimals,
    );
    notifyListeners();
    await _fetch();
  }

  Future<void> _fetch() async {
    await _resolveBaseCurrency();
    final from = _state.from!;
    final to = _state.to!;
    try {
      final report = await _repo.report(from: from, to: to);
      _state = ProfitReportState(
        loading: false,
        period: _state.period,
        from: from,
        to: to,
        report: report,
        loadedAt: _nowValue(),
        currencyCode: _currencyCode,
        decimals: _decimals,
      );
    } catch (error) {
      _state = ProfitReportState(
        loading: false,
        error: error,
        period: _state.period,
        from: from,
        to: to,
        report: _state.report,
        loadedAt: _state.loadedAt,
        currencyCode: _currencyCode,
        decimals: _decimals,
      );
    }
    notifyListeners();
  }

  /// رمز العملة الأساسية ومنازلها — مرة واحدة (فشلها لا يُسقط التقرير:
  /// عرض بمنازل 2 وبلا رمز).
  Future<void> _resolveBaseCurrency() async {
    if (_currencyResolved) return;
    final repo = _companies;
    if (repo != null) {
      try {
        final currency = await repo.findBaseCurrency();
        if (currency != null) {
          _currencyCode = currency.code;
          _decimals = currency.decimals;
        }
      } catch (_) {
        // عرض بلا رمز عملة — التقرير نفسه لا يتأثر.
      }
    }
    _currencyResolved = true;
  }
}
