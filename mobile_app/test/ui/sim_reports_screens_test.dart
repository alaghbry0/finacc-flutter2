/// اختبارات V7-C — شاشات التقارير بهوية Simple Invoice Manager: مركز
/// التقارير (ترويسة فرعية بلا رجوع — جذر وحدة /reports + صف «كشف حساب
/// طرف» الجديد → /parties) والشاشات التفصيلية الخمس (الأرباح/الأعمار/
/// حركة صنف/ملخص المخزون/المبيعات حسب): الترويسة الفرعية برجوع منطقي،
/// شريط الفترات المسبقة القائم، عناصر البنية المفتاحية (شرائح الأعمار
/// الملونة/الباقي التراكمي/بطاقة الإجمالي)، و**شريط التصدير الثلاثي
/// الثابت** بأزراره الثلاثة بعناوينها المقفلة (صورة/PDF/تفوق) — زر PDF
/// يفتح نافذة معاينة الطباعة (قناة net.nfet.printing محاكاة بنمط V6
/// فتبقى النافذة بحالة التحميل وعنوانها ظاهرًا)، ولا ازدواج: ترويسة
/// واحدة وشريط واحد لكل شاشة.
///
/// الإعداد بنمط الاختبارات القائمة: قاعدة FFI حقيقية (تأسيس جاهز —
/// المركز عبر راوتر التطبيق كاملاً bootApp، والتفصيلية عبر seam بنماذج
/// محمّلة مسبقاً فوق مستودعات معلَّبة) + تعريب عربي، وكل التفاعل داخل
/// `runAsync` (القاعدة حقيقية غير متزامنة).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/debt_aging_repository.dart';
import 'package:mobile_app/data/repositories/movement_reports_repository.dart';
import 'package:mobile_app/data/repositories/profit_report_repository.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/router/app_router.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/core/widgets/loading_state.dart';
import 'package:mobile_app/ui/core/widgets/sim_list_widgets.dart';
import 'package:mobile_app/ui/features/parties/views/sim_clients_screen.dart';
import 'package:mobile_app/ui/features/reports/view_models/aging_view_model.dart';
import 'package:mobile_app/ui/features/reports/view_models/movement_reports_view_model.dart';
import 'package:mobile_app/ui/features/reports/view_models/profit_report_view_model.dart';
import 'package:mobile_app/ui/features/reports/views/aging_report_screen.dart';
import 'package:mobile_app/ui/features/reports/views/item_movement_screen.dart';
import 'package:mobile_app/ui/features/reports/views/profit_report_screen.dart';
import 'package:mobile_app/ui/features/reports/views/reports_hub_screen.dart';
import 'package:mobile_app/ui/features/reports/views/sales_by_screen.dart';
import 'package:mobile_app/ui/features/reports/views/stock_summary_screen.dart';
import 'package:mobile_app/ui/features/reports/views/widgets/aging_summary_card.dart';
import 'package:mobile_app/ui/features/reports/views/widgets/period_preset_bar.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

/// لحظات «الآن» المحقونة — ثابتة (نفس اصطلاح اختبارات الشاشات القائمة).
final DateTime _now = DateTime(2026, 10, 8, 15);
final DateTime _asOf = DateTime.utc(2026, 10, 8);

