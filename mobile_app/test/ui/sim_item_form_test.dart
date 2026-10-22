/// اختبارات V10-A — نموذج إدخال المنتج (الصنف) بهوية Simple Invoice
/// Manager: الترويسة الفرعية بعنوان النموذج الأولي «نموذج إدخال المنتج»
/// وزر رجوع بmaybePop (يمر بنفس طريق إيماءة النظام الذي يحرسه
/// DirtyFormGuard)، شريط «حفظ المنتج» الأزرق الثابت أسفل الشاشة (خارج
/// التمرير)، بطاقات SimFormCard الثلاث وحقل الاسم بنجمة الإلزام،
/// التبديل الخدمي يخفي حقول المخزون كاملة (FR-01-16)، حماية المغادرة
/// (P1-4 — حوار «مغادرة/بقاء») عند تعديل الاسم، والحفظ الناجح: SnackBar
/// + رجوع تلقائي مؤجل بإطار لاحق (R17) مع خلق الصنف فعلياً في القاعدة.
///
/// الإعداد بنمط `sim_party_form_test` (توأم الجولة): قاعدة FFI حقيقية
/// (ملف فريد + تأسيس جاهز) + Seam النموذج المحضون (`ItemFormScreen
/// (viewModel: vm)` — يُحمَّل بعد بناء الشاشة كي تُلتقط لقطة الأساس
/// بعد التحميل) + AppController + راوتر بمسارين متداخلين، وكل التفاعل
/// داخل `runAsync` (القاعدة حقيقية غير متزامنة).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/core/widgets/sim_form_widgets.dart';
import 'package:mobile_app/ui/core/widgets/sim_list_widgets.dart';
import 'package:mobile_app/ui/features/inventory/view_models/item_form_view_model.dart';
import 'package:mobile_app/ui/features/inventory/views/item_form_screen.dart';
import 'package:mobile_app/ui/features/inventory/views/widgets/item_form_fields.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

/// حزمة الاختبار — قاعدة حية + نموذج محضون + راوتر.
final class _Harness {
  _Harness(this.db, this.controller, this.vm, this.router);

  final AppDatabase db;
  final AppController controller;
  final ItemFormViewModel vm;
  final GoRouter router;
}

/// يفتح قاعدة مؤسّسة ويبني الشاشة فوق راوتر بمسارين متداخلين (الرجوع
/// متاح للنظام) — النموذج يُنشأ هنا ويُحقن عبر Seam الشاشة.
Future<_Harness> _bootForm(WidgetTester tester) async {
  final seeded = await openSeededApp();
  addTearDown(seeded.$1.close);
  final controller = AppController(forTesting: seeded.$1);
  await controller.decidePhaseForTest();
  controller.unlockSession();
  addTearDown(controller.dispose);

  final vm = ItemFormViewModel(
    itemRepo: ItemRepository(seeded.$1.db),
    companyRepo: seeded.$2,
  );
  addTearDown(vm.dispose);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('الرئيسية'))),
        routes: [
          GoRoute(
            path: 'form',
            builder: (_, _) => ItemFormScreen(viewModel: vm),
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
  return _Harness(seeded.$1, controller, vm, router);
}

/// يدخل مسار النموذج ويحمّل النموذج بعد بناء الشاشة (كما يفعل الإنتاج)
/// — التحميل يوقظ المستمع فتُعبَّأ المتحكمات وتُلتقط لقطة الأساس (P1-4)
/// ثم يُنتظر ظهور الحقول فعلياً.
Future<void> _openForm(WidgetTester tester, _Harness h) async {
  h.router.go('/form');
  await pumpQuietly(tester, 2);
  await h.vm.load();
  await Future<void>.delayed(const Duration(milliseconds: 200));
  await pumpQuietly(tester, 4);
  for (var i = 0; i < 20; i++) {
    if (find.byKey(const Key('item_form_name_field'))
        .evaluate()
        .isNotEmpty) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await pumpQuietly(tester, 2);
  }
  expect(
    find.byKey(const Key('item_form_name_field')),
    findsOneWidget,
    reason: 'النموذج لم يكتمل تحميله',
  );
}

/// مهلة حقيقية تُنجز عمليات FFI المعلقة ثم إطارات لإعادة البناء.
Future<void> _settleDb(WidgetTester tester, {int frames = 6}) async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await pumpQuietly(tester, frames);
}

