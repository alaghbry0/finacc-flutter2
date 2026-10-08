/// خدمة النسخ الاحتياطي والاستعادة — FR-11-01/02/04/05/06/08 (وحدة 11).
///
/// المنسّق الكامل فوق الطبقات النقية:
/// - [BackupFormat] (`domain/services/backup_format.dart`): zip/manifest/bصمة.
/// - [BackupPolicy] (`domain/services/backup_policy.dart`): الجدولة/الاستحقاق.
/// - `BackupFileStore` (هذا المجلد): ملفات المنصة + الاستبدال الذرّي.
/// - `BackupLogRepository` + `SettingsRepository`: السجل والمفاتيح.
///
/// **سياسة الاستعادة (FR-11-02 حرفياً)**: فحص سلامة كامل (بصمة + بيان) →
/// **رفض مخطط أحدث من تطبيق التطبيق** → نسخة أمان تلقائية (`pre_restore`)
/// → إغلاق القاعدة → استبدال ذرّي (مؤقت → rename + علامة `.restore-ok`)
/// → فتح القاعدة الجديدة → اعتماد (حذف العلامة والقديمة). أي فشل بالمنتصف
/// = **إرجاع القاعدة القديمة** وإعادة فتحها وإبلاغ المستخدم — وعلامة
/// متروكة عند الإقلاع تُرجع القديمة أيضاً (`recoverInterruptedRestore`).
///
/// حد الذاكرة الموثّق: قاعدة SQLite المحلية تُقرأ بالكامل بالذاكرة
/// (zip/بصمة يحتاجان المحتوى كاملاً) — مقياس التطبيق عشرات الميغابايت
/// كحد أقصى؛ الملفات المضغوطة أصغر بكثير على القرص.
library;

import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/migrations.dart';
import '../../../domain/services/backup_format.dart';
import '../../../domain/services/backup_policy.dart';
import '../../repositories/backup_log_repository.dart';
import '../../repositories/settings_repository.dart';
import 'backup_store.dart';
import 'backup_store_factory.dart';

// نوع النسخة جزء من واجهة الخدمة (يستهلكه العرض والاختبارات).
export '../../repositories/backup_log_repository.dart' show BackupKind;

/// نتيجة محاولة إنشاء نسخة (نجحت أو فشلت — كلتاهما تُسجَّل).
class BackupRunResult {
  const BackupRunResult({
    required this.ok,
    required this.kind,
    required this.atUtc,
    this.fileName,
    this.sizeBytes,
    this.checksum,
    this.errorDetails,
  });

  /// هل نجحت وكُتب الملف؟
  final bool ok;

  /// نوع المحاولة.
  final BackupKind kind;

  /// لحظة المحاولة (UTC).
  final DateTime atUtc;

  /// اسم الملف المكتوب (null عند الفشل).
  final String? fileName;

  /// حجم الأرشيف المضغوط بالبايت.
  final int? sizeBytes;

  /// بصمة SHA-256 للملف المضغوط (hex).
  final String? checksum;

  /// تفاصيل الفشل التقنية (للعرض التقني فقط).
  final String? errorDetails;
}

/// حالة استحقاق النسخة التلقائية (للعرض والتذكير).
class BackupDueInfo {
  const BackupDueInfo({
    required this.schedule,
    required this.lastBackupAt,
    required this.isDue,
    required this.isSupported,
  });

  final BackupSchedule schedule;
  final DateTime? lastBackupAt;
  final bool isDue;
  final bool isSupported;
}

/// فحص ملف نسخة قبل التأكيد (نافذة «عرض فحص الملف» — FR-11-02).
class BackupInspection {
  const BackupInspection({
    required this.fileName,
    required this.fileSizeBytes,
    required this.manifest,
  });

  /// الاسم كما اختاره المستخدم أو المحفوظ.
  final String fileName;

  /// حجم الملف المضغوط بالبايت.
  final int fileSizeBytes;

  /// بيان النسخة (تاريخ/مخطط/بصمة/نوع).
  final BackupManifest manifest;
}

