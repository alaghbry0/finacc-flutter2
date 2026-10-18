/// خدمة النسخ الاحتياطي والاستعادة — FR-11-01/02/04/05/06/08 (وحدة 11).
///
/// المنسّق الكامل فوق الطبقات النقية:
/// - [BackupFormat] (`domain/services/backup_format.dart`): zip/manifest/bصمة.
/// - [BackupPolicy] (`domain/services/backup_policy.dart`): الجدولة/الاستحقاق.
/// - `BackupFileStore` (هذا المجلد): ملفات المنصة + الاستبدال الذرّي.
/// - `BackupLogRepository` + `SettingsRepository`: السجل والمفاتيح.
///
/// وحدات التنفيذ مستخرجة إلى هذا المجلد نفسه (R20-D3a — نمط تقسيم
/// R19-D3d): الأنواع العامة (`backup_models.dart` — تُصدَّر من هنا فكل
/// استيرادات الخدمة التاريخية تحل كما كانت) والإنشاء والاحتفاظ
/// (`backup_create_flow.dart`) والاستعادة بسياسة إخفاقها الكاملة
/// (`backup_restore_flow.dart`) والجدولة والقوائم
/// (`backup_schedule_listing.dart`) وعمليات الملفات
/// (`backup_file_ops.dart`) — هذا الصنف واجهة تفويض رقيقة بتواقيعه
/// العامة نفسها ومُنشئه الحقّي.
library;

import 'dart:typed_data';

import '../../../core/storage/app_database.dart';
import '../../repositories/backup_log_repository.dart';
import '../../repositories/settings_repository.dart';
import 'backup_create_flow.dart';
import 'backup_file_ops.dart';
import 'backup_models.dart';
import 'backup_restore_flow.dart';
import 'backup_schedule_listing.dart';
import 'backup_store.dart';
import 'backup_store_factory.dart';

// نوع النسخة جزء من واجهة الخدمة (يستهلكه العرض والاختبارات).
export '../../repositories/backup_log_repository.dart' show BackupKind;
export 'backup_models.dart';

/// محرك النسخ الاحتياطي — يُنشأ فوق قاعدة مفتوحة ومخزن منصة.
class BackupService {
  BackupService({
    required AppDatabase database,
    required SettingsRepository settings,
    required BackupFileStore store,
    BackupLogRepository? logRepository,
  }) : _database = database,
       _settingsRepo = settings,
       _fileStore = store,
       _log = logRepository ?? BackupLogRepository(database.db);

  final AppDatabase _database;
  final SettingsRepository _settingsRepo;
  final BackupFileStore _fileStore;
  final BackupLogRepository _log;

  /// هل ملفات النسخ مدعومة على هذه المنصة؟
  bool get isSupported => _fileStore.isSupported;

  /// يبني الخدمة بمخزن المنصة الافتراضي — أو null إن تعذّر (نادر).
  static Future<BackupService?> createDefault(
    AppDatabase database,
    SettingsRepository settings,
  ) async {
    try {
      final store = await defaultBackupFileStore();
      return BackupService(
        database: database,
        settings: settings,
        store: store,
      );
    } catch (_) {
      return null;
    }
  }

