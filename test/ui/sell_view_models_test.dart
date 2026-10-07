/// اختبارات نماذج عرض البيع (المرحلة 4) — قيادة مباشرة بقاعدة حقيقية
/// وفق النمط المعتمد (openSeededApp + مستودعات فعلية).
///
/// التغطية: بناء السلة والتسعير الحي (خصوم سطر وفاتورة pro-rata) ←
/// الدفع نقدي/آجل/مختلط بقواعده (FR-02-02/03) ← بوابة سعر الصرف
/// (FR-08-09) ← عروض الأسعار وحفظها وتحويلها (FR-02-11) ← سلة لا
/// تُفقد عند الرفض.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/customer_repository.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/quotation_repository.dart';
import 'package:mobile_app/data/repositories/sale_repository.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/quotation.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:mobile_app/domain/models/sale.dart';

import '../helpers/app_for_tests.dart';

import 'package:mobile_app/ui/features/sell/view_models/quotations_view_model.dart';
import 'package:mobile_app/ui/features/sell/view_models/sales_invoices_view_model.dart';
import 'package:mobile_app/ui/features/sell/view_models/sell_cart_view_model.dart';

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
  late int usdId;

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
    final currencies = await companies.listActiveCurrencies();
    baseId = currencies.firstWhere((c) => c.isBase).id;
    usdId = currencies.firstWhere((c) => c.code == 'USD').id;
    addTearDown(handle.close);
  }

  /// ينشئ صنفاً مادياً بمخزون وسعر بيع بالعملة الأساسية (+USD اختيارياً).
  Future<int> makeItem(
    String name, {
    double cost = 50,
    double price = 100,
    double qty = 10,
    double? usdPrice,
  }) async {
    final result = await items.createItem(
      ItemDraft(
        name: name,
        costPrice: cost,
        openingQty: qty,
        prices: [
          ItemPrice(currencyId: baseId, price: price),
          if (usdPrice != null) ItemPrice(currencyId: usdId, price: usdPrice),
        ],
      ),
      warehouseId: warehouseId,
      userId: userId,
      now: at,
    );
    return result.valueOrNull!;
  }

  Future<int> makeCustomer(String name, {double? creditLimit}) async {
    final result = await customers.createCustomer(
      CustomerDraft(name: name, creditLimit: creditLimit, openingBalance: 0),
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

  /// يجلب ItemStockInfo بالبحث (المحرك الذي تستخدمه نافذة اختيار الصنف)
  /// — السعر بعملة السلة الحالية (بدونها يأتي السعر فارغاً).
  Future<ItemStockInfo> findInfo(int itemId, {int? currencyId}) async {
    final all = await items.searchItems(
      '',
      currencyIdForPrice: currencyId ?? baseId,
    );
    return all.firstWhere((i) => i.item.id == itemId);
  }

  Future<double> stockOf(int itemId) async {
    final rows = await handle.db.rawQuery(
      'SELECT COALESCE(SUM(qty), 0) AS q FROM stock_level WHERE product_id = ?',
      [itemId],
    );
    return (rows.first['q'] as num?)?.toDouble() ?? 0;
  }

  group('SellCartViewModel — بناء السلة والتسعير الحي', () {
    test(
      'سطر + خصم سطر + خصم فاتورة (مبلغ ونسبة) بأرقام محسوبة يدوياً',
      () async {
        await open();
        final item = await makeItem('سكر', cost: 40, price: 100, qty: 20);
        final vm = cartVm();
        await vm.load();
        vm.addItemFromInfo(await findInfo(item));
        vm.setQty(0, 3);
        // المجموع 300، خصم سطر 10% = 30 → 270، خصم فاتورة 20 → 250.
        vm.setLineDiscount(0, SaleDiscountType.percent, 10);
        vm.setInvoiceDiscount(SaleDiscountType.amount, 20);
        final priced = vm.pricedCart!;
        expect(priced.totals.subtotal, 300);
        expect(priced.totals.lineDiscountsTotal, closeTo(30, 0.001));
        expect(priced.totals.invoiceDiscount, closeTo(20, 0.001));
        expect(priced.totals.grandTotal, closeTo(250, 0.001));
        // خصم فاتورة بنسبة 10% على 270 → الصافي 243.
        vm.setInvoiceDiscount(SaleDiscountType.percent, 10);
        expect(vm.grandTotal, closeTo(243, 0.001));
        // كميات غير صالحة ترفض فورياً بإشعار — السطر لا يتغير.
        vm.setQty(0, 0);
        expect(vm.state.notice, isNotNull);
        expect(vm.state.lines.first.qty, 3);
        // خصم فاتورة يصفّر الصافي → خطأ تحقق يمنع الدفع حتى التصحيح.
        vm.setInvoiceDiscount(SaleDiscountType.amount, 400);
        expect(vm.cartError, isNotNull);
        vm.setInvoiceDiscount(SaleDiscountType.amount, 20);
        expect(vm.cartError, isNull);
        vm.dispose();
      },
    );

    test('إضافة نفس الصنف ثانية تدمج في سطر واحد بكمية +1', () async {
      await open();
      final item = await makeItem('شاي', price: 25, qty: 9);
      final vm = cartVm();
      await vm.load();
      final info = await findInfo(item);
      vm.addItemFromInfo(info);
      vm.addItemFromInfo(info);
      expect(vm.state.lines, hasLength(1));
      expect(vm.state.lines.first.qty, 2);
      expect(vm.pricedCart!.totals.subtotal, 50);
      vm.dispose();
    });

    test(
      'مسح باركود: أول تطابق يضاف؛ غير الموجود يترك إشعاراً لا خطأً',
      () async {
        await open();
        final item = await makeItem('أرز بسمتي', price: 60, qty: 5);
        final barcode =
            (await handle.db.rawQuery(
                  'SELECT barcode FROM product WHERE id = ?',
                  [item],
                )).first['barcode']
                as String?;
        final vm = cartVm();
        await vm.load();
        expect(await vm.addByBarcode(barcode!), isTrue);
        expect(vm.state.lines, hasLength(1));
        expect(vm.state.lines.first.productId, item);
        expect(await vm.addByBarcode('0000000000000'), isFalse);
        expect(vm.state.notice, isNotNull);
        expect(vm.state.postError, isNull);
        vm.dispose();
      },
    );
  });

  group('SellCartViewModel — الدفع (FR-02-02/03)', () {
    test('سلة فارغة ترفض الدفع برسالة واضحة', () async {
      await open();
      final vm = cartVm();
      await vm.load();
      final result = await vm.postSale(
        paidCash: 0,
        method: SalePaymentMethod.cash,
      );
      expect(result.isOk, isFalse);
      expect(result.errorOrNull, contains('بنداً واحداً'));
      vm.dispose();
    });

    test(
      'نقدي كامل بلا عميل: INV متسلسلة + مخزون وصندوق + تفريغ السلة',
      () async {
        await open();
        final item = await makeItem('زيت', cost: 60, price: 120, qty: 10);
        final vm = cartVm();
        await vm.load();
        vm.addItemFromInfo(await findInfo(item));
        vm.setQty(0, 2);
        final first = await vm.postSale(
          paidCash: 240,
          method: SalePaymentMethod.cash,
        );
        expect(first.isOk, isTrue, reason: '${first.errorOrNull}');
        final receipt = first.valueOrNull!;
        expect(receipt.invoiceNo, contains('INV-'));
        expect(receipt.totals.grandTotal, 240);
        expect(receipt.changeDue, 0);
        expect(await stockOf(item), 8);
        // السلة فُرغت والإيصال محفوظ للحظة النجاح.
        expect(vm.state.lines, isEmpty);
        expect(vm.state.lastReceipt?.invoiceNo, receipt.invoiceNo);
        // فاتورة ثانية → ترقيم متسلسل.
        vm.addItemFromInfo(await findInfo(item));
        final second = await vm.postSale(
          paidCash: 120,
          method: SalePaymentMethod.cash,
        );
        expect(second.isOk, isTrue);
        final rows = await handle.db.rawQuery(
          "SELECT COUNT(*) AS n FROM cash_tx WHERE tx_type = 'receipt'",
        );
        expect(rows.first['n'], 2);
        vm.dispose();
      },
    );

    test('آجل بعميل نقدي مجهول يُرفض؛ بعميل حقيقي ينجح ويرفع رصيده', () async {
      await open();
      final item = await makeItem('دقيق', price: 80, qty: 10);
      final customer = await makeCustomer('بهاء الدين');
      final vm = cartVm();
      await vm.load();
      vm.addItemFromInfo(await findInfo(item));
      vm.setQty(0, 4); // 320
      final blocked = await vm.postSale(
        paidCash: 0,
        method: SalePaymentMethod.credit,
      );
      expect(blocked.isOk, isFalse);
      expect(blocked.errorOrNull, contains('اختيار عميل'));

      vm.setCustomer(id: customer, name: 'بهاء الدين');
      final ok = await vm.postSale(
        paidCash: 0,
        method: SalePaymentMethod.credit,
      );
      expect(ok.isOk, isTrue, reason: '${ok.errorOrNull}');
      expect(ok.valueOrNull!.remainingCredit, closeTo(320, 0.001));
      expect(
        await customers.balanceInCurrency(customer, baseId),
        closeTo(320, 0.001),
      );
      vm.dispose();
    });

    test(
      'مختلط: جزء نقدي والباقي آجلاً بعميل — الإيصال يفصل الاثنين',
      () async {
        await open();
        final item = await makeItem('معمول', price: 90, qty: 10);
        final customer = await makeCustomer('سومية');
        final vm = cartVm();
        await vm.load();
        vm.addItemFromInfo(await findInfo(item));
        vm.setQty(0, 5); // 450
        vm.setCustomer(id: customer, name: 'سومية');
        final result = await vm.postSale(
          paidCash: 200,
          method: SalePaymentMethod.mixed,
        );
        expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
        final receipt = result.valueOrNull!;
        expect(receipt.payStatus, SalePaymentMethod.mixed);
        expect(receipt.remainingCredit, closeTo(250, 0.001));
        expect(
          await customers.balanceInCurrency(customer, baseId),
          closeTo(250, 0.001),
        );
        vm.dispose();
      },
    );

    test(
      'نقص المخزون: رفض برسالة عربية والسلة لا تُفقد (قابل للتعديل)',
      () async {
        await open();
        final item = await makeItem('جبن', price: 30, qty: 3);
        final vm = cartVm();
        await vm.load();
        vm.addItemFromInfo(await findInfo(item));
        vm.setQty(0, 7); // فوق المتاح (3).
        final result = await vm.postSale(
          paidCash: 210,
          method: SalePaymentMethod.cash,
        );
        expect(result.isOk, isFalse);
        expect(result.errorOrNull, contains('سالب'));
        expect(vm.state.lines, hasLength(1)); // السلة باقية.
        expect(vm.state.postError, isNotNull);
        expect(await stockOf(item), 3); // لا أثر.
        // تعديل الكمية للمتاح ثم إعادة الدفع تنجح.
        vm.setQty(0, 3);
        vm.clearPostError();
        final retry = await vm.postSale(
          paidCash: 90,
          method: SalePaymentMethod.cash,
        );
        expect(retry.isOk, isTrue, reason: '${retry.errorOrNull}');
        vm.dispose();
      },
    );
  });

  group('SellCartViewModel — بوابة سعر الصرف (FR-08-09)', () {
    test('عملة غير الأساس بلا سعر اليوم: بوابة تُفتح والحفظ يُمنع؛'
        ' بعد إدخال السعر ينجح الترحيل به', () async {
      await open();
      final item = await makeItem(
        'ساعة حائط',
        price: 15000,
        qty: 4,
        usdPrice: 30,
      );
      final vm = cartVm();
      await vm.load();
      await vm.setCurrency(usdId);
      expect(vm.state.rateKnown, isFalse);
      expect(vm.state.fxGateRequired, isTrue); // البوابة تطلبت الفتح.

      vm.addItemFromInfo(await findInfo(item, currencyId: usdId));
      vm.setQty(0, 2); // 60 دولاراً.
      final blocked = await vm.postSale(
        paidCash: 60,
        method: SalePaymentMethod.cash,
      );
      expect(blocked.isOk, isFalse);
      expect(blocked.errorOrNull, contains('سعر صرف'));

      // إدخال سعر اليوم من البوابة نفسها.
      final saved = await vm.saveTodayRate(530);
      expect(saved.isOk, isTrue, reason: '${saved.errorOrNull}');
      expect(vm.state.rateKnown, isTrue);
      vm.clearFxGate();
      expect(vm.state.fxGateRequired, isFalse);

      final ok = await vm.postSale(
        paidCash: 60,
        method: SalePaymentMethod.cash,
      );
      expect(ok.isOk, isTrue, reason: '${ok.errorOrNull}');
      expect(ok.valueOrNull!.exchangeRate, 530);
      expect(ok.valueOrNull!.rateIsFallback, isFalse);
      expect(await stockOf(item), 2);
      vm.dispose();
    });
  });

  group('SellCartViewModel — عروض الأسعار (FR-02-11)', () {
    test('حفظ السلة كعرض سعر: QTE بلا حركة مخزون والسلة تبقى؛ تحويل'
        ' لاحق يخصم مرة واحدة ثم يُرفض', () async {
      await open();
      final item = await makeItem('مكنسة', price: 500, qty: 6);
      final customer = await makeCustomer('فهد');
      final vm = cartVm();
      await vm.load();
      vm.addItemFromInfo(await findInfo(item));
      vm.setQty(0, 2); // 1000.
      vm.setCustomer(id: customer, name: 'فهد');
      final saved = await vm.saveAsQuotation();
      expect(saved.isOk, isTrue, reason: '${saved.errorOrNull}');
      expect(saved.valueOrNull!.quotationNo, contains('QTE-'));
      expect(saved.valueOrNull!.status, QuotationStatus.draft);
      // لا حركة مخزون للعرض والسلة بقيت كما هي.
      expect(await stockOf(item), 6);
      expect(vm.state.lines, hasLength(1));

      // التحويل من نموذج تفاصيل العرض (يدفع كاملاً نقداً).
      final detailVm = QuotationDetailViewModel(
        quotationRepo: quotations,
        companyRepo: companies,
        quotationId: saved.valueOrNull!.id,
        initialUserId: userId,
      );
      await detailVm.load();
      expect(detailVm.quotation, isNotNull);
      final converted = await detailVm.convertToInvoice(
        paidCash: 1000,
        paymentMethod: SalePaymentMethod.cash,
      );
      expect(converted.isOk, isTrue, reason: '${converted.errorOrNull}');
      expect(converted.valueOrNull!.totals.grandTotal, closeTo(1000, 0.001));
      expect(await stockOf(item), 4); // خصمت مرة واحدة فقط.
      expect(detailVm.quotation!.status, QuotationStatus.converted);

      // تحويل ثانٍ لنفس العرض يُرفض.
      final again = await detailVm.convertToInvoice(
        paidCash: 1000,
        paymentMethod: SalePaymentMethod.cash,
      );
      expect(again.isOk, isFalse);
      vm.dispose();
    });
  });

  group('QuotationsViewModel — القائمة والتصفية', () {
    test('الحالات: مسودة ← مرسل ← محوّل؛ رقائق التصفية تعمل', () async {
      await open();
      final item = await makeItem('دلو', price: 70, qty: 20);
      final vm = cartVm();
      await vm.load();
      vm.addItemFromInfo(await findInfo(item));
      final q1 = (await vm.saveAsQuotation()).valueOrNull!;
      vm.addItemFromInfo(await findInfo(item));
      final q2 = (await vm.saveAsQuotation()).valueOrNull!;
      vm.dispose();

      final listVm = QuotationsViewModel(quotationRepo: quotations);
      await listVm.load();
      expect(listVm.state.quotations, hasLength(2));

      await listVm.markSent(q1.id, userId: userId);
      await listVm.load();
      expect(
        listVm.state.quotations.firstWhere((q) => q.id == q1.id).status,
        QuotationStatus.sent,
      );
      await listVm.setStatusFilter(QuotationStatus.sent);
      expect(listVm.state.quotations.map((q) => q.id), contains(q1.id));
      expect(listVm.state.quotations.map((q) => q.id), isNot(contains(q2.id)));

      final canceled = await listVm.cancel(q2.id, userId: userId);
      expect(canceled.isOk, isTrue);
      await listVm.setStatusFilter(null);
      expect(
        listVm.state.quotations.firstWhere((q) => q.id == q2.id).status,
        QuotationStatus.rejected, // الإلغاء = حالة rejected بالمخطط.
      );
    });
  });

  group('SalesInvoicesViewModel — فواتير المبيعات', () {
    test('بعد ترحيلتين: قائمة بالعميل والعملة وتفصيل بالبنود', () async {
      await open();
      final item = await makeItem('منظف', price: 45, qty: 30);
      final customer = await makeCustomer('أمل');
      final vm = cartVm();
      await vm.load();
      vm.addItemFromInfo(await findInfo(item));
      vm.setQty(0, 2);
      vm.setCustomer(id: customer, name: 'أمل');
      final receipt = (await vm.postSale(
        paidCash: 90,
        method: SalePaymentMethod.cash,
      )).valueOrNull!;
      vm.dispose();

      final listVm = SalesInvoicesViewModel(saleRepo: sales);
      await listVm.load();
      expect(listVm.state.invoices, hasLength(1));
      final row = listVm.state.invoices.first;
      expect(row.invoiceNo, receipt.invoiceNo);
      expect(row.customerName, 'أمل');
      expect(row.total, closeTo(90, 0.001));

      final detail = await listVm.detail(receipt.invoiceId);
      expect(detail, isNotNull);
      expect(detail!.items, hasLength(1));
      expect(detail.items.first.qty, 2);
      expect(detail.items.first.unitPrice, closeTo(45, 0.001));
      // البحث النصي بالاسم (التصفية على visible).
      listVm.setFilter('أمل');
      expect(listVm.state.visible, hasLength(1));
      listVm.setFilter('لا شئ');
      expect(listVm.state.visible, isEmpty);
      expect(listVm.state.invoices, hasLength(1)); // الأصل لم يُمس.
    });
  });
}
