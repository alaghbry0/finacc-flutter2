/// نموذج عرض Onboarding — قيادة خطوات التأسيس (FR-13-01).
///
/// الخطوات: ترحيب → بيانات المنشأة → PIN (إدخال + تأكيد) → عبارة المرور
/// (إدخال + تأكيد) → تنفيذ ذرّي → تم.
/// التحقق عبر `SetupCompanyValidator` (النطاق) والتنفيذ عبر المستودع
/// (المعاملة الواحدة) — ثم تسليم الجلسة للمتحكم الرئيسي.
library;

import 'package:flutter/foundation.dart';

import '../../../../domain/models/company.dart';
import '../../../../domain/use_cases/setup_company.dart';
import '../../../core/session/app_controller.dart';

/// خطوات المعالج.
enum OnboardingStep { welcome, company, security, creating, done }

/// رموز أخطاء النموذج (تُترجم في الواجهة عبر l10n).
enum OnboardingError {
  pinMismatch,
  pinInvalidLength,
  passphraseMismatch,
  passphraseShort,
  passphraseRequired,
  setupFailed;

  /// النص الخام المخزَّن (توافق داخلي).
  String get code => name;
}

/// نتيجة إنشاء المنشأة (لرسالة النجاح).
class SetupResult {
  const SetupResult({
    required this.company,
    required this.warehouseName,
    required this.cashboxName,
    required this.currencyName,
  });

  final Company company;
  final String warehouseName;
  final String cashboxName;
  final String currencyName;
}

