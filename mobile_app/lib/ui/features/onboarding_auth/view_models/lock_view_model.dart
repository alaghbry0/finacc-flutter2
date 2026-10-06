/// نموذج عرض شاشة القفل — سياسة PIN الكاملة (FR-12-06 / AC-15).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/user_repository.dart';
import '../../../../domain/use_cases/pin_policy.dart';
import '../../../core/session/app_controller.dart';

/// واجهة شاشة القفل.
enum LockUiMode { pin, passphrase }

/// الحالة المرئية لبوابة PIN.
class LockGateView {
  const LockGateView({
    required this.mode,
    required this.enabled,
    required this.messageCode,
    required this.remainingDelay,
    required this.attemptsLeftBeforeDelay,
  });

  final LockUiMode mode;

  /// لوحة الأرقام مفعلة؟ (معطلة داخل نافذة الانتظار).
  final bool enabled;

  /// رمز رسالة الحالة (يُترجم في الواجهة).
  final LockMessage? messageCode;

  /// الوقت المتبقي (لعرض العدّاد).
  final Duration remainingDelay;

  /// المحاولات المتبقية قبل بدء التأخير.
  final int attemptsLeftBeforeDelay;
}

/// رسائل حالة البوابة.
enum LockMessage { wrong, delayed, passphraseRequired, passphraseFailed }

class LockViewModel extends ChangeNotifier {
  LockViewModel({UserRepository? userRepository}) : _users = userRepository;

  UserRepository? _users;
  LockUiMode _mode = LockUiMode.pin;
  String _pin = '';
  Object? _shakeKey;
  LockMessage? _message;
  Duration _remaining = Duration.zero;
  int _attemptsBeforeDelay = PinPolicy.passphraseThreshold;
  bool _verifying = false;
  Timer? _ticker;
  bool _wipeOffered = false;

  LockUiMode get mode => _mode;
  String get pin => _pin;
  bool get verifying => _verifying;
  Object? get shakeKey => _shakeKey;
  LockMessage? get message => _message;
  Duration get remaining => _remaining;
  bool get wipeOffered => _wipeOffered;

  /// الحالة المرئية المجمّعة.
  LockGateView get gate => LockGateView(
    mode: _mode,
    enabled: _remaining == Duration.zero && !_verifying,
    messageCode: _message,
    remainingDelay: _remaining,
    attemptsLeftBeforeDelay: _attemptsBeforeDelay,
  );

  void attach(UserRepository users) {
    _users ??= users;
  }

  void addDigit(int digit) {
    if (_pin.length >= 6) return;
    _pin = '$_pin$digit';
    _message = null;
    notifyListeners();
  }

  void backspace() {
    _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1);
    notifyListeners();
  }

  void switchToPassphrase() {
    _mode = LockUiMode.passphrase;
    _message = null;
    notifyListeners();
  }

  void backToPin() {
    _mode = LockUiMode.pin;
    _pin = '';
    _message = null;
    notifyListeners();
  }

  /// تحقق من PIN المُدخل — يفتح الجلسة أو يحدّث حالة السياسة.
  Future<void> submitPin(AppController app) async {
    if (_verifying || _pin.length < 4) return;
    final users = _users;
    if (users == null) return;
    _verifying = true;
    notifyListeners();
    try {
      final outcome = await users.verifyPin(_pin);
      switch (outcome) {
        case PinVerifyOutcome.success:
          app.unlockSession();
          return;
        case PinVerifyOutcome.wrong:
          _message = LockMessage.wrong;
          _shakeKey = Object();
          _pin = '';
          unawaited(_refreshAttempts(users));
        case PinVerifyOutcome.delayed:
          _message = LockMessage.delayed;
          _startTicker(users);
        case PinVerifyOutcome.passphraseRequired:
          _mode = LockUiMode.passphrase;
          _message = LockMessage.passphraseRequired;
          _pin = '';
      }
    } finally {
      _verifying = false;
      notifyListeners();
    }
  }

  /// تحقق من عبارة المرور — يفتح الجلسة أو يعرض خيار المسح.
  Future<void> submitPassphrase(AppController app, String passphrase) async {
    if (_verifying) return;
    final users = _users;
    if (users == null) return;
    _verifying = true;
    notifyListeners();
    try {
      final ok = await users.verifyPassphrase(passphrase);
      if (ok) {
        await users.resetLockout();
        app.unlockSession();
        return;
      }
      _message = LockMessage.passphraseFailed;
      _wipeOffered = true;
    } finally {
      _verifying = false;
      notifyListeners();
    }
  }

  /// مسح كامل بعد التأكيد المزدوج (AC-15).
  Future<void> wipeAll(AppController app) async {
    await app.wipeAllData();
  }

  Future<void> _refreshAttempts(UserRepository users) async {
    // عدد المحاولات الحالية من قاعدة البيانات لعرض «المتبقي قبل التأخير».
    final failed = await users.currentFailedAttempts();
    _attemptsBeforeDelay = (PinPolicy.delayThreshold - failed).clamp(
      0,
      PinPolicy.delayThreshold,
    );
    notifyListeners();
  }

  void _startTicker(UserRepository users) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tick(users));
    });
    // أول نبضة فورية.
    unawaited(_tick(users));
  }

  Future<void> _tick(UserRepository users) async {
    final lockedUntil = await users.currentLockedUntil();
    final now = DateTime.now();
    final remaining = PinPolicy.remainingDelay(
      now: now,
      lockedUntil: lockedUntil,
    );
    if (remaining == Duration.zero) {
      _remaining = Duration.zero;
      _ticker?.cancel();
      _ticker = null;
      _message = null;
      notifyListeners();
      return;
    }
    _remaining = remaining;
    _message = LockMessage.delayed;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @visibleForTesting
  void debugSetStateForTest({
    LockUiMode? mode,
    String? pin,
    LockMessage? message,
    Duration? remaining,
  }) {
    _mode = mode ?? _mode;
    _pin = pin ?? _pin;
    _message = message;
    _remaining = remaining ?? _remaining;
    notifyListeners();
  }
}
