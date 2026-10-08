/// مخزن ملفات النسخ للمنصات الأصلية (أندرويد/iOS) — ملفات حقيقية.
///
/// - ملف القاعدة: `documents/finacc.db` (نفس مسار `resolveDatabasePath`).
/// - مجلد النسخ: `documents/backups/FinAcc-Backup-….finbak` (FR-11-01).
/// - الاستبدال الذرّي (FR-11-02): كتابة مؤقتة → تحويل الحالية إلى
///   `finacc.db.pre-restore` → `rename` ذرّي للجديدة → علامة `.restore-ok`
///   تُحذف بعد نجاح الفتح (commit)؛ أي فشل = rollback يعيد القديمة.
///
/// عمليات الملفات متزامنة (`Sync`) عمداً: قاعدة SQLite محلية صغيرة،
/// وتسلسل العملية الضمني أضمن للترتيب الذرّي (lint `avoid_slow_async_io`
/// يمنع البطيئة منها أصلاً).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import 'backup_store.dart';

/// المخزن الأصلي الافتراضي — مسار القاعدة الرسمي ومجلد `backups/` بجواره.
Future<BackupFileStore> defaultBackupFileStore() async {
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, AppDatabase.databaseName);
  return IoBackupStore(dbPath: dbPath);
}

/// تنفيذ الملفات الحقيقية — قابل للحقن بمسارات مخصصة في الاختبارات.
class IoBackupStore implements BackupFileStore {
  IoBackupStore({required String dbPath, String? backupsDirPath})
    : dbPath = dbPath,
      backupsDirPath = backupsDirPath ?? p.join(p.dirname(dbPath), 'backups');

  /// المسار المطلق لملف القاعدة.
  final String dbPath;

  /// مجلد حفظ النسخ (يُنشأ عند أول كتابة).
  final String backupsDirPath;

  @override
  bool get isSupported => true;

  @override
  Future<String> databasePath() async => dbPath;

  Directory get _backupsDir => Directory(backupsDirPath);

  File get _dbFile => File(dbPath);

  File get _preRestoreFile => File('$dbPath.pre-restore');

  File get _markerFile => File('$dbPath.restore-ok');

  File get _tmpFile => File('$dbPath.restore-tmp');

  @override
  Future<Uint8List> readDatabaseFile() async {
    return Uint8List.fromList(_dbFile.readAsBytesSync());
  }

  @override
  Future<int?> databaseFileSize() async {
    if (!_dbFile.existsSync()) return null;
    return _dbFile.lengthSync();
  }

  @override
  Future<String> backupFilePath(String fileName) async =>
      p.join(backupsDirPath, fileName);

  @override
  Future<Uint8List> readBackupFile(String fileName) async {
    return Uint8List.fromList(
      File(p.join(backupsDirPath, fileName)).readAsBytesSync(),
    );
  }

  @override
  Future<void> writeBackupFile(String fileName, Uint8List bytes) async {
    if (!_backupsDir.existsSync()) {
      _backupsDir.createSync(recursive: true);
    }
    final file = File(p.join(backupsDirPath, fileName));
    file.writeAsBytesSync(bytes, flush: true);
  }

  @override
  Future<void> deleteBackupFile(String fileName) async {
    final file = File(p.join(backupsDirPath, fileName));
    if (file.existsSync()) file.deleteSync();
  }

  @override
  Future<List<BackupFileInfo>> listBackupFiles() async {
    if (!_backupsDir.existsSync()) return const <BackupFileInfo>[];
    final files = _backupsDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.finbak'))
        .toList(growable: false);
    return [
      for (final file in files)
        BackupFileInfo(
          fileName: p.basename(file.path),
          sizeBytes: file.lengthSync(),
          modifiedAt: file.statSync().modified.toUtc(),
        ),
    ];
  }

  @override
  Future<DatabaseSwapHandle> swapDatabaseFile(Uint8List newDbBytes) async {
    // جانبيات WAL للقاعدة المغلقة — بعد checkpoint(TRUNCATE) فارغة؛
    // تُحذف كي لا تلتصق بالملف الجديد.
    _deleteSidecars();
    // 1) كتابة القاعدة المستعادة في ملف مؤقت بجانب الهدف (نفس نظام
    //    الملفات — rename ذرّي مضمون).
    if (_tmpFile.existsSync()) _tmpFile.deleteSync();
    _tmpFile.writeAsBytesSync(newDbBytes, flush: true);
    // 2) تحويل القاعدة الحالية إلى جانبية (شبكة أمان الفشل بالمنتصف).
    if (_preRestoreFile.existsSync()) _preRestoreFile.deleteSync();
    if (_dbFile.existsSync()) {
      _dbFile.renameSync(_preRestoreFile.path);
    }
    // 3) الرفع الذرّي للملف الجديد + علامة «عملية جارية».
    _tmpFile.renameSync(dbPath);
    _markerFile.writeAsStringSync(
      DateTime.now().toUtc().toIso8601String(),
      flush: true,
    );
    return _IoDatabaseSwapHandle(owner: this);
  }

  @override
  Future<void> recoverInterruptedRestore() async {
    if (!_markerFile.existsSync()) return;
    // علامة متروكة = استعادة قُطعت قبل الاعتماد → الإقلاع بالنسخة
    // القديمة (سياسة الإخفاق حرفياً — FR-11-02).
    if (_preRestoreFile.existsSync()) {
      _deleteSidecars();
      if (_dbFile.existsSync()) _dbFile.deleteSync();
      _preRestoreFile.renameSync(dbPath);
    }
    if (_markerFile.existsSync()) _markerFile.deleteSync();
    if (_tmpFile.existsSync()) _tmpFile.deleteSync();
  }

  @override
  Future<AppDatabase> openDatabase() async {
    // `databaseFactory` العام: مصنع sqflite الأصلي في الإنتاج، ومصنع FFI
    // في الاختبارات (يضبطه helper الاختبارات) — نفس مسار AppDatabase.
    return AppDatabase.openWith(databaseFactory, dbPath);
  }

  /// يحذف ملفات `-wal`/`-shm` الجانبية إن وُجدت.
  void _deleteSidecars() {
    for (final suffix in const ['-wal', '-shm']) {
      final file = File('$dbPath$suffix');
      if (file.existsSync()) file.deleteSync();
    }
  }
}

/// مقبض الاستبدال الذرّي — يغلق على المخزن صاحب المسارات.
class _IoDatabaseSwapHandle implements DatabaseSwapHandle {
  _IoDatabaseSwapHandle({required IoBackupStore owner}) : _store = owner;

  final IoBackupStore _store;

  @override
  Future<void> commit() async {
    // نجاح موثّق: إزالة العلامة ثم القاعدة القديمة الجانبية.
    final marker = _store._markerFile;
    if (marker.existsSync()) marker.deleteSync();
    final pre = _store._preRestoreFile;
    if (pre.existsSync()) pre.deleteSync();
  }

  @override
  Future<void> rollback() async {
    // إرجاع القديمة: حذف جانبيات الجديدة + الملف الجديد نفسه ثم rename.
    _store._deleteSidecars();
    final db = _store._dbFile;
    if (db.existsSync()) db.deleteSync();
    final pre = _store._preRestoreFile;
    if (pre.existsSync()) pre.renameSync(_store.dbPath);
    final marker = _store._markerFile;
    if (marker.existsSync()) marker.deleteSync();
    final tmp = _store._tmpFile;
    if (tmp.existsSync()) tmp.deleteSync();
  }
}
