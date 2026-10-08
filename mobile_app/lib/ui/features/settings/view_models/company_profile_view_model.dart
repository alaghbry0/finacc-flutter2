/// نموذج عرض محرر بيانات المنشأة (UX-2a) — تحميل الكيان الكامل (الأعمدة
/// الموجودة منذ v1 والمستغلة الآن: واتساب/عنوان/رقم ضريبي/تذييل) + رافع
/// الشعار (BLOB عبر هجرة v3) + حفظ ذرّي واحد عبر `CompanyRepository.update`.
///
/// رافع الشعار **seam قابل للحقن** ([logoPicker]) — الإنتاج يمرر منتقي
/// image_picker والاختبارات بايتات جاهزة بلا منصة.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../domain/models/company.dart';

/// سقف حجم الشعار بالبايت (1 م.ب مضغوطاً — يُختبر قبل الحفظ).
const int kCompanyLogoMaxBytes = 1024 * 1024;

/// حالة محرر بيانات المنشأة.
class CompanyProfileState {
  const CompanyProfileState({
    required this.loading,
    this.error,
    this.currency,
    this.saving = false,
    this.saveError,
    this.saved = false,
  });

  final bool loading;
  final Object? error;

  /// العملة الأساسية (عرض فقط — تُثبَّت من التأسيس FR-08-01).
  final Currency? currency;

  final bool saving;

  /// رسالة فشل الحفظ الأخيرة (تُعرض بوضوح — التعديلات تبقى).
  final String? saveError;

  /// نجح آخر حفظ (يُستهلك عند العرض — SnackBar).
  final bool saved;

  /// قيمة حراسة للحقول القابلة للتصفير في [copyWith] (نمط SellCartState).
  static const Object _keep = Object();

  CompanyProfileState copyWith({
    bool? loading,
    Object? error = _keep,
    Currency? currency,
    bool? saving,
    Object? saveError = _keep,
    bool? saved,
  }) => CompanyProfileState(
    loading: loading ?? this.loading,
    error: identical(error, _keep) ? this.error : error,
    currency: currency ?? this.currency,
    saving: saving ?? this.saving,
    saveError: identical(saveError, _keep)
        ? this.saveError
        : saveError as String?,
    saved: saved ?? this.saved,
  );
}

/// نموذج عرض محرر بيانات المنشأة.
class CompanyProfileViewModel extends ChangeNotifier {
  CompanyProfileViewModel({
    required CompanyRepository companyRepo,
    Future<Uint8List?> Function()? logoPicker,
  }) : _companies = companyRepo,
       _pickLogo = logoPicker;

  final CompanyRepository _companies;

  /// رافع الشعار (seam) — null = الزر يختفي (منصة بلا منتقي).
  final Future<Uint8List?> Function()? _pickLogo;

  CompanyProfileState _state = const CompanyProfileState(loading: true);
  CompanyProfileState get state => _state;

  Company? _company;
  Company? get company => _company;

  // ── حقول النموذج ──
  String _name = '';
  String _phone = '';
  String _whatsapp = '';
  String _address = '';
  String _taxNumber = '';
  String _taxRateText = '0';
  String _footerText = '';
  Uint8List? _logoPng;

  String get name => _name;
  String get phone => _phone;
  String get whatsapp => _whatsapp;
  String get address => _address;
  String get taxNumber => _taxNumber;
  String get taxRateText => _taxRateText;
  String get footerText => _footerText;
  Uint8List? get logoPng => _logoPng;

  /// هل رافع الشعار متاح؟ (غيابه يخفي أزرار الرفع).
  bool get canPickLogo => _pickLogo != null;

  // ── التحميل ──