class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel({SetupCompanyValidator? validator})
    : validator = validator ?? const SetupCompanyValidator();

  final SetupCompanyValidator validator;

  OnboardingStep _step = OnboardingStep.welcome;
  OnboardingError? _error;
  Object? _errorDetails;
  bool _submitting = false;
  SetupResult? _result;

  // حقول نموذج المنشأة.
  String _companyName = '';
  String _companyPhone = '';
  String _baseCurrencyCode = 'YER';
  int _baseCurrencyDecimals = 0;

  // حقول الأمان (خام — لا تُخزَّن نصاً أبداً).
  String _pin = '';
  String _confirmedPin = '';
  bool _confirmingPin = false;
  bool _passphraseMode = false;
  String _passphrase = '';
  String _confirmedPassphrase = '';

  OnboardingStep get step => _step;
  OnboardingError? get error => _error;
  Object? get errorDetails => _errorDetails;
  bool get submitting => _submitting;
  SetupResult? get result => _result;

  String get companyName => _companyName;
  String get companyPhone => _companyPhone;
  String get baseCurrencyCode => _baseCurrencyCode;
  int get baseCurrencyDecimals => _baseCurrencyDecimals;
  bool get isCompanyNameValid => _companyName.trim().isNotEmpty;

  /// هل نحن في وضع تأكيد PIN (الإدخال الثاني)?
  bool get confirmingPin => _confirmingPin;

  /// هل انتقلنا لقسم عبارة المرور داخل خطوة الأمان?
  bool get passphraseMode => _passphraseMode;

  /// الرقم الجاري للعرض على النقاط.
  String get pinForDots => _confirmingPin ? _confirmedPin : _pin;

  /// إجمالي طول نقاط العرض (4 أو 6 حسب أول إدخال مكتمل).
  int get pinDotsLength => _pin.length >= 4 ? _pin.length.clamp(4, 6) : 6;

  // ── التعديلات ──

  void setCompanyName(String value) {
    _companyName = value;
    notifyListeners();
  }

  void setCompanyPhone(String value) {
    _companyPhone = value;
    notifyListeners();
  }

  /// يثبّت العملة الأساسية المختارة وخصائصها.
  void selectCurrency(String code, int decimals) {
    _baseCurrencyCode = code;
    _baseCurrencyDecimals = decimals;
    notifyListeners();
  }

  void goTo(OnboardingStep step) {
    _step = step;
    _error = null;
    notifyListeners();
  }

  /// من خطوة الترحيب إلى نموذج المنشأة.
  void startCompanyForm() => goTo(OnboardingStep.company);

  /// التحقق من نموذج المنشأة والانتقال لخطوة الأمان.
  bool submitCompanyForm() {
    if (!isCompanyNameValid) {
      notifyListeners();
      return false;
    }
    goTo(OnboardingStep.security);
    return true;
  }

  // ── إدخال PIN ──

  void addPinDigit(int digit) {
    final target = _confirmingPin ? _confirmedPin : _pin;
    if (target.length >= 6) return;
    if (_confirmingPin) {
      _confirmedPin = '$target$digit';
    } else {
      _pin = '$target$digit';
    }
    _error = null;
    notifyListeners();
  }

  void backspacePin() {
    if (_confirmingPin) {
      _confirmedPin = _confirmedPin.isEmpty
          ? ''
          : _confirmedPin.substring(0, _confirmedPin.length - 1);
    } else {
      _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1);
    }
    notifyListeners();
  }

  /// عند الضغط على زر المتابعة في وضع الإدخال الأول: يتحقق من الطول
  /// وينتقل للتأكيد. في وضع التأكيد: يقارن وينتقل لعبارة المرور عند
  /// التطابق (ويعيد true)، أو يصفّر مع خطأ (ويعيد false).
  bool pinContinuePressed() {
    if (!_confirmingPin) {
      if (_pin.length < 4 || _pin.length > 6) {
        _error = OnboardingError.pinInvalidLength;
        notifyListeners();
        return false;
      }
      _confirmingPin = true;
      _error = null;
      notifyListeners();
      return false;
    }
    if (_confirmedPin != _pin) {
      _error = OnboardingError.pinMismatch;
      _confirmedPin = '';
      notifyListeners();
      return false;
    }
    _passphraseMode = true;
    _error = null;
    notifyListeners();
    return true;
  }

  /// العودة من قسم عبارة المرور إلى تأكيد PIN — **الـ PIN الأول محفوظ**
  /// (كان يُصفَّر كاملاً فَيُضطر المستخدم لإدخاله مرتين من جديد — P2-10)؛
  /// يُعاد التأكيد فقط (إدخال واحد).
  void backToPin() {
    _passphraseMode = false;
    _confirmingPin = true;
    _confirmedPin = '';
    _error = null;
    notifyListeners();
  }

  // ── عبارة المرور ──

  void setPassphrase(String value) {
    _passphrase = value;
    _error = null;
    notifyListeners();
  }

  void setConfirmedPassphrase(String value) {
    _confirmedPassphrase = value;
    notifyListeners();
  }

  /// صلاحية النموذج المحلي قبل الإرسال (طول + تطابق).
  bool get passphraseFormValid =>
      _passphrase.length >= 8 && _confirmedPassphrase == _passphrase;

  /// التنفيذ النهائي — تحقق النطاق ثم المعاملة الذرّية.
  Future<void> submit(AppController app, {DateTime? now}) async {
    if (_submitting) return;
    if (_passphrase.length < 8) {
      _error = OnboardingError.passphraseShort;
      notifyListeners();
      return;
    }
    if (_confirmedPassphrase != _passphrase) {
      _error = OnboardingError.passphraseMismatch;
      notifyListeners();
      return;
    }
    _submitting = true;
    _error = null;
    _step = OnboardingStep.creating;
    notifyListeners();
    try {
      final draft = validator
          .validate(
            companyName: _companyName,
            currencyCode: _baseCurrencyCode,
            pin: _pin,
            passphrase: _passphrase,
            phone: _companyPhone,
            now: now ?? DateTime.now(),
          )
          .valueOrNull;
      if (draft == null) {
        _error = OnboardingError.setupFailed;
        _step = OnboardingStep.security;
        return;
      }
      final repo = app.companies;
      if (repo == null) {
        _error = OnboardingError.setupFailed;
        _step = OnboardingStep.security;
        return;
      }
      final company = await repo.executeSetup(draft, now ?? DateTime.now());
      final currencyName = (await repo.listActiveCurrencies())
          .firstWhere((c) => c.code == _baseCurrencyCode)
          .name;
      _result = SetupResult(
        company: company,
        warehouseName: draft.warehouseName,
        cashboxName: draft.cashboxName,
        currencyName: currencyName,
      );
      _step = OnboardingStep.done;
      // ملاحظة تدفق: لا نقلب الطور هنا — شاشة «تم التأسيس» تظهر أولاً،
      // وزر «ابدأ الاستخدام» هو من يستدعي completeOnboarding (يذهب بها
      // الموجّه تلقائياً إلى /home).
    } catch (error) {
      _error = OnboardingError.setupFailed;
      _errorDetails = error;
      _step = OnboardingStep.security;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  /// تصفير كامل (اختبارات).
  @visibleForTesting
  void resetForTest() {
    _step = OnboardingStep.welcome;
    _error = null;
    _errorDetails = null;
    _submitting = false;
    _result = null;
    _companyName = '';
    _companyPhone = '';
    _baseCurrencyCode = 'YER';
    _baseCurrencyDecimals = 0;
    _pin = '';
    _confirmedPin = '';
    _confirmingPin = false;
    _passphraseMode = false;
    _passphrase = '';
    _confirmedPassphrase = '';
    notifyListeners();
  }
}
