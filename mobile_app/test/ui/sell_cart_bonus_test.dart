/// اختبارات بوابة البونص بالكاشير (موجة UX-4): مفتاح `sale.free_qty`
/// (المزروع 'off' بهجرة v5) يكشف حقل الكمية المجانية بالسطر —
/// `SellCartState.bonusQtyEnabled` تُقرأ عند `load()` عبر مستودع الإعدادات
/// (نفس seam سياسات UX-2a في sell_cart_policies_test) — و`setFreeQty`
/// تحرّر قيمة السطر بلا أي أثر بالتسعير، بينما off (والغياب = سلوك
/// v0.x) يخفيه. ويغطّي اختبار الشاشة الرقاقة المرئية نفسها بسطر السلة
/// عند on عبر الراوتر الكامل (نمط sell_fixes_test).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  /// هل قاعدة هذا الاختبار مفتوحة؟ (تُصفَّر في tearDown — كل اختبار يفتح
  /// قاعدة تأسيس حديثة خاصة به).
  bool dbOpen = false;

  /// يفتح قاعدة تأسيس حديثة للاختبار الحالي (مرة واحدة — الاستدعاءات
  /// التالية داخل نفس الاختبار تعيد استخدامها).
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

  /// نموذج سلة فوق قاعدة الاختبار الحالية — [noSettings] = بلا مستودع
  /// إعدادات (سلوك v0.x). المفتاح يُقرأ عند `load()` فيُكتب قبله.
  Future<SellCartViewModel> newVm({bool noSettings = false}) async {
    final vm = SellCartViewModel(
      itemRepo: items,
      companyRepo: companies,
      fxRepo: fx,
      saleRepo: sales,
      quotationRepo: quotations,
      database: handle.db,
      settingsRepo: noSettings ? null : settings,
      clock: () => at,
    );
    await vm.load();
    addTearDown(vm.dispose);
    return vm;
  }

  /// ينشئ صنفاً (تكلفة 50، سعر 100 بالأساس، مخزون 10) ويضيفه للسلة.
  Future<void> addStockedItem(SellCartViewModel vm) async {
    final created = await items.createItem(
      ItemDraft(
        name: 'صنف بوابة البونص',
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

  group('sale.free_qty — بوابة حقل البونص بالكاشير', () {
    test(
      'on يكشف الحقل: bonusQtyEnabled وsetFreeQty تسري بلا أي أثر بالتسعير',
      () async {
        await openDb();
        // المفتاح يُكتب قبل load() — يُقرأ مرة واحدة مع التحميل.
        await settings.set('sale.free_qty', 'on');
        final vm = await newVm();
        expect(vm.state.bonusQtyEnabled, isTrue);
        await addStockedItem(vm);

        // تحرير البونص: قيمة السطر تتغير والإجمالي لا يمس إطلاقاً.
        expect(vm.grandTotal, 100);
        vm.setFreeQty(0, 2);
        expect(vm.state.lines.single.freeQty, 2);
        expect(vm.grandTotal, 100, reason: 'البونص لا يدخل أي تسعير');
        expect(vm.pricedCart!.lines.single.netFinal, 100);
        // ويسري للترحيل عبر CartLine (المنصرف الكلي هناك).
        expect(vm.cartLines.single.freeQty, 2);

        // المنصرف الكلي (9 مدفوعة + 2 مجاني) يتجاوز المتاح 10 → تحذير
        // التجاوز المرئي (FR-02-02) — البونص يخرج من المخزون كالمدفوع.
        vm.setQty(0, 9);
        expect(vm.state.lines.single.exceedsAvailable, isTrue);
        // بالمقابل 8+2 = 10 = المتاح → لا تجاوز.
        vm.setQty(0, 8);
        expect(vm.state.lines.single.exceedsAvailable, isFalse);

        // القيم المرفوضة (سالب / أدق من ثلاث منازل): إشعار والسطر ثابت.
        vm.setFreeQty(0, -1);
        expect(vm.state.notice, isNotNull);
        expect(vm.state.lines.single.freeQty, 2);
        vm.setFreeQty(0, 0.0005);
        expect(vm.state.notice, isNotNull);
        expect(vm.state.lines.single.freeQty, 2);
        // والصفر يمسح البونص.
        vm.setFreeQty(0, 0);
        expect(vm.state.lines.single.freeQty, 0);
      },
    );

    test('off (بذرة هجرة v5) يخفي الحقل — والتبديل ينعكس بتحميل جديد، والغياب كالإخفاء', () async {
      await openDb();
      // لم نكتب شيئاً — بذرة الهجرة v5 'off' (المحافظة على المتاجر).
      final vm = await newVm();
      expect(vm.state.bonusQtyEnabled, isFalse, reason: 'الافتراضي المزروع');

      // تبديل المفتاح ثم تحميل نموذج جديد فوق نفس القاعدة يعكس on
      // (قراءة load() حية لا قيمة مرة واحدة أبدية — نمط showDiscounts).
      await settings.setBonusQtyEnabled(true);
      final vmOn = await newVm();
      expect(vmOn.state.bonusQtyEnabled, isTrue);

      // غياب مستودع الإعدادات (سلوك v0.x): الحقل مخفي دائماً.
      final vmNoSettings = await newVm(noSettings: true);
      expect(vmNoSettings.state.bonusQtyEnabled, isFalse);
    });
  });

  group('شاشة الكاشير — رقاقة البونص بسطر السلة (sale.free_qty)', () {
    testWidgets(
      'on: الرقاقة ظاهرة بقيمتها «+2 مجاني» — وبعد الإغلاق وجلسة جديدة مختفية',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          sellCartSession.reset();
          addTearDown(sellCartSession.reset);
          await openDb();
          // on قبل أي تحميل — الرقاقة تظهر بالسطر.
          await settings.setBonusQtyEnabled(true);

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

          // جلسة سلة تحمل سطراً ببونص (الشاشة تعيد استخدامها — attach).
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
          vm.setFreeQty(0, 2);

          router.go('/sell/new');
          await pumpQuietly(tester, 10);

          // الرقاقة ظاهرة بالسطر بقيمتها، والكمية المجانية على السطر.
          expect(
            find.byKey(const Key('sell_line_bonus_chip')),
            findsOneWidget,
            reason: 'sale.free_qty=on → حقل البونص بالسطر',
          );
          expect(find.text('+2 مجاني'), findsOneWidget);
          expect(vm.state.lines.single.freeQty, 2);

          // off بعد إغلاق المفتاح وجلسة سلة جديدة: الرقاقة مختفية والسطر
          // قائم (المفتاح يخفي الحقل لا السلة).
          await settings.setBonusQtyEnabled(false);
          router.go('/sell');
          await pumpQuietly(tester, 6);
          sellCartSession.reset();
          final vm2 = sellCartSession.attach(
            itemRepo: items,
            companyRepo: companies,
            fxRepo: fx,
            saleRepo: sales,
            quotationRepo: quotations,
            database: handle.db,
            settingsRepo: settings,
          );
          await vm2.load();
          await addStockedItem(vm2);
          router.go('/sell/new');
          await pumpQuietly(tester, 10);
          expect(
            find.byKey(const Key('sell_line_bonus_chip')),
            findsNothing,
            reason: 'off → حقل البونص مخفي والسطر باقٍ',
          );
          expect(vm2.state.lines.single.qty, 1);

          router.dispose();
          vm.dispose();
          vm2.dispose();
        });
      },
    );
  });
}
