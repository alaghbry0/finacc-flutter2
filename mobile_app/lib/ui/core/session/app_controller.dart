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
import '../../../data/repositories/audit_repository.dart';
import '../../../data/repositories/batch_repository.dart';
import '../../../data/repositories/cash_repository.dart';
import '../../../data/repositories/company_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../data/repositories/exchange_rate_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/purchase_repository.dart';
import '../../../data/repositories/print_template_repository.dart';
import '../../../data/repositories/quotation_repository.dart';
import '../../../data/repositories/return_repository.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/services/backup/backup_service.dart';
import '../../../data/services/backup/backup_store.dart';
import '../../../data/services/backup/backup_store_factory.dart';

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

/// نتيجة المسح الكامل (AC-15) — نجاح أو حجب بفشل نسخة الأمان.
sealed class WipeOutcome {
  const WipeOutcome();
}

/// نجح المسح — `safetyBackupFileName` اسم ملف نسخة الأمان التي أُنشئت
/// قبله مباشرة (null على منصة بلا ملفات: معاينة الويب).
class WipeSucceeded extends WipeOutcome {
  const WipeSucceeded({this.safetyBackupFileName});

  final String? safetyBackupFileName;
}

/// حجب المسح — فشل إنشاء نسخة الأمان الإجبارية ولم يُمسَح أي شيء؛
/// المتصل يعرض الخيار (إعادة المحاولة أو متابعة صريحة بلا نسخة).
class WipeBlockedByBackupFailure extends WipeOutcome {
  const WipeBlockedByBackupFailure(this.errorDetails);

  final String errorDetails;
}

/// التحكم بحياة الجلسة كاملة.
class AppController extends ChangeNotifier {
  AppController({AppDatabase? forTesting, BackupFileStore? backupStoreOverride})
    : _testBackupStore = backupStoreOverride {
    if (forTesting != null) {
      _adopt(forTesting);
    }
  }

  /// مخزن ملفات النسخ المحقون (اختبارات الاستعادة) — null في الإنتاج.
  final BackupFileStore? _testBackupStore;

  AppPhase _phase = AppPhase.initializing;
  String? _errorDetails;
  AppDatabase? _db;
  CompanyRepository? _companyRepo;
  UserRepository? _userRepo;
  SettingsRepository? _settingsRepo;
  DashboardRepository? _dashboardRepo;
  AuditRepository? _auditRepo;
  ItemRepository? _itemRepo;
  BatchRepository? _batchRepo;
  CustomerRepository? _customerRepo;
  SupplierRepository? _supplierRepo;
  ExchangeRateRepository? _fxRepo;
  SaleRepository? _saleRepo;
  QuotationRepository? _quotationRepo;
  PurchaseRepository? _purchaseRepo;
  ReturnRepository? _returnRepo;
  CashRepository? _cashRepo;
  PrintTemplateRepository? _printTemplateRepo;
  BackupService? _backupSvc;
  Company? _company;

  DateTime _lastActivity = DateTime.now();
  DateTime? _hiddenAt;
  Timer? _idleTicker;
  int _autolockMinutes = 5;

  /// وضع الثيم المحفوظ (`system`/`light`/`dark`) — يُقرأ عند التهيئة
  /// ويُكتب فور التبديل من شاشة الإعدادات (حالة نظامية في settings).
  String _themeMode = 'system';

  /// نظام الأرقام المحفوظ (`display.numerals` — western/arabic_indic).
  String _numerals = 'western';

  /// حجم الخط المحفوظ (`display.font_scale` — normal/large/xlarge، UX-2a).
  String _fontScale = 'normal';

  /// التباين العالي المحفوظ (`ui.high_contrast` — UX-2a وصله بالثيم).
  bool _highContrast = false;

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

  /// مستودع سجل التدقيق (للإضافة فقط — عرض حصري).
  AuditRepository? get audit => _auditRepo;

