/// اختبار انحدار: عنوان URL يتبع المسارات الفرعية للفرع (go لا push).
///
/// اكتُشف حياً: push كان يترك #/more ثابتاً عند فتح سجل التدقيق وتغيير
/// الرمز — الإصلاح: go من شاشة الإعدادات.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/router/app_router.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  testWidgets('go للمسار الفرعي يحدّث URI ثم العودة تعيد /more', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();

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
      await pumpQuietly(tester, 6);

      router.go('/more');
      await pumpQuietly(tester, 6);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/more');

      router.go('/more/audit-log');
      await pumpQuietly(tester, 8);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/more/audit-log',
        reason: 'عنوان URL يجب أن يتبع المسار الفرعي',
      );

      router.go('/more/change-pin');
      await pumpQuietly(tester, 8);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/more/change-pin',
      );

      // العودة إلى جذر الفرع.
      router.go('/more');
      await pumpQuietly(tester, 6);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/more');

      router.dispose();
      controller.dispose();
    });
  });
}
