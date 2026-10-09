/// اختبارات R17-a — «كتابة/تعديل كميات الأصناف مباشرة عند إنشاء الفواتير»
/// بمسار البيع: قيمة الكمية داخل [QtyStepper] تصبح زراً قابلاً للنقر
/// (`sell_line_qty_value`) يفتح المحرر الرقمي السريع (showNumberEditSheet)
/// — نقرة واحدة + كتابة (7 أو 2.5) بدل فتح محرر السطر الكامل. زرّا ±
/// يبقيان كما هما، والإلغاء لا يمسّ السطر، والقيمة غير الصالحة (صفر)
/// ترفض داخل النافذة بنفس قيود `SellCartViewModel.setQty`.
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
import 'package:mobile_app/ui/features/sell/views/widgets/sell_widgets.dart';
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

  /// صنف مخزون (تكلفة 50، سعر 100 بالأساس، متاح 10) بلا بونص.
  Future<void> addStockedItem(SellCartViewModel vm) async {
    final created = await items.createItem(
      ItemDraft(
        name: 'صنف الكمية المباشرة',
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
  Future<(GoRouter, SellCartViewModel)> bootApp(WidgetTester tester) async {
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
    await pumpQuietly(tester, 8);

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
    await addStockedItem(vm);
    return (router, vm);
  }

  group('الكاشير — نقرة قيمة الكمية → كتابة مباشرة (R17-a)', () {
    testWidgets('نقرة القيمة تفتح المحرر الرقمي؛ كتابة 7 وتأكيد → كمية السطر 7 '
        'وأزرار ± باقية لم تُمسّ', (tester) async {
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

        // القيمة نفسها صارت هدفاً قابلاً للنقر — وزرّا ± كما هما.
        final valueTap = find.byKey(const Key('sell_line_qty_value'));
        expect(valueTap, findsOneWidget);
        expect(vm.state.lines.single.qty, 1);

        await tester.tap(valueTap);
        await pumpQuietly(tester, 6);

        // النافذة السفلية ظهرت بعنوان «تعديل الكمية» ومعها حقل واحد.
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('تعديل الكمية: صنف الكمية المباشرة'), findsOneWidget);
        final field = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        );
        expect(field, findsOneWidget);

        await tester.enterText(field, '7');
        await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
        await pumpQuietly(tester, 12);

        // الكمية صارت 7 بالسطر وبالعرض — والسعر لم يُمسّ.
        expect(vm.state.lines.single.qty, 7);
        expect(
          find.descendant(of: valueTap, matching: find.text('7')),
          findsOneWidget,
          reason: 'قيمة السطر تعرض 7 بعد الكتابة المباشرة',
        );
        expect(vm.grandTotal, 700, reason: '7 × 100 — التسعير سليم');

        // أزرار ± تعمل بعد التحرير المباشر (كمية 7 → 8 بنقرة +).
        await tester.tap(
          find.descendant(
            of: find.byType(QtyStepper),
            matching: find.byIcon(Icons.add_rounded),
          ),
        );
        await pumpQuietly(tester, 6);
        expect(vm.state.lines.single.qty, 8);

        router.dispose();
        vm.dispose();
      });
    });

    testWidgets('كسور عشرية (2.5) مقبولة، والإلغاء لا يمسّ السطر، والصفر يرفض '
        'داخل النافذة (allowZero=false)', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        await openDb();

        // إخفاء خصومات الكاشير (UX-2a — إعداد موثّق): الرقم الكسري أعرض
        // بخط الاختبار الافتراضي من خطوط الإنتاج، وصف الكمية + السعر +
        // الخصم بعرض 390dp كان على الحافة أصلاً حتى قبل R17-a مع قيم
        // كسرية — هنا نعزل سلوك الكتابة المباشرة بلا تداخل العرض.
        await settings.set('sale.show_discounts', 'off');

        final (router, vm) = await bootApp(tester);
        router.go('/sell/new');
        await pumpQuietly(tester, 10);

        final valueTap = find.byKey(const Key('sell_line_qty_value'));

        // ── كسر عشري: 2.5 (تقليم الأصفار يعرضها «2.5» لا «2.500») ───
        await tester.tap(valueTap);
        await pumpQuietly(tester, 6);
        final field = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        );
        await tester.enterText(field, '2.5');
        await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
        await pumpQuietly(tester, 12);
        expect(vm.state.lines.single.qty, 2.5);
        expect(
          find.descendant(of: valueTap, matching: find.text('2.5')),
          findsOneWidget,
        );

        // ── إلغاء: السطر باقٍ على 2.5 ─────────────────────────────
        await tester.tap(valueTap);
        await pumpQuietly(tester, 6);
        await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
        await pumpQuietly(tester, 8);
        expect(vm.state.lines.single.qty, 2.5);

        // ── صفر: يرفض داخل النافذة (رسالة خطأ) ولا يصل setQty ────
        await tester.tap(valueTap);
        await pumpQuietly(tester, 6);
        expect(find.byType(BottomSheet), findsOneWidget);
        await tester.enterText(field, '0');
        await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
        await pumpQuietly(tester, 6);
        expect(
          find.byType(BottomSheet),
          findsOneWidget,
          reason: 'الصفر مرفوض — النافذة تبقى مفتوحة برسالة',
        );
        expect(find.text('أدخل رقماً صالحاً.'), findsOneWidget);
        expect(vm.state.lines.single.qty, 2.5);

        router.dispose();
        vm.dispose();
      });
    });
  });
}
