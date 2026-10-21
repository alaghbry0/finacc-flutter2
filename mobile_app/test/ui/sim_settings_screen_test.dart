/// اختبارات V7-A — شاشة «إعدادات» (جذر تبويب /more) بهوية Simple
/// Invoice Manager: الترويسة الفرعية بعنوان «إعدادات» **بلا زر رجوع**
/// (لا أب يُرجَع إليه — نقد F9-a)، بطاقة المنشأة أعلى كما هي (FR-12-05)،
/// الصفوف الستة المقفلة بنمط `.setting-row` (عناوين وأوصاف ومسارات)،
/// فاصل «المزيد من إعدادات FinAcc»، الأقسام الباقية بصفوف SIM (التخصيص/
/// الأمان/البيانات/مركز التقارير) وبطاقة «حول» أسفل القائمة — كل وجهة
/// قديمة بقيت قابلة الوصول.
///
/// الإعداد بنمط `sim_voucher_screen_test` القائم: قاعدة FFI حقيقية (ملف
/// فريد + تأسيس جاهز) + راوتر التطبيق كاملاً (bootApp) + Provider +
/// تعريب عربي، وكل التفاعل داخل `runAsync` (القاعدة حقيقية غير متزامنة).
/// كل مطابقات النص مقيّدة بشجرة SettingsScreen — فروع IndexedStack الأخرى
/// (الرئيسية المبنية عند الإقلاع) تبقى بالشجرة خارج المسرح ونصوصها
/// («إعدادات»/«التقارير» في ترويسة الرئيسية) لا تُحسب عليها.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/router/app_router.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/core/widgets/sim_list_widgets.dart';
import 'package:mobile_app/ui/features/settings/views/settings_screen.dart';
import 'package:mobile_app/ui/features/settings/views/widgets/settings_about_card.dart';
import 'package:mobile_app/ui/features/settings/views/widgets/settings_company_card.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;
  bool dbOpen = false;

  /// قاعدة مؤسّسة (تفتح مرة لكل اختبار وتغلق مع نهايته).
  Future<void> openDb() async {
    if (dbOpen) return;
    final seeded = await openSeededApp();
    handle = seeded.$1;
    addTearDown(() async {
      dbOpen = false;
      await handle.close();
    });
    dbOpen = true;
  }

  /// يبني التطبيق كاملاً (راوتر + جلسة مفتوحة) — نمط sim_voucher.
  Future<GoRouter> bootApp(WidgetTester tester) async {
    final controller = AppController(forTesting: handle);
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
    await pumpQuietly(tester);
    return router;
  }

  /// مطابقة داخل شجرة شاشة الإعدادات وحدها.
  Finder inSettings(Finder finder) =>
      find.descendant(of: find.byType(SettingsScreen), matching: finder);

  group('V7-A — شاشة الإعدادات بهوية SIM', () {
    testWidgets('١) الترويسة الفرعية بعنوان «إعدادات» وبلا زر رجوع', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await _openSettings(tester, router);

        // الترويسة الفرعية بعنوان «إعدادات» — جذر تبويب بلا زر رجوع.
        expect(inSettings(find.byType(SimSubHeader)), findsOneWidget);
        expect(inSettings(find.text('إعدادات')), findsOneWidget);
        expect(inSettings(find.byIcon(Icons.arrow_back_rounded)), findsNothing);
        expect(inSettings(find.byType(BackButton)), findsNothing);
        router.dispose();
      });
    });

    testWidgets('٢) الصفوف الستة المقفلة: العناوين والأوصاف حرفياً', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await _openSettings(tester, router);

        // الصفوف الستة — العناوين والأوصاف المقفلة (l10n محمية).
        const expected = <(String, String)>[
          ('الإعدادات ابتدائي', 'الاسم والبلد والعملة الأساسية والشعار'),
          ('اعدادات قالب الفاتورة', 'اختيار القالب والألوان وخصائص الطباعة'),
          ('رأس الفاتورة', 'الترويسة والتوقيعات وختم مدفوع والتذييل'),
          ('ادارة المخزون', 'المخزون والجرد وتنبيهات النفاد'),
          ('عملات متعددة إعدادات', 'العملات وأسعار الصرف اليومية'),
          ('إعداد تصنيف المنتج', 'فئات المنتجات والوحدات'),
        ];
        for (final (title, desc) in expected) {
          expect(inSettings(find.text(title)), findsOneWidget, reason: title);
          expect(inSettings(find.text(desc)), findsOneWidget, reason: title);
        }
        // 6 أساسية + التخصيص 2 + الأمان 2 + النسخ 1 + التقارير 1.
        expect(inSettings(find.byType(SimSettingRow)), findsNWidgets(12));
        router.dispose();
      });
    });

    testWidgets('٣) نقر كل صف من الستة → المسار الصحيح', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await _openSettings(tester, router);

        const destinations = <(String, String)>[
          ('sim_settings_row_basic', '/more/company'),
          ('sim_settings_row_template', '/more/print-templates'),
          ('sim_settings_row_header', '/more/print-templates'),
          ('sim_settings_row_stock', '/inventory'),
          ('sim_settings_row_currency', '/parties/rates'),
          ('sim_settings_row_category', '/inventory/categories-units'),
        ];
        for (final (rowKey, path) in destinations) {
          await tester.tap(find.byKey(Key(rowKey)));
          await _settleDb(tester);
          expect(
            router.routerDelegate.currentConfiguration.uri.path,
            path,
            reason: 'نقر $rowKey يجب أن يقود إلى $path',
          );
          // العودة للمركز ثم الاستقرار قبل الصف التالي.
          await _openSettings(tester, router);
        }
        router.dispose();
      });
    });

    testWidgets('٤) بطاقة المنشأة + فاصل «المزيد» + الأقسام + بطاقة حول', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await _openSettings(tester, router);

        // بطاقة المنشأة باقية ببياناتها الحية (FR-12-05 داخلها).
        expect(inSettings(find.byType(SettingsCompanyCard)), findsOneWidget);
        expect(
          inSettings(find.text('متجر النور للأدوات المنزلية')),
          findsOneWidget,
        );
        expect(inSettings(find.textContaining('ريال يمني')), findsWidgets);
        expect(inSettings(find.text('أبو نور')), findsOneWidget);
        expect(inSettings(find.text('القفل التلقائي بعد')), findsOneWidget);

        // فاصل القسم الصغير + عناوين الأقسام الباقية.
        expect(
          inSettings(find.text('المزيد من إعدادات FinAcc')),
          findsOneWidget,
        );
        expect(inSettings(find.text('التخصيص')), findsOneWidget);
        expect(inSettings(find.text('الأمان')), findsOneWidget);
        expect(inSettings(find.text('البيانات')), findsOneWidget);
        expect(inSettings(find.text('التقارير')), findsOneWidget);

        // صفوف الأقسام الباقية كلها قابلة الوصول (بوابات وأفعال).
        expect(inSettings(find.text('العرض والمظهر')), findsOneWidget);
        expect(inSettings(find.text('تفضيلات البيع')), findsOneWidget);
        expect(inSettings(find.text('تغيير رمز PIN')), findsOneWidget);
        expect(inSettings(find.text('سجل التدقيق')), findsOneWidget);
        expect(inSettings(find.text('قفل التطبيق الآن')), findsOneWidget);
        expect(
          inSettings(find.text('النسخ الاحتياطي والاستعادة')),
          findsOneWidget,
        );
        expect(inSettings(find.text('مسح كل البيانات')), findsOneWidget);
        expect(inSettings(find.text('مركز التقارير والرقابة')), findsOneWidget);

        // بطاقة «حول» باقية أسفل القائمة (بلا مسار).
        expect(inSettings(find.byType(SettingsAboutCard)), findsOneWidget);
        expect(inSettings(find.textContaining('الإصدار')), findsWidgets);
        expect(inSettings(find.text('التراخيص المفتوحة')), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('٥) وجهات الأقسام الباقية تعمل (المظهر/النسخ/التقارير)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await _openSettings(tester, router);

        // عينة الوجهات: المظهر ثم النسخ الاحتياطي ثم مركز التقارير.
        const destinations = <(String, String)>[
          ('sim_settings_row_appearance', '/more/appearance'),
          ('sim_settings_row_backup', '/more/backup'),
          ('sim_settings_row_reports', '/reports'),
        ];
        for (final (rowKey, path) in destinations) {
          await tester.tap(find.byKey(Key(rowKey)));
          await _settleDb(tester);
          expect(
            router.routerDelegate.currentConfiguration.uri.path,
            path,
            reason: 'نقر $rowKey يجب أن يقود إلى $path',
          );
          await _openSettings(tester, router);
        }
        router.dispose();
      });
    });
  });
}

/// يفتح مركز الإعدادات ويستقر حتى **تظهر بطاقة المنشأة فعليًا** (علامة
/// اكتمال التحميل — النموذج FFI حقيقي غير متزامن: دورة مهلات قصيرة
/// بنمط openVoucher بدل عدّاد أعمى).
Future<void> _openSettings(
  WidgetTester tester,
  GoRouter router, {
  int maxWaits = 40,
}) async {
  router.go('/more');
  for (var i = 0; i < maxWaits; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await pumpQuietly(tester, 4);
    if (find.byType(SettingsCompanyCard).evaluate().isNotEmpty) break;
  }
  await pumpQuietly(tester, 4);
}

/// مهلة حقيقية تُنجز استعلامات FFI المعلقة ثم إطارات لإعادة بناء الشجرة.
Future<void> _settleDb(WidgetTester tester, {int frames = 8}) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await pumpQuietly(tester, frames);
}
