/// اختبارات الاستهلاك الفعلي لعرض UX-2a عبر جذر التطبيق الحقيقي
/// (`FinAccApp`): حجم الخط (`display.font_scale`) يرفع textScaler لكامل
/// التطبيق، والتباين العالي (`ui.high_contrast`) يبدّل الثيم لأسطح صافية
/// ونصوص قصوى — كلاهما فوراً بلا إعادة تشغيل.
///
/// **كل الجسد داخل `tester.runAsync`** (نمط aging/stocktake الموثق): فتح
/// القاعدة و`decidePhaseForTest` وضبط السياسات استعلامات FFI حقيقية لا
/// تتقدم في منطقة fake-async للاختبار — بدونها يعلّق أول await إلى الأبد.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/app.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  /// عنصر تحت MediaQuery الجذري (الملاحّة داخل builder التطبيق) —
  /// يُستخدم لقراءة textScaler وTheme الحية.
  Future<BuildContext> appContext(WidgetTester tester) async {
    await pumpQuietly(tester, 12);
    return tester.element(find.byType(Navigator).first);
  }

  testWidgets(
    'font_scale: normal بلا تجاوز، وlarge يرفع textScaler لكامل التطبيق',
    (tester) async {
      await tester.runAsync(() async {
        final app = await openUniqueFileApp();
        addTearDown(app.close);
        final controller = AppController(forTesting: app);
        await controller.decidePhaseForTest();
        addTearDown(controller.dispose);

        await tester.pumpWidget(FinAccApp(controller: controller));
        // normal: القياس 1.0 حرفياً (لا تجاوز MediaQuery إطلاقاً).
        var context = await appContext(tester);
        expect(MediaQuery.textScalerOf(context).scale(14), 14.0);

        // large: كل النصوص تتوسع بـ1.15 فوراً من الجذر.
        await controller.setFontScale('large');
        context = await appContext(tester);
        expect(
          MediaQuery.textScalerOf(context).scale(14),
          closeTo(14 * 1.15, 0.01),
        );

        // xlarge: 1.3.
        await controller.setFontScale('xlarge');
        context = await appContext(tester);
        expect(
          MediaQuery.textScalerOf(context).scale(14),
          closeTo(14 * 1.3, 0.01),
        );
      });
    },
  );

  testWidgets('high_contrast: ثيم فاتح بأسطح بيضاء وحبر خالص وحدود قصوى', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final controller = AppController(forTesting: app);
      await controller.decidePhaseForTest();
      addTearDown(controller.dispose);
      await controller.setThemeMode('light');

      await tester.pumpWidget(FinAccApp(controller: controller));
      var context = await appContext(tester);
      var theme = Theme.of(context);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF4F8F6));
      expect(theme.colorScheme.onSurface, isNot(const Color(0xFF000000)));

      // التبديل فوري: أسطح صافية وحبر خالص وحدود مؤكدة.
      await controller.setHighContrast(true);
      context = await appContext(tester);
      theme = Theme.of(context);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSurface, const Color(0xFF000000));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF000000));
      expect(theme.colorScheme.outlineVariant, const Color(0xFF000000));
      expect(theme.brightness, Brightness.light);
    });
  });

  testWidgets('high_contrast داكناً: أسود صافٍ ونص أبيض قصوى', (tester) async {
    await tester.runAsync(() async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final controller = AppController(forTesting: app);
      await controller.decidePhaseForTest();
      addTearDown(controller.dispose);
      await controller.setThemeMode('dark');
      await controller.setHighContrast(true);

      await tester.pumpWidget(FinAccApp(controller: controller));
      final context = await appContext(tester);
      final theme = Theme.of(context);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(theme.colorScheme.onSurface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.surface, const Color(0xFF000000));
    });
  });
}
