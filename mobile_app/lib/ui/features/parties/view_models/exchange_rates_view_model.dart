/// نموذج عرض شاشة أسعار الصرف اليومية (FR-08-03/05/09) — الإدخال اليدوي
/// اليومي لكل عملة نشطة غير الأساسية، مع آخر سعر معروف وسجله، وحالة
/// إدخال اليوم لكل عملة. العملة الأساسية لا تظهر إطلاقاً (سعرها 1).
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/exchange_rate_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/exchange_rate.dart';

/// صف عملة واحدة في شاشة الأسعار.
final class FxCurrencyEntry {
  const FxCurrencyEntry({
    required this.currency,
    required this.history,
    this.todayRate,
    this.saving = false,
    this.fieldError = false,
  });

  /// العملة (غير الأساسية دائماً).
  final Currency currency;

  /// سعر اليوم إن أُدخل (null = لم يُدخل بعد — FR-08-09).
  final double? todayRate;

  /// سجل الأسعار تنازلياً (الأحدث أولاً).
  final List<ExchangeRateEntry> history;

  final bool saving;

  /// خطأ نص الحقل (رقم غير صالح) — يظهر تحت الحقل.
  final bool fieldError;

  /// آخر سعر معروف من السجل — أو null إن لا تاريخ.
  ExchangeRateEntry? get latest => history.isEmpty ? null : history.first;

  /// هل أُدخل سعر اليوم؟
  bool get enteredToday => todayRate != null;

  FxCurrencyEntry copyWith({
    double? todayRate,
    bool clearTodayRate = false,
    List<ExchangeRateEntry>? history,
    bool? saving,
    bool? fieldError,
  }) => FxCurrencyEntry(
    currency: currency,
    todayRate: clearTodayRate ? null : (todayRate ?? this.todayRate),
    history: history ?? this.history,
    saving: saving ?? this.saving,
    fieldError: fieldError ?? this.fieldError,
  );
}

/// حالة شاشة الأسعار.
class ExchangeRatesState {
  const ExchangeRatesState({
    required this.loading,
    this.error,
    this.baseCurrency,
    required this.entries,
    this.savingCurrencyId,
    this.savedCurrencyId,
    this.repoError,
  });

  final bool loading;
  final Object? error;

  /// العملة الأساسية — سعرها 1 ولا تُعرض كبطاقة إدخال.
  final Currency? baseCurrency;

  /// صفوف العملات غير الأساسية (بترتيب المستودع).
  final List<FxCurrencyEntry> entries;

  /// عملة قيد الحفظ الآن.
  final int? savingCurrencyId;

  /// آخر عملة حُفظ سعرها بنجاح (لإشعار الواجهة).
  final int? savedCurrencyId;

  /// خطأ المستودع (عربي — SnackBar).
  final String? repoError;

  /// عدد العملات المُدخل سعرها اليوم.
  int get enteredCount => entries.where((entry) => entry.enteredToday).length;

  /// عدد العملات غير الأساسية.
  int get totalCount => entries.length;

  /// هل إدخال اليوم مكتمل؟
  bool get complete => entries.isNotEmpty && enteredCount == entries.length;

  /// هل الإدخال ناقص؟ (يستدعي الشارة التحذيرية — FR-08-09)
  bool get missing => entries.isNotEmpty && enteredCount < entries.length;

  static const ExchangeRatesState initial = ExchangeRatesState(
    loading: true,
    entries: <FxCurrencyEntry>[],
  );
}

class ExchangeRatesViewModel extends ChangeNotifier {
  ExchangeRatesViewModel({
    required CompanyRepository companyRepo,
    required ExchangeRateRepository fxRepo,
    DateTime? now,
  }) : _companies = companyRepo,
       _fx = fxRepo,
       _today = _dayOf(now ?? DateTime.now());

  final CompanyRepository _companies;
  final ExchangeRateRepository _fx;

  /// «اليوم» — يوم عمل واحد صريح (قابل للحقن).
  final DateTime _today;

  ExchangeRatesState _state = ExchangeRatesState.initial;
  ExchangeRatesState get state => _state;

  /// اليوم المرجعي للإدخال (يوم عمل كامل بلا وقت).
  DateTime get today => _today;

