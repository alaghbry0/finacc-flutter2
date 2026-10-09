/// اختبارات البونص بالكاشير بعد ثورة R16-a (لا بوابة إعدادات):
/// `setFreeQty` دائم التوفر بلا أي مفتاح — تحرير قيمة السطر بلا أي أثر
/// بالتسعير (الإيراد من المدفوع حصراً) والمنصرف الكلي (qty + freeQty)
/// يقود تحذير التجاوز، والقيم الشاذة ترفض بإشعار. ويغطّي اختبار الشاشة
/// الشارة الديناميكية: «(+2 مجاني)» تظهر **حصراً عند freeQty>0** بلا أي
/// شرط إعدادات، ومحرر السطر الموحّد (نقرة صف السطر) يحمل حقل الكمية
/// المجانية دائماً ويحرّر السطر كاملاً (كمية/بونص/سعر/خصم).
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
  /// إعدادات. البونص دائم التوفر بلا أي قراءة إعدادات الآن (R16-a).
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

  group('البونص دائم التوفر — بلا أي بوابة إعدادات (R16-a)', () {
    test(
      'setFreeQty تسري فوراً بلا أي إعداد وبلا أي أثر بالتسعير، '
      'والمفتاح المتقاعد غير معتمد بالمستودع',
      () async {
        await openDb();
        // لم يُكتب أي إعداد — الحقل متاح دائماً الآن.
        final vm = await newVm();
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

        // المفتاح المتقاعد: هجرة v6 حذفته وكتابته تُرفض (FR-13-09 —
        // أي مفتاح خارج السجل ممنوع).
        expect(
          () => settings.set('sale.free_qty', 'on'),
          throwsArgumentError,
        );
        expect(await settings.raw('sale.free_qty'), isNull);
      },
    );

    test('غياب مستودع الإعدادات لا يخفي البونص — الحقل دائم التوفر', () async {
      await openDb();
      final vm = await newVm(noSettings: true);
      await addStockedItem(vm);
      vm.setFreeQty(0, 3);
      expect(vm.state.lines.single.freeQty, 3);
      expect(vm.grandTotal, 100, reason: 'بلا إعدادات: التسعير كالمدفوع');
    });
  });

  group('شاشة الكاشير — الشارة الديناميكية ومحرر السطر الموحّد', () {
    testWidgets(
      'الشارة تظهر حصراً عند freeQty>0 (بلا أي إعدادات) ومحرر السطر يحرّر البونص',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          sellCartSession.reset();
          addTearDown(sellCartSession.reset);
          await openDb();

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

          // جلسة سلة تحمل سطراً بلا بونص — لا إعدادات إطلاقاً.
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

          router.go('/sell/new');
          await pumpQuietly(tester, 10);

          // بلا بونص: لا شارة إطلاقاً (الديناميكية — قرار المالك).
          expect(
            find.byKey(const Key('sell_line_bonus_chip')),
            findsNothing,
            reason: 'freeQty=0 → لا وجود للشارة بلا أي شرط إعدادات',
          );

          // نقرة صف السطر تفتح محرر السطر الموحّد — حقل البونص دائم
          // التوفر هناك.
          await tester.tap(find.text('صنف بوابة البونص'));
          await pumpQuietly(tester, 6);
          expect(
            find.byKey(const Key('sell_line_edit_sheet')),
            findsOneWidget,
            reason: 'محرر السطر الموحّد مفتوح من نقرة الصف',
          );
          expect(
            find.byKey(const Key('sell_line_edit_bonus_field')),
            findsOneWidget,
          );

          // إدخال بونص 2 وحفظ — الشارة تظهر بقيمتها والسعر لم يُمسّ.
          await tester.enterText(
            find.byKey(const Key('sell_line_edit_bonus_field')),
            '2',
          );
          await tester.tap(find.byKey(const Key('sell_line_edit_save')));
          await pumpQuietly(tester, 8);

          expect(vm.state.lines.single.freeQty, 2);
          expect(vm.grandTotal, 100, reason: 'البونص لا يدخل التسعير');
          expect(
            find.byKey(const Key('sell_line_bonus_chip')),
            findsOneWidget,
            reason: 'freeQty=2 → الشارة الديناميكية ظاهرة',
          );
          expect(find.text('+2 مجاني'), findsOneWidget);

          // إعادة فتح المحرر ومسح البونص (صفر) → الشارة تختفي والسطر باقٍ.
          await tester.tap(find.byKey(const Key('sell_line_bonus_chip')));
          await pumpQuietly(tester, 6);
          expect(
            find.byKey(const Key('sell_line_edit_sheet')),
            findsOneWidget,
          );
          await tester.enterText(
            find.byKey(const Key('sell_line_edit_bonus_field')),
            '0',
          );
          await tester.tap(find.byKey(const Key('sell_line_edit_save')));
          await pumpQuietly(tester, 8);

          expect(vm.state.lines.single.freeQty, 0);
          expect(vm.state.lines.single.qty, 1, reason: 'السطر باقٍ');
          expect(
            find.byKey(const Key('sell_line_bonus_chip')),
            findsNothing,
            reason: 'عودة لصفر → لا شارة',
          );

          router.dispose();
          vm.dispose();
        });
      },
    );
  });
}
