/// اختبارات استهلاك سياسات UX-2a الفعلي بالكاشير: منع الترحيل عند
/// `sale.over_avail_policy` = block (وwarn يمرّ إلى حارس المستودع)،
/// إظهار/إخفاء الخصومات، كشف البيع تحت التكلفة، ووضع الدفع الافتتاحي
/// لنافذة الدفع من `sale.default_payment`، وحارس التأريخ الرجعي.
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
import 'package:mobile_app/domain/models/sale.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/features/cash/views/voucher_screen.dart';
import 'package:mobile_app/ui/features/sell/view_models/sell_cart_view_model.dart';
import 'package:mobile_app/ui/features/sell/views/widgets/payment_sheet.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  final at = DateTime.utc(2026, 10, 6, 12);

  late AppDatabase handle;
  late ItemRepository items;
  late CompanyRepository companies;
  late SettingsRepository settings;
  late int warehouseId;
  late int userId;
  late int baseId;

  /// هل قاعدة هذا الاختبار مفتوحة؟ (تُصفَّر في tearDown — كل اختبار يفتح
  /// قاعدة تأسيس حديثة خاصة به).
  bool dbOpen = false;

  /// يفتح قاعدة تأسيس حديثة للاختبار الحالي (مرة واحدة — الاستدعاءات
  /// التالية داخل نفس الاختبار تعيد استخدامها: نموذج جديد بعد تبديل
  /// إعداد يحمّل من نفس القاعدة ويعكسها).
  Future<void> openDb() async {
    if (dbOpen) return;
    final seeded = await openSeededApp();
    handle = seeded.$1;
    items = ItemRepository(handle.db);
    companies = seeded.$2;
    settings = seeded.$4;
    userId = (await companies.findAdminUserId())!;
    warehouseId = (await companies.findDefaultWarehouseId())!;
    final currencies = await companies.listActiveCurrencies();
    baseId = currencies.firstWhere((c) => c.isBase).id;
    addTearDown(() async {
      dbOpen = false;
      await handle.close();
    });
    dbOpen = true;
  }

  /// نموذج سلة فوق قاعدة الاختبار الحالية — [noSettings] = بلا مستودع
  /// إعدادات (سلوك v0.x)، والافتراضي مستودع القاعدة. السياسات تُقرأ عند
  /// `load()` فالإعداد المراد اختباره يُكتب قبله (بعد openDb مباشرة).
  Future<SellCartViewModel> newVm({bool noSettings = false}) async {
    final vm = SellCartViewModel(
      itemRepo: items,
      companyRepo: companies,
      fxRepo: ExchangeRateRepository(handle.db),
      saleRepo: SaleRepository(handle.db),
      quotationRepo: QuotationRepository(handle.db),
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
        name: 'صنف سياسات البيع',
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

  group('sale.over_avail_policy — سياسة البيع فوق المتاح', () {
    test(
      'block يمنع الترحيل من الكاشير قبل أي كتابة (المخزون لم يُمسّ)',
      () async {
        await openDb();
        // السياسة تُكتب قبل load() — تُقرأ مرة مع التحميل.
        await settings.set('sale.over_avail_policy', 'block');
        final vm = await newVm();
        await addStockedItem(vm);
        expect(vm.state.overAvailPolicy, 'block');
        expect(vm.state.lines.single.availableQty, 10);
        vm.setQty(0, 15);
        expect(vm.state.lines.single.exceedsAvailable, isTrue);

        final result = await vm.postSale(
          paidCash: 1500,
          method: SalePaymentMethod.cash,
        );
        expect(result.isErr, isTrue);
        expect(result.errorOrNull, contains('لا يمكن الترحيل'));
        expect(result.errorOrNull, contains('منع البيع فوق المتاح'));
        // السلة لم تُفرَّغ (رفض ما قبل الترحيل) والمخزون لم يتغير.
        expect(vm.state.lines, hasLength(1));
        final qty = await handle.db.rawQuery(
          'SELECT qty FROM stock_level WHERE product_id = ?',
          [vm.state.lines.single.productId],
        );
        expect((qty.first['qty'] as num).toDouble(), 10);
      },
    );

    test(
      'warn (الافتراضي) يمرّ إلى المستودع — رفضه برسالته لا برسالة السياسة',
      () async {
        await openDb();
        final vm = await newVm();
        await addStockedItem(vm);
        vm.setQty(0, 15);

        final result = await vm.postSale(
          paidCash: 1500,
          method: SalePaymentMethod.cash,
        );
        // المستودع الحارس الأخير يرفض برسالته (لا رسالة سياسة الكاشير).
        expect(result.isErr, isTrue);
        expect(result.errorOrNull, contains('الكمية غير متوفرة'));
        expect(result.errorOrNull, isNot(contains('منع البيع فوق المتاح')));
      },
    );
  });

  group('sale.show_discounts + invoicing.discount_below_margin', () {
    test(
      'الحالة تعكس الإعدادين بعد التحميل (on الافتراضي / off عند التبديل)',
      () async {
        await openDb();
        final vm = await newVm();
        expect(vm.state.showDiscounts, isTrue, reason: 'الافتراضي on');
        expect(vm.state.warnBelowMargin, isFalse);

        // تبديل الإعداد ثم تحميل نموذج جديد فوق نفس القاعدة يعكس off
        // عند التحميل (قراءة load() حية لا قيمة مرة واحدة أبدية).
        await settings.setShowDiscounts(false);
        final vm2 = await newVm();
        expect(vm2.state.showDiscounts, isFalse);
      },
    );

    test(
      'belowCostLineNames يكشف البيع تحت التكلفة بعملة الأساس حصراً',
      () async {
        await openDb();
        await settings.set('invoicing.discount_below_margin', 'on');
        final vm = await newVm();
        await addStockedItem(vm);

        // سعر أعلى من التكلفة: لا تحذير.
        expect(vm.belowCostLineNames, isEmpty);

        // سعر تحت التكلفة (100 → 40 والتكلفة 50): تحذير باسم الصنف.
        vm.setUnitPrice(0, 40);
        expect(vm.belowCostLineNames, isNotEmpty);
        expect(vm.belowCostLineNames.single, vm.state.lines.single.name);

        // غياب مستودع الإعدادات (سلوك v0.x): بلا كشف إطلاقاً.
        final vmNoSettings = await newVm(noSettings: true);
        await addStockedItem(vmNoSettings);
        vmNoSettings.setUnitPrice(0, 40);
        expect(vmNoSettings.belowCostLineNames, isEmpty);
      },
    );
  });

  group('sale.default_payment — وضع نافذة الدفع الافتتاحي', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      required String initialPayMode,
      String? customerName,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showPaymentSheet(
                    context,
                    grandTotal: 250,
                    decimals: 2,
                    currencyCode: 'YER',
                    customerName: customerName,
                    initialPayMode: initialPayMode,
                    onConfirm: (paid, method) async =>
                        throw StateError('لن نؤكد في هذا الاختبار'),
                  ),
                  child: const Text('افتح'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('افتح'));
      await pumpQuietly(tester, 8);
    }

    testWidgets('cash: حقل النقد مملوء بالصافي كاملاً', (tester) async {
      await tester.runAsync(() async {
        await pumpSheet(tester, initialPayMode: 'cash');
        expect(find.byType(TextField), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, '250');
      });
    });

    testWidgets('mixed مع عميل: يبدأ من صفر (P2-2)', (tester) async {
      await tester.runAsync(() async {
        await pumpSheet(
          tester,
          initialPayMode: 'mixed',
          customerName: 'عميل النور',
        );
        expect(find.byType(TextField), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, '0');
      });
    });

    testWidgets('credit بلا عميل يسقط إلى نقدي (P2-3) — الحقل مملوء', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await pumpSheet(tester, initialPayMode: 'credit', customerName: null);
        expect(find.byType(TextField), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, '250');
      });
    });
  });

  group('dating.max_backdate_days — حارس التأريخ الرجعي للسندات', () {
    test('الحد الأدنى = اليوم − عدد الأيام، وحد غير موجب = اليوم فقط', () {
      final now = DateTime(2026, 10, 6, 12);
      expect(voucherBackdateLowerBound(now, 30), DateTime(2026, 9, 6, 12));
      expect(voucherBackdateLowerBound(now, 0), now);
      expect(voucherBackdateLowerBound(now, -7), now);
    });
  });
}