  /// تحميل العملات غير الأساسية + أسعار اليوم + سجل كل عملة.
  Future<void> load() async {
    _state = ExchangeRatesState(loading: true, entries: const []);
    notifyListeners();
    try {
      final currencies = await _companies.listActiveCurrencies();
      final nonBase = currencies.where((c) => !c.isBase).toList();
      final todayRates = await _fx.todayRates(_today);
      final histories = await Future.wait(
        nonBase.map((c) => _fx.history(c.id, limit: 12)),
      );
      _state = ExchangeRatesState(
        loading: false,
        baseCurrency: _baseOf(currencies),
        entries: [
          for (var i = 0; i < nonBase.length; i++)
            FxCurrencyEntry(
              currency: nonBase[i],
              todayRate: todayRates[nonBase[i].id],
              history: histories[i],
            ),
        ],
      );
    } catch (error) {
      _state = ExchangeRatesState(
        loading: false,
        error: error,
        entries: const <FxCurrencyEntry>[],
      );
    }
    notifyListeners();
  }

  /// يحفظ سعر اليوم لعملة — يعيد true عند النجاح (UPSERT: التحديث
  /// لا ينشئ تكراراً). النص غير الصالح يضع علامة خطأ الحقل فقط.
  Future<bool> setRateFor(int currencyId, String text) async {
    final trimmed = text.trim();
    final rate = double.tryParse(trimmed);
    if (rate == null || rate <= 0 || rate.isNaN || rate.isInfinite) {
      _mutateEntry(currencyId, fieldError: true);
      return false;
    }
    final userId = await _companies.findAdminUserId();
    if (userId == null) {
      _state = _copyEntries(
        repoError: 'تعذّر الحفظ — لا مستخدم مدير نشط في القاعدة.',
      );
      notifyListeners();
      return false;
    }
    _mutateEntry(currencyId, saving: true, fieldError: false);
    final result = await _fx.setRate(
      currencyId: currencyId,
      date: _today,
      rate: rate,
      userId: userId,
    );
    switch (result) {
      case Ok<void, String>():
        await _refreshEntry(currencyId, saved: true);
        return true;
      case final Err<void, String> err:
        _state = _copyEntries(repoError: err.error);
        _mutateEntry(currencyId, saving: false);
        return false;
    }
  }

  /// يحدّث صف عملة بعد الحفظ (سعر اليوم + السجل).
  Future<void> _refreshEntry(int currencyId, {required bool saved}) async {
    final todayRate = await _fx.rateFor(currencyId, _today);
    final history = await _fx.history(currencyId, limit: 12);
    _state = _copyEntries(
      entries: [
        for (final entry in _state.entries)
          entry.currency.id == currencyId
              ? entry.copyWith(
                  todayRate: todayRate,
                  history: history,
                  saving: false,
                )
              : entry,
      ],
      savedCurrencyId: saved ? currencyId : _state.savedCurrencyId,
    );
    notifyListeners();
  }

  void _mutateEntry(
    int currencyId, {
    bool? saving,
    bool? fieldError,
    bool clearFieldError = false,
  }) {
    _state = _copyEntries(
      entries: [
        for (final entry in _state.entries)
          entry.currency.id == currencyId
              ? entry.copyWith(
                  saving: saving,
                  fieldError: clearFieldError ? false : fieldError,
                )
              : entry,
      ],
    );
    notifyListeners();
  }

  /// يمسح علامة خطأ الحقل عند بدء الكتابة من جديد.
  void clearFieldError(int currencyId) =>
      _mutateEntry(currencyId, clearFieldError: true);

  /// يمسح إشعار آخر حفظ (بعد عرضه).
  void clearSavedFlag() {
    if (_state.savedCurrencyId == null) return;
    _state = _copyEntries(savedCurrencyId: null);
    notifyListeners();
  }

  ExchangeRatesState _copyEntries({
    List<FxCurrencyEntry>? entries,
    int? savingCurrencyId,
    int? savedCurrencyId,
    bool clearSaved = false,
    String? repoError,
    bool clearRepoError = false,
  }) => ExchangeRatesState(
    loading: _state.loading,
    error: _state.error,
    baseCurrency: _state.baseCurrency,
    entries: entries ?? _state.entries,
    savingCurrencyId: savingCurrencyId ?? _state.savingCurrencyId,
    savedCurrencyId: clearSaved
        ? null
        : (savedCurrencyId ?? _state.savedCurrencyId),
    repoError: clearRepoError ? null : (repoError ?? _state.repoError),
  );

  static Currency? _baseOf(List<Currency> currencies) {
    for (final currency in currencies) {
      if (currency.isBase) return currency;
    }
    return null;
  }

  /// يوم عمل كامل بلا وقت.
  static DateTime _dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