  /// تحميل الكيان الكامل والعملة الأساسية (مرة عند الفتح).
  Future<void> load() async {
    _state = _state.copyWith(loading: true, error: null);
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _companies.findCompany(),
        _companies.findBaseCurrency(),
      ]);
      final company = results[0] as Company?;
      _company = company;
      if (company != null) {
        _name = company.name;
        _phone = company.phone ?? '';
        _whatsapp = company.whatsapp ?? '';
        _address = company.address ?? '';
        _taxNumber = company.taxNumber ?? '';
        _taxRateText = _formatRate(company.taxRate);
        _footerText = company.footerText ?? '';
        _logoPng = company.logoPng;
      }
      _state = CompanyProfileState(
        loading: false,
        currency: results[1] as Currency?,
      );
    } catch (error) {
      _state = _state.copyWith(loading: false, error: error);
    }
    notifyListeners();
  }

  // ── محررات الحقول ──

  void setName(String value) {
    if (value == _name) return;
    _name = value;
    _dirtyNotify();
  }

  void setPhone(String value) {
    if (value == _phone) return;
    _phone = value;
    _dirtyNotify();
  }

  void setWhatsapp(String value) {
    if (value == _whatsapp) return;
    _whatsapp = value;
    _dirtyNotify();
  }

  void setAddress(String value) {
    if (value == _address) return;
    _address = value;
    _dirtyNotify();
  }

  void setTaxNumber(String value) {
    if (value == _taxNumber) return;
    _taxNumber = value;
    _dirtyNotify();
  }

  void setTaxRateText(String value) {
    if (value == _taxRateText) return;
    _taxRateText = value;
    _dirtyNotify();
  }

  void setFooterText(String value) {
    if (value == _footerText) return;
    _footerText = value;
    _dirtyNotify();
  }

  void _dirtyNotify() {
    _state = _state.copyWith(saved: false, saveError: null);
    notifyListeners();
  }

  /// يفتح رافع الشعار (seam) — الصورة كبيرة الحجم تُرفض برسالة واضحة.
  Future<String?> pickLogo() async {
    final picker = _pickLogo;
    if (picker == null) return null;
    final bytes = await picker();
    if (bytes == null) return null;
    if (bytes.length > kCompanyLogoMaxBytes) {
      return 'LOGO_TOO_LARGE';
    }
    _logoPng = bytes;
    _state = _state.copyWith(saved: false);
    notifyListeners();
    return null;
  }

  /// إزالة الشعار (تصفير BLOB).
  void clearLogo() {
    if (_logoPng == null) return;
    _logoPng = null;
    _state = _state.copyWith(saved: false);
    notifyListeners();
  }

  // ── الحفظ ──

  /// تحقق النموذج — رسالة خطأ أو null.
  String? validate() {
    if (name.trim().isEmpty) return 'NAME_REQUIRED';
    final rate = double.tryParse(_taxRateText.trim().replaceAll(',', '.'));
    if (rate == null || rate < 0 || rate > 100) return 'TAX_RATE_INVALID';
    return null;
  }

  /// حفظ التعديلات عبر `update` الذرّي — يعيد true عند النجاح.
  Future<bool> save({int? userId}) async {
    final company = _company;
    if (company == null) return false;
    final failure = validate();
    if (failure != null) {
      _state = _state.copyWith(saveError: failure);
      notifyListeners();
      return false;
    }
    _state = _state.copyWith(saving: true, saveError: null, saved: false);
    notifyListeners();
    final rate = double.tryParse(_taxRateText.trim().replaceAll(',', '.'));
    try {
      final updated = await _companies.update(
        company.copyWith(
          name: name.trim(),
          phone: _emptyToNull(phone),
          whatsapp: _emptyToNull(whatsapp),
          address: _emptyToNull(address),
          taxNumber: _emptyToNull(taxNumber),
          taxRate: rate ?? 0,
          footerText: _emptyToNull(footerText),
          logoPng: _logoPng,
        ),
        userId: userId,
      );
      _company = updated;
      _state = _state.copyWith(saving: false, saved: true);
      notifyListeners();
      return true;
    } catch (error) {
      _state = _state.copyWith(saving: false, saveError: 'SAVE_FAILED');
      if (kDebugMode) {
        debugPrint('CompanyProfileViewModel.save: $error');
      }
      notifyListeners();
      return false;
    }
  }

  /// استهلاك إشعار النجاح (بعد عرضه).
  void consumeSaved() {
    if (!_state.saved) return;
    _state = _state.copyWith(saved: false);
    notifyListeners();
  }

  /// مسح خطأ الحفظ المعروض.
  void clearSaveError() {
    if (_state.saveError == null) return;
    _state = _state.copyWith(saveError: null);
    notifyListeners();
  }

  static String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  static String _formatRate(double rate) =>
      rate == rate.truncateToDouble() ? rate.truncate().toString() : '$rate';
}
