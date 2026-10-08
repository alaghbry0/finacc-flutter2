/// نموذج عرض شاشة الإعدادات — يجمع بيانات المنشأة والأمان والحالة
/// في تحميل واحد (لا مسودة شاشة بيضاء — Skeleton أثناء التحميل).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/services/backup/backup_service.dart';
import '../../../../domain/models/company.dart';

/// بيانات شاشة الإعدادات مجمّعة.
class SettingsData {
  const SettingsData({
    required this.loading,
    this.company,
    this.baseCurrency,
    this.adminName,
    this.autolockMinutes = 5,
    this.themeMode = 'system',
    this.dbSizeBytes,
    this.error,
  });

  final bool loading;
  final Company? company;
  final Currency? baseCurrency;
  final String? adminName;
  final int autolockMinutes;
  final String themeMode;

  /// حجم ملف القاعدة بالبايت (بند «حول» — FR-13-07) أو null.
  final int? dbSizeBytes;

  final Object? error;
}

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required CompanyRepository companyRepo,
    required UserRepository userRepo,
    required SettingsRepository settingsRepo,
    BackupService? backupEngine,
  }) : _companies = companyRepo,
       _users = userRepo,
       _settings = settingsRepo,
       _backup = backupEngine;

  final CompanyRepository _companies;
  final UserRepository _users;
  final SettingsRepository _settings;

  /// محرك النسخ — لحجم القاعدة في بند «حول» (اختياري).
  final BackupService? _backup;

  SettingsData _state = const SettingsData(loading: true);
  SettingsData get state => _state;

  /// تحميل كامل (مرة عند فتح الشاشة، وبعد أي تغيير جوهري).
  Future<void> load() async {
    _state = SettingsData(
      loading: true,
      company: _state.company,
      baseCurrency: _state.baseCurrency,
      adminName: _state.adminName,
      autolockMinutes: _state.autolockMinutes,
      themeMode: _state.themeMode,
      dbSizeBytes: _state.dbSizeBytes,
    );
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _companies.findCompany(),
        _companies.findBaseCurrency(),
        _users.adminDisplayName(),
        _settings.autolockMinutes(),
        _settings.themeMode(),
        _backup == null
            ? Future<Object?>.value(null)
            : _backup.databaseFileSize(),
      ]);
      _state = SettingsData(
        loading: false,
        company: results[0] as Company?,
        baseCurrency: results[1] as Currency?,
        adminName: results[2] as String?,
        autolockMinutes: results[3] as int,
        themeMode: results[4] as String,
        dbSizeBytes: results[5] as int?,
      );
    } catch (error) {
      _state = SettingsData(
        loading: false,
        company: _state.company,
        baseCurrency: _state.baseCurrency,
        adminName: _state.adminName,
        autolockMinutes: _state.autolockMinutes,
        themeMode: _state.themeMode,
        dbSizeBytes: _state.dbSizeBytes,
        error: error,
      );
    }
    notifyListeners();
  }
}

/// نموذج عرض تدفق تغيير PIN: الحالي ← الجديد ← التأكيد.
class ChangePinViewModel extends ChangeNotifier {
  ChangePinViewModel({required UserRepository userRepo}) : _users = userRepo;

  final UserRepository _users;

  /// خطوات التدفق.
  int _step = 0; // 0 = الحالي، 1 = الجديد، 2 = التأكيد، 3 = تم.
  String _currentPin = '';
  String _newPin = '';
  String _confirmedPin = '';
  String? _errorKey;
  bool _submitting = false;

  int get step => _step;
  bool get submitting => _submitting;
  String? get errorKey => _errorKey;

  /// طول الخانة الحالية (للنقاط).
  int get dotLength => 6;

  /// النص المُدخل للخطوة الحالية (يعكس المخزن الصحيح لكل خطوة —
  /// النقاط وزر المتابعة يقرآن منه).
  String get entered => switch (_step) {
    0 => _currentPin,
    1 => _newPin,
    _ => _confirmedPin,
  };

  /// النص الفرعي لكل خطوة (يُترجم في العرض عبر المفاتيح).
  String get subtitleKey => switch (_step) {
    0 => 'changePinStepCurrent',
    1 => 'changePinStepNew',
    2 => 'changePinStepConfirm',
    _ => 'changePinStepDone',
  };

  /// يضيف خانة (من لوحة PIN) ويتقدم تلقائياً عند الاكتمال.
  void addDigit(int d) {
    if (_submitting) return;
    _errorKey = null;
    if (_step == 0) {
      if (_currentPin.length >= 6) return;
      _currentPin += '$d';
    } else if (_step == 1) {
      if (_newPin.length >= 6) return;
      _newPin += '$d';
    } else {
      if (_confirmedPin.length >= 6) return;
      _confirmedPin += '$d';
    }
    notifyListeners();
  }

  /// مسح خانة.
  void backspace() {
    if (_submitting) return;
    _errorKey = null;
    if (_step == 0) {
      _currentPin = _currentPin.isEmpty
          ? ''
          : _currentPin.substring(0, _currentPin.length - 1);
    } else if (_step == 1) {
      _newPin = _newPin.isEmpty ? '' : _newPin.substring(0, _newPin.length - 1);
    } else {
      _confirmedPin = _confirmedPin.isEmpty
          ? ''
          : _confirmedPin.substring(0, _confirmedPin.length - 1);
    }
    notifyListeners();
  }

  /// إرسال الخطوة الحالية (زر «متابعة»/الاكتمال).
  Future<bool> submit() async {
    if (_submitting) return false;
    switch (_step) {
      case 0:
        if (_currentPin.length < 4) {
          _errorKey = 'pinShort';
          notifyListeners();
          return false;
        }
        _step = 1;
        notifyListeners();
        return true;
      case 1:
        if (_newPin.length < 4) {
          _errorKey = 'pinShort';
          notifyListeners();
          return false;
        }
        _step = 2;
        notifyListeners();
        return true;
      case 2:
        if (_confirmedPin.length < 4) {
          _errorKey = 'pinShort';
          notifyListeners();
          return false;
        }
        if (_confirmedPin != _newPin) {
          _errorKey = 'pinMismatch';
          _confirmedPin = '';
          notifyListeners();
          return false;
        }
        if (_newPin == _currentPin) {
          _errorKey = 'sameAsCurrent';
          _confirmedPin = '';
          notifyListeners();
          return false;
        }
        _submitting = true;
        notifyListeners();
        final outcome = await _users.changePin(_currentPin, _newPin);
        _submitting = false;
        switch (outcome) {
          case PinChangeOutcome.success:
            _step = 3;
            _errorKey = null;
            notifyListeners();
            return true;
          case PinChangeOutcome.wrongCurrent:
            _errorKey = 'wrongCurrent';
            _currentPin = '';
            _confirmedPin = '';
            _step = 0;
            notifyListeners();
            return false;
          case PinChangeOutcome.invalidLength:
            _errorKey = 'pinShort';
            notifyListeners();
            return false;
          case PinChangeOutcome.noPin:
            _errorKey = 'noPin';
            notifyListeners();
            return false;
        }
      default:
        return false;
    }
  }

  /// إعادة التدفق من البداية (بعد النجاح أو الخروج).
  void reset() {
    _step = 0;
    _currentPin = '';
    _newPin = '';
    _confirmedPin = '';
    _errorKey = null;
    _submitting = false;
    notifyListeners();
  }
}
