/// مصنع قاعدة البيانات لبيئة الويب — SQLite wasm عبر IndexedDB.
///
/// اسم القاعدة اسم افتراضي داخل نظام ملفات IndexedDB الخاص بالمحرك،
/// والاستمرارية مضمونة عبر إعادة تحميل الصفحة (بيئة المعاينة الحية).
library;

import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart' show DatabaseFactory;

/// اسم القاعدة داخل نظام ملفات IndexedDB (لا مسارات حقيقية على الويب).
Future<String> resolveDatabasePath() async => 'finacc.db';

/// مصنع FFI-Web: sqlite3.wasm + Shared Worker (مع سقوط آمن إلى Web Worker
/// ثم إلى الخيط الرئيسي).
DatabaseFactory get platformDatabaseFactory => databaseFactoryFfiWeb;
