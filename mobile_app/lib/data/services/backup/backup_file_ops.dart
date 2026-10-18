/// عمليات ملفات النسخ (الفحص/القراءة/المشاركة/الحجم) — جزء من تقسيم
/// R20-D3a لخدمة النسخ (نمط R19-D3d): منقولة حرفياً من backup_service.dart
/// (الواجهة العامة والسلوك ثابتان — الخدمة تفوِّض بتواقيعها نفسها).
library;

import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../../domain/services/backup_format.dart';
import 'backup_models.dart';
import 'backup_store.dart';

/// حجم ملف القاعدة الحالي (بند «حول» — FR-13-07) أو null.
Future<int?> databaseFileSizeFlow(BackupFileStore fileStore) =>
    fileStore.databaseFileSize();

/// يفك الملف ويتحقق من سلامته — يرمي [BackupFormatException] المفهرسة
/// عند أي عيب (ترجمها الواجهة بمفاتيح l10n).
Future<BackupInspection> inspectBytesFlow(
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
Future<BackupInspection> inspectStoredBackupFlow(
  BackupFileStore fileStore,
  String fileName,
) async {
  final bytes = await fileStore.readBackupFile(fileName);
  return inspectBytesFlow(bytes, fileName: fileName);
}

/// بايتات ملف نسخة محفوظ (تغذية الاستعادة من القائمة مباشرة).
Future<Uint8List> readStoredBytesFlow(
  BackupFileStore fileStore,
  String fileName,
) => fileStore.readBackupFile(fileName);

/// يشارك ملف نسخة عبر نظام التشغيل (FR-11-08) — وبديل «حفظ في
/// Downloads/درايف» (النصف الثاني من FR-11-01): الوصول المباشر لمجلد
/// Downloads يتطلب MANAGE_EXTERNAL_STORAGE (مرفوض) — ورقة المشاركة
/// تغطيه بأذونات النظام القياسية.
Future<bool> shareBackupFileFlow(
  BackupFileStore fileStore,
  String fileName, {
  String? text,
}) async {
  if (!fileStore.isSupported) return false;
  final path = await fileStore.backupFilePath(fileName);
  try {
    final result = await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(path)], text: text, title: fileName),
    );
    return result.status != ShareResultStatus.unavailable;
  } catch (_) {
    return false;
  }
}
