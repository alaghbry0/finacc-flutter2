/// نموذج عرض شاشة تفضيلات البيع (UX-2a) — ست سياسات في تحميل واحد:
/// طريقة الدفع الافتراضية (`sale.default_payment`) + إظهار الخصومات
/// (`sale.show_discounts`) + سياسة حد الائتمان (`parties.credit_limit_action`
/// — كانت مستهلكة بلا واجهة) + البيع فوق المتاح (`sale.over_avail_policy`)
/// + تحذير البيع تحت التكلفة (`invoicing.discount_below_margin`)
/// + حقل الكمية المجانية/بونص (`sale.free_qty` — موجة UX-4).
///
/// كل تبديل يُكتب فوراً في المستودع (إعداد لحظي بلا زر حفظ) مع تحديث
/// متشائم آمن: فشل الكتابة يبقي القيمة الحية ويُعرض خطأً.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/settings_repository.dart';

/// حالة شاشة تفضيلات البيع.
class SalePreferencesState {
  const SalePreferencesState({
    required this.loading,
    this.error,
    this.defaultPayment = 'cash',
    this.showDiscounts = true,
    this.creditLimitAction = 'warn',
    this.overAvailPolicy = 'warn',
    this.warnBelowMargin = false,
    this.bonusQtyEnabled = false,
    this.writeError,
  });

  final bool loading;
  final Object? error;

  /// `sale.default_payment` — cash/credit/mixed.
  final String defaultPayment;

  /// `sale.show_discounts` — إظهار عناصر الخصم بالكاشير.
  final bool showDiscounts;

  /// `parties.credit_limit_action` — warn/block.
  final String creditLimitAction;

  /// `sale.over_avail_policy` — warn/block.
  final String overAvailPolicy;

  /// `invoicing.discount_below_margin` — لافتة تحذير عند هامش سالب.
  final bool warnBelowMargin;

  /// `sale.free_qty` — حقل الكمية المجانية (بونص) ببنود الكاشير
  /// (UX-4 — مزروعة 'off' بهجرة v5: مغلقة افتراضياً).
  final bool bonusQtyEnabled;

  /// فشل كتابة آخر تبديل (يُعرض — القيمة الحية تبقى كما كانت).
  final String? writeError;

  SalePreferencesState copyWith({
    bool? loading,
    Object? error,
    String? defaultPayment,
    bool? showDiscounts,
    String? creditLimitAction,
    String? overAvailPolicy,
    bool? warnBelowMargin,
    bool? bonusQtyEnabled,
    Object? writeError = _keep,
  }) => SalePreferencesState(
    loading: loading ?? this.loading,
    error: error,
    defaultPayment: defaultPayment ?? this.defaultPayment,
    showDiscounts: showDiscounts ?? this.showDiscounts,
    creditLimitAction: creditLimitAction ?? this.creditLimitAction,
    overAvailPolicy: overAvailPolicy ?? this.overAvailPolicy,
    warnBelowMargin: warnBelowMargin ?? this.warnBelowMargin,
    bonusQtyEnabled: bonusQtyEnabled ?? this.bonusQtyEnabled,
    writeError: identical(writeError, _keep)
        ? this.writeError
        : writeError as String?,
  );

  static const Object _keep = Object();
}

/// نموذج عرض تفضيلات البيع.
class SalePreferencesViewModel extends ChangeNotifier {
  SalePreferencesViewModel({required SettingsRepository settingsRepo})
    : _settings = settingsRepo;

  final SettingsRepository _settings;

  SalePreferencesState _state = const SalePreferencesState(loading: true);
  SalePreferencesState get state => _state;

  /// تحميل السياسات في جولة واحدة.
  Future<void> load() async {
    _state = _state.copyWith(loading: true, error: null);
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _settings.defaultPayment(),
        _settings.showDiscounts(),
        _settings.creditLimitAction(),
        _settings.overAvailPolicy(),
        _settings.discountBelowMargin(),
        _settings.bonusQtyEnabled(),
      ]);
      _state = SalePreferencesState(
        loading: false,
        defaultPayment: results[0]! as String,
        showDiscounts: results[1]! as bool,
        creditLimitAction: results[2]! as String,
        overAvailPolicy: results[3]! as String,
        warnBelowMargin: results[4]! as bool,
        bonusQtyEnabled: results[5]! as bool,
      );
    } catch (error) {
      _state = _state.copyWith(loading: false, error: error);
    }
    notifyListeners();
  }

  // ── التبديلات (كتابة فورية + تحديث حي) ──

  Future<void> setDefaultPayment(String mode) =>
      _write(() => _settings.setDefaultPayment(mode), defaultPayment: mode);

  Future<void> setShowDiscounts(bool show) =>
      _write(() => _settings.setShowDiscounts(show), showDiscounts: show);

  Future<void> setCreditLimitAction(String action) => _write(
    () => _settings.set('parties.credit_limit_action', action),
    creditLimitAction: action,
  );

  Future<void> setOverAvailPolicy(String policy) => _write(
    () => _settings.set('sale.over_avail_policy', policy),
    overAvailPolicy: policy,
  );

  Future<void> setWarnBelowMargin(bool on) => _write(
    () => _settings.set('invoicing.discount_below_margin', on ? 'on' : 'off'),
    warnBelowMargin: on,
  );

  /// يثبّت إظهار/إخفاء حقل البونص بالكاشير (UX-4 — `sale.free_qty`).
  Future<void> setBonusQtyEnabled(bool on) =>
      _write(() => _settings.setBonusQtyEnabled(on), bonusQtyEnabled: on);

  /// يطبّق تبديلاً: تحديث حي فوري ثم كتابة — فشلها يُعرض دون كسر القيمة.
  Future<void> _write(
    Future<void> Function() write, {
    String? defaultPayment,
    bool? showDiscounts,
    String? creditLimitAction,
    String? overAvailPolicy,
    bool? warnBelowMargin,
    bool? bonusQtyEnabled,
  }) async {
    _state = _state.copyWith(
      defaultPayment: defaultPayment,
      showDiscounts: showDiscounts,
      creditLimitAction: creditLimitAction,
      overAvailPolicy: overAvailPolicy,
      warnBelowMargin: warnBelowMargin,
      bonusQtyEnabled: bonusQtyEnabled,
      writeError: null,
    );
    notifyListeners();
    try {
      await write();
    } catch (error) {
      _state = _state.copyWith(writeError: 'WRITE_FAILED');
      if (kDebugMode) {
        debugPrint('SalePreferencesViewModel._write: $error');
      }
      notifyListeners();
    }
  }

  /// مسح خطأ الكتابة المعروض.
  void clearWriteError() {
    if (_state.writeError == null) return;
    _state = _state.copyWith(writeError: null);
    notifyListeners();
  }
}
