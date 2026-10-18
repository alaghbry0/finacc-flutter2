/// متحكم الجلسة — دورة حياة التطبيق: تهيئة → تأسيس/قفل → جاهز.
///
/// يملك محرك القاعدة ومستودعات الجلسة (تُنشأ بعد نجاح الفتح) وحالة
/// القفل التلقائي بعد الخمول (FR-12-05 — `security.autolock_minutes`).
///
/// R20-D1 (فرصتا فصل R19-D1 الأولى والرابعة): المستودعات الستة عشر
/// صارت حاوية واحدة متماسكة ([AppRepositories]) — بناء في `_adopt`
/// وتصفير في المسح بعملية واحدة؛ ومراقب الخمول (المؤقّت وآخر نشاط
/// والغياب ومدة القفل) وحدة مستقلة ([AutoLockWatcher]) يملكها هذا
/// المتحكم. الواجهة العامة لم تتغير حرفاً واحداً (فاصل خالص).
library;

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
import 'app_repositories.dart';
import 'auto_lock_watcher.dart';

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
    // المراقب يستلم حالة الجاهزية وفعل القفل من المتحكم نفسه.
    _autolock = AutoLockWatcher(
      isSessionReady: () => _phase == AppPhase.ready,
      onLock: lock,
    );
    if (forTesting != null) {
      _adopt(forTesting);
    }
  }

  /// مخزن ملفات النسخ المحقون (اختبارات الاستعادة) — null في الإنتاج.
  final BackupFileStore? _testBackupStore;

  AppPhase _phase = AppPhase.initializing;
  String? _errorDetails;
  AppDatabase? _db;

  /// مستودعات الجلسة الستة عشر — حاوية واحدة (R20-D1): تُبنى في
  /// `_adopt` وتُصفَّر في المسح، وكل getters أدناه تفوّض إليها.
  AppRepositories? _repos;

  /// مراقب القفل التلقائي — مؤقّت الخمول وآخر نشاط وغياب التطبيق
  /// (R20-D1): وحدة مستقلة يستضيفها هذا المتحكم.
  late final AutoLockWatcher _autolock;

  BackupService? _backupSvc;
  Company? _company;

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

  CompanyRepository? get companies => _repos?.companies;

  UserRepository? get users => _repos?.users;

  SettingsRepository? get settings => _repos?.settings;

  DashboardRepository? get dashboard => _repos?.dashboard;

  /// مستودع سجل التدقيق (للإضافة فقط — عرض حصري).
  AuditRepository? get audit => _repos?.audit;

  /// مستودع الأصناف (المرحلة 2 — FR-01).
  ItemRepository? get items => _repos?.items;

  /// مستودع الدفعات وتواريخ الصلاحية (FEFO — FR-01-10).
  BatchRepository? get batches => _repos?.batches;

  /// مستودع العملاء (المرحلة 3 — FR-03).
  CustomerRepository? get customers => _repos?.customers;

  /// مستودع الموردين (المرحلة 3 — FR-03-03).
  SupplierRepository? get suppliers => _repos?.suppliers;

  /// مستودع أسعار الصرف اليومية (FR-08-03).
  ExchangeRateRepository? get fxRates => _repos?.fxRates;

  /// مستودع ترحيل فواتير البيع (المرحلة 4 — FR-02).
  SaleRepository? get sales => _repos?.sales;

  /// مستودع عروض الأسعار وتحويلها (المرحلة 4 — FR-02).
  QuotationRepository? get quotations => _repos?.quotations;

  /// مستودع المشتريات (المرحلة 5 — FR-02-08: PUR + WAC + الدفعات الواردة).
  PurchaseRepository? get purchases => _repos?.purchases;

  /// مستودع المرتجعات المرتبطة (المرحلة 5 — FR-02-07/08: SRN وPRN).
  ReturnRepository? get returns => _repos?.returns;

  /// مستودع النقدية والصناديق (المرحلة 6 — FR-04).
  CashRepository? get cash => _repos?.cash;

  /// مستودع قوالب الطباعة (موجة UX-3) — القالب النشط لفواتير البيع.
  PrintTemplateRepository? get printTemplates => _repos?.printTemplates;

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
  int get autolockMinutes => _autolock.autolockMinutes;

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
    _repos = AppRepositories(db);
    // محرك النسخ يُبنى لاحقاً (يحتاج حل مسار المنصة غير المتزامن).
    _backupSvc = null;
  }

  /// يبني محرك النسخ فوق القاعدة الحالية (مخزن الاختبار إن وُجد).
  Future<void> _initBackupEngine() async {
    final db = _db;
    final repos = _repos;
    if (db == null || repos == null) return;
    try {
      final store = _testBackupStore ?? await _defaultBackupStore();
      _backupSvc = BackupService(
        database: db,
        settings: repos.settings,
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
    final repos = _repos!;
    final company = await repos.companies.findCompany();
    _company = company;
    _autolock.setAutolockMinutes(await repos.settings.autolockMinutes());
    _themeMode = await repos.settings.themeMode();
    _numerals = await repos.settings.numerals();
    _fontScale = await repos.settings.fontScale();
    _highContrast = await repos.settings.highContrast();
    // بذر فئة «رواتب» idempotent (FR-04-05) — قبل أي واجهة.
    await repos.cash.ensureSeeded();
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
    final repos = _repos!;
    _company = await repos.companies.findCompany();
    _autolock.setAutolockMinutes(await repos.settings.autolockMinutes());
    _numerals = await repos.settings.numerals();
    _fontScale = await repos.settings.fontScale();
    _highContrast = await repos.settings.highContrast();
    _enterSession();
  }

  /// فتح القفل بعد تحقق PIN/عبارة المرور.
  void unlockSession() => _enterSession();

  void _enterSession() {
    _phase = AppPhase.ready;
    _autolock.touch();
    _autolock.startWatch();
    notifyListeners();
  }

  /// قفل يدوي أو تلقائي.
  void lock() {
    if (_phase != AppPhase.ready) return;
    _phase = AppPhase.locked;
    _autolock.stopWatch();
    notifyListeners();
  }

  // ── وضع الثيم ──

  /// يثبّت وضع الثيم محلياً وفي القاعدة (يستدعيه شاشة الإعدادات).
  Future<void> setThemeMode(String mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      await _repos?.settings.setThemeMode(mode);
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
      await _repos?.settings.setNumerals(mode);
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
      await _repos?.settings.setFontScale(mode);
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
      await _repos?.settings.setHighContrast(on);
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
        _autolock.stopWatch();
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
    if (minutes == _autolock.autolockMinutes) return;
    if (minutes < 1 || minutes > 60) {
      throw ArgumentError('مدة القفل التلقائي خارج النطاق 1–60: $minutes');
    }
    _autolock.setAutolockMinutes(minutes);
    notifyListeners();
    try {
      await _repos?.settings.setAutolockMinutes(minutes);
      // قيد تدقيق للتغييرات الأمنية (FR-12-04 — أحداث موسّعة).
      await _repos?.users.audit(
        'settings_change',
        entity: 'settings',
        details: 'security.autolock_minutes=$minutes',
      );
    } catch (_) {
      // فشل الحفظ لا يكسر الجلسة — القيمة تُقرأ مجدداً عند الإقلاع.
    }
  }

  // ── القفل التلقائي بعد الخمول (FR-12-05) ──

  /// لمس أي عنصر — تجديد النشاط (يفوّض للمراقب).
  void touch() => _autolock.touch();

  /// لحظة آخر نشاط (اختبارات — مراقبة الخمول).
  @visibleForTesting
  DateTime get lastActivityForTest => _autolock.lastActivity;

  /// التطبيق صار خلفياً — يبدأ عدّ الخمول (يفوّض للمراقب).
  void appHidden() => _autolock.appHidden();

  /// عاد التطبيق للأمام — قفل إن تجاوز الغياب الحد (يفوّض للمراقب).
  void appResumed() => _autolock.appResumed();

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
    _autolock.stopWatch();
    _company = null;
    _lockedFromPath = null;
    _repos = null;
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
    _autolock.stopWatch();
    super.dispose();
  }
}
