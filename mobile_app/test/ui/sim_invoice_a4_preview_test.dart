/// اختبارات V6-B — معاينة A4 للفاتورة من المسودة الحية على `/sell/new`:
/// تبويبا نموذج الإدخال/معاينة (تبديل شرطي `if` لا IndexedStack فلا ازدواج
/// نصوص بين الوضعين)، الورقة A4 بعناصر `renderA4Preview` بالنموذج الأولي
/// (ترويسة المنشأة/العنوان/فاتورة إلى/الجدول الخماسي/المبلغ الإجمالي/
/// توازن/التوقيع)، حفظ حالة الأكورديونات عبر الذهاب والعودة، سطر
/// «مجاني: N» تحت اسم المنتج، صف الخصم بقيمة الشريط الأزرق = الصافي بعد
/// الخصومات، حالة الفراغ الصادقة، والشريط السفلي المشترك في الوضعين.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/quotation_repository.dart';
import 'package:mobile_app/data/repositories/sale_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/sale.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/router/app_router.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/core/widgets/sim_doc_widgets.dart';
import 'package:mobile_app/ui/features/sell/view_models/sell_cart_session.dart';
import 'package:mobile_app/ui/features/sell/view_models/sell_cart_view_model.dart';
import 'package:mobile_app/ui/features/sell/views/widgets/sim_invoice_widgets.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  final at = DateTime.utc(2026, 10, 6, 12);

  late AppDatabase handle;
  late ItemRepository items;
  late CompanyRepository companies;
  late SettingsRepository settings;
  late ExchangeRateRepository fx;
  late SaleRepository sales;
  late QuotationRepository quotations;
  late int warehouseId;
  late int userId;
  late int baseId;

  bool dbOpen = false;

  Future<void> openDb() async {
    if (dbOpen) return;
    final seeded = await openSeededApp();
    handle = seeded.$1;
    items = ItemRepository(handle.db);
    companies = seeded.$2;
    settings = seeded.$4;
    fx = ExchangeRateRepository(handle.db);
    sales = SaleRepository(handle.db);
    quotations = QuotationRepository(handle.db);
    userId = (await companies.findAdminUserId())!;
    warehouseId = (await companies.findDefaultWarehouseId())!;
    baseId = (await companies.listActiveCurrencies())
        .firstWhere((c) => c.isBase)
        .id;
    addTearDown(() async {
      dbOpen = false;
      await handle.close();
    });
    dbOpen = true;
  }

  /// صنف مخزون بكسر قابل للتخصيص (تكلفة نصف السعر، متاح 10).
  Future<void> addStockedItem(
    SellCartViewModel vm, {
    required String name,
    required double price,
  }) async {
    final created = await items.createItem(
      ItemDraft(
        name: name,
        costPrice: price / 2,
        openingQty: 10,
        prices: [ItemPrice(currencyId: baseId, price: price)],
      ),
      warehouseId: warehouseId,
      userId: userId,
      now: at,
    );
    final all = await items.searchItems('', currencyIdForPrice: baseId);
    final info = all.firstWhere((i) => i.item.id == created.valueOrNull!);
    vm.addItemFromInfo(info);
  }

  /// يبني التطبيق كاملاً (راوتر + جلسة مفتوحة) ويعيد الراوتر ونموذج السلة.
  Future<(GoRouter, SellCartViewModel)> bootApp(
    WidgetTester tester, {
    List<(String, double)> stock = const [],
  }) async {
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

    final vm = sellCartSession.attach(
      itemRepo: items,
      companyRepo: companies,
      fxRepo: fx,
      saleRepo: sales,
      quotationRepo: quotations,
      database: handle.db,
      settingsRepo: settings,
    );
    await vm.load();
    for (final (name, price) in stock) {
      await addStockedItem(vm, name: name, price: price);
    }
    return (router, vm);
  }

  group('V6-B — تبويبات نموذج/معاينة + معاينة A4 للفاتورة', () {
    testWidgets('١) تبويبا الوضع ظاهران بنصيهما والافتراضي نموذج الإدخال', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(
          tester,
          stock: const [('صنف معاينة A4', 100)],
        );
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        // التبويبان بنصيهما — فوق الجسم مباشرة تحت الـAppBar.
        expect(find.text('نموذج الإدخال'), findsOneWidget);
        expect(find.text('معاينة'), findsOneWidget);

        // الافتراضي = النموذج: هيكل V4 حي ولا ورقة A4 بالشجرة.
        expect(find.byType(SimInvoiceTopRow), findsOneWidget);
        expect(find.byType(SimA4Sheet), findsNothing);
        expect(find.text('فاتورة إلى:'), findsNothing);
        router.dispose();
      });
    });

    testWidgets('٢) «معاينة» تعرض ورقة A4 كاملة بعناصر النموذج الأولي', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(
          tester,
          stock: const [('صنف معاينة A4', 100)],
        );
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester, 6);

        // الورقة + ترويسة المنشأة (اسم تأسيس قاعدة الاختبار).
        expect(find.byType(SimA4Sheet), findsOneWidget);
        expect(find.text('متجر النور للأدوات المنزلية'), findsOneWidget);

        // رقم INV داخل صف العنوان (الـAppBar يعرضه أيضاً — نُحصر بالصف).
        expect(
          find.descendant(
            of: find.byType(SimDocTitleRow),
            matching: find.text(vm.state.nextInvoiceNo!),
          ),
          findsOneWidget,
        );
        // العنوان الكبير «فاتورة» (أقصى اليمين — درس الطباعة العربية).
        expect(find.text('فاتورة'), findsOneWidget);

        // «فاتورة إلى:» + عميل نقدي بالفاتورة (بلا هاتف) — الاسم نفسه
        // يظهر أيضاً باسم الموقِّع أسفل الورقة (اسمان مشروعان).
        expect(find.text('فاتورة إلى:'), findsOneWidget);
        expect(find.text('عميل نقدي'), findsNWidgets(2));

        // جدول البنود بأعمدته الخمسة (الخامس «المبلغ» — تصحيح مطبعية
        // النموذج الأصلي الذي يكرر «كمية»).
        final table = find.byType(SimDocItemsTable);
        expect(table, findsOneWidget);
        for (final header in ['رقم', 'المنتج', 'كمية', 'معدل', 'المبلغ']) {
          expect(
            find.descendant(of: table, matching: find.text(header)),
            findsOneWidget,
            reason: 'عمود «$header» برأس الجدول',
          );
        }
        // اسم الصنف داخل الجدول.
        expect(
          find.descendant(of: table, matching: find.text('صنف معاينة A4')),
          findsOneWidget,
        );

        // شريط «المبلغ الإجمالي» الأزرق + «توازن» + «التوقيع:».
        expect(find.text('المبلغ الإجمالي'), findsOneWidget);
        expect(find.text('توازن'), findsOneWidget);
        expect(find.text('التوقيع:'), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('٣) لا ازدواج نصوص بين الوضعين — المبلغ المشترك مرة '
        'واحدة في كل وضع على حدة', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        // بنوان ٣٠+٧٠ = ١٠٠: ببند واحد يستوي مبلغ السطر والمجموع فيتكرر
        // المشترك حقه داخل الوضع الواحد نفسه — البندان يجعلان المجموع
        // نصاً وحيداً في كل وضع (النموذج: شريط المجموع الداكن حصراً؛
        // المعاينة: صف «توازن» حصراً).
        final (router, vm) = await bootApp(
          tester,
          stock: const [('صنف أول', 30), ('صنف ثانٍ', 70)],
        );
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        // وضع النموذج: لا عناصر معاينة إطلاقاً + المبلغ مرة واحدة.
        expect(find.byType(SimA4Sheet), findsNothing);
        expect(find.text('فاتورة إلى:'), findsNothing);
        expect(find.text('المبلغ الإجمالي'), findsNothing);
        expect(find.text('توازن'), findsNothing);
        expect(
          find.text('100'),
          findsOneWidget,
          reason: 'بالنموذج المجموع ١٠٠ على شريط «مجموع» الداكن وحده',
        );
        expect(find.text('100 (+)'), findsOneWidget);

        // معاينة: لا عناصر النموذج إطلاقاً + المبلغ مرة واحدة.
        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester, 6);
        expect(find.byType(SimDarkTotalBar), findsNothing);
        expect(find.byType(SimItemsTotalBar), findsNothing);
        expect(find.byType(SimInvoiceTopRow), findsNothing);
        expect(find.text('إجمالي عناصر'), findsNothing);
        expect(
          find.text('100'),
          findsOneWidget,
          reason: 'بالمعاينة المجموع ١٠٠ في صف «توازن» وحده (خلايا ٣٠/٧٠)',
        );
        expect(find.text('100 YER'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SimDocBlueTotalBar),
            matching: find.text('100 YER'),
          ),
          findsOneWidget,
        );

        // العودة للنموذج تعيد مبلغه الحي دون أي ازدواج.
        await tester.tap(find.text('نموذج الإدخال'));
        await pumpQuietly(tester, 6);
        expect(find.byType(SimA4Sheet), findsNothing);
        expect(find.text('100 (+)'), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('٤) الذهاب للمعاينة والعودة يحفظان حالة الأكورديون الموسَّع', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(
          tester,
          stock: const [('صنف الأكورديونات', 100)],
        );
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        // توسيع أكورديون العميل (مطوي افتراضياً) — أزرار الاختيار مكشوفة.
        await tester.tap(find.byType(SimAccordionHeader).first);
        await pumpQuietly(tester, 6);
        expect(
          find.text('اختيار عميل').hitTestable(),
          findsOneWidget,
          reason: 'أكورديون العميل موسَّع قبل التبديل',
        );

        // الذهاب للمعاينة ثم العودة — الحالة كما كانت (تسكن State).
        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester, 6);
        expect(find.byType(SimA4Sheet), findsOneWidget);
        await tester.tap(find.text('نموذج الإدخال'));
        await pumpQuietly(tester, 6);
        expect(
          find.text('اختيار عميل').hitTestable(),
          findsOneWidget,
          reason: 'التوسيع محفوظ عبر الذهاب للمعاينة والعودة',
        );
        // وقسم البنود كذلك (موسَّع افتراضياً).
        expect(find.text('صنف الأكورديونات'), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('٥) بند بمجانية freeQty>0 → «مجاني: 2» تحت اسمه بالمعاينة', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(
          tester,
          stock: const [('صنف ذو بونص', 100)],
        );
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        // بونص 2 على السطر الأول ثم المعاينة.
        vm.setFreeQty(0, 2);
        await pumpQuietly(tester, 6);
        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester, 6);

        expect(find.text('مجاني: 2'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SimDocItemsTable),
            matching: find.text('مجاني: 2'),
          ),
          findsOneWidget,
          reason: 'سطر المجانية داخل خلية المنتج بالجدول',
        );
        router.dispose();
      });
    });

    testWidgets('٦) بند بخصم → صف «الخصم» ظاهر والشريط الأزرق = الصافي '
        'بعد الخصم لا subtotal', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(
          tester,
          stock: const [('صنف مخصوم', 100)],
        );
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        // خصم رأس ٣٠ → الصافي ٧٠.
        vm.setInvoiceDiscount(SaleDiscountType.amount, 30);
        await pumpQuietly(tester, 6);
        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester, 6);

        // صف «الخصم» ظاهر بقيمة سالبة.
        expect(find.text('الخصم'), findsOneWidget);
        expect(find.text('−30'), findsOneWidget);

        // الشريط الأزرق = grandTotal بعد الخصم (٧٠) لا subtotal (١٠٠).
        expect(
          find.descendant(
            of: find.byType(SimDocBlueTotalBar),
            matching: find.text('70 YER'),
          ),
          findsOneWidget,
          reason: 'قيمة الشريط الأزرق هي الصافي بعد الخصومات',
        );
        expect(find.text('100 YER'), findsNothing);
        // «توازن» = الصافي نفسه.
        expect(
          find.descendant(
            of: find.byType(SimDocRow).last,
            matching: find.text('70'),
          ),
          findsOneWidget,
        );
        router.dispose();
      });
    });

    testWidgets('٧) سلة فارغة → المعاينة بحالة فراغ صادقة (لا جدول)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(tester);
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester, 6);

        // الورقة حية بنص الحالة الفارغة بدل الجدول — وإجمالي صادق 0.
        expect(find.byType(SimA4Sheet), findsOneWidget);
        expect(
          find.text('لا بنود في الفاتورة بعد — أضف عناصر من نموذج الإدخال'),
          findsOneWidget,
        );
        expect(find.byType(SimDocItemsTable), findsNothing);
        expect(find.text('فاتورة'), findsOneWidget);
        expect(find.text('المبلغ الإجمالي'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SimDocBlueTotalBar),
            matching: find.text('0 YER'),
          ),
          findsOneWidget,
        );
        router.dispose();
      });
    });

    testWidgets('٨) الشريط السفلي الرباعي ظاهر في الوضعين (زر «حفظ» '
        'واحد في كليهما)', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(
          tester,
          stock: const [('صنف الشريط المشترك', 100)],
        );
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        // النموذج: الشريط حي بزمرة أزراره.
        expect(find.byType(SimBottomActionBar), findsOneWidget);
        expect(find.text('حفظ'), findsOneWidget);
        expect(find.text('عرض سعر'), findsOneWidget);

        // المعاينة: الشريط نفسه خارج التبديل — ظاهر بلا ازدواج.
        await tester.tap(find.text('معاينة'));
        await pumpQuietly(tester, 6);
        expect(find.byType(SimBottomActionBar), findsOneWidget);
        expect(find.text('حفظ'), findsOneWidget);
        router.dispose();
      });
    });
  });
}
