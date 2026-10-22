/// اختبارات V10-B — نموذج الطرف (عميل/مورد) بهوية Simple Invoice
/// Manager: الترويسة الفرعية بعنوان النموذج الأولي «إضافة عميل / مورد
/// جديد» وزر رجوع بmaybePop (🔴-4 — يمر بنفس طريق الحارس)، شريط «حفظ
/// هذا» الأزرق الثابت أسفل الشاشة، اختلاف حقول العميل/المورد بمنطق
/// kind (واتساب/الحي/حد الائتمان للعملاء وحدهم)، حماية المغادرة
/// (P1-4 — حوار «مغادرة/بقاء») عند تعديل الاسم، الحفظ الناجح
/// (SnackBar + رجوع تلقائي مؤجل R17)، وبوابة validate-أولاً: الاسم
/// الفارغ يوقف الحفظ بخطأ الحقل، وخطأ المتحكم يظهر بلافتة التحقق.
///
/// الإعداد بنمط `dirty_form_guard_test` (تكامل ItemFormScreen الحقيقي):
/// قاعدة FFI حقيقية (ملف فريد + تأسيس جاهز) + Seam النموذج المحضون
/// (`CustomerFormScreen(viewModel: vm)` — يُحمَّل بعد بناء الشاشة كي
/// تلتقط لقطة الأساس بعد التحميل) + AppController + راوتر بمسارين
/// متداخلين، وكل التفاعل داخل `runAsync` (القاعدة حقيقية غير متزامنة).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/customer_repository.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';
import 'package:mobile_app/data/repositories/supplier_repository.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/core/widgets/sim_form_widgets.dart';
import 'package:mobile_app/ui/core/widgets/sim_list_widgets.dart';
import 'package:mobile_app/ui/features/parties/views/party_form_screen.dart';
import 'package:mobile_app/ui/features/parties/views/widgets/party_form_fields.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_form_view_model.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_kind.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_lookup.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

/// حزمة الاختبار — قاعدة حية + نموذج محضون + راوتر.
final class _Harness {
  _Harness(this.db, this.controller, this.vm, this.router);

  final AppDatabase db;
  final AppController controller;
  final PartyFormViewModel vm;
  final GoRouter router;
}

/// يفتح قاعدة مؤسّسة ويبني الشاشة فوق راوتر بمسارين متداخلين (الرجوع
/// متاح للنظام) — النموذج يُنشأ هنا ويُحقن عبر Seam الشاشة.
Future<_Harness> _bootForm(
  WidgetTester tester, {
  required PartyKind kind,
}) async {
  final seeded = await openSeededApp();
  addTearDown(seeded.$1.close);
  final controller = AppController(forTesting: seeded.$1);
  await controller.decidePhaseForTest();
  controller.unlockSession();
  addTearDown(controller.dispose);

  final vm = PartyFormViewModel(
    customerRepo: CustomerRepository(seeded.$1.db),
    supplierRepo: SupplierRepository(seeded.$1.db),
    companyRepo: seeded.$2,
    fxRepo: ExchangeRateRepository(seeded.$1.db),
    partyLookup: PartyLookup(seeded.$1.db),
    partyKind: kind,
    reference: DateTime(2026, 10, 6, 12),
  );
  addTearDown(vm.dispose);

  final screen = kind == PartyKind.customer
      ? CustomerFormScreen(viewModel: vm)
      : SupplierFormScreen(viewModel: vm);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('الرئيسية'))),
        routes: [
          GoRoute(path: 'form', builder: (_, _) => screen),
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
    if (find.byKey(const Key('party_form_name_field'))
        .evaluate()
        .isNotEmpty) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await pumpQuietly(tester, 2);
  }
  expect(
    find.byKey(const Key('party_form_name_field')),
    findsOneWidget,
    reason: 'النموذج لم يكتمل تحميله',
  );
}

/// مهلة حقيقية تُنجز استعلامات FFI المعلقة ثم إطارات لإعادة البناء.
Future<void> _settleDb(WidgetTester tester, {int frames = 6}) async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await pumpQuietly(tester, frames);
}