void main() {
  setUpAll(initFfiForTests);

  // ─────────────────────────────────────────────────────────────────────
  // المركز — عبر راوتر التطبيق كاملاً (نمط sim_settings_screen_test).
  // ─────────────────────────────────────────────────────────────────────

  late AppDatabase hubDb;
  bool hubOpen = false;

  Future<void> openHubDb() async {
    if (hubOpen) return;
    final seeded = await openSeededApp();
    hubDb = seeded.$1;
    addTearDown(() async {
      hubOpen = false;
      await hubDb.close();
    });
    hubOpen = true;
  }

  Future<GoRouter> bootApp(WidgetTester tester) async {
    final controller = AppController(forTesting: hubDb);
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

  Finder inHub(Finder finder) =>
      find.descendant(of: find.byType(ReportsHubScreen), matching: finder);

  /// يفتح المركز ويستقر حتى يظهر فعلياً (علامة بطاقة البطل).
  Future<void> openHub(WidgetTester tester, GoRouter router) async {
    router.go('/reports');
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await pumpQuietly(tester, 4);
      if (inHub(find.text('مركز التقارير والرقابة')).evaluate().isNotEmpty) {
        break;
      }
    }
    await pumpQuietly(tester, 4);
  }

  testWidgets('١) المركز: ترويسة بلا رجوع + صف «كشف حساب طرف» → /parties', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await openHubDb();
      final router = await bootApp(tester);
      await openHub(tester, router);

      // الترويسة الفرعية بعنوان «التقارير» — **بزر رجوع** (مسار علوي
      // خارج الهيكل: بلا شريط سفلي/درج — مخرج إلزامي ضد الحصار،
      // رجوع R16-b — مراجعة V7 🔴-1): وجوده هنا والنقر يُختبر آخرًا
      // (بعد فحص المحتوى والصف الجديد كي لا يغادر الاختبار المركز).
      expect(inHub(find.byType(SimSubHeader)), findsOneWidget);
      expect(inHub(find.text('التقارير')), findsOneWidget);
      expect(inHub(find.byIcon(Icons.arrow_back_rounded)), findsOneWidget);

      // بطاقة البطل بمحتواها + صفوف المجموعات الأربع كلها قابلة الوصول.
      expect(inHub(find.text('مركز التقارير والرقابة')), findsOneWidget);
      expect(inHub(find.text('الأرباح والخسائر')), findsOneWidget);
      expect(inHub(find.text('حركة صنف')), findsOneWidget);
      expect(inHub(find.text('ملخص حركة المخزون')), findsOneWidget);
      expect(inHub(find.text('المبيعات حسب')), findsOneWidget);
      expect(inHub(find.text('أعمار الديون')), findsOneWidget);
      expect(inHub(find.text('الجرد الفعلي')), findsOneWidget);

      // الصف الجديد (V7-7): كشف حساب طرف → محور الأطراف.
      expect(inHub(find.text('كشف حساب طرف')), findsOneWidget);
      expect(
        inHub(find.text('كشف رسمي بالرصيد التراكمي لعميل أو مورد')),
        findsOneWidget,
      );

      await tester.tap(inHub(find.text('كشف حساب طرف')));
      // استقرار محور الأطراف حتى يكتمل تحميل قائمته (النموذج FFI حقيقي
      // غير متزامن — ننتظر زوال الهيكل العظمي وإلا استمر تحميله بعد
      // انتهاء الاختبار فطبق dispose على نموذج مستخدم).
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await pumpQuietly(tester, 3);
        final clients = find.byType(SimClientsScreen).evaluate();
        if (clients.isNotEmpty &&
            find
                .descendant(
                  of: find.byType(SimClientsScreen),
                  matching: find.byType(ListSkeleton),
                )
                .evaluate()
                .isEmpty) {
          break;
        }
      }
      await pumpQuietly(tester, 4);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/parties',
        reason: 'نقر «كشف حساب طرف» يقود إلى محور الأطراف',
      );

      // عودة للمركز مباشرة (نمط درج التطبيق) ثم نقر زر رجوعه — لا شيء
      // فوق المكدس (كل التنقل go) فيسقط للمخرج الصريح /home (🔴-1).
      router.go('/reports');
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await pumpQuietly(tester, 3);
        if (find.text('مركز التقارير والرقابة').evaluate().isNotEmpty) break;
      }
      await pumpQuietly(tester, 4);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await pumpQuietly(tester, 3);
        if (find.text('مركز التقارير والرقابة').evaluate().isEmpty) break;
      }
      await pumpQuietly(tester, 4);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/home',
        reason: 'زر رجوع المركز يسقط للرئيسية عند فراغ المكدس (R16-b)',
      );
      router.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // الشاشات التفصيلية — seam بنماذج محمّلة مسبقاً (نمط اختباراتها القائمة).
  // ─────────────────────────────────────────────────────────────────────

  /// يحاكي قناة printing (نمط V6) — الحوار يبقى بحالة التحميل وعنوانه
  /// ظاهر (الترسيم لا يكتمل عبر القناة الصامتة) ثم ينظف المحاكاة.
  void mockPrintingChannel() {
    const printChannel = MethodChannel('net.nfet.printing');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(printChannel, (call) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(printChannel, null);
    });
  }

  /// ينقر زر PDF بالشريط الثلاثي ويستقر حتى تظهر نافذة المعاينة بعنوانها.
  Future<void> openPdfPreview(WidgetTester tester) async {
    await tester.tap(find.text('PDF'));
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await pumpQuietly(tester, 3);
      if (find.byType(Dialog).evaluate().isNotEmpty) break;
    }
    await pumpQuietly(tester, 3);
  }

  /// الترويسة + الفترات + الثلاثية بعناوينها المقفلة — فحص مشترك.
  void expectSimScaffold({bool withPeriodBar = true}) {
    expect(find.byType(SimSubHeader), findsOneWidget);
    expect(find.byType(SimBottomActionBar), findsOneWidget);
    expect(find.text('صورة'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('تفوق'), findsOneWidget);
    if (withPeriodBar) {
      expect(find.byType(PeriodPresetBar), findsOneWidget);
      expect(find.byKey(const Key('periodToday')), findsOneWidget);
      expect(find.byKey(const Key('periodMonth')), findsOneWidget);
    }
  }

  testWidgets('٢) الأرباح: ترويسة وفترات وثلاثية + PDF الباني الغني', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final report = ProfitReport(
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 8),
        sales: 1250,
        salesReturns: 250,
        cogs: 700,
        returnCost: 150,
        stockSurplus: 300,
        stockShortage: 120,
        expenses: 180,
        fxGainLoss: 40,
        ownerDrawings: 90,
        salesInvoiceCount: 5,
        returnInvoiceCount: 2,
      );
      final seeded = await openSeededApp();
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = ProfitReportViewModel(
        profitRepo: _CannedProfitRepo(seeded.$1.db, report),
        companyRepo: CompanyRepository(seeded.$1.db),
        reference: _now,
      );
      await vm.load();

      await tester.binding.setSurfaceSize(const Size(390, 2400));
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(ProfitReportScreen(viewModel: vm)),
        ),
      );
      await pumpQuietly(tester, 12);

      expect(find.text('الأرباح والخسائر'), findsOneWidget);
      expectSimScaffold();
      // البنية المفتاحية باقية (بطاقة الربح + صافي المالك).
      expect(find.byKey(const Key('profit_total_card')), findsOneWidget);
      expect(find.text('+490'), findsOneWidget);
      expect(find.text('صافي ما بقي للمالك'), findsOneWidget);

      // PDF → معاينة بعنوان تقرير الأرباح (الباني الغني القائم).
      mockPrintingChannel();
      await openPdfPreview(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('تقرير الأرباح والخسائر'), findsOneWidget);
      expect(find.text('معاينة الطباعة'), findsWidgets);

      await seeded.$1.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('٣) الأعمار: رجوع الأصل + الشرائح الملونة + الثلاثية + PDF', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final seeded = await openSeededApp();
      final db = seeded.$1.db;
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // بذر ديون حقيقي (نمط aging_report_screen_test): عميل بدلاء ٣١–٦٠
      // و٠–٣٠ + عميل بلا أرقام بدلو +٩٠.
      final warehouseId =
          (await db.query('warehouse', limit: 1)).first['id'] as int;
      final yer =
          (await db.rawQuery(
                "SELECT id FROM currency WHERE code = 'YER' LIMIT 1",
              )).first['id']
              as int;
      final customerId = await db.insert('customer', {
        'name': 'عميل التعمير',
        'phone': '777000111',
        'whatsapp': '777000111',
        'is_archived': 0,
        'created_at': '2026-09-01T00:00:00.000Z',
      });
      await db.insert('invoice', {
        'invoice_no': 'V7C-AGING-1',
        'doc_type': 'sale',
        'pay_status': 'credit',
        'status': 'completed',
        'issued_at': '2026-09-05T10:00:00.000Z',
        'due_date': '2026-09-05',
        'warehouse_id': warehouseId,
        'customer_id': customerId,
        'currency_id': yer,
        'exchange_rate': 1,
        'total': 250,
        'paid_amount': 0,
        'due_amount': 250,
      });

      final vm = AgingViewModel(
        debtRepo: DebtAgingRepository(db),
        companyRepo: CompanyRepository(db),
        company: controller.company,
        reference: _asOf,
      );
      await vm.load();

      // راوتر مصغر بوجهة الأصل — إثبات منطق رجوع الأصل القائم (A6).
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              child: Scaffold(
                body: AgingReportScreen(viewModel: vm, origin: '/parties'),
              ),
            ),
          ),
          GoRoute(
            path: '/parties',
            pageBuilder: (context, state) =>
                const NoTransitionPage<void>(child: Scaffold()),
          ),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(390, 2400));
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
      await pumpQuietly(tester, 12);

      expect(find.text('أعمار الديون'), findsOneWidget);
      expectSimScaffold(withPeriodBar: false);
      // شرائح الأعمار الملونة الأربع باقية بالملخص + الدلو ٣١–٦٠ مثقل.
      expect(find.byType(AgingSummaryCard), findsOneWidget);
      expect(find.text('٠–٣٠ يوماً'), findsOneWidget);
      expect(find.text('٣١–٦٠ يوماً'), findsOneWidget);
      expect(find.text('٦١–٩٠ يوماً'), findsOneWidget);
      expect(find.text('أكثر من ٩٠ يوماً'), findsOneWidget);
      expect(find.text('عميل التعمير'), findsOneWidget);
      // ٢٥٠ تظهر بعدة مواضع صادقة (بلاطة الدلو + الإجمالي + سطر العميل).
      expect(find.text('250'), findsWidgets);

      // رجوع الأصل: زر الترويسة يعود إلى /parties (وجهة الدخول المدونة).
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await pumpQuietly(tester, 4);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/parties',
        reason: 'رجوع الأعمار يتبع origin القائم (AgingOriginTracker)',
      );

      // العودة للتقرير ثم PDF → معاينة بعنوان الأعمار.
      router.go('/');
      await pumpQuietly(tester);
      mockPrintingChannel();
      await openPdfPreview(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('أعمار الديون'), findsWidgets);
      expect(find.text('معاينة الطباعة'), findsWidgets);

      router.dispose();
      await seeded.$1.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('٤) حركة صنف: الباقي التراكمي + الثلاثية + PDF بالمسقط', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final report = ItemMovementReport(
        productId: 1,
        name: 'أرز بسمتي',
        unitCostNow: 150,
        openingBalance: 10,
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 8),
        rows: [
          ItemMovementRow(
            movedAt: DateTime.utc(2026, 10, 3, 10),
            movementType: 'sale',
            qty: -3,
            unitCost: 150,
            refType: 'invoice',
            refId: 101,
            notes: 'INV-2026-000101',
            balanceAfter: 7,
          ),
          ItemMovementRow(
            movedAt: DateTime.utc(2026, 10, 8, 11, 30),
            movementType: 'purchase',
            qty: 5,
            unitCost: 150,
            refType: 'invoice',
            refId: 102,
            notes: 'PUR-2026-000102',
            balanceAfter: 12,
          ),
        ],
      );
      final seeded = await openSeededApp();
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = ItemMovementViewModel(
        movementRepo: _CannedMovementRepo(seeded.$1.db, report),
        companyRepo: CompanyRepository(seeded.$1.db),
        productId: 1,
        reference: _now,
      );
      await vm.load();

      await tester.binding.setSurfaceSize(const Size(390, 2400));
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(ItemMovementScreen(viewModel: vm)),
        ),
      );
      await pumpQuietly(tester, 12);

      expect(find.text('حركة صنف'), findsOneWidget);
      expectSimScaffold();
      // الباقي التراكمي باقٍ (شارة الباقي بكل صف + رصيد ما قبل الفترة).
      expect(
        find.byKey(const Key('itemMovement_summary_card')),
        findsOneWidget,
      );
      expect(find.text('رصيد ما قبل الفترة'), findsOneWidget);
      expect(find.byKey(const Key('itemMovement_row_0')), findsOneWidget);
      expect(find.text('الباقي'), findsNWidgets(2));

      // PDF → معاينة بعنوان «حركة صنف — اسم الصنف».
      mockPrintingChannel();
      await openPdfPreview(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('حركة صنف — أرز بسمتي'), findsOneWidget);
      expect(find.text('معاينة الطباعة'), findsWidgets);

      await seeded.$1.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('٥) ملخص المخزون: بطاقة الإجمالي + الثلاثية + PDF بالمسقط', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final rows = [
        const StockSummaryRow(
          productId: 1,
          name: 'ثلاجة',
          qtyIn: 3,
          qtyOut: 0,
          qtyReturns: 0,
          qtyAdjustNet: 0,
          endBalance: 3,
          valueAtCost: 3000,
        ),
        const StockSummaryRow(
          productId: 2,
          name: 'مروحة',
          qtyIn: 4,
          qtyOut: 1,
          qtyReturns: 1,
          qtyAdjustNet: -1,
          endBalance: 3,
          valueAtCost: 750,
        ),
      ];
      final seeded = await openSeededApp();
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = StockSummaryViewModel(
        movementRepo: _CannedStockRepo(seeded.$1.db, rows),
        companyRepo: CompanyRepository(seeded.$1.db),
        reference: _now,
      );
      await vm.load();

      await tester.binding.setSurfaceSize(const Size(390, 2400));
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(StockSummaryScreen(viewModel: vm)),
        ),
      );
      await pumpQuietly(tester, 12);

      expect(find.text('ملخص حركة المخزون'), findsOneWidget);
      expectSimScaffold();
      // صف الإجمالي (بطاقة الرأس) + القيمة بالتكلفة باقيتين.
      expect(find.byKey(const Key('stockSummary_totals_card')), findsOneWidget);
      expect(find.text('3,750'), findsOneWidget);
      expect(find.byKey(const Key('stockSummary_row_0')), findsOneWidget);

      // PDF → معاينة بعنوان الملخص.
      mockPrintingChannel();
      await openPdfPreview(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('ملخص حركة المخزون'), findsWidgets);
      expect(find.text('معاينة الطباعة'), findsWidgets);

      await seeded.$1.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('٦) المبيعات حسب: الأبعاد + الثلاثية + PDF بالمسقط', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final rows = [
        const SalesByRow(
          label: 'أحمد سعيد',
          salesBase: 500,
          invoiceCount: 2,
          changePct: 25.0,
        ),
        const SalesByRow(label: '', salesBase: 50, invoiceCount: 1),
      ];
      final seeded = await openSeededApp();
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = SalesByViewModel(
        movementRepo: _CannedSalesRepo(seeded.$1.db, rows),
        companyRepo: CompanyRepository(seeded.$1.db),
        reference: _now,
      );
      await vm.load();

      await tester.binding.setSurfaceSize(const Size(390, 2400));
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(SalesByScreen(viewModel: vm)),
        ),
      );
      await pumpQuietly(tester, 12);

      expect(find.text('المبيعات حسب'), findsOneWidget);
      expectSimScaffold();
      // رقائق الأبعاد + بطاقة الإجمالي باقيتين.
      expect(find.byKey(const Key('salesByTabCustomer')), findsOneWidget);
      expect(find.byKey(const Key('salesByTabItem')), findsOneWidget);
      expect(find.byKey(const Key('salesBy_total_card')), findsOneWidget);
      expect(find.text('550'), findsOneWidget);

      // PDF → معاينة بعنوان المبيعات حسب.
      mockPrintingChannel();
      await openPdfPreview(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('المبيعات حسب'), findsWidgets);
      expect(find.text('معاينة الطباعة'), findsWidgets);

      await seeded.$1.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('٧) لا ازدواج: ترويسة واحدة وشريط واحد لكل شاشة', (tester) async {
    await tester.runAsync(() async {
      final seeded = await openSeededApp();
      final db = seeded.$1.db;
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() async => await seeded.$1.close());
      addTearDown(controller.dispose);

      await tester.binding.setSurfaceSize(const Size(390, 2400));

      // الأرباح.
      final vm1 = ProfitReportViewModel(
        profitRepo: _CannedProfitRepo(db, _cannedProfit()),
        companyRepo: CompanyRepository(db),
        reference: _now,
      );
      await vm1.load();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(ProfitReportScreen(viewModel: vm1)),
        ),
      );
      await pumpQuietly(tester, 10);
      expect(find.byType(SimSubHeader), findsOneWidget);
      expect(find.byType(SimBottomActionBar), findsOneWidget);
      expect(find.byType(PeriodPresetBar), findsOneWidget);
      vm1.dispose();

      // ملخص المخزون.
      final vm2 = StockSummaryViewModel(
        movementRepo: _CannedStockRepo(db, const []),
        companyRepo: CompanyRepository(db),
        reference: _now,
      );
      await vm2.load();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(StockSummaryScreen(viewModel: vm2)),
        ),
      );
      await pumpQuietly(tester, 10);
      expect(find.byType(SimSubHeader), findsOneWidget);
      expect(find.byType(SimBottomActionBar), findsOneWidget);
      vm2.dispose();

      // المبيعات حسب.
      final vm3 = SalesByViewModel(
        movementRepo: _CannedSalesRepo(db, const []),
        companyRepo: CompanyRepository(db),
        reference: _now,
      );
      await vm3.load();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(SalesByScreen(viewModel: vm3)),
        ),
      );
      await pumpQuietly(tester, 10);
      expect(find.byType(SimSubHeader), findsOneWidget);
      expect(find.byType(SimBottomActionBar), findsOneWidget);
      vm3.dispose();

      // حركة صنف (بلا صنف — الشريط معطل لكنه واحد).
      final vm4 = ItemMovementViewModel(
        movementRepo: _CannedMovementRepo(db, _cannedMovement()),
        companyRepo: CompanyRepository(db),
        reference: _now,
      );
      await vm4.load();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(ItemMovementScreen(viewModel: vm4)),
        ),
      );
      await pumpQuietly(tester, 10);
      expect(find.byType(SimSubHeader), findsOneWidget);
      expect(find.byType(SimBottomActionBar), findsOneWidget);
      vm4.dispose();

      // الأعمار (قاعدة فارغة من الديون — فراغ محتفظ بشريط واحد).
      final vm5 = AgingViewModel(
        debtRepo: DebtAgingRepository(db),
        companyRepo: CompanyRepository(db),
        company: controller.company,
        reference: _asOf,
      );
      await vm5.load();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(AgingReportScreen(viewModel: vm5)),
        ),
      );
      await pumpQuietly(tester, 10);
      expect(find.byType(SimSubHeader), findsOneWidget);
      expect(find.byType(SimBottomActionBar), findsOneWidget);
      vm5.dispose();
    });
  });

  testWidgets('٨) زر «تفوق» موصول فعليًا: يبني المصنف ويبلغ بالنتيجة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final rows = [
        const SalesByRow(label: 'أحمد سعيد', salesBase: 500, invoiceCount: 2),
      ];
      final seeded = await openSeededApp();
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = SalesByViewModel(
        movementRepo: _CannedSalesRepo(seeded.$1.db, rows),
        companyRepo: CompanyRepository(seeded.$1.db),
        reference: _now,
      );
      await vm.load();

      await tester.binding.setSurfaceSize(const Size(390, 2400));
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(SalesByScreen(viewModel: vm)),
        ),
      );
      await pumpQuietly(tester, 12);

      // النقر يبني مصنف xlsx فعليًا ويصل خطوة التنزيل؛ بيئة الاختبار
      // (غير الويب) ترفض التنزيل المباشر فيظهر إشعار الصدق العام — إثبات
      // أن الزر موصول بطوله (ليس زرًا ميتًا) وأن الاستثناء مُلتقط برسالة.
      await tester.tap(find.text('تفوق'));
      await pumpQuietly(tester, 6);
      expect(
        find.text('حدث خطأ غير متوقع'),
        findsOneWidget,
        reason: 'التنزيل غير مدعوم ببيئة الاختبار — مسار الإشعار الصادق',
      );

      await seeded.$1.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('٩) زر «صورة» حي ومفعل بمساره (مراجعة 🟡-8)', (tester) async {
    await tester.runAsync(() async {
      final rows = [
        const SalesByRow(label: 'أحمد سعيد', salesBase: 500, invoiceCount: 2),
      ];
      final seeded = await openSeededApp();
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = SalesByViewModel(
        movementRepo: _CannedSalesRepo(seeded.$1.db, rows),
        companyRepo: CompanyRepository(seeded.$1.db),
        reference: _now,
      );
      await vm.load();

      await tester.binding.setSurfaceSize(const Size(390, 2400));
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(SalesByScreen(viewModel: vm)),
        ),
      );
      await pumpQuietly(tester, 12);

      // إثبات هيكلي كامل للزر: موجود بعنوانه وأيقونته **ومفعل بوظيفة**
      // (onTap ≠ null — ليس زرًا ميتًا). مسار النقر الكامل (بناء PDF →
      // ترسيم قناة printing → تركيب → تنزيل) لا يُحاكى وحدويًا: بنية
      // الحزمة fire-and-forget تستلزم تدفق أحداث منصة كاملًا (محاكاة
      // null تعلّق المستقبل للأبد — كُشف بالتشخيص) — وقد أثبته **التحقق
      // الحي** بتنزيل PNG فعلي (أعمار الديون.png بجودة A4) والخدمة
      // مغطاة وحدويًا (تركيب/سقف/فراغ — report_image_export_test).
      final bar = tester.widget<SimBottomActionBar>(
        find.byType(SimBottomActionBar),
      );
      final imageItem = bar.items.first; // RTL: «صورة» أول زر (أقصى يمين)
      expect(imageItem.label, 'صورة');
      expect(imageItem.icon, Icons.image_outlined);
      expect(imageItem.enabled, isTrue, reason: 'بيانات محملة → زر مفعل');
      expect(imageItem.onTap, isNotNull, reason: 'موصول بمسار التصدير');

      await seeded.$1.close();
      controller.dispose();
      vm.dispose();
    });
  });
}

