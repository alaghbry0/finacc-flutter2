/// تنزيل الملفات — **كعب غير الويب** (V7): أندرويد/دسكتوب تستخدم
/// مسارات المشاركة والحفظ الأصلية (share_plus/file_picker القائمة)
/// فالتنزيل المباشر غير مدعوم بعد — كعب صادق بنمط `backup_store_web`
/// (رسالة واضحة بدل سكوت أو استثناء مبهم)؛ يوثق بخطة ما بعد V7.
library;

void downloadBytes(
  List<int> bytes,
  String fileName, {
  String mime = 'application/octet-stream',
}) {
  throw UnsupportedError(
    'التنزيل المباشر مدعوم على الويب فقط حالياً — استخدم المشاركة الأصلية.',
  );
}

void downloadText(String text, String fileName, {String mime = 'text/plain'}) {
  throw UnsupportedError(
    'التنزيل المباشر مدعوم على الويب فقط حالياً — استخدم المشاركة الأصلية.',
  );
}