void main() {
  setUpAll(initFfiForTests);

  group('V10-B — نموذج الطرف بهوية SIM', () {
    testWidgets('١) الترويسة: «إضافة عميل / مورد جديد» وزر رجوع يعمل', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester, kind: PartyKind.customer);
        await _openForm(tester, h);

        // ترويسة SIM الفرعية — بلا AppBar القديم.
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(SimSubHeader), findsOneWidget);
        expect(find.byKey(const Key('party_form_sim_title')), findsOneWidget);
        expect(find.text('إضافة عميل / مورد جديد'), findsOneWidget);

        // زر الرجوع بmaybePop (🔴-4): نموذج نظيف يخرج مباشرة بلا حوار.
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

    testWidgets('٢) شريط «حفظ هذا» الأزرق الثابت ظاهر أسفل الشاشة', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester, kind: PartyKind.customer);
        await _openForm(tester, h);

        // شريط الحفظ الثابت (bottomNavigationBar) بمفتاح الزر القديم.
        expect(find.byType(SimFormSaveBar), findsOneWidget);
        expect(find.text('حفظ هذا'), findsOneWidget);
        expect(find.byKey(const Key('party_form_save_btn')), findsOneWidget);
        // زر الحفظ القديم داخل القائمة سقط (انتقل للشريط الثابت).
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byKey(const Key('party_form_save_btn')),
          ),
          findsNothing,
        );
        h.router.dispose();
      });
    });

    testWidgets('٣-أ) حقول العميل تشمل واتساب/الحي/حد الائتمان', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester, kind: PartyKind.customer);
        await _openForm(tester, h);
        expect(
          find.byKey(const Key('party_form_whatsapp_field')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('party_form_area_field')), findsOneWidget);
        expect(
          find.byKey(const Key('party_form_credit_field')),
          findsOneWidget,
        );
        h.router.dispose();
      });
    });

    testWidgets('٣-ب) حقول المورد لا تشملها (منطق kind)', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        // المورد: نفس العنوان الموحد بلا الحقول الثلاثة.
        final h = await _bootForm(tester, kind: PartyKind.supplier);
        await _openForm(tester, h);
        expect(find.text('إضافة عميل / مورد جديد'), findsOneWidget);
        expect(
          find.byKey(const Key('party_form_whatsapp_field')),
          findsNothing,
        );
        expect(find.byKey(const Key('party_form_area_field')), findsNothing);
        expect(find.byKey(const Key('party_form_credit_field')), findsNothing);
        // المشتركة باقية.
        expect(find.byKey(const Key('party_form_phone_field')), findsOneWidget);
        expect(
          find.byKey(const Key('party_form_address_field')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('party_form_notes_field')), findsOneWidget);
        h.router.dispose();
      });
    });

    testWidgets('٤) حارس المغادرة: تعديل الاسم يعرض الحوار و«بقاء» يُبقي', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester, kind: PartyKind.customer);
        await _openForm(tester, h);

        // تعديل الاسم → وسخ (P1-4: مقارنة لقطة ما بعد التحميل).
        await tester.enterText(
          find.byKey(const Key('party_form_name_field')),
          'عميل اختبار الحماية',
        );
        await pumpQuietly(tester, 4);

        // الرجوع النظامي عبر maybePop — يُحرس بالحوار.
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        await navigator.maybePop();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('تغييرات غير محفوظة'), findsOneWidget);
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/form');

        // «بقاء»: الحوار يُغلق والنموذج يبقى ببياناته.
        await tester.tap(find.text('بقاء'));
        await tester.pumpAndSettle();
        expect(find.text('تغييرات غير محفوظة'), findsNothing);
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/form');
        expect(find.text('عميل اختبار الحماية'), findsOneWidget);
        h.router.dispose();
      });
    });

    testWidgets('٥) حفظ ناجح: SnackBar + رجوع تلقائي مؤجل (R17)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester, kind: PartyKind.customer);
        await _openForm(tester, h);

        await tester.enterText(
          find.byKey(const Key('party_form_name_field')),
          'عميل حفظ ناجح',
        );
        await pumpQuietly(tester, 4);

        // «حفظ هذا» → validate أولاً ثم المستودع.
        await tester.tap(find.byKey(const Key('party_form_save_btn')));
        await _settleDb(tester, frames: 8);

        // رسالة النجاح القائمة (بلا حوار مغادرة — الرجوع المؤجل R17
        // يمر بعد التزام canPop الجديدة).
        expect(find.text('حُفظت بيانات العميل'), findsOneWidget);
        expect(find.text('تغييرات غير محفوظة'), findsNothing);
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/');
        expect(find.text('الرئيسية'), findsOneWidget);

        // العميل خُلق فعلياً في القاعدة.
        final rows = await h.db.db.query(
          'customer',
          where: 'name = ?',
          whereArgs: ['عميل حفظ ناجح'],
        );
        expect(rows, hasLength(1));
        h.router.dispose();
      });
    });

    testWidgets('٦) اسم فارغ: بوابة validate-أولاً توقف الحفظ بخطأ الحقل', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester, kind: PartyKind.customer);
        await _openForm(tester, h);

        // الاسم فارغ — لا كتابة في الحقل إطلاقاً.
        await tester.tap(find.byKey(const Key('party_form_save_btn')));
        await _settleDb(tester);

        // خطأ الحقل يظهر تحت الاسم (بوابة النموذج قبل المتحكم) والشاشة
        // باقية بلا SnackBar ولا لافتة (المتحكم لم يُستدعَ).
        expect(
          find.text('الاسم مطلوب — أدخل الاسم ثم احفظ.'),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(PartyFormValidationErrorBanner), findsNothing);
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/form');
        h.router.dispose();
      });
    });

    testWidgets('٧) لافتة خطأ التحقق: افتتاحي بعملة بلا سعر يُرفض (FR-08-09)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final h = await _bootForm(tester, kind: PartyKind.customer);
        await _openForm(tester, h);

        await tester.enterText(
          find.byKey(const Key('party_form_name_field')),
          'عميل افتتاحي دولار',
        );
        await pumpQuietly(tester, 2);
        await tester.enterText(
          find.byKey(const Key('party_form_opening_field')),
          '250',
        );
        await pumpQuietly(tester, 2);

        // العملة: اختر الدولار (بلا سعر مسجّل في القاعدة المؤسّسة).
        final currencyKey = Key(
          'party_form_opening_currency_${h.vm.state.openingCurrencyId}',
        );
        await tester.tap(find.byKey(currencyKey));
        await pumpQuietly(tester, 3);
        await tester.tap(find.textContaining('(USD)').last);
        await pumpQuietly(tester, 3);
        expect(
          h.vm.state.openingCurrencyId,
          isNotNull,
          reason: 'اختيار الدولار لم يثبت',
        );

        // الحفظ يمر بوابة النموذج ثم يرفضه المتحكم باللافتة (noRate).
        await tester.tap(find.byKey(const Key('party_form_save_btn')));
        await _settleDb(tester, frames: 8);
        expect(find.byType(PartyFormValidationErrorBanner), findsOneWidget);
        expect(
          find.text(
            'لا يوجد سعر صرف مسجّل لهذه العملة — سجّل سعر اليوم من شاشة '
            '«أسعار الصرف» أولاً.',
          ),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/form');
        h.router.dispose();
      });
    });
  });
}
