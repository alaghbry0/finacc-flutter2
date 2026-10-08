/// عقد مخزن ملفات النسخ الاحتياطي — طبقة I/O خلف واجهة واحدة (وحدة 11).
///
/// التنفيذ الفعلي شرطي المنصة (نمط `core/storage/db_factory.dart`):
/// - أندرويد/iOS: `backup_store_io.dart` (ملفات حقيقية + استبدال ذرّي).
/// - الويب: `backup_store_web.dart` (دفاعي — القاعدة داخل IndexedDB لا
///   نظام ملفات؛ الإنشاء/الاستعادة/المشاركة «متاحة على أندرويد»).
library;

import 'dart:typed_data';

import '../../../core/storage/app_database.dart';

/// معلومات ملف نسخة على القرص.
class BackupFileInfo {
  const BackupFileInfo({
    required this.fileName,
    required this.sizeBytes,
    this.modifiedAt,
  });

  final String fileName;
  final int sizeBytes;
  final DateTime? modifiedAt;
}

/// مقبض استبدال القاعدة (FR-11-02): يُنشأ بعد وضع الملف الجديد ذرّياً —
/// `commit()` عند نجاح الفتح، و`rollback()` يعيد القاعدة القديمة عند أي
/// فشل بالمنتصف.
abstract class DatabaseSwapHandle {
  /// إتمام ناجح: حذف علامة `.restore-ok` والنسخة القديمة الجانبية.
  Future<void> commit();

  /// إرجاع القاعدة القديمة لمكانها وحذف كل آثار المحاولة.
  Future<void> rollback();
}

/// العمليات الملفية التي تحتاجها خدمة النسخ — منفذة لكل منصة.
abstract class BackupFileStore {
  /// هل هذه المنصة تدعم ملفات النسخ فعلياً؟ (الويب = معاينة فقط).
  bool get isSupported;

  /// مسار ملف القاعدة الحالي.
  Future<String> databasePath();

  /// بايتات ملف القاعدة (بعد checkpoint من الخدمة).
  Future<Uint8List> readDatabaseFile();

  /// حجم ملف القاعدة بالبايت — أو null عند التعذر (شاشة «حول»).
  Future<int?> databaseFileSize();

  /// المسار المطلق لملف نسخة باسمه.
  Future<String> backupFilePath(String fileName);

  /// بايتات ملف نسخة محفوظ.
  Future<Uint8List> readBackupFile(String fileName);

  /// يكتب ملف نسخة جديد في مجلد `backups/`.
  Future<void> writeBackupFile(String fileName, Uint8List bytes);

  /// يحذف ملف نسخة (الاحتفاظ — FR-11-05).
  Future<void> deleteBackupFile(String fileName);

  /// كل ملفات `.finbak` في مجلد النسخ.
  Future<List<BackupFileInfo>> listBackupFiles();

  /// الاستبدال الذرّي: يفترض أن المتصل **أغلق القاعدة** قبل الاستدعاء —
  /// يكتب الملف الجديد مؤقتاً، يحوّل الحالي إلى `finacc.db.pre-restore`،
  /// ينقل الجديد إلى `finacc.db`، ويضع علامة نجاح `.restore-ok`.
  Future<DatabaseSwapHandle> swapDatabaseFile(Uint8List newDbBytes);

  /// شبكة أمان الإقلاع (FR-11-02): علامة `.restore-ok` متروكة = استعادة
  /// قُطعت بالمنتصف → إعادة القاعدة القديمة لمكانها وحذف العلامة.
  Future<void> recoverInterruptedRestore();

  /// يفتح القاعدة من مسارها (المستعادة أو المرجعة) بالمصنع المناسب.
  Future<AppDatabase> openDatabase();
}
