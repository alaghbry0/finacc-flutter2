/// محرك قاعدة البيانات المحلي — SRS v1.5 §3.3/§5.3/§0.3.
///
/// - SQLite عبر `sqflite` على أندرويد (إنتاج) وعبر محرك FFI-Web في المعاينة
///   (تخزين IndexedDB — استمرارية حقيقية عبر إعادة التحميل).
/// - **WAL مفعّل دائماً** (NFR-06) — ما عدا بيئة الويب حيث يعمل محرك
///   الـ wasm بنظام ملفات IndexedDB الخاص به (يُحاول WAL ويتقبل النتيجة).
/// - `PRAGMA foreign_keys = ON` على كل اتصال.
/// - الهجرات عبر [applyMigrations] بسجل `_migrations` موثّق.
library;

import 'package:sqflite/sqflite.dart';

import 'db_factory.dart';
import 'doc_sequence.dart';
import 'migrations.dart';

/// قاعدة بيانات التطبيق المفتوحة مع خدماتها الأساسية.
class AppDatabase {
  AppDatabase._(this.db, this.journalMode, this.sqliteVersion);

  /// اسم ملف القاعدة (على الويب: اسم قاعدة IndexedDB الافتراضية).
  static const String databaseName = 'finacc.db';

  /// كائن `Database` من sqflite (جاهز للمعاملات والاستعلامات).
  final Database db;

  /// وضع التدوين الفعلي بعد محاولة تفعيل WAL (`wal` عند النجاح).
  final String journalMode;

  /// إصدار SQLite الفعلي (قرار مسار الترقيم الذرّي).
  final String sqliteVersion;

  /// يفتح قاعدة البيانات على المنصة الحالية ويطبّق الهجرات المعلّقة.
  static Future<AppDatabase> open() async {
    final path = await resolveDatabasePath();
    final db = await openAppDatabase(platformDatabaseFactory, path);
    return AppDatabase._(
      db,
      await _readJournalMode(db),
      await _readSqliteVersion(db),
    );
  }

  /// يفتح قاعدة فوق مصنع معيّن ومسار معلن — لاختبارات الوحدة والأدوات.
  static Future<AppDatabase> openWith(
    DatabaseFactory factory,
    String path,
  ) async {
    final db = await openAppDatabase(factory, path);
    return AppDatabase._(
      db,
      await _readJournalMode(db),
      await _readSqliteVersion(db),
    );
  }

  /// خدمة الترقيم الذرّي لهذه القاعدة.
  DocSequenceService get docSequence => DocSequenceService(db);

  /// يغلق القاعدة بلطف (checkpoint WAL ضمنياً).
  Future<void> close() => db.close();

  static Future<Database> openAppDatabase(
    DatabaseFactory factory,
    String path,
  ) {
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: currentSchemaVersion,
        onConfigure: _onConfigure,
        onCreate: (db, _) => applyMigrations(db),
        onUpgrade: (db, _, _) => applyMigrations(db),
        onDowngrade: onDatabaseDowngradeDelete,
      ),
    );
  }

  /// Pragmas الاتصال: قيود المفاتيح الأجنبية دائماً + محاولة WAL.
  ///
  /// ملاحظة: `PRAGMA journal_mode` لا يمكن ضبطه داخل معاملة —
  /// و`onConfigure` يُنفَّذ قبل أي معاملة، فهو الموضع الصحيح.
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL');
    } on DatabaseException {
      // على الويب (VFS IndexedDB) قد لا يدعم المحرك WAL — نقبل النظام
      // الافتراضي للمعاينة فقط؛ الإنتاج على أندرويد يدعمه دائماً.
    }
  }

  static Future<String> _readJournalMode(Database db) async {
    final rows = await db.rawQuery('PRAGMA journal_mode');
    return (rows.first.values.first ?? '').toString();
  }

  static Future<String> _readSqliteVersion(Database db) async {
    final rows = await db.rawQuery('SELECT sqlite_version() AS v');
    return (rows.first['v'] as String?) ?? '';
  }
}
