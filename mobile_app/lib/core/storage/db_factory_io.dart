/// مصنع قاعدة البيانات للمنصات الأصلية (أندرويد/iOS) — sqflite الرسمي.
library;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// يقرر مسار ملف قاعدة البيانات داخل مجلد مستندات التطبيق.
Future<String> resolveDatabasePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'finacc.db');
}

/// مصنع sqflite الرسمي على المنصات الأصلية.
DatabaseFactory get platformDatabaseFactory => databaseFactory;
