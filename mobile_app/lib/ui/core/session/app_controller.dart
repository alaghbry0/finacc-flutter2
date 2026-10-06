/// متحكم الجلسة — دورة حياة التطبيق: تهيئة → تأسيس/قفل → جاهز.
///
/// يملك محرك القاعدة والمستودعات (تُنشأ بعد نجاح الفتح) وحالة القفل
/// التلقائي بعد الخمول (FR-12-05 — `security.autolock_minutes`).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/db_factory.dart';
import '../../../domain/models/company.dart';
import '../../../data/repositories/company_repository.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/user_repository.dart';

/// أطوار التطبيق المرئية.
enum AppPhase {
  /// فتح القاعدة والتحقق الأولي جارٍ.
  initializing,

  /// لا منشأة بعد — Onboarding.
  needsOnboarding,

  /// مقفل — شاشة PIN/عبارة المرور.
  locked,

  /// جاهز للعمل.
  ready,

  /// فشل فتح القاعدة — ErrorState مع إعادة محاولة (DS-33).
  error,
}

/// التحكم بحياة الجلسة كاملة.
class AppController extends ChangeNotifier {
  AppController({AppDatabase? forTesting}) {
    if (forTesting != null) {
      _adopt(forTesting);
    }
  }

  AppPhase _phase = AppPhase.initializing;
  String? _errorDetails;
  AppDatabase? _db;
  CompanyRepository? _companyRepo;
  UserRepository? _userRepo;
  SettingsRepository? _settingsRepo;
  DashboardRepository? _dashboardRepo;
  Company? _company;

  DateTime _lastActivity = DateTime.now();
  DateTime? _hiddenAt;
  Timer? _idleTicker;
  int _autolockMinutes = 5;

  /// وضع الثيم المحفوظ (`system`/`light`/`dark`) — يُقرأ عند التهيئة
  /// ويُكتب فور التبديل من شاشة الإعدادات (حالة نظامية في settings).
  String _themeMode = 'system';

  /// الطور الحالي.
  AppPhase get phase => _phase;

  /// تفاصيل فشل الفتح (للعرض التقني القابل للتوسيع — DS-33).
  String? get errorDetails => _errorDetails;

  /// محرك القاعدة (بعد نجاح التهيئة).
  AppDatabase? get database => _db;

  CompanyRepository? get companies => _companyRepo;

  UserRepository? get users => _userRepo;

  SettingsRepository? get settings => _settingsRepo;

  DashboardRepository? get dashboard => _dashboardRepo;

  /// المنشأة الحالية (بعد التأسيس).
  Company? get company => _company;

  /// وضع الثيم الحالي (نص خام قابل للحفظ — يُحوّله العرض إلى ThemeMode).
  String get themeMode => _themeMode;

  /// يبدأ التهيئة (يُستدعى مرة عند الإقلاع).
  Future<void> bootstrap() async {
    _phase = AppPhase.initializing;
    _errorDetails = null;
    notifyListeners();
    try {
      final db = await AppDatabase.open();
      _adopt(db);
      await _decidePhase();
    } catch (error) {
      _phase = AppPhase.error;
      _errorDetails = error.toString();
      notifyListeners();
    }
  }

  /// اعتماد قاعدة مفتوحة (وضع الاختبار أو إعادة التهيئة بعد المسح).
  void _adopt(AppDatabase db) {
    _db = db;
    _companyRepo = CompanyRepository(db.db);
    _userRepo = UserRepository(db.db);
    _settingsRepo = SettingsRepository(db.db);
    _dashboardRepo = DashboardRepository(db.db);
  }

  Future<void> _decidePhase() async {
    final company = await _companyRepo!.findCompany();
    _company = company;
    _autolockMinutes = await _settingsRepo!.autolockMinutes();
    _themeMode = await _settingsRepo!.themeMode();
    // جلسة جديدة = مقفلة دائماً (PIN عند كل فتح — FR-12-01).
    _phase = company == null ? AppPhase.needsOnboarding : AppPhase.locked;
    notifyListeners();
  }

  /// يُستدعى بعد إتمام Onboarding — تحديث المنشأة والدخول للجلسة.
  Future<void> completeOnboarding() async {
    _company = await _companyRepo!.findCompany();
    _autolockMinutes = await _settingsRepo!.autolockMinutes();
    _enterSession();
  }

  /// فتح القفل بعد تحقق PIN/عبارة المرور.
  void unlockSession() => _enterSession();

  void _enterSession() {
    _phase = AppPhase.ready;
    _lastActivity = DateTime.now();
    _startIdleWatch();
    notifyListeners();
  }

  /// قفل يدوي أو تلقائي.
  void lock() {
    if (_phase != AppPhase.ready) return;
    _phase = AppPhase.locked;
    _idleTicker?.cancel();
    _idleTicker = null;
    notifyListeners();
  }

  // ── وضع الثيم ──

  /// يثبّت وضع الثيم محلياً وفي القاعدة (يستدعيه شاشة الإعدادات).
  Future<void> setThemeMode(String mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      await _settingsRepo?.setThemeMode(mode);
    } catch (_) {
      // فشل الحفظ لا يكسر الجلسة — القيمة تُقرأ مجدداً عند الإقلاع.
    }
  }

  // ── القفل التلقائي بعد الخمول (FR-12-05) ──

  /// لمس أي عنصر — تجديد النشاط.
  void touch() {
    _lastActivity = DateTime.now();
  }

  void _startIdleWatch() {
    _idleTicker?.cancel();
    _idleTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_phase != AppPhase.ready) return;
      final idleFor = DateTime.now().difference(_lastActivity);
      if (idleFor.inMinutes >= _autolockMinutes) {
        lock();
      }
    });
  }

  /// التطبيق صار خلفياً — يبدأ عدّ الخمول.
  void appHidden() {
    _hiddenAt ??= DateTime.now();
  }

  /// عاد التطبيق للأمام — قفل إن تجاوز الغياب الحد.
  void appResumed() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null) return;
    if (_phase != AppPhase.ready) return;
    final away = DateTime.now().difference(hiddenAt);
    if (away.inMinutes >= _autolockMinutes) {
      lock();
    } else {
      touch();
    }
  }

  /// مسح كامل — إغلاق ومحو القاعدة ثم إعادة التهيئة فارغة (AC-15).
  Future<void> wipeAllData() async {
    final db = _db;
    final dbFactory = platformDatabaseFactory;
    final path = await resolveDatabasePath();
    _idleTicker?.cancel();
    _idleTicker = null;
    _company = null;
    _companyRepo = null;
    _userRepo = null;
    _settingsRepo = null;
    _dashboardRepo = null;
    _db = null;
    if (db != null) {
      await db.close();
    }
    await dbFactory.deleteDatabase(path);
    await bootstrap();
  }

  @override
  void dispose() {
    _idleTicker?.cancel();
    super.dispose();
  }
}
