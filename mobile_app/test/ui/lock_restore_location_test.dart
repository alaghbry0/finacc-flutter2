/// اختبار استعادة الموقع بعد فتح القفل (P0-1b):
///
/// القفل التلقائي/اليدوي من مسار عميق كان يُسقط المستخدم على `/home`
/// دائماً بعد الفتح — الآن يُسجَّل المسار المقصود (المسار فقط — بلا بيانات
/// حساسة) قبل تحويل القفل، وبعد الفتح الناجح يعود إليه؛ والمسار يُستهلك
/// مرة واحدة (لا حلقات).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/router/app_router.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  /// يرفع التطبيق كاملاً فوق راوتر حقيقي بجلسة مفتوحة.
  Future<RouterHandle> boot(WidgetTester tester) async {
    final seeded = await openSeededApp();
    addTearDown(seeded.$1.close);
    final controller = AppController(forTesting: seeded.$1);
    await controller.decidePhaseForTest();
    controller.unlockSession();
    addTearDown(controller.dispose);

    final router = buildAppRouter(controller);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await pumpQuietly(tester, 8);
    return (router, controller);
  }

  testWidgets('قفل من مسار عميق ثم فتح: العودة للمسار الأصلي', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final (router, controller) = await boot(tester);

      // مسار عميق: قائمة الأصناف داخل فرع المخزون.
      router.go('/inventory/items');
      await pumpQuietly(tester, 8);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/inventory/items',
      );

      // قفل تلقائي/يدوي أثناء العمل هناك.
      controller.lock();
      await pumpQuietly(tester, 8);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/lock');

      // فتح ناجح → العودة للمسار العميق لا للرئيسية.
      controller.unlockSession();
      await pumpQuietly(tester, 8);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/inventory/items',
        reason: 'بعد الفتح يعود المستخدم لموقعه الأصلي (P0-1b)',
      );

      router.dispose();
    });
  });

  testWidgets('المسار يُستهلك مرة واحدة ومسار القفل لا يُخزَّن', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final (router, controller) = await boot(tester);

      // من الرئيسية: قفل → فتح → الرئيسية.
      router.go('/home');
      await pumpQuietly(tester, 6);
      controller.lock();
      await pumpQuietly(tester, 6);
      expect(controller.lockedFromPathForTest, '/home');

      // إعادة التوجيه من داخل /lock نفسه لا تعيد التخزين (لا حلقات).
      controller.unlockSession();
      await pumpQuietly(tester, 8);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
      expect(
        controller.lockedFromPathForTest,
        isNull,
        reason: 'المسار يُستهلك مرة واحدة',
      );

      // قفل ثانٍ من مسار آخر → يعود للمسار الجديد.
      router.go('/cash');
      await pumpQuietly(tester, 6);
      controller.lock();
      await pumpQuietly(tester, 6);
      controller.unlockSession();
      await pumpQuietly(tester, 8);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/cash');

      router.dispose();
    });
  });
}

/// مقبض الاختبار: الراوتر والمتحكم.
typedef RouterHandle = (GoRouter, AppController);