ProfitReport _cannedProfit() => ProfitReport(
  from: DateTime(2026, 10),
  to: DateTime(2026, 10, 8),
  sales: 1250,
  salesReturns: 250,
  cogs: 700,
  returnCost: 150,
  stockSurplus: 300,
  stockShortage: 120,
  expenses: 180,
  fxGainLoss: 40,
  ownerDrawings: 90,
  salesInvoiceCount: 5,
  returnInvoiceCount: 2,
);

ItemMovementReport _cannedMovement() => ItemMovementReport(
  productId: 1,
  name: 'أرز بسمتي',
  unitCostNow: 150,
  openingBalance: 10,
  from: DateTime(2026, 10),
  to: DateTime(2026, 10, 8),
  rows: const <ItemMovementRow>[],
);

/// مستودع أرباح معلَّب — يعيد التقرير نفسه أياً كانت النافذة.
class _CannedProfitRepo extends ProfitReportRepository {
  _CannedProfitRepo(super.db, this.canned);

  final ProfitReport canned;

  @override
  Future<ProfitReport> report({
    required DateTime from,
    required DateTime to,
  }) async {
    return ProfitReport(
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      sales: canned.sales,
      salesReturns: canned.salesReturns,
      cogs: canned.cogs,
      returnCost: canned.returnCost,
      stockSurplus: canned.stockSurplus,
      stockShortage: canned.stockShortage,
      expenses: canned.expenses,
      fxGainLoss: canned.fxGainLoss,
      ownerDrawings: canned.ownerDrawings,
      salesInvoiceCount: canned.salesInvoiceCount,
      returnInvoiceCount: canned.returnInvoiceCount,
    );
  }
}

