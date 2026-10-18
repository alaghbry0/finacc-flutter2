/// الجدولة والقوائم (FR-11-04/06) — جزء من تقسيم R20-D3a لخدمة النسخ
/// (نمط R19-D3d): منقولة حرفياً من backup_service.dart (الواجهة العامة
/// والسلوك ثابتان — الخدمة تفوِّض بتواقيعها نفسها).
library;

import '../../../core/storage/app_database.dart';
import '../../../domain/services/backup_format.dart';
import '../../../domain/services/backup_policy.dart';
import '../../repositories/backup_log_repository.dart';
import '../../repositories/settings_repository.dart';
import 'backup_create_flow.dart';
import 'backup_models.dart';
import 'backup_store.dart';

/// حالة الاستحقاق الحالية (للعرض — بانر الداشبورد).
Future<BackupDueInfo> dueInfoFlow({
  required SettingsRepository settingsRepo,
  required BackupFileStore fileStore,
  DateTime? now,
}) async {
  final schedule = parseBackupSchedule(await settingsRepo.backupSchedule());
  final last = await settingsRepo.backupLastBackupAt();
  return BackupDueInfo(
    schedule: schedule,
    lastBackupAt: last,
    isDue: isBackupDue(
      schedule: schedule,
      lastBackupAt: last,
      now: now ?? DateTime.now(),
    ),
    isSupported: fileStore.isSupported,
  );
}

/// نسخة تلقائية صامتة إن حان الوقت (FR-11-04) — null = لم يحن/متوقف.
Future<BackupRunResult?> runScheduledBackupIfDueFlow({
  required AppDatabase database,
  required SettingsRepository settingsRepo,
  required BackupFileStore fileStore,
  required BackupLogRepository log,
  DateTime? now,
}) async {
  if (!fileStore.isSupported) return null;
  final info = await dueInfoFlow(
    settingsRepo: settingsRepo,
    fileStore: fileStore,
    now: now,
  );
  if (!info.isDue) return null;
  return createBackupFlow(
    database: database,
    settingsRepo: settingsRepo,
    fileStore: fileStore,
    log: log,
    kind: BackupKind.auto,
  );
}

/// قائمة سجل النسخ (FR-11-06): قيود الجدول مدمجة بملفات القرص.
Future<List<BackupListEntry>> listEntriesFlow({
  required BackupLogRepository log,
  required BackupFileStore fileStore,
}) async {
  final rows = await log.list();
  final files = await fileStore.listBackupFiles();
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
        fileExists: true,
        statusOk: true,
        sizeBytes: file.sizeBytes,
      ),
    );
  }
  entries.sort((a, b) => b.atUtc.compareTo(a.atUtc));
  return entries;
}
