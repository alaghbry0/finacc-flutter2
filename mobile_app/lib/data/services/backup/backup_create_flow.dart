/// تدفق إنشاء النسخة الاحتياطية (FR-11-01) والاحتفاظ (FR-11-05) —
/// جزء من تقسيم R20-D3a لخدمة النسخ (نمط R19-D3d): منقول حرفياً من
/// backup_service.dart (الواجهة العامة والسلوك ثابتان — الخدمة تفوِّض
/// بتواقيعها نفسها).
///
/// حد الذاكرة الموثّق: قاعدة SQLite المحلية تُقرأ بالكامل بالذاكرة
/// (zip/بصمة يحتاجان المحتوى كاملاً) — مقياس التطبيق عشرات الميغابايت
/// كحد أقصى؛ الملفات المضغوطة أصغر بكثير على القرص.
library;

import '../../../core/storage/app_database.dart';
import '../../../domain/services/backup_format.dart';
import '../../repositories/backup_log_repository.dart';
import '../../repositories/settings_repository.dart';
import 'backup_models.dart';
import 'backup_store.dart';

/// ينشئ نسخة محلية: checkpoint WAL → قراءة الملف → zip + بيان →
/// كتابة `FinAcc-Backup-….finbak` في `backups/` → تسجيل → احتفاظ.
Future<BackupRunResult> createBackupFlow({
  required AppDatabase database,
  required SettingsRepository settingsRepo,
  required BackupFileStore fileStore,
  required BackupLogRepository log,
  required BackupKind kind,
}) async {
  final atUtc = DateTime.now().toUtc();
  if (!fileStore.isSupported) {
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
      await database.db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {
      // محركات بلا WAL (نادر) — تُقبل.
    }
    // 2) محتوى القاعدة + إصدار المخطط الفعلي.
    final dbBytes = await fileStore.readDatabaseFile();
    final schemaVersion = await _readUserVersion(database);
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
    await fileStore.writeBackupFile(fileName, archiveBytes);
    final checksum = sha256Hex(archiveBytes);
    // 4) السجل (FR-11-06).
    await log.insert(
      kind: kind,
      ok: true,
      atUtc: atUtc,
      fileName: fileName,
      fileSize: archiveBytes.length,
      checksum: checksum,
    );
    // 5) لحظة آخر نسخة ناجحة (حالة نظامية).
    await settingsRepo.setBackupLastBackupAt(atUtc);
    // 6) الاحتفاظ بآخر N (FR-11-05).
    await _applyRetention(fileStore, await settingsRepo.backupRetentionCount());
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
      await log.insert(kind: kind, ok: false, atUtc: atUtc);
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

// ─────────────────────────────────────────────────────────────────────
// مساعدات خاصة
// ─────────────────────────────────────────────────────────────────────

/// `PRAGMA user_version` — إصدار مخطط القاعدة المفتوحة فعلياً.
Future<int> _readUserVersion(AppDatabase database) async {
  final rows = await database.db.rawQuery('PRAGMA user_version');
  final value = rows.first.values.first;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

/// الاحتفاظ بآخر N ملفاً (FR-11-05) — الحذف بالأقدم أولاً حسب بطاقة
/// الزمن في الاسم (أدق من تاريخ التعديل) ثم تاريخ التعديل.
Future<void> _applyRetention(BackupFileStore fileStore, int keepCount) async {
  if (keepCount < 1) return;
  final files = await fileStore.listBackupFiles();
  if (files.length <= keepCount) return;
  int timestamp(BackupFileInfo file) =>
      parseBackupFileNameTime(file.fileName)?.millisecondsSinceEpoch ??
      file.modifiedAt?.millisecondsSinceEpoch ??
      0;
  final sorted = [...files]
    ..sort((a, b) => timestamp(b).compareTo(timestamp(a)));
  for (final old in sorted.skip(keepCount)) {
    try {
      await fileStore.deleteBackupFile(old.fileName);
    } catch (_) {
      // ملف مقفول/محذوف — يتجاوزه الاحتفاظ التالي.
    }
  }
}