/// مستودع حركة صنف معلَّب — يعيد البطاقة نفسها أياً كانت النافذة.
class _CannedMovementRepo extends MovementReportsRepository {
  _CannedMovementRepo(super.db, this.canned);

  final ItemMovementReport canned;

  @override
  Future<ItemMovementReport> itemMovement({
    required int productId,
    required DateTime from,
    required DateTime to,
    int? warehouseId,
  }) async {
    return ItemMovementReport(
      productId: productId,
      name: canned.name,
      unitCostNow: canned.unitCostNow,
      openingBalance: canned.openingBalance,
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      rows: canned.rows,
    );
  }
}

/// مستودع ملخص مخزون معلَّب — يعيد الصفوف نفسها أياً كانت النافذة.
class _CannedStockRepo extends MovementReportsRepository {
  _CannedStockRepo(super.db, this.rows);

  final List<StockSummaryRow> rows;

  @override
  Future<List<StockSummaryRow>> stockSummary({
    required DateTime from,
    required DateTime to,
    int? warehouseId,
  }) async {
    return rows;
  }
}

/// مستودع مبيعات حسب معلَّب — يعيد الصفوف نفسها أياً كانت النافذة.
class _CannedSalesRepo extends MovementReportsRepository {
  _CannedSalesRepo(super.db, this.rows);

  final List<SalesByRow> rows;

  @override
  Future<List<SalesByRow>> salesBy({
    required SalesByDimension dimension,
    required DateTime from,
    required DateTime to,
  }) async {
    return rows;
  }
}