  /// شبكة أمان الإقلاع (FR-11-02): إن وُجدت علامة استعادة متروكة فالقاعدة
  /// القديمة تُعاد لمكانها قبل أي فتح — تُستدعى من bootstrap.
  static Future<void> recoverInterruptedRestoreIfAny() async {
    try {
      final store = await defaultBackupFileStore();
      if (!store.isSupported) return;
      await store.recoverInterruptedRestore();
    } catch (_) {
      // فشل الفحص نفسه لا يمنع الإقلاع — الفتح العادي يقرر بعده.
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // الإنشاء (FR-11-01)
  // ─────────────────────────────────────────────────────────────────────

  /// ينشئ نسخة محلية: checkpoint WAL → قراءة الملف → zip + بيان →
  /// كتابة `FinAcc-Backup-….finbak` في `backups/` → تسجيل → احتفاظ.
  Future<BackupRunResult> createBackup({required BackupKind kind}) async =>
      createBackupFlow(
        database: _database,
        settingsRepo: _settingsRepo,
        fileStore: _fileStore,
        log: _log,
        kind: kind,
      );

  /// حجم ملف القاعدة الحالي (بند «حول» — FR-13-07) أو null.
  Future<int?> databaseFileSize() => databaseFileSizeFlow(_fileStore);

  // ─────────────────────────────────────────────────────────────────────
  // الفحص (FR-11-02)
  // ─────────────────────────────────────────────────────────────────────

  /// يفك الملف ويتحقق من سلامته — يرمي [BackupFormatException] المفهرسة
  /// عند أي عيب (ترجمها الواجهة بمفاتيح l10n).
  Future<BackupInspection> inspectBytes(
    Uint8List bytes, {
    required String fileName,
  }) async => inspectBytesFlow(bytes, fileName: fileName);

  /// يقرأ ملف نسخة محفوظاً ويفحصه (زر استعادة من القائمة).
  Future<BackupInspection> inspectStoredBackup(String fileName) async =>
      inspectStoredBackupFlow(_fileStore, fileName);

  /// بايتات ملف نسخة محفوظ (تغذية الاستعادة من القائمة مباشرة).
  Future<Uint8List> readStoredBytes(String fileName) =>
      readStoredBytesFlow(_fileStore, fileName);

  // ─────────────────────────────────────────────────────────────────────
  // الاستعادة (FR-11-02 — سياسة الإخفاق حرفياً)
  // ─────────────────────────────────────────────────────────────────────

  /// يستعيد من بايتات ملف — انظر وثائق المكتبة أعلى الملف للسياسة كاملة.
  Future<RestoreResult> restoreFromBytes(
    Uint8List bytes, {
    String? sourceName,
  }) async => restoreFromBytesFlow(
    database: _database,
    settingsRepo: _settingsRepo,
    fileStore: _fileStore,
    log: _log,
    bytes: bytes,
    sourceName: sourceName,
  );

  /// يقرأ ملفاً محفوظاً ويستعيده مباشرة (زر استعادة من القائمة).
  Future<RestoreResult> restoreFromStoredBackup(String fileName) async {
    final bytes = await _fileStore.readBackupFile(fileName);
    return restoreFromBytes(bytes, sourceName: fileName);
  }

  // ─────────────────────────────────────────────────────────────────────
  // الجدولة والقوائم والمشاركة
  // ─────────────────────────────────────────────────────────────────────

  /// حالة الاستحقاق الحالية (للعرض — بانر الداشبورد).
  Future<BackupDueInfo> dueInfo({DateTime? now}) async =>
      dueInfoFlow(settingsRepo: _settingsRepo, fileStore: _fileStore, now: now);

  /// نسخة تلقائية صامتة إن حان الوقت (FR-11-04) — null = لم يحن/متوقف.
  Future<BackupRunResult?> runScheduledBackupIfDue({DateTime? now}) async =>
      runScheduledBackupIfDueFlow(
        database: _database,
        settingsRepo: _settingsRepo,
        fileStore: _fileStore,
        log: _log,
        now: now,
      );

  /// قائمة سجل النسخ (FR-11-06): قيود الجدول مدمجة بملفات القرص.
  Future<List<BackupListEntry>> listEntries() async =>
      listEntriesFlow(log: _log, fileStore: _fileStore);

  /// يشارك ملف نسخة عبر نظام التشغيل (FR-11-08) — وبديل «حفظ في
  /// Downloads/درايف» (النصف الثاني من FR-11-01): الوصول المباشر لمجلد
  /// Downloads يتطلب MANAGE_EXTERNAL_STORAGE (مرفوض) — ورقة المشاركة
  /// تغطيه بأذونات النظام القياسية.
  Future<bool> shareBackupFile(String fileName, {String? text}) async =>
      shareBackupFileFlow(_fileStore, fileName, text: text);
}
