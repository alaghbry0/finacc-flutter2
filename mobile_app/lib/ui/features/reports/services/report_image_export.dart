/// تصدير التقرير إلى صورة PNG واحدة (V7-B، عدة تصدير التقارير).
///
/// **آلية الصورة المعتمدة (قرار نقد V7-5)**: ترسيم PDF نفسه عبر
/// `Printing.raster(dpi: 150)` — نفس آلية معاينة الطباعة القائمة
/// (`pdf_preview_dialog`) — وليس RepaintBoundary (محفوف بمخاطر القوائم
/// الكسولة). الصفحات المرسمة تُركَّب **عموديًا في صورة PNG واحدة**
/// فتنزل عبر `downloadBytes` (الويب حاليًا).
///
/// ## قرار معماري موثق: التركيب عبر dart:ui لا package:image
/// حزمة `image` (4.3.0) متاحة **عبوريًا** فقط (عبر pdf 3.12.0 — تحقق
/// `flutter pub deps`)، لكنها ليست تبعية معلنة في pubspec فاستيرادها
/// المباشر يفعّل قاعدة `depend_on_referenced_packages` (مفعلة عبر
/// flutter_lints → lints/recommended → core) و**يكسر بوابة analyze 0/0**
/// — وpubspec مقفول في V7. البديل الأنظف المتاح: تركيب `dart:ui` الصرف
/// (instantiateImageCodec ← Canvas ← toImage ← toByteData(png)) — نفس
/// الآلية التي تستعملها `PdfRaster.toPng` نفسها في حزمة printing، تعمل
/// على الويب (CanvasKit = Skia/WASM على المعالج — بلا سقف ملموسات GPU)
/// وفي flutter_tester (رسم برمجي) وفي الاختبارات عبر `tester.runAsync`.
///
/// ## حدود التصميم
/// - **السقف** [maxPages] (افتراضي 12): أكثر من ذلك يعيد
///   [ImageExportResult.tooLong] **بلا تنزيل** — المستدعي (شاشة
///   التقارير) يعرض `l10n.reportSimExportImageCap`.
/// - لا SnackBar هنا إطلاقًا: الدالة تعيد النتيجة والمستدعي يقرر
///   الرسالة (`l10n.reportSimExportImageDone` عند النجاح) — عقد أنظف
///   للاختبار بلا Scaffold.
/// - التكامل الكامل (قناة printing للترسيم) يغطيه التحقق الحي للمنسق —
///   اختبارات الوحدة تغطي التركيب النقي والسقف.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/utils/web_download.dart';
import 'report_excel_export.dart' show sanitizeReportFileName;

/// نتيجة تصدير صورة التقرير.
enum ImageExportResult {
  /// نُزِّلت صورة PNG مركّبة بنجاح.
  done,

  /// التقرير أطول من السقف — لم يُنزَّل شيء؛ المستدعي يعرض رسالة السقف.
  tooLong,
}

/// يبني PDF التقرير، يرسم صفحاته (150dpi)، يركبها عموديًا في صورة PNG
/// واحدة وينزّلها.
///
/// [buildPdf] يُستدعى عند الطلب (باني `ReportPdfBuilder.build` عادة).
/// [fileName] بلا امتداد (يُضاف `.png` بعد تنظيف محارف المسارات).
/// [maxPages] سقف عدد الصفحات في الصورة الواحدة.
Future<ImageExportResult> exportReportImage({
  required Future<pw.Document> Function() buildPdf,
  required String fileName,
  int maxPages = 12,
}) async {
  final pdf = await buildPdf();
  final bytes = await pdf.save();
  // ترسيم الصفحات بدقة 150 — بنمط pdf_preview_dialog. **مراجعة V7 🟡-5:
  // نأخذ سقف+1 فقط** — تقرير من 50 صفحة كان يُرسَم كاملاً (~435MB
  // نقطية) قبل رفض السقف؛ الآن الذروة محصورة عند 13 صفحة ثم القرار.
  final pages = await Printing.raster(
    bytes,
    dpi: 150,
  ).take(maxPages + 1).toList();

  // السقف أولًا — قبل أي ترميز PNG أو تنزيل.
  if (evaluateImagePageCap(pages.length, maxPages: maxPages) ==
      ImageExportResult.tooLong) {
    return ImageExportResult.tooLong;
  }

  final pagePngs = <Uint8List>[];
  for (final page in pages) {
    pagePngs.add(await page.toPng());
  }
  final composed = await composePngPagesVertically(pagePngs);
  downloadBytes(
    composed,
    '${sanitizeReportFileName(fileName)}.png',
    mime: 'image/png',
  );
  return ImageExportResult.done;
}

/// فحص سقف صفحات صورة التقرير — **نقي** قابل للاختبار بلا قناة printing.
ImageExportResult evaluateImagePageCap(int pageCount, {required int maxPages}) {
  return pageCount > maxPages
      ? ImageExportResult.tooLong
      : ImageExportResult.done;
}

/// يركّب صور صفحات PNG **عموديًا في صورة PNG واحدة** — نقية بلا
/// قناة printing ولا تنزيل: تحلّ كل صفحة (instantiateImageCodec)، ترسم
/// فوق لوحة بيضاء بعرض أعرض صفحة وارتفاع مجموع الارتفاعات، ثم ترمّز
/// PNG واحدًا.
///
/// تستعمل مباشرة في اختبارات الوحدة (داخل `tester.runAsync` — برامج
/// الترميز حقيقية غير متزامنة) وفي [exportReportImage].
Future<Uint8List> composePngPagesVertically(List<Uint8List> pagePngs) async {
  if (pagePngs.isEmpty) {
    throw ArgumentError('لا صفحات PNG للتركيب', 'pagePngs');
  }

  // 1) فك ترميز كل الصفحات إلى صور dart:ui حقيقية.
  final pages = <ui.Image>[];
  for (final png in pagePngs) {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    pages.add(frame.image);
    codec.dispose();
  }

  // 2) أبعاد اللوحة: أعرض صفحة × مجموع الارتفاعات.
  final width = pages.map((image) => image.width).reduce(math.max);
  final height = pages.fold<int>(0, (sum, image) => sum + image.height);

  // 3) الرسم: خلفية بيضاء أولًا (فرجات العرض المختلف تبيضّ لا تشفّ)
  //    ثم كل صفحة عند إزاحتها العمودية التراكمية.
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
  var offsetY = 0.0;
  for (final image in pages) {
    canvas.drawImage(image, ui.Offset(0, offsetY), ui.Paint());
    offsetY += image.height;
  }

  // 4) ترميز PNG واحد — نفس مسار PdfRaster.toPng في حزمة printing.
  final picture = recorder.endRecording();
  final composed = await picture.toImage(width, height);
  picture.dispose();
  final data = await composed.toByteData(format: ui.ImageByteFormat.png);

  // 5) نظافة الذاكرة — الصور المؤقتة كبيرة بطبيعتها (A4 بدقة 150).
  for (final image in pages) {
    image.dispose();
  }
  composed.dispose();

  if (data == null) {
    throw StateError('تعذّر ترميز صورة PNG المركبة');
  }
  return data.buffer.asUint8List();
}
