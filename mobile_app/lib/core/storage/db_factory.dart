/// اختيار مصنع قاعدة البيانات حسب المنصة (شرطي التصدير).
///
/// - أندرويد/iOS (الإنتاج): مصنع `sqflite` الرسمي.
/// - الويب (المعاينة الحية): `sqflite_common_ffi_web` — محرك SQLite wasm
///   مع تخزين IndexedDB (استمرارية حقيقية) وملفات `sqlite3.wasm` و
///   `sqflite_sw.js` المُخدَّمة نسبياً من مجلد التطبيق نفسه.
library;

export 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';
