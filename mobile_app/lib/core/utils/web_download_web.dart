/// تنزيل الملفات — تنفيذ **الويب** (package:web — V7).
///
/// Blob + objectURL + `<a download>` ثم `revokeObjectURL` فورًا بعد
/// النقر — نفس وصفة التنزيل القياسية للمتصفحات بلا أي dependencies
/// خارج package:web الرسمي (متوافق JS/WASM معًا).
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// ينزّل البايتات باسم ملف ونوع MIME — إنشاء الرابط مؤقت ويُحرَّر
/// مباشرة (المتصفح يمسك نسخته عند بدء التنزيل).
void downloadBytes(
  List<int> bytes,
  String fileName, {
  String mime = 'application/octet-stream',
}) {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

/// ينزّل نصًا (UTF-8) — صيغة ملائمة لملفات CSV النصية إن لزمت.
void downloadText(String text, String fileName, {String mime = 'text/plain'}) {
  downloadBytes(text.codeUnits, fileName, mime: mime);
}
