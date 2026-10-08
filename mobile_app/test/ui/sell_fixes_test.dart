/// اختبارات انحدار إصلاحات تدفقات البيع والكاشير (موجة 1-b):
///
/// - **P0-2**: أزرار طباعة/مشاركة فورية من إيصال نجاح البيع + استهلاك
///   `invoicing.print_on_save` (ask/always/off).
/// - **P1-1**: زر «مرتجع» من تفاصيل فاتورة البيع (ربط ?invoice=).
/// - **P1-3**: «عميل جديد سريع» داخل منتقي العميل يعيد الطرف مختاراً.
/// - **P2-1/2/3**: تمييز زري الإيصال + المختلط يبدأ 0 + تعطيل آجل/مختلط
///   لعميل نقدي.
/// - **P2-5**: validUntil افتراضي +30 يوماً + رقم INV الحقيقي في شريحة
///   التحويل (قابلة للنقر لتفاصيل الفاتورة).
/// - **P2-6**: زر البيع البارز بسلة فارغة يفتح /sell/new مباشرة.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/customer_repository.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/quotation_repository.dart';
import 'package:mobile_app/data/repositories/sale_repository.dart';
import 'package:mobile_app/domain/core/result.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:mobile_app/domain/models/sale.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/router/app_router.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/sell/view_models/customer_picker_view_model.dart';
import 'package:mobile_app/ui/features/sell/view_models/print_on_save.dart';
import 'package:mobile_app/ui/features/sell/view_models/quotations_view_model.dart';
import 'package:mobile_app/ui/features/sell/view_models/sell_cart_session.dart';
import 'package:mobile_app/ui/features/sell/view_models/sell_cart_view_model.dart';
import 'package:mobile_app/ui/features/sell/views/widgets/customer_picker_sheet.dart';
import 'package:mobile_app/ui/features/sell/views/widgets/payment_sheet.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  final at = DateTime.utc(2026, 10, 6, 12);

  late AppDatabase handle;
  late CompanyRepository companies;
  late ItemRepository items;
  late CustomerRepository customers;
  late ExchangeRateRepository fx;
  late SaleRepository sales;
  late QuotationRepository quotations;
  late int userId;
  late int warehouseId;
  late int baseId;

  Future<void> open() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    companies = seeded.$2;
    items = ItemRepository(handle.db);
    customers = CustomerRepository(handle.db);
    fx = ExchangeRateRepository(handle.db);
    sales = SaleRepository(handle.db);
    quotations = QuotationRepository(handle.db);
    userId = (await companies.findAdminUserId())!;
    warehouseId = (await companies.findDefaultWarehouseId())!;
    baseId = (await companies.listActiveCurrencies())
        .firstWhere((c) => c.isBase)
        .id;
    addTearDown(handle.close);
  }

  Future<int> makeItem(String name, {double price = 100}) async {
    final result = await items.createItem(
      ItemDraft(
        name: name,
        costPrice: 50,
        openingQty: 10,
        prices: [ItemPrice(currencyId: baseId, price: price)],
      ),
      warehouseId: warehouseId,
      userId: userId,
      now: at,
    );
    return result.valueOrNull!;
  }

  SellCartViewModel cartVm() => SellCartViewModel(
    itemRepo: items,
    companyRepo: companies,
    fxRepo: fx,
    saleRepo: sales,
    quotationRepo: quotations,
    database: handle.db,
    clock: () => at,
  );

  Future<ItemStockInfo> findInfo(int itemId) async {
    final all = await items.searchItems('', currencyIdForPrice: baseId);
    return all.firstWhere((i) => i.item.id == itemId);
  }

  // ─────────────────────────────────────────────────────────────────────
  // P0-2 — استهلاك invoicing.print_on_save
  // ─────────────────────────────────────────────────────────────────────

  group('PrintOnSave — استهلاك invoicing.print_on_save', () {
    test('parsePrintOnSave: القيم الثلاث المعتمدة والمجهول والغياب = ask', () {
      expect(parsePrintOnSave('ask'), PrintOnSaveMode.ask);
      expect(parsePrintOnSave('always'), PrintOnSaveMode.always);
      expect(parsePrintOnSave('off'), PrintOnSaveMode.off);
      expect(parsePrintOnSave(null), PrintOnSaveMode.ask);
      expect(parsePrintOnSave('garbage'), PrintOnSaveMode.ask);
      expect(parsePrintOnSave(''), PrintOnSaveMode.ask);
    });

    test(
      'resolvePrintOnSave من مستودع حقيقي: الافتراضي ask ثم off/always',
      () async {
        final seeded = await openSeededApp();
        addTearDown(seeded.$1.close);
        final settings = seeded.$4;
        // المزروع في الهجرة v2 = 'ask'.
        expect(await resolvePrintOnSave(settings), PrintOnSaveMode.ask);
        await settings.set('invoicing.print_on_save', 'off');
        expect(await resolvePrintOnSave(settings), PrintOnSaveMode.off);
        await settings.set('invoicing.print_on_save', 'always');
        expect(await resolvePrintOnSave(settings), PrintOnSaveMode.always);
        // بلا مستودع (خارج الجلسة) = ask المحافظ.
        expect(await resolvePrintOnSave(null), PrintOnSaveMode.ask);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  // P0-2 / P2-1 / P2-2 / P2-3 — نافذة الدفع وإيصال النجاح
  // ─────────────────────────────────────────────────────────────────────

  SalePostedReceipt testReceipt() => SalePostedReceipt(
    invoiceId: 7,
    invoiceNo: 'INV-2026-00007',
    totals: const CartTotals(
      subtotal: 100,
      lineDiscountsTotal: 0,
      invoiceDiscount: 0,
      grandTotal: 100,
      itemsCount: 1,
    ),
    payStatus: SalePaymentMethod.cash,
    exchangeRate: 1,
    rateIsFallback: false,
  );

  Future<void> pumpPaymentSheet(
    WidgetTester tester, {
    String? customerName,
    PrintOnSaveMode mode = PrintOnSaveMode.ask,
    Future<void> Function(SalePostedReceipt receipt)? opener,
    required Future<Result<SalePostedReceipt, String>> Function(
      double paidCash,
      SalePaymentMethod method,
    )
    onConfirm,
    required ValueNotifier<bool> posted,
  }) async {
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const Key('fix_open_payment'),
                onPressed: () async {
                  posted.value = await showPaymentSheet(
                    context,
                    grandTotal: 100,
                    decimals: 0,
                    currencyCode: 'YER',
                    customerName: customerName,
                    onConfirm: onConfirm,
                    printOnSave: mode,
                    openInvoicePreview: opener,
                  );
                },
                child: const Text('افتح الدفع'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('fix_open_payment')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// يفتح النافذة ويرحّل نقداً كاملاً → إيصال النجاح ظاهر.
  Future<void> confirmCash(WidgetTester tester) async {
    await tester.tap(find.text('تأكيد الترحيل'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('PaymentSheet — إيصال النجاح (P0-2/P2-1/P2-2/P2-3)', () {
    testWidgets('ask: زرا الطباعة والمشاركة يظهران ويفتحان المعاينة', (
      tester,
    ) async {
      final openedIds = <int>[];
      final posted = ValueNotifier<bool>(false);
      await pumpPaymentSheet(
        tester,
        mode: PrintOnSaveMode.ask,
        opener: (receipt) async => openedIds.add(receipt.invoiceId),
        onConfirm: (paidCash, method) async =>
            Future.value(Ok<SalePostedReceipt, String>(testReceipt())),
        posted: posted,
      );
      await confirmCash(tester);

      // بطاقة الإيصال ظاهرة برقم الفاتورة.
      expect(find.text('INV-2026-00007'), findsOneWidget);
      expect(
        find.byKey(const Key('sell_receipt_print_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('sell_receipt_share_button')),
        findsOneWidget,
      );

      // زر الطباعة يفتح المعاينة (المُسجِّل بدل PDF الحقيقي).
      await tester.tap(find.byKey(const Key('sell_receipt_print_button')));
      await tester.pump();
      expect(openedIds, [7]);
      // زر المشاركة يفتح نفس المعاينة.
      await tester.tap(find.byKey(const Key('sell_receipt_share_button')));
      await tester.pump();
      expect(openedIds, [7, 7]);
    });

    testWidgets('off: الأزرار مخفية والأساسي «فاتورة جديدة» والثانوي «إغلاق»', (
      tester,
    ) async {
      final openedIds = <int>[];
      final posted = ValueNotifier<bool>(false);
      await pumpPaymentSheet(
        tester,
        mode: PrintOnSaveMode.off,
        opener: (receipt) async => openedIds.add(receipt.invoiceId),
        onConfirm: (paidCash, method) async =>
            Future.value(Ok<SalePostedReceipt, String>(testReceipt())),
        posted: posted,
      );
      await confirmCash(tester);

      expect(find.byKey(const Key('sell_receipt_print_button')), findsNothing);
      expect(find.byKey(const Key('sell_receipt_share_button')), findsNothing);
      // الزران متمايزان (P2-1): الأساسي بلا طباعة، والثانوي «إغلاق».
      expect(find.text('فاتورة جديدة'), findsOneWidget);
      expect(find.text('إغلاق'), findsOneWidget);
      expect(find.text('طباعة + فاتورة جديدة'), findsNothing);

      // «إغلاق» ينهي النافذة بنجاح الترحيل (السلوك القائم).
      await tester.tap(find.byKey(const Key('sell_receipt_close_action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(posted.value, isTrue);
      expect(openedIds, isEmpty);
    });

    testWidgets('always: المعاينة تفتح تلقائياً مرة واحدة بعد الترحيل', (
      tester,
    ) async {
      final openedIds = <int>[];
      final posted = ValueNotifier<bool>(false);
      await pumpPaymentSheet(
        tester,
        mode: PrintOnSaveMode.always,
        opener: (receipt) async => openedIds.add(receipt.invoiceId),
        onConfirm: (paidCash, method) async =>
            Future.value(Ok<SalePostedReceipt, String>(testReceipt())),
        posted: posted,
      );
      await confirmCash(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // فتح تلقائي واحد فقط (لا تكرار عند البناء مجدداً).
      expect(openedIds, [7]);
      await tester.pump(const Duration(milliseconds: 200));
      expect(openedIds, [7]);
      // الأزرار اليدوية متاحة أيضاً في always (الوضعان ask/always يعرضانها).
      expect(
        find.byKey(const Key('sell_receipt_print_button')),
        findsOneWidget,
      );
    });

    testWidgets('P2-1: الأساسي «طباعة + فاتورة جديدة» يفتح المعاينة ثم يغلق', (
      tester,
    ) async {
      final openedIds = <int>[];
      final posted = ValueNotifier<bool>(false);
      await pumpPaymentSheet(
        tester,
        mode: PrintOnSaveMode.ask,
        opener: (receipt) async => openedIds.add(receipt.invoiceId),
        onConfirm: (paidCash, method) async =>
            Future.value(Ok<SalePostedReceipt, String>(testReceipt())),
        posted: posted,
      );
      await confirmCash(tester);

      expect(find.text('طباعة + فاتورة جديدة'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sell_receipt_primary_action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // فتح المعاينة ثم إغلاق النافذة بنجاح الترحيل (فاتورة جديدة).
      expect(openedIds, [7]);
      expect(posted.value, isTrue);
      expect(
        find.byKey(const Key('sell_receipt_primary_action')),
        findsNothing,
      );
    });

    testWidgets('P2-2: الدفع المختلط يبدأ من صفر لا من نصف الصافي', (
      tester,
    ) async {
      final posted = ValueNotifier<bool>(false);
      await pumpPaymentSheet(
        tester,
        customerName: 'عميل فهد',
        onConfirm: (paidCash, method) async =>
            Future.value(Ok<SalePostedReceipt, String>(testReceipt())),
        posted: posted,
      );

      await tester.tap(find.text('مختلط'));
      await tester.pump(const Duration(milliseconds: 100));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '0', reason: 'المختلط يبدأ 0 (P2-2)');

      // النقدي الكامل يعود فيملأ الصافي كاملاً.
      await tester.tap(find.text('نقدي كامل'));
      await tester.pump(const Duration(milliseconds: 100));
      final cashField = tester.widget<TextField>(find.byType(TextField));
      expect(cashField.controller!.text, '100');
    });

    testWidgets('P2-3: آجل/مختلط معطّلان للعميل النقدي والتحذير يبقى معروضاً', (
      tester,
    ) async {
      final posted = ValueNotifier<bool>(false);
      await pumpPaymentSheet(
        tester,
        onConfirm: (paidCash, method) async =>
            Future.value(Ok<SalePostedReceipt, String>(testReceipt())),
        posted: posted,
      );

      // التحذير القائم ظاهر.
      expect(
        find.text('العميل النقدي المجهول يسدد نقداً كاملاً فقط.'),
        findsOneWidget,
      );
      // الضغط على «آجل كامل» لا يغيّر النمط (السطر النقدي يبقى) —
      // القبعة معطلة لا رفض بعد الضغط.
      await tester.tap(find.text('آجل كامل'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'بقي نمط النقدي الكامل',
      );
      await tester.tap(find.text('مختلط'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'بقي نمط النقدي الكامل بعد محاولة المختلط',
      );
      // ولا رسالة خطأ (لم يُؤكَّد شيء).
      expect(
        find.text(
          'البيع الآجل يتطلب اختيار عميل أولاً — العميل النقدي المجهول يسدد كاملاً.',
        ),
        findsNothing,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // P1-3 — عميل جديد سريع داخل منتقي العميل
  // ─────────────────────────────────────────────────────────────────────

  group('منتقي العميل — عميل جديد سريع (P1-3)', () {
    Future<void> pumpPicker(
      WidgetTester tester, {
      Future<Result<CustomerPick, String>> Function(String name, String? phone)?
      onCreate,
      required ValueNotifier<CustomerPick?> picked,
    }) async {
      await tester.pumpWidget(
        wrapWithL10n(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  key: const Key('fix_open_picker'),
                  onPressed: () => showCustomerPickerSheet(
                    context,
                    customerRepo: customers,
                    onPick: (pick) => picked.value = pick,
                    onCashCustomer: () {},
                    onCreateCustomer: onCreate,
                  ),
                  child: const Text('افتح المنتقي'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('fix_open_picker')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      // البحث الأولي FFI غير متزامن — أعطه زمناً حقيقياً ليكتمل قبل
      // انتهاء الاختبار (notifyListeners بعد dispose يكسر الإطار).
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await pumpQuietly(tester, 4);
    }

    testWidgets('الحفظ يعيد الطرف الجديد مختاراً ويُنشئه فعلاً في القاعدة', (
      tester,
    ) async {
      // سطح منطقي 390×1600 (dpr=1) — setSurfaceSize وحده يعطي منطقياً
      // 130×533 على dpr الاختباري 3.0 فيفيض كل شيء.
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await open();
        final picked = ValueNotifier<CustomerPick?>(null);
        await pumpPicker(
          tester,
          onCreate: (name, phone) async {
            final result = await customers.createCustomer(
              CustomerDraft(name: name, phone: phone),
              userId: userId,
            );
            return result.map(
              (id) => CustomerPick(
                partyId: id,
                name: name,
                phone: phone,
                currencyCode: 'YER',
                balance: 0,
                hasMoreCurrencies: false,
              ),
            );
          },
          picked: picked,
        );

        expect(
          find.byKey(const Key('sell_customer_new_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('sell_customer_new_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // النموذج المصغّر: الاسم إلزامي.
        await tester.tap(find.byKey(const Key('sell_quick_customer_save')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('اسم العميل مطلوب.'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('sell_quick_customer_name')),
          'سالم أحمد',
        );
        await tester.enterText(
          find.byKey(const Key('sell_quick_customer_phone')),
          '777123999',
        );
        await tester.tap(find.byKey(const Key('sell_quick_customer_save')));
        // الحفظ عبر FFI حقيقي — مهلة حقيقية ليكتمل الإنشاء والإرجاع قبل
        // الفحص (بدونها يُغلق الاختبار القاعدة قبله → database_closed).
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await pumpQuietly(tester, 4);

        // الطرف الجديد عاد مختاراً في المنتقي (pop بالنتيجة).
        expect(picked.value, isNotNull);
        expect(picked.value!.name, 'سالم أحمد');
        expect(picked.value!.phone, '777123999');
        expect(picked.value!.partyId, greaterThan(0));
        // واختُلق فعلاً في القاعدة.
        final rows = await handle.db.query(
          'customer',
          where: 'name = ?',
          whereArgs: ['سالم أحمد'],
        );
        expect(rows, hasLength(1));
        expect(rows.first['phone'], '777123999');
        // المنتقي كله أُغلق.
        expect(find.byKey(const Key('sell_customer_new_button')), findsNothing);
        expect(
          find.byKey(const Key('sell_customer_search_field')),
          findsNothing,
        );
      });
    });

    testWidgets('غياب onCreateCustomer يخفي الزر (السلوك القائم)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await open();
        final picked = ValueNotifier<CustomerPick?>(null);
        await pumpPicker(tester, onCreate: null, picked: picked);
        expect(find.byKey(const Key('sell_customer_new_button')), findsNothing);
        // والمنتقي نفسه يعمل (بحث + عميل نقدي).
        expect(
          find.byKey(const Key('sell_customer_search_field')),
          findsOneWidget,
        );
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // P2-5 — عروض الأسعار: الصلاحية الافتراضية ورقم الفاتورة الحقيقي
  // ─────────────────────────────────────────────────────────────────────

  group('عروض الأسعار (P2-5)', () {
    test('validUntil افتراضي +30 يوماً عند الحفظ من السلة', () async {
      await open();
      final item = await makeItem('قلم حبر');
      final vm = cartVm();
      await vm.load();
      vm.addItemFromInfo(await findInfo(item));

      final saved = await vm.saveAsQuotation();
      expect(saved.isOk, isTrue, reason: '${saved.errorOrNull}');
      final quotation = saved.valueOrNull!;
      expect(quotation.validUntil, isNotNull);
      final want = at.add(const Duration(days: 30));
      // التخزين date-only — التساوي على مستوى اليوم.
      expect(
        DateTime(
          quotation.validUntil!.year,
          quotation.validUntil!.month,
          quotation.validUntil!.day,
        ),
        DateTime(want.year, want.month, want.day),
        reason: 'الصلاحية = يوم الحفظ + 30 يوماً',
      );

      // صلاحية صريحة تُحترم كما هي (التخزين date-only بلا منطقة زمنية).
      final explicit = await vm.saveAsQuotation(
        validUntil: DateTime.utc(2026, 12, 25),
      );
      final got = explicit.valueOrNull!.validUntil!;
      expect(
        DateTime.utc(got.year, got.month, got.day),
        DateTime.utc(2026, 12, 25),
      );
      vm.dispose();
    });

    test('convertedInvoiceNo يجلب رقم INV الحقيقي بعد التحويل', () async {
      await open();
      final item = await makeItem('دفتر مدرسي', price: 500);
      final vm = cartVm();
      await vm.load();
      vm.addItemFromInfo(await findInfo(item));
      final saved = await vm.saveAsQuotation();
      final quotationId = saved.valueOrNull!.id;

      final detailVm = QuotationDetailViewModel(
        quotationRepo: quotations,
        companyRepo: companies,
        quotationId: quotationId,
        saleRepo: sales,
        initialUserId: userId,
      );
      final converted = await detailVm.convertToInvoice(
        paidCash: 500,
        paymentMethod: SalePaymentMethod.cash,
      );
      expect(converted.isOk, isTrue, reason: '${converted.errorOrNull}');
      final invoiceNo = converted.valueOrNull!.invoiceNo;
      expect(invoiceNo, startsWith('INV-'));

      await detailVm.load();
      expect(detailVm.state.convertedInvoiceNo, invoiceNo);
      expect(detailVm.quotation!.convertedInvoiceId, isNotNull);

      // بلا مستودع مبيعات: null (الشريحة تعود للمعرّف الداخلي).
      final noRepoVm = QuotationDetailViewModel(
        quotationRepo: quotations,
        companyRepo: companies,
        quotationId: quotationId,
      );
      await noRepoVm.load();
      expect(noRepoVm.state.convertedInvoiceNo, isNull);
      vm.dispose();
      detailVm.dispose();
      noRepoVm.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // الشاشات عبر الراوتر الكامل — P1-1 و P2-5 و P2-6
  // ─────────────────────────────────────────────────────────────────────

  group('الشاشات عبر الراوتر الكامل', () {
    Future<GoRouter> pumpApp(WidgetTester tester) async {
      final seeded = await openSeededApp();
      handle = seeded.$1;
      companies = seeded.$2;
      items = ItemRepository(handle.db);
      customers = CustomerRepository(handle.db);
      fx = ExchangeRateRepository(handle.db);
      sales = SaleRepository(handle.db);
      quotations = QuotationRepository(handle.db);
      userId = (await companies.findAdminUserId())!;
      warehouseId = (await companies.findDefaultWarehouseId())!;
      baseId = (await companies.listActiveCurrencies())
          .firstWhere((c) => c.isBase)
          .id;
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
      return router;
    }

    testWidgets(
      'P1-1: زر المرتجع بتفاصيل فاتورة البيع → ربط ?invoice= العميق',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          sellCartSession.reset();
          addTearDown(sellCartSession.reset);
          final router = await pumpApp(tester);

          // فاتورة بيع مرحّلة فعلياً.
          final item = await makeItem('حليب المراعي', price: 40);
          final vm = cartVm();
          await vm.load();
          vm.addItemFromInfo(await findInfo(item));
          final posted = await vm.postSale(
            paidCash: 40,
            method: SalePaymentMethod.cash,
          );
          expect(posted.isOk, isTrue, reason: '${posted.errorOrNull}');
          final invoiceId = posted.valueOrNull!.invoiceId;
          vm.dispose();

          router.go('/sell/invoices/$invoiceId');
          await pumpQuietly(tester, 10);
          // تحميل تفاصيل الفاتورة عبر FFI غير متزامن — مهلة حقيقية ليكتمل
          // قبل الفحص (نمط منتقي العميل أعلاه).
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await pumpQuietly(tester, 4);

          final returnButton = find.byKey(
            const Key('sell_detail_return_button'),
          );
          expect(
            returnButton,
            findsOneWidget,
            reason: 'زر المرتجع ظاهر (P1-1)',
          );
          await tester.ensureVisible(returnButton);
          await tester.tap(returnButton);
          await pumpQuietly(tester, 8);

          final uri = router.routerDelegate.currentConfiguration.uri;
          expect(uri.path, '/purchases/returns/sale');
          expect(uri.queryParameters['invoice'], '$invoiceId');
          router.dispose();
        });
      },
    );

    testWidgets('P2-5: شريحة التحويل برقم INV الحقيقي تفتح تفاصيل الفاتورة', (
      tester,
    ) async {
      // سطح منطقي 390×1600 (dpr=1) — setSurfaceSize وحده يعطي منطقياً
      // 130×533 على dpr الاختباري 3.0 فيفيض كل شيء.
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        final router = await pumpApp(tester);

        // عرض سعر محوَّل إلى فاتورة.
        final item = await makeItem('كيس سكر', price: 500);
        final vm = cartVm();
        await vm.load();
        vm.addItemFromInfo(await findInfo(item));
        final saved = await vm.saveAsQuotation();
        final quotationId = saved.valueOrNull!.id;
        final detailVm = QuotationDetailViewModel(
          quotationRepo: quotations,
          companyRepo: companies,
          quotationId: quotationId,
          saleRepo: sales,
          initialUserId: userId,
        );
        final converted = await detailVm.convertToInvoice(
          paidCash: 500,
          paymentMethod: SalePaymentMethod.cash,
        );
        expect(converted.isOk, isTrue, reason: '${converted.errorOrNull}');
        final invoiceId = converted.valueOrNull!.invoiceId;
        final invoiceNo = converted.valueOrNull!.invoiceNo;
        vm.dispose();
        detailVm.dispose();

        router.go('/sell/quotations/$quotationId');
        await pumpQuietly(tester, 10);
        // تحميل التفاصيل عبر FFI غير متزامن — مهلة حقيقية ليكتمل قبل
        // فحص شريحة INV (نفس نمط تفاصيل الفاتورة أعلاه).
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await pumpQuietly(tester, 4);

        // الشريحة تحمل رقم INV الحقيقي لا المعرّف الداخلي.
        final chip = find.byKey(const Key('quotation_converted_invoice_chip'));
        expect(chip, findsOneWidget);
        expect(find.textContaining(invoiceNo), findsOneWidget);
        expect(find.textContaining('#$invoiceId'), findsNothing);

        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await pumpQuietly(tester, 8);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/sell/invoices/$invoiceId',
        );
        router.dispose();
      });
    });

    testWidgets('P2-6: زر البيع البارز بسلة فارغة يفتح /sell/new مباشرة', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        sellCartSession.reset();
        addTearDown(sellCartSession.reset);
        final router = await pumpApp(tester);
        expect(router.routerDelegate.currentConfiguration.uri.path, '/home');

        // سلة فارغة (لا جلسة) → الزر البارز يفتح الكاشير مباشرة.
        // مفتاح مستقر: الأيقونة تتبدل حسب نشاط فرع البيع.
        final sellButton = find.byKey(const Key('shell_sell_button'));
        await tester.tap(sellButton);
        await pumpQuietly(tester, 8);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/sell/new',
          reason: 'سلة فارغة → الكاشير مباشرة (P2-6)',
        );

        // جلسة سلة قائمة (سطر واحد) → الزر يتصرف كمحور البيع كما كان:
        // لا قفز إلى /sell/new — يبقى على موقع فرع البيع الحالي.
        final item = await makeItem('علبة شاي');
        final vm = sellCartSession.attach(
          itemRepo: items,
          companyRepo: companies,
          fxRepo: fx,
          saleRepo: sales,
          quotationRepo: quotations,
          database: handle.db,
        );
        await vm.load();
        vm.addItemFromInfo(await findInfo(item));
        expect(vm.state.lines, isNotEmpty);
        router.go('/sell');
        await pumpQuietly(tester, 8);
        await tester.tap(sellButton);
        await pumpQuietly(tester, 8);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/sell',
          reason: 'جلسة سلة قائمة → محور البيع كما كان (لا قفز للكاشير)',
        );
        router.dispose();
        vm.dispose();
      });
    });
  });
}
