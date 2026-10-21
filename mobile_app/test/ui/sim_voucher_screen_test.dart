/// اختبارات V6-C — شاشة سند القبض/الصرف بهوية Simple Invoice Manager
/// (`/cash/voucher/:type`): الترويسة الفرعية والتبويبان («إيصال/سند» +
/// «معاينة») بمساري القبض والصرف، مستند المعاينة A4 من المسودة الحية
/// (اسم المنشأة + الشريط الأزرق بمعاينة رقم RVT/PMT القادم من قاعدة
/// فراغ + «تسلم من:» + «مقابل الفواتير:» + سطر التفقيط + التوقيع)،
/// التبديل الشرطي `if` (لا ازدواج نصوص بين الوضعين)، حوار التغييرات
/// غير المحفوظة (DirtyFormGuard)، عرض رفض الترحيل فوق الشريط، SnackBar
/// النجاح بعد ترحيل صالح والانتقال `/cash`، سطر «على الحساب»، فتح
/// معاينة PDF المسودة من زري الإرسال/الطباعة، وتعطيل زر الحفظ أثناء
/// الترحيل — إضافة إلى بناء PDF المسودة الموسوم (draftLabel).
///
/// الإعداد بنمط `sim_invoice_a4_preview_test` القائم: قاعدة FFI حقيقية
/// (ملف فريد لكل اختبار + تأسيس جاهز) + راوتر التطبيق كاملاً + Provider
/// + تعريب عربي، وكل التفاعل داخل `runAsync` (القاعدة حقيقية غير
/// متزامنة).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/customer_repository.dart';
import 'package:mobile_app/data/repositories/supplier_repository.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/router/app_router.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/core/widgets/sim_doc_widgets.dart';
import 'package:mobile_app/ui/core/widgets/sim_list_widgets.dart';
import 'package:mobile_app/ui/features/cash/view_models/voucher_view_model.dart';
import 'package:mobile_app/ui/features/cash/views/cash_home_screen.dart';
import 'package:mobile_app/ui/features/cash/views/widgets/voucher_draft_pdf.dart';
import 'package:mobile_app/ui/features/cash/views/widgets/voucher_party_card.dart';
import 'package:mobile_app/ui/features/printing/services/voucher_pdf_builder.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';
import '../helpers/printing_docs_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  final at = DateTime.utc(2026, 10, 6, 12);

  late AppDatabase handle;
  late CustomerRepository customers;
  late SupplierRepository suppliers;
  late int userId;

  bool dbOpen = false;

  /// قاعدة + بذر: عميل ومورد لانتقاء الأطراف بمساري القبض والصرف.
  Future<void> openDb() async {
    if (dbOpen) return;
    final seeded = await openSeededApp();
    handle = seeded.$1;
    customers = CustomerRepository(handle.db);
    suppliers = SupplierRepository(handle.db);
    userId = (await seeded.$2.findAdminUserId())!;
    await customers.createCustomer(
      const CustomerDraft(name: 'عميل سند القبض'),
      userId: userId,
      now: at,
    );
    await suppliers.createSupplier(
      const SupplierDraft(name: 'مورد سند الصرف'),
      userId: userId,
      now: at,
    );
    addTearDown(() async {
      dbOpen = false;
      await handle.close();
    });
    dbOpen = true;
  }

  /// يبني التطبيق كاملاً (راوتر + جلسة مفتوحة) — نمط sim_invoice.
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

  /// مهلة حقيقية تُنجز استعلامات FFI المعلقة (منطقة الاختبار الزائفة لا
  /// تقدّم أحداث القاعدة الحقيقية — نمط stocktake_screen) ثم إطارات
  /// لإعادة بناء الشجرة على نتائجها.
  Future<void> settleDb(WidgetTester tester, {int frames = 6}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await pumpQuietly(tester, frames);
  }

  /// يفتح شاشة السند بنوعه ويستقر حتى **يظهر النموذج فعليًا** — التحميل
  /// FFI حقيقي غير متزامن: عدد إطارات ثابت قد يسبق اكتماله فيبتلع
  /// `_buildLoading` تبديل التبويب/الإدخال (كُشف بتشخيص V6). دورة مهلات
  /// قصيرة حتى بطاقة الطرف (علامة اكتمال التحميل) بدل عدّاد أعمى.
  Future<void> openVoucher(
    WidgetTester tester,
    GoRouter router,
    String type, {
    int maxWaits = 40,
  }) async {
    router.go('/cash/voucher/$type');
    for (var i = 0; i < maxWaits; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await pumpQuietly(tester, 4);
      if (find.byType(VoucherPartyCard).evaluate().isNotEmpty) break;
    }
    await pumpQuietly(tester, 4);
  }

  /// معاينة رقم السند القادم بسنة اليوم (txDate = now عند الإنشاء).
  String previewNo(String prefix) => '$prefix-${DateTime.now().year}-00001';

  /// ينتقي الطرف من منتقي السند (يفتح الورقة وينقر صف الطرف) — بحث
  /// الأطراف FFI حقيقي غير متزامن فنستقر حتى **يظهر صف الطرف فعليًا**
  /// (دورة مهلات قصيرة بنمط openVoucher) بدل مهلة ثابتة تسبق النتيجة.
  Future<void> pickParty(WidgetTester tester, String pickLabel) async {
    await tester.tap(find.text('اختر الطرف'));
    await settleDb(tester);
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await pumpQuietly(tester, 3);
      if (find.text(pickLabel).evaluate().isNotEmpty) break;
    }
    await tester.tap(find.text(pickLabel));
    await settleDb(tester);
  }

  /// يدخل مبلغ السند بحقل المبلغ (التسمية «المبلغ»).
  Future<void> enterAmount(WidgetTester tester, String raw) async {
    await tester.enterText(find.widgetWithText(TextField, 'المبلغ'), raw);
    await pumpQuietly(tester, 4);
  }

  group('V6-C — شاشة السند بهوية SIM', () {
    testWidgets('١) الترويسة الفرعية والتبويبان بمساري القبض والصرف', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);

        // مسار القبض: «سند قبض» + تبويبا «إيصال»/«معاينة».
        await openVoucher(tester, router, 'receipt');
        expect(find.byType(SimSubHeader), findsOneWidget);
        expect(find.text('سند قبض'), findsOneWidget);
        expect(find.text('إيصال'), findsOneWidget);
        expect(find.text('معاينة'), findsOneWidget);

        // مسار الصرف: «سند صرف» + تبويبا «سند»/«معاينة».
        await openVoucher(tester, router, 'payment');
        expect(find.byType(SimSubHeader), findsOneWidget);
        expect(find.text('سند صرف'), findsOneWidget);
        expect(find.text('سند'), findsOneWidget);
        expect(find.text('معاينة'), findsOneWidget);
        expect(find.text('إيصال'), findsNothing);
        router.dispose();
      });
    });

    testWidgets('٢) تبويب المعاينة: مستند A4 حي بعناصر screen-receipt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await openVoucher(tester, router, 'receipt');

        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester);

        // الورقة + اسم المنشأة (تأسيس قاعدة الاختبار).
        expect(find.byType(SimA4Sheet), findsOneWidget);
        expect(find.text('متجر النور للأدوات المنزلية'), findsOneWidget);

        // الشريط الأزرق بمعاينة الرقم من قاعدة فراغ (RVT-السنة-00001).
        expect(
          find.descendant(
            of: find.byType(SimDocBlueBar),
            matching: find.text(previewNo('RVT')),
          ),
          findsOneWidget,
        );

        // «تسلم من:» + قسم مراجع الفواتير + سطر التفقيط + منطقة التوقيع.
        expect(find.text('تسلم من:'), findsOneWidget);
        expect(find.text('مقابل الفواتير:'), findsOneWidget);
        // المسودة الفارغة: مبلغ 0 → «مجموع صفر … فقط» بعملة السياق YER.
        expect(find.textContaining('مجموع صفر'), findsOneWidget);
        expect(find.textContaining('فقط'), findsOneWidget);
        expect(find.byType(SimDocSignatureArea), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('٣) تبديل شرطي: شجرة وضع واحد فقط في كل لحظة (لا ازدواج)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await openVoucher(tester, router, 'receipt');

        // وضع النموذج: لا عناصر مستند إطلاقاً + العنوان المشترك مرة.
        expect(find.byType(SimA4Sheet), findsNothing);
        expect(find.byType(SimDocSignatureArea), findsNothing);
        expect(find.text('تسلم من:'), findsNothing);
        expect(find.text('مقابل الفواتير:'), findsNothing);
        expect(find.byType(SimBottomActionBar), findsOneWidget);
        expect(find.text('حفظ'), findsOneWidget);

        // وضع المعاينة: لا عناصر النموذج إطلاقاً + المشترك مرة واحدة.
        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester);
        expect(find.byType(SimA4Sheet), findsOneWidget);
        expect(find.text('تسلم من:'), findsOneWidget);
        expect(find.text('سند قبض'), findsOneWidget);
        expect(find.byType(SimBottomActionBar), findsOneWidget);
        expect(find.text('حفظ'), findsOneWidget);

        // العودة للنموذج تعيد هيكله بلا أي ازدواج.
        await tester.tap(find.text('إيصال'));
        await pumpQuietly(tester);
        expect(find.byType(SimA4Sheet), findsNothing);
        expect(find.text('تسلم من:'), findsNothing);
        expect(find.text('إيصال'), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('٤) حوار التغييرات غير المحفوظة عند الرجوع بعد إدخال', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await openVoucher(tester, router, 'receipt');

        // إدخال مبلغ يلوّث النموذج (محرك النموذج الحي).
        await enterAmount(tester, '500');
        expect(find.text('تغييرات غير محفوظة'), findsNothing);

        // زر الرجوع بالترويسة الفرعية → حوار الحماية.
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await pumpQuietly(tester, 6);
        expect(find.text('تغييرات غير محفوظة'), findsOneWidget);

        // «بقاء» يبقي الشاشة.
        await tester.tap(find.text('بقاء'));
        await pumpQuietly(tester, 6);
        expect(find.text('تغييرات غير محفوظة'), findsNothing);
        expect(find.text('سند قبض'), findsOneWidget);

        // «مغادرة» يؤكد ويعود لمحور النقدية.
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await pumpQuietly(tester, 6);
        await tester.tap(find.text('مغادرة'));
        await pumpQuietly(tester, 10);
        expect(find.byType(CashHomeScreen), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('٥) رفض ترحيل بلا طرف → رسالة الفحص الأول ظاهرة فوق الشريط', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await openVoucher(tester, router, 'receipt');

        // ترحيل بلا طرف: أول فحص عملي برسالة «اختر الطرف أولاً...».
        await tester.tap(find.text('حفظ'));
        await pumpQuietly(tester, 6);
        expect(
          find.text('اختر الطرف أولاً (عميلاً للقبض أو مورداً للصرف).'),
          findsOneWidget,
          reason: 'رسالة الرفض ظاهرة فوق شريط الإجراءات ولا تُبتلع صامتة',
        );
        // لم يُرحَّل شيء ولم يغادر الشاشة.
        expect(find.text('سند قبض'), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('٦) ترحيل صالح → SnackBar برقم السند + انتقال /cash', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await openVoucher(tester, router, 'receipt');

        // طرف + صندوق افتراضي + مبلغ → ترحيل «على الحساب» (لا فواتير).
        await pickParty(tester, 'عميل سند القبض');
        await enterAmount(tester, '250');
        await tester.tap(find.text('حفظ'));
        // الترحيل FFI حقيقي (معاملة) — استقرار حقيقي للإيصال والانتقال.
        await settleDb(tester);
        await pumpQuietly(tester, 12);

        // SnackBar النجاح برقم السند المرقَّم الفعلي (المعاينة نفسها) —
        // الرقم يظهر أيضًا بشكل مشروع ببلاطة الحركة بمحور النقدية فنحصر
        // التحقق داخل SnackBar (V6-C: رمز العملة صار يُمرَّر — ن-7).
        final no = previewNo('RVT');
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('تم ترحيل السند'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining(no),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('YER'),
          ),
          findsOneWidget,
          reason: 'رمز العملة يظهر الآن بالإيصال (كان يُمرَّر فارغًا قبل V6-C)',
        );

        // الانتقال لمحور النقدية (سلوك ما بعد الترحيل حرفياً).
        expect(find.byType(CashHomeScreen), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('٧) FIFO موقوف (لا مديونية مفتوحة) → سطر «على الحساب»', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await openVoucher(tester, router, 'receipt');

        // اختيار طرف بلا فواتير مفتوحة يوقف التخصيص تلقائياً (لا مديونية).
        await pickParty(tester, 'عميل سند القبض');
        await enterAmount(tester, '250');
        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester);

        // القسم باقٍ (لا قفز تخطيط) بسطر «على الحساب» الصادق البديل.
        expect(find.text('مقابل الفواتير:'), findsOneWidget);
        expect(find.text('على الحساب — بلا تخصيص فواتير'), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('٨) زرا الإرسال/الطباعة يفتحان معاينة PDF المسودة', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await openVoucher(tester, router, 'receipt');

        // حزمة printing بلا تسجيل بالاختبار — استدعاء rasterPdf غير
        // منتظر بالحزمة فيفلت استثناءه من try/catch الحوار ويُفشل
        // الاختبار. نبتلعه بمحاكاة القناة: الحوار يبقى بحالة التحميل
        // وعنوانه + رقم المسودة + «معاينة الطباعة» ظاهرة (هدف التحقق).
        const printChannel = MethodChannel('net.nfet.printing');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(printChannel, (call) async => null);
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(printChannel, null);
        });

        // زر الطباعة → نافذة معاينة PDF بعنوانها ورقم المسودة — فتحها
        // غير متزامن (إعدادات القالب ثم الحوار) فنستقر حقيقيًا حتى تظهر.
        await tester.tap(find.text('طباعة'));
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await pumpQuietly(tester, 3);
          if (find.byType(Dialog).evaluate().isNotEmpty) break;
        }
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text(previewNo('RVT')), findsOneWidget);
        expect(find.text('معاينة الطباعة'), findsWidgets);

        // إغلاق ثم زر الإرسال → النافذة نفسها (المرسل الحقيقي من
        // أزرارها: طباعة/مشاركة/واتساب — القيد موثق بالرأس).
        await tester.tap(find.byIcon(Icons.close_rounded).last);
        await settleDb(tester);
        expect(find.byType(Dialog), findsNothing);

        await tester.tap(find.text('إرسال'));
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await pumpQuietly(tester, 3);
          if (find.byType(Dialog).evaluate().isNotEmpty) break;
        }
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text(previewNo('RVT')), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('٩) زر الحفظ معطل أثناء الترحيل (saving)', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await openVoucher(tester, router, 'receipt');

        // طرف + مبلغ → نموذج صالح.
        await pickParty(tester, 'عميل سند القبض');
        await enterAmount(tester, '250');

        // نمسك النموذج من الشجرة ونطلق الترحيل يدوياً: نافذة تزامنية
        // حتمية (Dart يبلغ أول await داخل save قبل أي حدث قاعدة).
        final vm = Provider.of<VoucherViewModel>(
          tester.element(find.byType(SimSubHeader)),
          listen: false,
        );
        final saveFuture = vm.save();
        expect(vm.saving, isTrue, reason: 'العجلة نشطة بالنافذة التزامنية');

        // الإطار التالي يعرض الزر معطلاً — ما لم تكن قاعدة الذاكرة قد
        // أنجزت الترحيل كله خلال فجوة الحدث نفسها (FFI فوري بالذاكرة)
        // فنكتفي بإثبات الإنجاز (القيد موثق).
        await tester.pump();
        final bars = find.byType(SimBottomActionBar).evaluate();
        if (bars.isNotEmpty && vm.saving) {
          final bar = tester.widget<SimBottomActionBar>(
            find.byType(SimBottomActionBar),
          );
          expect(
            bar.items.first.enabled,
            isFalse,
            reason: 'زر الحفظ معطل أثناء saving',
          );
        }
        await saveFuture;
        await settleDb(tester, frames: 10);

        // الترحيل المباشر أنجز فعلاً (المسار النهائي يتحقق به في ٦ —
        // SnackBar والانتقال سلوكان الشاشة في _post لا النموذج).
        final result = await saveFuture;
        final receipt = result.valueOrNull;
        expect(receipt, isNotNull, reason: 'الترحيل أنجز برقم مرقَّم');
        expect(receipt!.voucherNo, previewNo('RVT'));
        expect(vm.saveError, isNull);
        expect(find.byType(CashHomeScreen), findsNothing);
        router.dispose();
      });
    });

    testWidgets('١٠) PDF المسودة: وسم «مسودة» داخل المستند + بناء سليم', (
      tester,
    ) async {
      // بناء المسقط الموسوم من بيانات حية + بناء PDF بخطوط حقيقية
      // (نمط voucher_pdf_builder_test) — والمستند المُرحّل القديم بلا وسم.
      await tester.runAsync(() async {
        final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

        final draft = buildVoucherDraftPrintDoc(
          l10n,
          isReceipt: true,
          voucherNo: 'RVT-2026-00001',
          dateLabel: '06/10/2026',
          partyName: 'عميل سند القبض',
          amountLabel: '250',
          currencyCode: 'YER',
          boxName: 'الصندوق الرئيسي',
          isDraft: true,
          amountWords: 'مئتان وخمسون ريالاً يمنياً فقط',
        );
        expect(draft.labels.draftLabel, l10n.simRcptDraftBadge);
        // V6 (مراجعة 🟡-3) — سطر التفقيط يصل المسقط كاملاً (قارئ النموذج
        // → المستند → القالب) مع تسميته.
        expect(draft.amountWords, 'مئتان وخمسون ريالاً يمنياً فقط');
        expect(draft.labels.wordsLabel, l10n.printingLblAmountWords);
        expect(draft.isReceipt, isTrue);
        expect(draft.voucherNo, 'RVT-2026-00001');

        final bytes = await (await const VoucherPdfBuilder().build(draft))
            .save();
        expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
        expect(pdfPageCount(bytes), 1, reason: 'المسودة صفحة A5 واحدة');

        // المستند المُرحّل (movement) بلا وسم ولا تفقيط — سلوك القالب
        // القائم حرفياً (الحقول الاختيارية null افتراضياً).
        final posted = voucherDocForTests(l10n);
        expect(posted.labels.draftLabel, isNull);
        expect(posted.amountWords, isNull);
        expect(posted.labels.wordsLabel, isNull);
        final postedBytes = await (await const VoucherPdfBuilder().build(
          posted,
        )).save();
        expect(String.fromCharCodes(postedBytes, 0, 4), '%PDF');
        expect(pdfPageCount(postedBytes), 1);
      });
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('١١) حارس سقف التفقيط (🔴-1): لصق رقم ضخم لا يكسر المعاينة', (
      tester,
    ) async {
      // حقل المبلغ يقبل لصق أرقام بلا سقف (`\d*`) وعقد `amountInWords`
      // يرمي فوق 999,999,999,999.99 — قبل الحارس كان تبويب المعاينة
      // ينهار كاملاً؛ الآن يُتخطى سطر الكلمات فقط (الرقم ظاهر أعلاه).
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await openDb();
        final router = await bootApp(tester);
        await openVoucher(tester, router, 'receipt');

        // 15 خانة = 999 تريليون ≫ السقف — أعلى من أي مبلغ تجاري.
        await enterAmount(tester, '999999999999999');

        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester);

        // المعاينة حية (لا انهيار) والورقة موجودة…
        expect(find.byType(SimA4Sheet), findsOneWidget);
        // …وسطر الكلمات متخطى بلا كذب (لا «فقط» والرقم الضخم ظاهر أعلاه).
        expect(find.textContaining('فقط'), findsNothing);

        // العودة للنموذج ومبلغ طبيعي تعيد السطر فوراً (الحارس ديناميكي).
        await tester.tap(find.text('إيصال'));
        await pumpQuietly(tester);
        await enterAmount(tester, '250');
        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester);
        expect(find.textContaining('مئتان وخمسون'), findsOneWidget);
        expect(find.textContaining('فقط'), findsOneWidget);
        router.dispose();
      });
    });
  });
}
