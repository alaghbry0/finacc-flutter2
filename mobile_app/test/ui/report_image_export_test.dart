/// اختبار تصدير صورة التقرير (V7-B): التركيب العمودي النقي
/// (صفحات PNG ← صورة PNG واحدة عبر dart:ui — انظر القرار الموثق في
/// report_image_export.dart) + فحص السقف (tooLong عند تجاوز maxPages).
/// التكامل الكامل (قناة printing للترسيم) يغطيه التحقق الحي للمنسق —
/// قناة printing لا تعمل في اختبارات الويدجت.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/ui/features/reports/services/report_image_export.dart';

void main() {
  test('فحص السقف نقي: tooLong فقط عند تجاوز maxPages', () {
    expect(
      evaluateImagePageCap(13, maxPages: 12),
      ImageExportResult.tooLong,
      reason: '13 صفحة فوق سقف 12',
    );
    expect(
      evaluateImagePageCap(12, maxPages: 12),
      ImageExportResult.done,
      reason: 'السقف نفسه مقبول (أكثر من maxPages فقط يُرفض)',
    );
    expect(evaluateImagePageCap(1, maxPages: 12), ImageExportResult.done);
    expect(evaluateImagePageCap(0, maxPages: 12), ImageExportResult.done);
    expect(evaluateImagePageCap(3, maxPages: 2), ImageExportResult.tooLong);
  });

  testWidgets('التركيب العمودي النقي: ثلاث صفحات ← PNG واحد بأبعاد مجمعة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // صفحات بأحجام مختلفة عن قصد: العرض الأكبر يحكم، والفرجة تبيضّ.
      final page1 = await _tinyPng(10, 4, const ui.Color(0xFFFF0000));
      final page2 = await _tinyPng(6, 3, const ui.Color(0xFF0000FF));
      final page3 = await _tinyPng(10, 5, const ui.Color(0xFF00AA00));

      final composed = await composePngPagesVertically([page1, page2, page3]);

      // بصمة PNG.
      expect(composed.length, greaterThan(8));
      expect(composed[0], 0x89);
      expect(String.fromCharCodes(composed.sublist(1, 4)), 'PNG');

      // فك التركيب والتحقق من الأبعاد: العرض الأكبر × مجموع الارتفاعات.
      final codec = await ui.instantiateImageCodec(composed);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      expect(image.width, 10, reason: 'أعرض صفحة تحكم عرض الصورة');
      expect(image.height, 12, reason: '4 + 3 + 5 = 12');
      codec.dispose();

      // البكسلات: صفحة 1 حمراء أعلى، صفحة 2 زرقاء تحتها، والفرقة يمين
      // الصفحة 2 بيضاء (لا شفافية)، وصفحة 3 خضراء أسفل.
      final pixels = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      expect(pixels, isNotNull);
      final rgba = pixels!;
      _expectPixel(rgba, 0, 0, 0xFF, 0x00, 0x00); // صفحة 1: أحمر.
      _expectPixel(rgba, 0, 4, 0x00, 0x00, 0xFF); // صفحة 2: أزرق.
      _expectPixel(rgba, 7, 4, 0xFF, 0xFF, 0xFF); // فرجة يمين الصفحة 2: أبيض.
      _expectPixel(rgba, 0, 7, 0x00, 0xAA, 0x00); // صفحة 3: أخضر.
      image.dispose();
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('التركيب: قائمة فارغة ترفض بـArgumentError', (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        composePngPagesVertically([]),
        throwsA(isA<ArgumentError>()),
      );
    });
  }, timeout: const Timeout(Duration(minutes: 1)));

  testWidgets('التركيب: صفحة واحدة تعاد بجودة سليمة', (tester) async {
    await tester.runAsync(() async {
      final page = await _tinyPng(8, 6, const ui.Color(0xFF123456));
      final composed = await composePngPagesVertically([page]);
      final codec = await ui.instantiateImageCodec(composed);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      expect(image.width, 8);
      expect(image.height, 6);
      codec.dispose();
      image.dispose();
    });
  }, timeout: const Timeout(Duration(minutes: 1)));
}

/// صورة PNG صغيرة بلون صامت — عبر dart:ui (نفس مسار الإنتاج).
Future<Uint8List> _tinyPng(int width, int height, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) {
    throw StateError('تعذّر ترميز صورة الاختبار');
  }
  return data.buffer.asUint8List();
}

/// يتحقق من بكسل RGBA (بترتيب R,G,B,A) عند (x, y) بلون متوقع تقريبًا —
/// ترميز PNG قد يحرف القيمة درجة واحدة بضغط بلا فقد للفاقد.
void _expectPixel(ByteData rgba, int x, int y, int r, int g, int b) {
  final offset = (y * 10 + x) * 4; // العرض الثابت 10 في الاختبار أعلاه.
  final pr = rgba.getUint8(offset);
  final pg = rgba.getUint8(offset + 1);
  final pb = rgba.getUint8(offset + 2);
  expect((pr - r).abs(), lessThan(3), reason: 'قناة R عند ($x,$y)');
  expect((pg - g).abs(), lessThan(3), reason: 'قناة G عند ($x,$y)');
  expect((pb - b).abs(), lessThan(3), reason: 'قناة B عند ($x,$y)');
}
