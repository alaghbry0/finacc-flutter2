/// اختبارات شاشة «الطباعة والفواتير» (موجة UX-3) بالـseam الموثق (نمط
/// settings2): نموذج محمّل مسبقاً داخل runAsync ثم تفاعل حقيقي —
/// بطاقتا القالبين والمختار الافتراضي، نقر قالب يفعّله بالمستودع فوراً،
/// تبديل مفتاح إظهار يحدّث الإعدادات المخزنة، استعادة الافتراضي تعيد
/// البسيط وبذور الجميع، ومسار الراوتر `/more/print-templates` يفتح
/// الشاشة الحقيقية فوق AppController بقاعدة حقيقية.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/repositories/print_template_repository.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/router/app_router.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/settings/view_models/print_templates_view_model.dart';
import 'package:mobile_app/ui/features/settings/views/print_templates_screen.dart';
import 'package:mobile_app/ui/features/printing/templates/invoice_template_settings.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  group('PrintTemplatesScreen — seam', () {
    testWidgets('بطاقتا القالبين معروضتان والبسيط مختاراً افتراضياً', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        final seeded = await openSeededApp();
        addTearDown(seeded.$1.close);
        final vm = PrintTemplatesViewModel(
          printRepo: PrintTemplateRepository(seeded.$1.db),
        );
        await vm.load();
        addTearDown(vm.dispose);

        await tester.pumpWidget(
          wrapWithL10n(PrintTemplatesScreen(viewModel: vm)),
        );
        await pumpQuietly(tester, 10);

        expect(find.text('الطباعة والفواتير'), findsOneWidget);
        expect(find.text('كلاسيكي A4 أفقي'), findsOneWidget);
        expect(find.text('بسيط A4 عمودي'), findsOneWidget);
        // الحراري حُذف بقرار المالك — لا وجود له بالشاشة.
        expect(find.text('حراري 80مم'), findsNothing);
        // مفاتيح الإظهار للقالب البسيط: بلا توقيعات/ختم/ملاحظات
        // (templateSupports) — خمسة مفاتيح.
        expect(find.text('عمود الخصم'), findsOneWidget);
        expect(find.text('خانات التوقيع'), findsNothing);
        expect(find.text('مكان الختم'), findsNothing);
        final switches = tester
            .widgetList<Switch>(find.byType(Switch))
            .toList();
        expect(switches, hasLength(5), reason: 'خصم/وحدة/باركود/ضريبة/تذييل');
        // علامة الاختيار على البسيط حصراً.
        expect(
          find.byIcon(Icons.check_circle_rounded),
          findsOneWidget,
        );
      });
    });

    testWidgets('نقر الكلاسيكي يفعّله بالمستودع فوراً (كتابة لحظية)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        final seeded = await openSeededApp();
        addTearDown(seeded.$1.close);
        final repo = PrintTemplateRepository(seeded.$1.db);
        final vm = PrintTemplatesViewModel(printRepo: repo);
        await vm.load();
        addTearDown(vm.dispose);

        await tester.pumpWidget(
          wrapWithL10n(PrintTemplatesScreen(viewModel: vm)),
        );
        await pumpQuietly(tester, 10);

        await tester.tap(find.text('كلاسيكي A4 أفقي'));
        await pumpQuietly(tester, 8);
        // مهلة حقيقية قبل الفحص — الكتابة عبر FFI (نمط موثق).
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final active = await repo.activeFor('sale');
        expect(active!.code, kInvoiceTemplateClassicA4);
        // والشاشة تعرض الآن مفاتيح الكلاسيكي كاملة (توقيعات/ختم/ملاحظات).
        expect(find.textContaining('خانات التوقيع'), findsOneWidget);
        expect(find.textContaining('مكان الختم'), findsOneWidget);
        expect(
          tester.widgetList<Switch>(find.byType(Switch)).length,
          8,
        );
      });
    });

    testWidgets('تبديل «عمود الخصم» يحدّث الإعدادات المخزنة فوراً', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        final seeded = await openSeededApp();
        addTearDown(seeded.$1.close);
        final repo = PrintTemplateRepository(seeded.$1.db);
        final vm = PrintTemplatesViewModel(printRepo: repo);
        await vm.load();
        addTearDown(vm.dispose);

        await tester.pumpWidget(
          wrapWithL10n(PrintTemplatesScreen(viewModel: vm)),
        );
        await pumpQuietly(tester, 10);

        // أول مفتاح = عمود الخصم (قيمته on افتراضياً).
        final discountSwitch = find.byType(Switch).at(0);
        expect(tester.widget<Switch>(discountSwitch).value, isTrue);
        await tester.tap(discountSwitch);
        await pumpQuietly(tester, 8);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // القيمة الحية انعكست والكتابة تمت للمستودع.
        expect(tester.widget<Switch>(discountSwitch).value, isFalse);
        final active = await repo.activeFor('sale');
        expect(active!.code, kPrintTemplateDefaultCode, reason: 'القالب نفسه');
        expect(active.config.showDiscountColumn, isFalse);
      });
    });

    testWidgets('استعادة الافتراضي تعيد البسيط نشطاً وبذور الجميع', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        final seeded = await openSeededApp();
        addTearDown(seeded.$1.close);
        final repo = PrintTemplateRepository(seeded.$1.db);
        final vm = PrintTemplatesViewModel(printRepo: repo);
        await vm.load();
        addTearDown(vm.dispose);

        // المستخدم فعّل الكلاسيكي وخصّصه (إخفاء عمود الخصم).
        await repo.save(
          kInvoiceTemplateClassicA4,
          kPrintTemplateSeedConfigs[kInvoiceTemplateClassicA4]!
              .copyWith(showDiscountColumn: false),
        );

        await tester.pumpWidget(
          wrapWithL10n(PrintTemplatesScreen(viewModel: vm)),
        );
        await pumpQuietly(tester, 10);
        // إعادة التحميل لجلب الكلاسيكي النشط.
        await tester.pumpWidget(
          wrapWithL10n(PrintTemplatesScreen(viewModel: vm)),
        );
        await vm.load();
        await pumpQuietly(tester, 6);
        expect(vm.state.activeCode, kInvoiceTemplateClassicA4);

        await tester.tap(find.text('استعادة الافتراضي'));
        await pumpQuietly(tester, 10);
        await Future<void>.delayed(const Duration(milliseconds: 250));

        final active = await repo.activeFor('sale');
        expect(active!.code, kPrintTemplateDefaultCode);
        expect(active.config.showDiscountColumn, isTrue,
            reason: 'بذر البسيط مستعاد');
        final classic = (await repo.allFor('sale'))
            .firstWhere((r) => r.code == kInvoiceTemplateClassicA4);
        expect(classic.config.showDiscountColumn, isTrue,
            reason: 'بذر الكلاسيكي مستعاد');
      });
    });
  });

  group('الراوتر — التوصيل الفعلي', () {
    testWidgets('/more/print-templates يفتح شاشة قوالب الطباعة', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2400));
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

        router.go('/more/print-templates');
        // التحميل الحقيقي (بلا seam) عبر FFI: جولتا مهلة-حقيقية +
        // مضخّات — الأولى تبني الشاشة وتبدأ الجولة، والثانية تلتقط
        // إعادة البناء بعد اكتمالها (نمط مؤكد بالتجربة).
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await pumpQuietly(tester, 6);
        }

        expect(router.routerDelegate.currentConfiguration.uri.path,
            '/more/print-templates');
        expect(find.byType(PrintTemplatesScreen), findsOneWidget);
        // الشاشة حمّلت القالبين من القاعدة الحقيقية (بلا seam —
        // عبر AppController.printTemplates).
        expect(find.text('حراري 80مم'), findsNothing);
        expect(find.text('كلاسيكي A4 أفقي'), findsOneWidget);

        router.dispose();
        controller.dispose();
      });
    });
  });
}