/// سطر في قائمة سجل النسخ (FR-11-06): دمج قيود الجدول مع ملفات القرص —
/// الملف المصدر الحقيقي للحقيقة (زر استعادة/مشاركة لما له ملف فقط).
class BackupListEntry {
  const BackupListEntry({
    required this.atUtc,
    required this.fileExists,
    required this.statusOk,
    required this.sizeBytes,
    this.fileName,
    this.kind,
    this.checksum,
  });

  /// لحظة المحاولة/الإنشاء (UTC).
  final DateTime atUtc;

  final String? fileName;

  /// النوع من الجدول (null = ملف بلا قيد — نجا من استعادة قديمة).
  final BackupKind? kind;

  final String? checksum;

  /// هل الملف موجود الآن في مجلد النسخ؟
  final bool fileExists;

  /// الحالة المعروضة (فشل الجدول أو فقد الملف = غير ناجحة).
  final bool statusOk;

  final int sizeBytes;
}

/// أسباب فشل الاستعادة — مفهرسة لتُترجم بمفاتيح l10n بلا نص حرفي.
enum RestoreFailureReason {
  /// المنصة لا تدعم ملفات النسخ (ويب — معاينة).
  unsupportedPlatform,

  /// الملف ليس نسخة `.finbak` صالحة.
  notBackupFile,

  /// فحص السلامة فشل (بصمة/طول لا يطابقان).
  checksumMismatch,

  /// نسخة بمخطط أحدث من تطبيق التطبيق — تُرفض (FR-11-02).
  newerSchema,

  /// فشلت نسخة الأمان التلقائية قبل الاستبدال — أُلغيت العملية.
  safetyBackupFailed,

  /// فشل فتح القاعدة المستعادة — أُرجعت القاعدة القديمة وسليمة.
  openFailed,
}

/// نتيجة الاستعادة — نجاح (قاعدة جديدة مفتوحة) أو فشل مفهرس السبب.
sealed class RestoreResult {
  const RestoreResult();
}

class RestoreSuccess extends RestoreResult {
  const RestoreSuccess({required this.newDatabase, required this.safety});

  /// القاعدة المستعادة **المفتوحة** — يتبنّاها AppController.
  final AppDatabase newDatabase;

  /// نتيجة نسخة الأمان التي سبقت الاستبدال.
  final BackupRunResult safety;
}

class RestoreFailure extends RestoreResult {
  const RestoreFailure(
    this.reason, {
    this.details,
    this.fileSchemaVersion,
    this.appSchemaVersion,
    this.reopenedDatabase,
  });

  final RestoreFailureReason reason;

  /// تفاصيل تقنية (العرض التقني فقط).
  final String? details;

  /// إصدار مخطط النسخة (عند newerSchema فقط).
  final int? fileSchemaVersion;

  /// إصدار مخطط التطبيق الحالي (عند newerSchema فقط).
  final int? appSchemaVersion;

