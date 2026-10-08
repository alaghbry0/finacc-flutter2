/// مخزن ملفات النسخ لبيئة الويب — دفاعي (المعاينة الحية).
///
/// القاعدة على الويب تعيش داخل IndexedDB عبر محرك FFI-Web فلا وصول لملف
/// `finacc.db` كبايتات — لذا الإنشاء/الاستعادة/المشاركة غير مدعومة هنا
/// وتُدار الواجهة برسالة «متاح على أندرويد». منطق الصيغة نفسه
/// (`backup_format.dart`) نقي ومُختبَر على أي منصة.
library;

import 'dart:typed_data';

import '../../../core/storage/app_database.dart';
import 'backup_store.dart';

/// مخزن الويب الافتراضي — كله غير مدعوم عدا القوائم الفارغة.
Future<BackupFileStore> defaultBackupFileStore() async =>
    const WebBackupStore();

/// تنفيذ ويب دفاعي — لا عمليات ملفية حقيقية.
class WebBackupStore implements BackupFileStore {
  const WebBackupStore();

  @override
  bool get isSupported => false;

  @override
  Future<String> databasePath() async =>
      throw UnsupportedError('لا مسارات ملفات على الويب');

  @override
  Future<Uint8List> readDatabaseFile() async =>
      throw UnsupportedError('النسخ الاحتياطي غير مدعوم على الويب');

  @override
  Future<int?> databaseFileSize() async => null;

  @override
  Future<String> backupFilePath(String fileName) async =>
      throw UnsupportedError('النسخ الاحتياطي غير مدعوم على الويب');

  @override
  Future<Uint8List> readBackupFile(String fileName) async =>
      throw UnsupportedError('النسخ الاحتياطي غير مدعوم على الويب');

  @override
  Future<void> writeBackupFile(String fileName, Uint8List bytes) async =>
      throw UnsupportedError('النسخ الاحتياطي غير مدعوم على الويب');

  @override
  Future<void> deleteBackupFile(String fileName) async =>
      throw UnsupportedError('النسخ الاحتياطي غير مدعوم على الويب');

  @override
  Future<List<BackupFileInfo>> listBackupFiles() async =>
      const <BackupFileInfo>[];

  @override
  Future<DatabaseSwapHandle> swapDatabaseFile(Uint8List newDbBytes) async =>
      throw UnsupportedError('الاستعادة غير مدعومة على الويب');

  @override
  Future<void> recoverInterruptedRestore() async {
    // لا ملفات على الويب — لا شيء للاسترداد.
  }

  @override
  Future<AppDatabase> openDatabase() async =>
      throw UnsupportedError('فتح قاعدة من ملف غير مدعوم على الويب');
}
