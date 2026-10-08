/// اختيار مخزن ملفات النسخ حسب المنصة (شرطي التصدير) — نمط
/// `core/storage/db_factory.dart`: مصنع افتراضي واحد لكل منصة بنفس
/// التوقيع `defaultBackupFileStore()`.
library;

export 'backup_store_io.dart'
    if (dart.library.js_interop) 'backup_store_web.dart';