  /// مستودع الأصناف (المرحلة 2 — FR-01).
  ItemRepository? get items => _itemRepo;

  /// مستودع الدفعات وتواريخ الصلاحية (FEFO — FR-01-10).
  BatchRepository? get batches => _batchRepo;

  /// مستودع العملاء (المرحلة 3 — FR-03).
  CustomerRepository? get customers => _customerRepo;

  /// مستودع الموردين (المرحلة 3 — FR-03-03).
  SupplierRepository? get suppliers => _supplierRepo;

  /// مستودع أسعار الصرف اليومية (FR-08-03).
  ExchangeRateRepository? get fxRates => _fxRepo;

  /// مستودع ترحيل فواتير البيع (المرحلة 4 — FR-02).
  SaleRepository? get sales => _saleRepo;

  /// مستودع عروض الأسعار وتحويلها (المرحلة 4 — FR-02).
  QuotationRepository? get quotations => _quotationRepo;

  /// مستودع المشتريات (المرحلة 5 — FR-02-08: PUR + WAC + الدفعات الواردة).
  PurchaseRepository? get purchases => _purchaseRepo;

  /// مستودع المرتجعات المرتبطة (المرحلة 5 — FR-02-07/08: SRN وPRN).
  ReturnRepository? get returns => _returnRepo;

  /// مستودع النقدية والصناديق (المرحلة 6 — FR-04).
  CashRepository? get cash => _cashRepo;

  /// مستودع قوالب الطباعة (موجة UX-3) — القالب النشط لفواتير البيع.
  PrintTemplateRepository? get printTemplates => _printTemplateRepo;

  /// محرك النسخ الاحتياطي والاستعادة (الشريحة 8 — FR-11) — يُنشأ مع
  /// كل قاعدة مفتوحة (جاهز بعد bootstrap) ويتجدد تلقائياً بعد أي استعادة.
  BackupService? get backupEngine => _backupSvc;

  /// المنشأة الحالية (بعد التأسيس).
  Company? get company => _company;

  /// وضع الثيم الحالي (نص خام قابل للحفظ — يُحوّله العرض إلى ThemeMode).
  String get themeMode => _themeMode;

  /// نظام الأرقام الحالي (`western` / `arabic_indic`).
  String get numerals => _numerals;

  /// حجم الخط الحالي (`normal` / `large` / `xlarge` — UX-2a).
  String get fontScale => _fontScale;

  /// معامل تكبير الخط الحالي (normal = 1.0 بلا تجاوز MediaQuery).
  double get fontScaleFactor => switch (_fontScale) {
    'large' => 1.15,
    'xlarge' => 1.3,
    _ => 1.0,
  };

  /// التباين العالي مفعّل؟ (ثيم أسطح صافية ونصوص قصوى — FR-13-05).
  bool get highContrast => _highContrast;

  /// مدة القفل التلقائي الحالية بالدقائق.
  int get autolockMinutes => _autolockMinutes;

  // ── استعادة الموقع بعد فتح القفل (P0-1b) ──

  /// آخر مسار غير القفل قبل تفعيل القفل — يعود إليه المستخدم بعد الفتح
  /// بدل إسقاطه على الرئيسية دائماً (فقدان سياق العمل عند القفل التلقائي).
  String? _lockedFromPath;

  /// يسجّل الموقع المقصود قبل تحويل القفل إليه (يستدعيه redirect الموجّه).
  /// **المسار فقط بلا نصوص استعلام** — لا بيانات حساسة تُخزّن في الذاكة،
  /// ومسارات القفل/الإقلاع/التأسيس تُتجاهل منعاً لحلقات إعادة التوجيه.
  void noteLockedFrom(String path) {
    if (path == '/lock' || path == '/splash' || path == '/onboarding') {
      return;
    }
    _lockedFromPath = path;
  }

  /// وجهة العودة بعد فتح القفل — تُستهلك مرة واحدة (null = الرئيسية).
  String? consumeUnlockDestination() {
    final path = _lockedFromPath;
    _lockedFromPath = null;
    return path;
  }