void main() {
  setUpAll(initFfiForTests);

  group('V10-A — نموذج إدخال المنتج بهوية SIM', () {
    testWidgets('١) الترويسة: «نموذج إدخال المنتج» وزر رجوع يعمل', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester);
        await _openForm(tester, h);

        // ترويسة SIM الفرعية — بلا AppBar القديم.
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(SimSubHeader), findsOneWidget);
        expect(find.byKey(const Key('item_form_sim_title')), findsOneWidget);
        expect(find.text('نموذج إدخال المنتج'), findsOneWidget);

        // زر الرجوع بmaybePop: نموذج نظيف يخرج مباشرة بلا حوار.
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await pumpQuietly(tester, 4);
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/');
        expect(find.text('الرئيسية'), findsOneWidget);
        expect(find.text('تغييرات غير محفوظة'), findsNothing);
        h.router.dispose();
      });
    });

    testWidgets('٢) شريط «حفظ المنتج» الأزرق الثابت + بوابة validate-أولاً', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester);
        await _openForm(tester, h);

        // شريط الحفظ الثابت (bottomNavigationBar) بمفتاح الزر القديم —
        // خارج قائمة التمرير فلا يختفي بالتمرير.
        expect(find.byType(SimFormSaveBar), findsOneWidget);
        expect(find.text('حفظ المنتج'), findsOneWidget);
        expect(find.byKey(const Key('item_form_save_btn')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byKey(const Key('item_form_save_btn')),
          ),
          findsNothing,
          reason: 'زر الحفظ ثابت خارج التمرير',
        );

        // نقره بلا اسم: بوابة validate-أولاً توقف الحفظ بخطأ الحقل
        // (المتحكم لم يُستدعَ — لا لافتة ولا SnackBar ولا رجوع).
        await tester.tap(find.byKey(const Key('item_form_save_btn')));
        await _settleDb(tester);
        expect(find.text('اسم الصنف مطلوب'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(
          find.byType(ItemFormValidationErrorBanner),
          findsNothing,
          reason: 'بوابة validate-أولاً: المتحكم لم يُستدعَ بعد',
        );
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/form');
        h.router.dispose();
      });
    });

    testWidgets('٣) تحويل بصري سليم: بطاقات SIM وحقل الاسم بنجمة', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester);
        await _openForm(tester, h);

        // ثلاث بطاقات: البيانات (اسم/باركود/فئة/وحدة/تكلفة/مفاتيح) +
        // الأسعار + الملاحظات.
        expect(find.byType(SimFormCard), findsNWidgets(3));
        // حقل الاسم سطري بنجمة الإلزام (نمط «اسم المنتج *» — التلميح
        // المعروض يحمل النجمة).
        final nameTextField = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('item_form_name_field')),
            matching: find.byType(TextField),
          ),
        );
        expect(nameTextField.decoration?.hintText, 'اسم الصنف *');
        // قسم الباركود القائم معاد الاستخدام داخل البطاقة (توليد EAN-13
        // بالإنشاء + قائمتا الفئة/الوحدة بأزرار الإضافة الفورية).
        expect(
          find.byKey(const Key('item_form_barcode_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('item_form_generate_btn')),
          findsOneWidget,
        );
        expect(find.byType(DropdownButtonFormField<int?>), findsNWidgets(2));
        // حقل سعر العملة الأساسية (ريال يمني — YER) داخل بطاقة الأسعار.
        expect(
          find.byKey(const Key('item_form_price_field_YER')),
          findsOneWidget,
        );

        // 🟡-12 — الحقول الرقمية تصفّف الأرقام: الحروف تُرشَّح فلا تصل
        // للمتحكم (كتابة «x1500y» ← نص التكلفة «1500» فقط).
        await tester.enterText(
          find.byKey(const Key('item_form_cost_field')),
          'x1500y',
        );
        await pumpQuietly(tester, 2);
        expect(h.vm.state.costText, '1500');
        h.router.dispose();
      });
    });

    testWidgets('٤) التبديل الخدمي يخفي حقول المخزون (FR-01-16)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester);
        await _openForm(tester, h);

        // قبل التبديل: الحد الأدنى والافتتاحية ومفتاح الدفعات ظاهرة.
        expect(
          find.byKey(const Key('item_form_min_stock_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('item_form_opening_qty_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('item_form_batches_switch')),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const Key('item_form_service_switch')),
        );
        await tester.tap(find.byKey(const Key('item_form_service_switch')));
        await pumpQuietly(tester, 4);

        // بعد التبديل: كل حقول المخزون اختفت — والأسعار باقية.
        expect(h.vm.state.isService, isTrue);
        expect(
          find.byKey(const Key('item_form_min_stock_field')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('item_form_opening_qty_field')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('item_form_batches_switch')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('item_form_price_field_YER')),
          findsOneWidget,
        );
        h.router.dispose();
      });
    });

    testWidgets('٥) حارس المغادرة: تعديل الاسم ← حوار «مغادرة/بقاء»', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester);
        await _openForm(tester, h);

        // تعديل الاسم → وسخ (P1-4: مقارنة لقطة ما بعد التحميل).
        await tester.enterText(
          find.byKey(const Key('item_form_name_field')),
          'صنف اختبار الحماية',
        );
        await pumpQuietly(tester, 4);

        // زر رجوع الترويسة (maybePop) — يُحرس بالحوار.
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('تغييرات غير محفوظة'), findsOneWidget);
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/form');

        // «بقاء»: الحوار يُغلق والنموذج يبقى ببياناته.
        await tester.tap(find.text('بقاء'));
        await tester.pumpAndSettle();
        expect(find.text('تغييرات غير محفوظة'), findsNothing);
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/form');
        expect(find.text('صنف اختبار الحماية'), findsOneWidget);

        // إفراغ التعديل → نظيف من جديد → رجوع مباشر بلا حوار.
        await tester.enterText(
          find.byKey(const Key('item_form_name_field')),
          '',
        );
        await pumpQuietly(tester, 4);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await pumpQuietly(tester, 4);
        expect(find.text('تغييرات غير محفوظة'), findsNothing);
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/');
        h.router.dispose();
      });
    });

    testWidgets('٦) حفظ ناجح: SnackBar + رجوع تلقائي مؤجل (R17)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester);
        await _openForm(tester, h);

        await tester.enterText(
          find.byKey(const Key('item_form_name_field')),
          'صنف حفظ ناجح',
        );
        await pumpQuietly(tester, 2);
        await tester.enterText(
          find.byKey(const Key('item_form_cost_field')),
          '1500',
        );
        await pumpQuietly(tester, 2);

        // «حفظ المنتج» → validate أولاً ثم المستودع.
        await tester.tap(find.byKey(const Key('item_form_save_btn')));
        await _settleDb(tester, frames: 8);

        // رسالة النجاح القائمة + الرجوع المؤجل R17 يمر بعد التزام canPop
        // الجديدة (isDirty=false بعد الحفظ) بلا حوار مغادرة.
        expect(find.text('تم حفظ الصنف بنجاح'), findsOneWidget);
        expect(find.text('تغييرات غير محفوظة'), findsNothing);
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/');
        expect(find.text('الرئيسية'), findsOneWidget);

        // الصنف خُلق فعلياً في القاعدة.
        final rows = await h.db.db.query(
          'product',
          where: 'name = ?',
          whereArgs: ['صنف حفظ ناجح'],
        );
        expect(rows, hasLength(1));
        h.router.dispose();
      });
    });
  });
}
