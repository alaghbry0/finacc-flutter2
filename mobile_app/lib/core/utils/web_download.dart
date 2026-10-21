/// تنزيل ملف إلى جهاز المستخدم — **مساعد مشروط بالمنصة** (V7):
/// واجهة واحدة `downloadBytes`/`downloadText` يستهلكها مصدّرو التقارير
/// (صورة PNG / تفوق xlsx / PDF) بلا علم بالمنصة.
///
/// - **الويب** (`web_download_web.dart` عبر package:web): Blob +
///   `URL.createObjectURL` + عنصر `<a download>` نقر برمجي ثم إلغاء
///   الرابط — سلوك المتصفح القياسي (قد يستأذن المتصفح عدة ملفات).
/// - **غير الويب** (`web_download_stub.dart`): كعب صادق `UnsupportedError`
///   بنمط `backup_store_web.dart` (مسار أندرويد لاحق عبر share_plus
///   القائمة — موثق بخطة ما بعد V7).
///
/// القرار (نقد V7-3): package:web الرسمي بدل dart:html المهمل —
/// analyze يبقى 0/0 ومتوافق مع بناءات WASM المستقبلية.
library;

export 'web_download_stub.dart'
    if (dart.library.js_interop) 'web_download_web.dart';