  /// آخر مسار سُجّل قبل القفل (اختبارات).
  @visibleForTesting
  String? get lockedFromPathForTest => _lockedFromPath;

  /// هل الأرقام عربية شرقية الآن؟ (اختصار للعرض).
  bool get arabicIndicNumerals => _numerals == 'arabic_indic';

  /// يبدأ التهيئة (يُستدعى مرة عند الإقلاع).
  Future<void> bootstrap() async {
    _phase = AppPhase.initializing;
    _errorDetails = null;
    notifyListeners();
    try {
      // شبكة أمان الاستعادة (FR-11-02): علامة متروكة = استعادة قُطعت
      // بالمنتصف → إرجاع القاعدة القديمة قبل أي فتح.
      await BackupService.recoverInterruptedRestoreIfAny();
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
    _auditRepo = AuditRepository(db.db);
    _itemRepo = ItemRepository(db.db);
    _batchRepo = BatchRepository(db.db);
    _customerRepo = CustomerRepository(db.db);
    _supplierRepo = SupplierRepository(db.db);
    _fxRepo = ExchangeRateRepository(db.db);
    _saleRepo = SaleRepository(db.db);
    _quotationRepo = QuotationRepository(db.db);
    _purchaseRepo = PurchaseRepository(db.db);
    _returnRepo = ReturnRepository(db.db);
    _cashRepo = CashRepository(db.db);
    _printTemplateRepo = PrintTemplateRepository(db.db);
    // محرك النسخ يُبنى لاحقاً (يحتاج حل مسار المنصة غير المتزامن).
    _backupSvc = null;
  }

  /// يبني محرك النسخ فوق القاعدة الحالية (مخزن الاختبار إن وُجد).
  Future<void> _initBackupEngine() async {
    final db = _db;
    final settings = _settingsRepo;
    if (db == null || settings == null) return;
    try {
      final store = _testBackupStore ?? await _defaultBackupStore();
      _backupSvc = BackupService(
        database: db,
        settings: settings,
        store: store,
      );
    } catch (_) {
      _backupSvc = null;
    }
  }

  /// مخزن ملفات النسخ الافتراضي للمنصة (يُستبدل في الاختبارات بالحقن).
  Future<BackupFileStore> _defaultBackupStore() {
    return defaultBackupFileStore();
  }

  /// يضمن تهيئة محرك النسخ إن لم يكن جاهزاً (idempotent) — تستدعيه شاشة
  /// النسخ عند الفتح كشبكة أمان إن تعذّرت التهيئة وقت الإقلاع.
  Future<void> ensureBackupEngine() async {
    if (_backupSvc == null) {
      await _initBackupEngine();
    }
  }

  Future<void> _decidePhase() async {
    final company = await _companyRepo!.findCompany();
    _company = company;
    _autolockMinutes = await _settingsRepo!.autolockMinutes();
    _themeMode = await _settingsRepo!.themeMode();
    _numerals = await _settingsRepo!.numerals();
    _fontScale = await _settingsRepo!.fontScale();
    _highContrast = await _settingsRepo!.highContrast();
    // بذر فئة «رواتب» idempotent (FR-04-05) — قبل أي واجهة.
    await _cashRepo!.ensureSeeded();
    // محرك النسخ الاحتياطي (الشريحة 8) — بعد نجاح كل ما سبق.
    await _initBackupEngine();
    // جلسة جديدة = مقفلة دائماً (PIN عند كل فتح — FR-12-01).
    _phase = company == null ? AppPhase.needsOnboarding : AppPhase.locked;
    notifyListeners();
  }

  /// إعادة قراءة حالة الجلسة من القاعدة (اختبارات — نفس منطق الإقلاع
  /// فوق قاعدة اختبار معتمدة عبر `forTesting`).
  @visibleForTesting
  Future<void> decidePhaseForTest() => _decidePhase();

  /// يُستدعى بعد إتمام Onboarding — تحديث المنشأة والدخول للجلسة.
  Future<void> completeOnboarding() async {
    _company = await _companyRepo!.findCompany();
    _autolockMinutes = await _settingsRepo!.autolockMinutes();
    _numerals = await _settingsRepo!.numerals();
    _fontScale = await _settingsRepo!.fontScale();
    _highContrast = await _settingsRepo!.highContrast();
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

  // ── نظام الأرقام (`display.numerals`) ──

  /// يثبّت نظام الأرقام محلياً وفي القاعدة — ينعكس فوراً على كل
  /// المبالغ والتواريخ (AmountText وخط التاريخ في الداشبورد).
  Future<void> setNumerals(String mode) async {
    if (mode != 'western' && mode != 'arabic_indic') return;
    if (mode == _numerals) return;
    _numerals = mode;
    notifyListeners();
    try {
      await _settingsRepo?.setNumerals(mode);
    } catch (_) {
      // فشل الحفظ لا يكسر الجلسة — القيمة تُقرأ مجدداً عند الإقلاع.
    }
  }

  // ── حجم الخط (`display.font_scale` — UX-2a) ──

  /// يثبّت حجم الخط محلياً وفي القاعدة — textScaler التطبيق كله يتغير
  /// فوراً (يُطبّقه جذر التطبيق من [fontScaleFactor]).
  Future<void> setFontScale(String mode) async {
    if (mode != 'normal' && mode != 'large' && mode != 'xlarge') return;
    if (mode == _fontScale) return;
    _fontScale = mode;
    notifyListeners();
    try {
      await _settingsRepo?.setFontScale(mode);
    } catch (_) {
      // فشل الحفظ لا يكسر الجلسة — القيمة تُقرأ مجدداً عند الإقلاع.
    }
  }

  // ── التباين العالي (`ui.high_contrast` — UX-2a) ──

  /// يثبّت التباين العالي محلياً وفي القاعدة — الثيم يتبدّل فوراً
  /// (جذر التطبيق يبني FinTheme بوضع التباين العالي).
  Future<void> setHighContrast(bool on) async {
    if (on == _highContrast) return;
    _highContrast = on;
    notifyListeners();
    try {
      await _settingsRepo?.setHighContrast(on);
    } catch (_) {
      // فشل الحفظ لا يكسر الجلسة — القيمة تُقرأ مجدداً عند الإقلاع.
    }
  }

  // ── مدة القفل التلقائي (FR-12-05 — `security.autolock_minutes`) ──

  /// يستعيد نسخة احتياطية من بايتات ملف (FR-11-02) — تنسيق كامل:
  /// الخدمة تتحقق وتؤمّن وتستبدل وتفتح، والمتحكم يتبنّى النتيجة:
  /// النجاح = مستودعات جديدة + إعادة تحديد الطور (قفل/تأسيس)؛ والفشل
  /// بعد الإغلاق = إعادة تبنّي القاعدة القديمة دون تغيير الطور.
  Future<RestoreResult> restoreBackupFromBytes(
    Uint8List bytes, {
    String? sourceName,
  }) async {
    var svc = _backupSvc;
    if (svc == null) {
      await _initBackupEngine();
      svc = _backupSvc;
    }
    if (svc == null) {
      return const RestoreFailure(RestoreFailureReason.unsupportedPlatform);
    }
    final result = await svc.restoreFromBytes(bytes, sourceName: sourceName);
    switch (result) {
      case final RestoreSuccess success:
        _idleTicker?.cancel();
        _idleTicker = null;
        _adopt(success.newDatabase);
        await _decidePhase();
        return result;
      case final RestoreFailure failure:
        final reopened = failure.reopenedDatabase;
        if (reopened != null) {
          // بيانات المستخدم لم تتغير — الجلسة تكمل بالمستودعات المعاد
          // فتحها (نفس القاعدة القديمة بعد الإرجاع).
          _adopt(reopened);
          notifyListeners();
        }
        return result;
    }
  }

  /// يثبّت مدة القفل التلقائي (1–60 دقيقة) — تُطبَّق فوراً على مراقب
  /// الخمول الجاري دون قفل الجلسة، مع قيد تدقيق للتغيير الأمني.
  Future<void> setAutolockMinutes(int minutes) async {
    if (minutes == _autolockMinutes) return;
    if (minutes < 1 || minutes > 60) {
      throw ArgumentError('مدة القفل التلقائي خارج النطاق 1–60: $minutes');
    }
    _autolockMinutes = minutes;
    notifyListeners();
    try {
      await _settingsRepo?.setAutolockMinutes(minutes);
      // قيد تدقيق للتغييرات الأمنية (FR-12-04 — أحداث موسّعة).
      await _userRepo?.audit(
        'settings_change',
        entity: 'settings',
        details: 'security.autolock_minutes=$minutes',
      );
    } catch (_) {
      // فشل الحفظ لا يكسر الجلسة — القيمة تُقرأ مجدداً عند الإقلاع.
    }
  }

  // ── القفل التلقائي بعد الخمول (FR-12-05) ──

  /// لمس أي عنصر — تجديد النشاط.
  void touch() {
    _lastActivity = DateTime.now();
  }

  /// لحظة آخر نشاط (اختبارات — مراقبة الخمول).
  @visibleForTesting
  DateTime get lastActivityForTest => _lastActivity;

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

  /// مسح كامل — **نسخة أمان إجبارية أولاً** (درس التراجع الحالي أصلاً:
  /// مسح بلا نسخة أخيرة = ضياع نهائي)، ثم إغلاق ومحو القاعدة ثم إعادة
  /// التهيئة فارغة (AC-15).
  ///
  /// فشل نسخة الأمان على منصة مدعومة **يحجب المسح** (لم يُمسَح شيء) —
  /// والمتصل يعرض الخيار: إعادة المحاولة أو المتابعة بلا نسخة صراحةً
  /// عبر [skipSafetyBackup]. نوع النسخة = «نسخة أمان» القائم
  /// (`pre_restore`) — قيد DDL المجمّد لا يعرف `pre_wipe` بعد (إضافة
  /// المفردة هجرة تقرّرها موجة التنسيق).
  Future<WipeOutcome> wipeAllData({bool skipSafetyBackup = false}) async {
    String? safetyBackupFileName;
    if (!skipSafetyBackup) {
      await ensureBackupEngine();
      final svc = _backupSvc;
      if (svc != null && svc.isSupported) {
        final safety = await svc.createBackup(kind: BackupKind.preRestore);
        if (!safety.ok) {
          return WipeBlockedByBackupFailure(
            safety.errorDetails ?? 'unknown backup failure',
          );
        }
        safetyBackupFileName = safety.fileName;
      }
    }
    final db = _db;
    final dbFactory = platformDatabaseFactory;
    final path = await resolveDatabasePath();
    _idleTicker?.cancel();
    _idleTicker = null;
    _company = null;
    _lockedFromPath = null;
    _companyRepo = null;
    _userRepo = null;
    _settingsRepo = null;
    _dashboardRepo = null;
    _auditRepo = null;
    _itemRepo = null;
    _batchRepo = null;
    _customerRepo = null;
    _supplierRepo = null;
    _fxRepo = null;
    _saleRepo = null;
    _quotationRepo = null;
    _purchaseRepo = null;
    _returnRepo = null;
    _cashRepo = null;
    _printTemplateRepo = null;
    _backupSvc = null;
    _db = null;
    if (db != null) {
      await db.close();
    }
    await dbFactory.deleteDatabase(path);
    await bootstrap();
    return WipeSucceeded(safetyBackupFileName: safetyBackupFileName);
  }

  @override
  void dispose() {
    _idleTicker?.cancel();
    super.dispose();
  }
}
