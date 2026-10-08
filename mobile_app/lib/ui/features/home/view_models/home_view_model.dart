/// نموذج عرض لوحة التحكم — FR-09-01 (البلاطات الأربع + رسم 30 يوماً +
/// تنبيهات المخزون + **مبيعات الشهر بالمقارنة (17-c)** + **أعلى الأصناف
/// مبيعاً**) من القاعدة الحقيقية، مع حالات تحميل/خطأ كاملة +
/// تذكير النسخ الاحتياطي المجدول (FR-11-04 — الشريحة 8): نسخة تلقائية
/// صامتة عند دخول اللوحة إن حان وقتها، وبانر داخلي بنتيجتها.
///
/// **عزل أخطاء 17-c**: استعلامات الشهر/الأصناف الأعلى تجري في حزمة
/// منفصلة — فشلها يُخفض القسم إلى null/قائمة فارغة (غياب البطاقة)
/// **دون إسقاط الإحصاءات القديمة ولا رفع حالة الخطأ العامة**.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/dashboard_repository.dart';
import '../../../../data/services/backup/backup_service.dart';
import '../../../../domain/services/backup_policy.dart';

class DashboardState {
  const DashboardState({
    required this.loading,
    required this.stats,
    required this.series,
    required this.lowStock,
    this.month,
    this.topItems,
    this.error,
    this.lastUpdated,
  });

  final bool loading;
  final DashboardTodayStats stats;
  final List<DailySalesPoint> series;
  final int lowStock;

  /// مبيعات الشهر مقارنة بالسابق — **null = فشل الاستعلام (تدهور رشيق)**
  /// فلا تُعرض البطاقة أصلاً (لا تُخفي بقية اللوحة).
  final MonthSalesStats? month;

  /// أعلى الأصناف مبيعاً هذا الشهر — null = فشل الاستعلام (تدهور)،
  /// القائمة الفارغة = لا مبيعات بعد (حالة فراغ سليمة).
  final List<TopItemStat>? topItems;

  final Object? error;

  /// لحظة آخر تحميل ناجح (شارة «آخر تحديث»).
  final DateTime? lastUpdated;

  static const DashboardState initial = DashboardState(
    loading: true,
    stats: DashboardTodayStats(
      sales: 0,
      profit: 0,
      invoiceCount: 0,
      netCash: 0,
    ),
    series: <DailySalesPoint>[],
    lowStock: 0,
  );
}

/// نوع تذكير النسخ في الداشبورد (بانر داخلي — FR-11-04).
enum BackupReminderKind {
  /// أُنشئت نسخة تلقائية بنجاح عند دخول اللوحة.
  autoDone,

  /// تعذّرت النسخة التلقائية — تنبيه لإنشاء يدوي.
  autoFailed,

  /// حان الوقت والمنصة معاينة ويب — الميزة الكاملة على أندرويد.
  webDue,
}

/// بيانات بانر التذكير.
class BackupReminder {
  const BackupReminder({required this.kind, this.at, this.sizeBytes});

  final BackupReminderKind kind;

  /// لحظة النسخة التلقائية (عند autoDone).
  final DateTime? at;

  /// حجم النسخة بالبايت (عند autoDone).
  final int? sizeBytes;
}

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required DashboardRepository repository,
    CompanyRepository? companyRepository,
    BackupService? backupEngine,
  }) : _repo = repository,
       _companyRepo = companyRepository,
       _backup = backupEngine;

  final DashboardRepository _repo;
  final CompanyRepository? _companyRepo;

  /// محرك النسخ (اختياري) — للنسخة التلقائية الصامتة والتذكير.
  final BackupService? _backup;

  DashboardState _state = DashboardState.initial;
  String? _companyName;
  String? _adminName;
  String? _currencyCode;
  BackupReminder? _backupReminder;
  bool _backupReminderDismissed = false;
  bool _isDisposed = false;

  DashboardState get state => _state;
  String? get companyName => _companyName;
  String? get adminName => _adminName;

  /// تذكير النسخ الحالي (null = لا بانر).
  BackupReminder? get backupReminder =>
      _backupReminderDismissed ? null : _backupReminder;

  /// رمز العملة الأساسية (YER/SAR/… — لفقاعة الرسم البياني).
  String? get currencyCode => _currencyCode;

  /// تحميل كامل (يُستدعى عند بناء الشاشة وعند السحب للتحديث).
  Future<void> load({String? companyName, String? adminName}) async {
    _companyName = companyName ?? _companyName;
    _adminName = adminName ?? _adminName;
    _state = DashboardState(
      loading: true,
      stats: _state.stats,
      series: _state.series,
      lowStock: _state.lowStock,
      month: _state.month,
      topItems: _state.topItems,
    );
    notifyListeners();
    try {
      final now = DateTime.now();
      final stats = await _repo.todayStats(now);
      final series = await _repo.last30DaysSales(now);
      final lowStock = await _repo.lowStockCount();
      if (_currencyCode == null && _companyRepo != null) {
        _currencyCode = (await _companyRepo.findBaseCurrency())?.code;
      }
      // 17-c: استعلامات الشهر/الأصناف في حزمة معزولة — فشل أحدها
      // يُخفض قسمه إلى null (غياب البطاقة) دون إسقاط اللوحة.
      final month = await _guard(() => _repo.monthStats(now));
      final topItems = await _guard(() => _repo.topItems());
      _state = DashboardState(
        loading: false,
        stats: stats,
        series: series,
        lowStock: lowStock,
        month: month,
        topItems: topItems,
        lastUpdated: DateTime.now(),
      );
    } catch (error) {
      _state = DashboardState(
        loading: false,
        stats: _state.stats,
        series: _state.series,
        lowStock: _state.lowStock,
        month: _state.month,
        topItems: _state.topItems,
        error: error,
      );
    }
    notifyListeners();
    // النسخة التلقائية الصامتة (FR-11-04) بعد عرض البيانات — لا تحجب
    // الإحصاءات ولا تكسر اللوحة عند أي فشل.
    await _runScheduledBackupIfDue();
  }

  /// يخفي بانر التذكير لبقية الجلسة.
  void dismissBackupReminder() {
    _backupReminderDismissed = true;
    notifyListeners();
  }

  /// يشغّل [action] ويعيد null عند أي فشل (عزل أخطاء أقسام 17-c).
  static Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// إن حان وقت النسخة المجدولة: تنشئها بصمت وتضبط البانر بنتيجتها.
  /// على الويب: بانر «الميزة على أندرويد» عند الاستحقاق فقط.
  Future<void> _runScheduledBackupIfDue() async {
    if (_isDisposed || _backupReminderDismissed || _backup == null) {
      return;
    }
    try {
      final engine = _backup;
      final info = await engine.dueInfo();
      if (info.schedule == BackupSchedule.off) return;
      if (info.isSupported) {
        if (!info.isDue) return;
        final run = await engine.runScheduledBackupIfDue();
        if (run == null || _isDisposed) return;
        _backupReminder = run.ok
            ? BackupReminder(
                kind: BackupReminderKind.autoDone,
                at: run.atUtc,
                sizeBytes: run.sizeBytes,
              )
            : const BackupReminder(kind: BackupReminderKind.autoFailed);
      } else if (info.isDue) {
        _backupReminder = const BackupReminder(kind: BackupReminderKind.webDue);
      } else {
        return;
      }
      if (!_isDisposed) notifyListeners();
    } catch (_) {
      // التذكير ميزة تكميلية — فشله لا يمس لوحة التحكم.
    }
  }
}
