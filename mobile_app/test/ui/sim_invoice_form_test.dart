/// اختبارات V4 — نموذج فاتورة Simple Invoice Manager (لقطة 062621):
/// البنية SIM الكاملة على `/sell/new`: سطر INV العلوي، أكورديون
/// العميل، شريط «إجمالي عناصر» الأزرق بمبلغ حي وعدد بنود، أكورديون
/// الخصومات، شريط «مجموع» الداكن، وشريط الإجراءات الرباعي (حفظ/عرض
/// سعر/خصم/أكثر) — مع طي/توسيع الأقسام وتعطيل الحفظ بسلة فارغة.
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
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/router/app_router.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
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

  /// صنف مخزون (تكلفة 50، سعر 100 بالأساس، متاح 10).
  Future<void> addStockedItem(SellCartViewModel vm) async {
    final created = await items.createItem(
      ItemDraft(
        name: 'صنف نموذج SIM',
        costPrice: 50,
        openingQty: 10,
        prices: [ItemPrice(currencyId: baseId, price: 100)],
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
    bool withItem = false,
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
    if (withItem) {
      await addStockedItem(vm);
    }
    return (router, vm);
  }

  group('نموذج فاتورة SIM (V4) — البنية على /sell/new', () {
    testWidgets('المكونات السبعة حاضرة: سطر INV، أكورديون العميل، الشريط '
        'الأزرق بعدد البنود، أكورديون الخصومات، شريط المجموع الداكن، زر '
        'الإضافة المربع، وشريط الإجراءات الرباعي', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(tester, withItem: true);
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        // ١) سطر INV العلوي — رقم الفاتورة القادم معروض كبيراً.
        expect(find.byType(SimInvoiceTopRow), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SimInvoiceTopRow),
            matching: find.text(vm.state.nextInvoiceNo!),
          ),
          findsOneWidget,
          reason: 'رقم INV الحي يظهر بسطر العنوان',
        );

        // ٢) الشريط الأزرق — عنوان «إجمالي عناصر» + عدد البنود (1) +
        //    المبلغ الحي 100 (+).
        final itemsBar = find.byType(SimItemsTotalBar);
        expect(itemsBar, findsOneWidget);
        expect(
          find.descendant(
            of: itemsBar,
            matching: find.textContaining('إجمالي عناصر'),
          ),
          findsOneWidget,
          reason: 'العنوان مع عدد البنود: «إجمالي عناصر (1)»',
        );
        expect(
          find.descendant(of: itemsBar, matching: find.text('100 (+)')),
          findsOneWidget,
          reason: 'سطر واحد 1×100 → المبلغ الحي على الشريط الأزرق',
        );

        // ٣) شريط «مجموع» الداكن — الصافي بعد الخصومات.
        final darkBar = find.byType(SimDarkTotalBar);
        expect(darkBar, findsOneWidget);
        expect(
          find.descendant(of: darkBar, matching: find.text('مجموع')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: darkBar, matching: find.text('100')),
          findsOneWidget,
        );

        // ٤) شريط الإجراءات الرباعي + زر الإضافة المربع.
        expect(find.byType(SimBottomActionBar), findsOneWidget);
        expect(find.byType(SimAddItemSquareButton), findsOneWidget);
        expect(find.text('حفظ'), findsOneWidget);
        expect(find.text('عرض سعر'), findsOneWidget);
        // «خصم الفاتورة» بالمكانين: زر الشريط السفلي (قابل للنقر) وزر
        // جسم الأكورديون المطوي (بالعُقد لكنه محجوب) — نتحقق من القابل
        // للنقر حصراً.
        expect(find.text('خصم الفاتورة').hitTestable(), findsOneWidget);
        expect(find.text('أكثر'), findsOneWidget);

        // ٥) أكورديون الخصومات حاضر بمبلغ صفري في الترويسة.
        expect(find.text('الخصومات'), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('طي قسم البنود بالشريط الأزرق يخفي البطاقات وزر الإضافة، '
        'والتوسيع يعيدها — المبلغ يبقى حياً على الشريط', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(tester, withItem: true);
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        // موسَّع افتراضياً — البطاقة والزر ظاهران.
        expect(find.text('صنف نموذج SIM'), findsOneWidget);
        expect(find.byType(SimAddItemSquareButton), findsOneWidget);

        // طي — يختفيان والشريط يبقى.
        await tester.tap(find.byType(SimItemsTotalBar));
        await pumpQuietly(tester, 6);
        expect(
          find.text('صنف نموذج SIM'),
          findsNothing,
          reason: 'البطاقة مطوية تحت الشريط الأزرق',
        );
        expect(find.byType(SimAddItemSquareButton), findsNothing);
        expect(find.byType(SimItemsTotalBar), findsOneWidget);
        expect(find.descendant(
          of: find.byType(SimItemsTotalBar),
          matching: find.text('100 (+)'),
        ), findsOneWidget);

        // توسيع — يعودان.
        await tester.tap(find.byType(SimItemsTotalBar));
        await pumpQuietly(tester, 6);
        expect(find.text('صنف نموذج SIM'), findsOneWidget);
        expect(find.byType(SimAddItemSquareButton), findsOneWidget);
        router.dispose();
      });
    });

    testWidgets('أكورديون العميل مطوي على «عميل نقدي» ويتمدد لأزرار '
        'الاختيار (اختيار عميل / عميل نقدي) وصف العملات', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(tester, withItem: true);
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        // مطوي افتراضياً — الترويسة تحمل «عميل نقدي» والأزرار غير قابلة
        // للنقر (AnimatedCrossFade يُبقيها بالشجرة لكنها محجوبة).
        expect(find.text('اختيار عميل').hitTestable(), findsNothing);
        expect(find.text('عميل نقدي'), findsWidgets);

        // ترويسة أكورديون العميل = SimAccordionHeader الأول بالشاشة.
        final clientHeader = find.byType(SimAccordionHeader).first;
        await tester.tap(clientHeader);
        await pumpQuietly(tester, 6);
        expect(
          find.text('اختيار عميل').hitTestable(),
          findsOneWidget,
          reason: 'التوسيع يكشف أزرار اختيار العميل',
        );
        router.dispose();
      });
    });

    testWidgets('الحفظ معطَّل بسلة فارغة ويتفعَّل مع بند — نفس قاعدة '
        'الدفع القديمة (warehouseId + بلا خطأ)', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        // سلة فارغة.
        final (router, vm) = await bootApp(tester);
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        final saveTile = find.ancestor(
          of: find.text('حفظ'),
          matching: find.byType(InkWell),
        );
        final emptyInk = tester.widget<InkWell>(saveTile.first);
        expect(
          emptyInk.onTap,
          isNull,
          reason: 'سلة فارغة → الحفظ معطَّل',
        );

        // إضافة بند — يتفعل بدون إعادة بناء الشاشة.
        await addStockedItem(vm);
        await pumpQuietly(tester, 6);
        final filledInk = tester.widget<InkWell>(saveTile.first);
        expect(filledInk.onTap, isNotNull, reason: 'بند واحد → الحفظ مفعّل');
        router.dispose();
      });
    });
  });
}
