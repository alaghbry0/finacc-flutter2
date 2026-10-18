/// تدفق الاستعادة (FR-11-02 — سياسة الإخفاق حرفياً) — جزء من تقسيم
/// R20-D3a لخدمة النسخ (نمط R19-D3d): منقول حرفياً من backup_service.dart
/// (الواجهة العامة والسلوك ثابتان — الخدمة تفوِّض بتواقيعها نفسها).
///
/// **سياسة الاستعادة (FR-11-02 حرفياً)**: فحص سلامة كامل (بصمة + بيان) →
/// **رفض مخطط أحدث من تطبيق التطبيق** → نسخة أمان تلقائية (`pre_restore`)
/// → إغلاق القاعدة → استبدال ذرّي (مؤقت → rename + علامة `.restore-ok`)
/// → فتح القاعدة الجديدة → اعتماد (حذف العلامة والقديمة). أي فشل بالمنتصف
/// = **إرجاع القاعدة القديمة** وإعادة فتحها وإبلاغ المستخدم — وعلامة
/// متروكة عند الإقلاع تُرجع القديمة أيضاً (`recoverInterruptedRestore`
/// بالواجهة).
library;

import 'dart:typed_data';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/migrations.dart';
import '../../../domain/services/backup_format.dart';
import '../../repositories/backup_log_repository.dart';
import '../../repositories/settings_repository.dart';
import 'backup_create_flow.dart';
import 'backup_models.dart';
import 'backup_store.dart';

/// يستعيد من بايتات ملف — انظر وثائق المكتبة أعلى الملف للسياسة كاملة.
Future<RestoreResult> restoreFromBytesFlow({
  required AppDatabase database,
  required SettingsRepository settingsRepo,
  required BackupFileStore fileStore,
  required BackupLogRepository log,
  required Uint8List bytes,
  String? sourceName,
}) async {
  if (!fileStore.isSupported) {
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
  final safety = await createBackupFlow(
    database: database,
    settingsRepo: settingsRepo,
    fileStore: fileStore,
    log: log,
    kind: BackupKind.preRestore,
  );
  if (!safety.ok) {
    return RestoreFailure(
      RestoreFailureReason.safetyBackupFailed,
      details: safety.errorDetails,
    );
  }
  // 4) إغلاق القاعدة الحالية (آخر لحظة تُلمَس فيها).
  try {
    await database.close();
  } catch (error) {
    return RestoreFailure(
      RestoreFailureReason.openFailed,
      details: 'close: $error',
    );
  }
  // 5) الاستبدال الذرّي ثم الفتح والاعتماد.
  DatabaseSwapHandle? handle;
  try {
    handle = await fileStore.swapDatabaseFile(content.dbBytes);
    final newDatabase = await fileStore.openDatabase();
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
      reopened = await fileStore.openDatabase();
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

// ─────────────────────────────────────────────────────────────────────
// مساعدات خاصة
// ─────────────────────────────────────────────────────────────────────

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
