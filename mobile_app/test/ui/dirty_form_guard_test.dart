/// اختبارات حماية «التغييرات غير المحفوظة» (P1-4 — موجة UX-fix):
///
/// - الحارس المشترك `DirtyFormGuard`: النموذج النظيف يرجع مباشرة؛ الوسخ
///   يعرض حوار «مغادرة/بقاء»؛ «بقاء» يبقي و«مغادرة» يخرج بلا حوار ثانٍ.
/// - تكامل حقيقي: نموذج الصنف (ItemFormScreen) — تعديل الاسم يجعل
///   الرجوع محروساً بالحوار نفسه، وإفراغه يعيد النظافة.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/core/widgets/dirty_form_guard.dart';
import 'package:mobile_app/ui/features/inventory/views/item_form_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  group('DirtyFormGuard (P1-4) — الحوار الموحد', () {
    /// راوتر من مسارين متداخلين (نمط فروع التطبيق): الرئيسية + نموذج
    /// محروس بالحارس — التداخل يجعل الرجوع متاحاً للـ navigator.
    GoRouter buildRouter(ValueNotifier<bool> dirty) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('الرئيسية'))),
          routes: [
            GoRoute(
              path: 'form',
              builder: (_, _) => ValueListenableBuilder<bool>(
                valueListenable: dirty,
                builder: (context, isDirty, _) => DirtyFormGuard(
                  isDirty: isDirty,
                  child: Scaffold(
                    appBar: AppBar(title: const Text('نموذج محروس')),
                    body: Center(
                      child: SwitchListTile(
                        key: const Key('guard_dirty_switch'),
                        title: const Text('تغييرات'),
                        value: isDirty,
                        onChanged: (v) => dirty.value = v,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    Widget buildApp(GoRouter router) => MaterialApp.router(
      routerConfig: router,
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );

    Future<GoRouter> pumpGuarded(WidgetTester tester) async {
      final dirty = ValueNotifier<bool>(false);
      final router = buildRouter(dirty);
      await tester.pumpWidget(buildApp(router));
      await tester.pump();
      router.go('/form');
      await tester.pumpAndSettle();
      return router;
    }

    /// الرجوع النظامي عبر maybePop (نفس مسار زر الرجوع/الإيماءة).
    Future<void> systemBack(WidgetTester tester) async {
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      await navigator.maybePop();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('نموذج نظيف: الرجوع مباشر بلا حوار', (tester) async {
      final router = await pumpGuarded(tester);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/form');

      await systemBack(tester);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      expect(find.text('تغييرات غير محفوظة'), findsNothing);
      router.dispose();
    });

    testWidgets(
      'نموذج وسخ: الحوار يظهر، «بقاء» يبقي ثم «مغادرة» تخرج بلا تكرار',
      (tester) async {
        final router = await pumpGuarded(tester);

        // اجعل النموذج وسخاً.
        await tester.tap(find.byKey(const Key('guard_dirty_switch')));
        await tester.pump();

        await systemBack(tester);
        await tester.pumpAndSettle();
        expect(find.text('تغييرات غير محفوظة'), findsOneWidget);
        expect(router.routerDelegate.currentConfiguration.uri.path, '/form');

        // «بقاء»: الحوار يُغلق والنموذج يبقى.
        await tester.tap(find.text('بقاء'));
        await tester.pumpAndSettle();
        expect(find.text('تغييرات غير محفوظة'), findsNothing);
        expect(router.routerDelegate.currentConfiguration.uri.path, '/form');

        // رجوع ثانٍ: الحوار مجدداً — «مغادرة» تفتح الباب مرة واحدة وتخرج.
        await systemBack(tester);
        await tester.pumpAndSettle();
        expect(find.text('تغييرات غير محفوظة'), findsOneWidget);
        await tester.tap(find.text('مغادرة'));
        await tester.pumpAndSettle();
        expect(router.routerDelegate.currentConfiguration.uri.path, '/');
        expect(find.text('نموذج محروس'), findsNothing);
        router.dispose();
      },
    );
  });

  group('ItemFormScreen (P1-4) — تكامل حقيقي', () {
    testWidgets(
      'تعديل الاسم يعرض حوار الحماية عند الرجوع وإفراغه يعيد النظافة',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.runAsync(() async {
          final seeded = await openSeededApp();
          addTearDown(seeded.$1.close);
          final controller = AppController(forTesting: seeded.$1);
          await controller.decidePhaseForTest();
          controller.unlockSession();
          addTearDown(controller.dispose);

          final router = GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('الرئيسية'))),
                routes: [
                  // بلا seam: الشاشة تنشئ نموذجها وتحمّله (نمط الإنتاج)
                  // — لقطة الأساس تُلتقط بعد التحميل وقبل أي تعديل.
                  GoRoute(
                    path: 'form',
                    builder: (_, _) => const ItemFormScreen(),
                  ),
                ],
              ),
            ],
          );
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
          // بناء الشاشة أولاً (يبدأ التحميل) ثم مهلة حقيقية لاكتمال FFI
          // ثم مضخات لإعادة البناء بالحقول — لقطة الأساس تُلتقط هنا.
          router.go('/form');
          await pumpQuietly(tester, 4);
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await pumpQuietly(tester, 8);
          expect(find.byKey(const Key('item_form_name_field')), findsOneWidget);

          // تعديل الاسم → وسخ.
          await tester.enterText(
            find.byKey(const Key('item_form_name_field')),
            'صنف اختبار الحماية',
          );
          await pumpQuietly(tester, 4);

          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator).first,
          );
          await navigator.maybePop();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          expect(find.text('تغييرات غير محفوظة'), findsOneWidget);
          expect(router.routerDelegate.currentConfiguration.uri.path, '/form');

          // «بقاء»: الحوار يُغلق والنموذج يبقى.
          await tester.tap(find.text('بقاء'));
          await tester.pumpAndSettle();
          expect(find.text('تغييرات غير محفوظة'), findsNothing);
          expect(router.routerDelegate.currentConfiguration.uri.path, '/form');

          // نظيف من جديد بعد إفراغ التعديل → رجوع مباشر بلا حوار.
          await tester.enterText(
            find.byKey(const Key('item_form_name_field')),
            '',
          );
          await pumpQuietly(tester, 4);
          await navigator.maybePop();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(find.text('تغييرات غير محفوظة'), findsNothing);
          expect(router.routerDelegate.currentConfiguration.uri.path, '/');
          router.dispose();
        });
      },
    );
  });
}