  /// القاعدة القديمة **المعاد فتحها** بعد rollback — على المتصل تبنّيها
  /// (null حين لم تُغلق أصلاً: أخطاء التحقق قبل أي لمسة للقاعدة).
  final AppDatabase? reopenedDatabase;
}

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
  Future<BackupRunResult> createBackup({required BackupKind kind}) async {
    final atUtc = DateTime.now().toUtc();
    if (!_fileStore.isSupported) {
      return BackupRunResult(
        ok: false,
        kind: kind,
        atUtc: atUtc,
        errorDetails: 'unsupported platform',
      );
    }
    try {
      // 1) نقطة تحقق WAL كاملة — القاعدة كلها في الملف الرئيسي قبل النسخ
      //    (FR-11-01 حرفياً). فشل الأمر لا يمنع النسخ (قراءة الملف الرئيسي
      //    وحده تبقى نسخة سليمة بلا آخر معاملات WAL).
      try {
        await _database.db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (_) {
        // محركات بلا WAL (نادر) — تُقبل.
      }
      // 2) محتوى القاعدة + إصدار المخطط الفعلي.
      final dbBytes = await _fileStore.readDatabaseFile();
      final schemaVersion = await _readUserVersion();
      final manifest = BackupManifest.forDbBytes(
        dbBytes,
        schemaVersion: schemaVersion,
        createdAtUtc: atUtc,
        kind: kind.tag,
      );
      // 3) الضغط والكتابة.
      final archiveBytes = encodeBackupArchive(
        dbBytes: dbBytes,
        manifest: manifest,
      );
      final fileName = formatBackupFileName(DateTime.now());
      await _fileStore.writeBackupFile(fileName, archiveBytes);
      final checksum = sha256Hex(archiveBytes);
      // 4) السجل (FR-11-06).
      await _log.insert(
        kind: kind,
        ok: true,
        atUtc: atUtc,
        fileName: fileName,
        fileSize: archiveBytes.length,
        checksum: checksum,
      );
      // 5) لحظة آخر نسخة ناجحة (حالة نظامية).
      await _settingsRepo.setBackupLastBackupAt(atUtc);
      // 6) الاحتفاظ بآخر N (FR-11-05).
      await _applyRetention(await _settingsRepo.backupRetentionCount());
      return BackupRunResult(
        ok: true,
        kind: kind,
        atUtc: atUtc,
        fileName: fileName,
        sizeBytes: archiveBytes.length,
        checksum: checksum,
      );
    } catch (error) {
      // الفشل يُسجَّل أيضاً — السجل تاريخي صادق.
      try {
        await _log.insert(kind: kind, ok: false, atUtc: atUtc);
      } catch (_) {
        // القاعدة نفسها قد تكون سبب الفشل — لا ما يسجَّل فيه.
      }
      return BackupRunResult(
        ok: false,
        kind: kind,
        atUtc: atUtc,
        errorDetails: error.toString(),
      );
    }
  }

  /// حجم ملف القاعدة الحالي (بند «حول» — FR-13-07) أو null.
  Future<int?> databaseFileSize() => _fileStore.databaseFileSize();

  // ─────────────────────────────────────────────────────────────────────
  // الفحص (FR-11-02)
  // ─────────────────────────────────────────────────────────────────────

  /// يفك الملف ويتحقق من سلامته — يرمي [BackupFormatException] المفهرسة
  /// عند أي عيب (ترجمها الواجهة بمفاتيح l10n).
  Future<BackupInspection> inspectBytes(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final content = decodeBackupArchive(bytes);
    return BackupInspection(
      fileName: fileName,
      fileSizeBytes: bytes.length,
      manifest: content.manifest,
    );
  }

  /// يقرأ ملف نسخة محفوظاً ويفحصه (زر استعادة من القائمة).
  Future<BackupInspection> inspectStoredBackup(String fileName) async {
    final bytes = await _fileStore.readBackupFile(fileName);
    return inspectBytes(bytes, fileName: fileName);
  }

  /// بايتات ملف نسخة محفوظ (تغذية الاستعادة من القائمة مباشرة).
  Future<Uint8List> readStoredBytes(String fileName) =>
      _fileStore.readBackupFile(fileName);

  // ─────────────────────────────────────────────────────────────────────
  // الاستعادة (FR-11-02 — سياسة الإخفاق حرفياً)
  // ─────────────────────────────────────────────────────────────────────

  /// يستعيد من بايتات ملف — انظر وثائق المكتبة أعلى الملف للسياسة كاملة.
  Future<RestoreResult> restoreFromBytes(
    Uint8List bytes, {
    String? sourceName,
  }) async {
    if (!_fileStore.isSupported) {
      return const RestoreFailure(RestoreFailureReason.unsupportedPlatform);
    }
    // 1) فحص السلامة (Checksum + البيان).
    BackupArchiveContent content;
    try {
      content = decodeBackupArchive(bytes);
    } on BackupFormatException catch (error) {
      return RestoreFailure(
        error.error == BackupFormatError.checksumMismatch
            ? RestoreFailureReason.checksumMismatch
            : RestoreFailureReason.notBackupFile,
        details: error.details,
      );
    }
    // 2) بوابة إصدار المخطط: نسخة أحدث من تطبيق التطبيق تُرفض برسالة
    //    واضحة (الأقدم تُستعاد ثم تُرقّيها الهجرات تلقائياً عند الفتح).
    if (content.manifest.schemaVersion > currentSchemaVersion) {
      return RestoreFailure(
        RestoreFailureReason.newerSchema,
        fileSchemaVersion: content.manifest.schemaVersion,
        appSchemaVersion: currentSchemaVersion,
      );
    }
    // 3) نسخة أمان تلقائية للقاعدة الحالية — فشلها يُلغي العملية
    //    (لا استبدال بلا شبكة أمان).
    final safety = await createBackup(kind: BackupKind.preRestore);
    if (!safety.ok) {
      return RestoreFailure(
        RestoreFailureReason.safetyBackupFailed,
        details: safety.errorDetails,
      );
    }
    // 4) إغلاق القاعدة الحالية (آخر لحظة تُلمَس فيها).
    try {
      await _database.close();
    } catch (error) {
      return RestoreFailure(
        RestoreFailureReason.openFailed,
        details: 'close: $error',
      );
    }
    // 5) الاستبدال الذرّي ثم الفتح والاعتماد.
    DatabaseSwapHandle? handle;
    try {
      handle = await _fileStore.swapDatabaseFile(content.dbBytes);
      final newDatabase = await _fileStore.openDatabase();
      await _logPostRestore(
        newDatabase,
        safety: safety,
        sourceName: sourceName,
        manifest: content.manifest,
      );
      await handle.commit();
      return RestoreSuccess(newDatabase: newDatabase, safety: safety);
    } catch (error) {
      // فشل بالمنتصف: إرجاع القاعدة القديمة وإعادة فتحها وإبلاغ المستخدم.
      AppDatabase? reopened;
      try {
        await handle?.rollback();
      } catch (_) {
        // الـ rollback نفسه تعثر — نحاول فتح ما في مكانه.
      }
      try {
        reopened = await _fileStore.openDatabase();
      } catch (_) {
        // حتى الفتح القديم فشل — وضع حر (نداء المستخدم لإعادة التشغيل؛
        // علامة الإقلاع ستعالجه عند إعادة الفتح).
      }
      return RestoreFailure(
        RestoreFailureReason.openFailed,
        details: error.toString(),
        reopenedDatabase: reopened,
      );
    }
  }

  /// يقرأ ملفاً محفوظاً ويستعيده مباشرة (زر استعادة من القائمة).
  Future<RestoreResult> restoreFromStoredBackup(String fileName) async {
    final bytes = await _fileStore.readBackupFile(fileName);
    return restoreFromBytes(bytes, sourceName: fileName);
  }

  // ─────────────────────────────────────────────────────────────────────
  // الجدولة والاحتفاظ والقوائم والمشاركة
  // ─────────────────────────────────────────────────────────────────────

  /// حالة الاستحقاق الحالية (للعرض — بانر الداشبورد).
  Future<BackupDueInfo> dueInfo({DateTime? now}) async {
    final schedule = parseBackupSchedule(await _settingsRepo.backupSchedule());
    final last = await _settingsRepo.backupLastBackupAt();
    return BackupDueInfo(
      schedule: schedule,
      lastBackupAt: last,
      isDue: isBackupDue(
        schedule: schedule,
        lastBackupAt: last,
        now: now ?? DateTime.now(),
      ),
      isSupported: _fileStore.isSupported,
    );
  }

  /// نسخة تلقائية صامتة إن حان الوقت (FR-11-04) — null = لم يحن/متوقف.
  Future<BackupRunResult?> runScheduledBackupIfDue({DateTime? now}) async {
    if (!_fileStore.isSupported) return null;
    final info = await dueInfo(now: now);
    if (!info.isDue) return null;
    return createBackup(kind: BackupKind.auto);
  }

  /// قائمة سجل النسخ (FR-11-06): قيود الجدول مدمجة بملفات القرص.
  Future<List<BackupListEntry>> listEntries() async {
    final rows = await _log.list();
    final files = await _fileStore.listBackupFiles();
    final fileByName = {for (final file in files) file.fileName: file};
    final entries = <BackupListEntry>[];
    final filesWithRows = <String>{};
    for (final row in rows) {
      final file = row.fileName == null ? null : fileByName[row.fileName];
      if (row.fileName != null) filesWithRows.add(row.fileName!);
      entries.add(
        BackupListEntry(
          atUtc: row.atUtc,
          fileName: row.fileName,
          kind: row.kind,
          checksum: row.checksum,
          fileExists: file != null,
          statusOk: row.ok && (row.fileName == null || file != null),
          sizeBytes: file?.sizeBytes ?? row.fileSize ?? 0,
        ),
      );
    }
    // ملفات بلا قيد (نجت من استعادة قديمة أو مسح) — تُعرض بنوع عام.
    for (final file in files) {
      if (filesWithRows.contains(file.fileName)) continue;
      final at =
          file.modifiedAt ??
          parseBackupFileNameTime(file.fileName)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      entries.add(
        BackupListEntry(
          atUtc: at,
          fileName: file.fileName,
          kind: null,
          fileExists: true,
          statusOk: true,
          sizeBytes: file.sizeBytes,
        ),
      );
    }
    entries.sort((a, b) => b.atUtc.compareTo(a.atUtc));
    return entries;
  }

  /// يشارك ملف نسخة عبر نظام التشغيل (FR-11-08) — وبديل «حفظ في
  /// Downloads/درايف» (النصف الثاني من FR-11-01): الوصول المباشر لمجلد
  /// Downloads يتطلب MANAGE_EXTERNAL_STORAGE (مرفوض) — ورقة المشاركة
  /// تغطيه بأذونات النظام القياسية.
  Future<bool> shareBackupFile(String fileName, {String? text}) async {
    if (!_fileStore.isSupported) return false;
    final path = await _fileStore.backupFilePath(fileName);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(path)], text: text, title: fileName),
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // داخليات
  // ─────────────────────────────────────────────────────────────────────

  /// `PRAGMA user_version` — إصدار مخطط القاعدة المفتوحة فعلياً.
  Future<int> _readUserVersion() async {
    final rows = await _database.db.rawQuery('PRAGMA user_version');
    final value = rows.first.values.first;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  /// الاحتفاظ بآخر N ملفاً (FR-11-05) — الحذف بالأقدم أولاً حسب بطاقة
  /// الزمن في الاسم (أدق من تاريخ التعديل) ثم تاريخ التعديل.
  Future<void> _applyRetention(int keepCount) async {
    if (keepCount < 1) return;
    final files = await _fileStore.listBackupFiles();
    if (files.length <= keepCount) return;
    int timestamp(BackupFileInfo file) =>
        parseBackupFileNameTime(file.fileName)?.millisecondsSinceEpoch ??
        file.modifiedAt?.millisecondsSinceEpoch ??
        0;
    final sorted = [...files]
      ..sort((a, b) => timestamp(b).compareTo(timestamp(a)));
    for (final old in sorted.skip(keepCount)) {
      try {
        await _fileStore.deleteBackupFile(old.fileName);
      } catch (_) {
        // ملف مقفول/محذوف — يتجاوزه الاحتفاظ التالي.
      }
    }
  }

  /// كتابة ما بعد الاستعادة في **القاعدة المستعادة**: قيد نسخة الأمان
  /// (كي يبقى السجل صادقاً — الجدول رجع بحالة ما قبل الاستعادة) + قيد
  /// تدقيق `backup_restore` (FR-12-04: استعادة نسخة حدث موسّع) + لحظة
  /// آخر نسخة = لحظة نسخة الأمان.
  Future<void> _logPostRestore(
    AppDatabase newDatabase, {
    required BackupRunResult safety,
    required BackupManifest manifest,
    String? sourceName,
  }) async {
    final log = BackupLogRepository(newDatabase.db);
    await log.insert(
      kind: BackupKind.preRestore,
      ok: true,
      atUtc: safety.atUtc,
      fileName: safety.fileName,
      fileSize: safety.sizeBytes,
      checksum: safety.checksum,
    );
    await newDatabase.db.insert('audit_log', <String, Object?>{
      'user_id': null,
      'action': 'backup_restore',
      'entity': 'backup_log',
      'entity_id': null,
      'details':
          'from=${sourceName ?? safety.fileName} '
          'schema=v${manifest.schemaVersion} '
          'app=${manifest.appVersion}',
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    final settings = SettingsRepository(newDatabase.db);
    await settings.setBackupLastBackupAt(safety.atUtc);
  }
}
