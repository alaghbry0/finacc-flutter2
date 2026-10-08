/// اختبارات محرك ترحيل فاتورة البيع — FR-02-06 / قواعد 5.4-3..5.4-7 /
/// FR-08-09 / AC-05 / AC-09-أ / AC-13 / AC-20 (الجزء المخزوني).
///
/// يغطي: الترحيل الكامل (كل الجداول)، تسلسل INV الذرّي، الخصومات
/// الموزعة، النقدي/الآجل/المختلط والباقي، FEFO عبر دفعتين، WAC
/// (line_cost لحظة البيع بلا تغيير لاحق)، منع السالب المخزوني والذرّية
/// الكاملة عند الرفض، حد الائتمان، سياسة سعر الصرف المفقود، فصل
/// العملات، الأصناف الخدمية، والقراءات.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/batch_repository.dart';
import 'package:mobile_app/data/repositories/customer_repository.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/sale_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/domain/core/result.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:mobile_app/domain/models/sale.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;
  late SaleRepository sales;
  late ItemRepository items;
  late BatchRepository batches;
  late CustomerRepository customers;
  late ExchangeRateRepository rates;
  late SettingsRepository settings;
  late int warehouseId;
  late int userId;
  late int baseCurrencyId;
  late int sarId;
  late int defaultCashboxId;
  final at = DateTime.utc(2026, 10, 6, 12);

  setUp(() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    sales = SaleRepository(handle.db);
    items = ItemRepository(handle.db);
    batches = BatchRepository(handle.db);
    customers = CustomerRepository(handle.db);
    rates = ExchangeRateRepository(handle.db);
    settings = SettingsRepository(handle.db);
    warehouseId =
        (await handle.db.rawQuery('SELECT id FROM warehouse LIMIT 1'))
                .first['id']
            as int;
    userId =
        (await handle.db.rawQuery('SELECT id FROM app_user LIMIT 1'))
                .first['id']
            as int;
    baseCurrencyId =
        (await handle.db.rawQuery('SELECT id FROM currency WHERE is_base = 1'))
                .first['id']
            as int;
    sarId =
        (await handle.db.rawQuery("SELECT id FROM currency WHERE code = 'SAR'"))
                .first['id']
            as int;
    defaultCashboxId =
        (await handle.db.rawQuery(
              'SELECT id FROM cashbox WHERE is_default = 1',
            )).first['id']
            as int;
  });

  tearDown(() async {
    await handle.close();
  });

  // ── بذور مساعدة ──────────────────────────────────────────────────

  /// ينشئ صنفاً مخزنياً/خدمياً ويعيد معرّفه (سعر تجزئة بعملة الأساس).
  Future<int> makeProduct(
    String name, {
    double cost = 0,
    double price = 0,
    double qty = 0,
    bool tracked = false,
    bool service = false,
  }) async {
    final result = await items.createItem(
      ItemDraft(
        name: name,
        costPrice: cost,
        openingQty: service ? 0 : qty,
        isService: service,
        trackBatches: tracked,
        prices: [ItemPrice(currencyId: baseCurrencyId, price: price)],
      ),
      warehouseId: warehouseId,
      userId: userId,
      now: at,
    );
    return result.valueOrNull!;
  }

  Future<int> makeCustomer(String name, {double? creditLimit}) async {
    final result = await customers.createCustomer(
      CustomerDraft(name: name, creditLimit: creditLimit),
      userId: userId,
      now: at,
    );
    return result.valueOrNull!;
  }

  Future<Map<String, Object?>> row(String table, {String? where}) async {
    final rows = await handle.db.query(table, where: where, limit: 1);
    return rows.first;
  }

  Future<int> count(String table, {String? where}) async {
    final rows = await handle.db.rawQuery(
      'SELECT COUNT(*) AS n FROM $table${where == null ? '' : ' WHERE $where'}',
    );
    return rows.first['n'] as int;
  }

  /// مسودة نقدي جاهزة (السعر بعملة الأساس افتراضياً).
  SaleDraft cashDraft(
    List<CartLine> lines, {
    required double paidCash,
    int? customerId,
    int? currencyId,
  }) => SaleDraft(
    customerId: customerId,
    currencyId: currencyId ?? baseCurrencyId,
    lines: lines,
    paidCash: paidCash,
    paymentMethod: SalePaymentMethod.cash,
    warehouseId: warehouseId,
    issuedAt: at,
  );

  // ── الترحيل الكامل ────────────────────────────────────────────────

  group('postSale — فاتورة نقدي بعملة الأساس (AC-09-أ)', () {
    test(
      'كل الجداول مكتوبة صحيحة: invoice/invoice_item/stock/cash/audit',
      () async {
        final pen = await makeProduct('قلم', cost: 10, price: 25, qty: 50);
        final result = await sales.postSale(
          cashDraft([
            CartLine(productId: pen, qty: 4, unitPrice: 25),
          ], paidCash: 100),
          userId: userId,
          now: at,
        );
        expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
        final receipt = result.valueOrNull!;

        expect(receipt.invoiceNo, 'INV-2026-00001');
        expect(receipt.totals.subtotal, 100);
        expect(receipt.totals.grandTotal, 100);
        expect(receipt.changeDue, 0);
        expect(receipt.remainingCredit, 0);
        expect(receipt.exchangeRate, 1);
        expect(receipt.rateIsFallback, isFalse);

        final invoice = await row('invoice');
        expect(invoice['invoice_no'], 'INV-2026-00001');
        expect(invoice['doc_type'], 'sale');
        expect(invoice['pay_status'], 'cash');
        expect(invoice['status'], 'completed');
        expect(invoice['issued_at'], at.toUtc().toIso8601String());
        expect(invoice['customer_id'], isNull);
        expect(invoice['quotation_id'], isNull);
        expect(invoice['warehouse_id'], warehouseId);
        expect(invoice['cashbox_id'], defaultCashboxId);
        expect(invoice['currency_id'], baseCurrencyId);
        expect(invoice['exchange_rate'], 1);
        expect(invoice['rate_is_fallback'], 0);
        expect(invoice['subtotal'], 100);
        expect(invoice['discount_amount'], 0);
        expect(invoice['tax_rate'], 0);
        expect(invoice['tax_amount'], 0);
        expect(invoice['total'], 100);
        expect(invoice['total_base'], 100);
        expect(invoice['paid_amount'], 100);
        expect(invoice['due_amount'], 0);
        expect(invoice['cost_total'], 40); // 4 × WAC 10
        expect(invoice['created_by'], userId);

        final item = await row('invoice_item');
        expect(item['invoice_id'], receipt.invoiceId);
        expect(item['product_id'], pen);
        expect(item['line_desc'], 'قلم');
        expect(item['qty'], 4);
        expect(item['unit_price'], 25);
        expect(item['discount_percent'], 0);
        expect(item['discount_amount'], 0);
        expect(item['line_total'], 100);
        expect(item['line_cost'], 40); // WAC لحظة البيع (5.4-3)
        expect(item['batch_id'], isNull);

        expect((await row('stock_level'))['qty'], 46);

        final movement = await row(
          'stock_movement',
          where: "product_id = $pen AND movement_type = 'sale'",
        );
        expect(movement['movement_type'], 'sale');
        expect((movement['qty'] as num).toDouble(), -4); // الخروج سالب.
        expect(movement['unit_cost'], 10);
        expect(movement['ref_type'], 'invoice');
        expect(movement['ref_id'], receipt.invoiceId);
        expect(movement['warehouse_id'], warehouseId);

        final cash = await row('cash_tx');
        expect(cash['tx_type'], 'receipt');
        expect(cash['cashbox_id'], defaultCashboxId);
        expect(cash['currency_id'], baseCurrencyId);
        expect(cash['amount'], 100);
        expect(cash['exchange_rate'], 1);
        expect(cash['ref_type'], 'invoice');
        expect(cash['ref_id'], receipt.invoiceId);
        expect(cash['customer_id'], isNull); // لا خصم مزدوج من رصيد العميل.
        expect(cash['is_voided'], 0);

        final allocation = await row('payment_allocation');
        expect(allocation['invoice_id'], receipt.invoiceId);
        expect(allocation['cash_tx_id'], cash['id']);
        expect(allocation['allocated_amount'], 100);

        final audit = await row('audit_log', where: "action = 'sale_post'");
        expect(audit['entity'], 'invoice');
        expect(audit['entity_id'], receipt.invoiceId);
        expect(audit['details'] as String, contains('INV-2026-00001'));
      },
    );

    test('تسلسل INV ذرّي: الفاتورة الثانية INV-2026-00002', () async {
      final pen = await makeProduct('قلم', cost: 1, price: 5, qty: 100);
      final first = await sales.postSale(
        cashDraft([
          CartLine(productId: pen, qty: 1, unitPrice: 5),
        ], paidCash: 5),
        userId: userId,
        now: at,
      );
      final second = await sales.postSale(
        cashDraft([
          CartLine(productId: pen, qty: 2, unitPrice: 5),
        ], paidCash: 10),
        userId: userId,
        now: at,
      );
      expect(first.valueOrNull!.invoiceNo, 'INV-2026-00001');
      expect(second.valueOrNull!.invoiceNo, 'INV-2026-00002');
    });

    test(
      'انحدار الموجة 4: متتبع برصيد افتتاحي يُباع فوراً (كان يُرفض بمتاح = 0)',
      () async {
        // العميل أنشأ صنفاً متتبعاً بكمية افتتاحية كبيرة ثم حاول البيع —
        // كان الرفض «المتاح 0» لأن الرصيد لم يُدفَّع. الإصلاح: دفعة افتتاحية.
        final milk = await makeProduct(
          'لبن 1ل',
          cost: 900,
          price: 1100,
          qty: 50,
          tracked: true,
        );

        final result = await sales.postSale(
          cashDraft([
            CartLine(productId: milk, qty: 5, unitPrice: 1100),
          ], paidCash: 5500),
          userId: userId,
          now: at,
        );
        expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

        // الدفعة الافتتاحية استُهلكت 5 والدفتان متطابقتان.
        final batchRow = await row('batch');
        expect((batchRow['qty'] as num).toDouble(), 45);
        expect(batchRow['expiry_date'], '9999-12-31');
        expect((await row('stock_level'))['qty'], 45);

        // السطر يحمل الدفعة المستهلكة (batch_id مرتبط).
        final item = await row('invoice_item');
        expect(item['batch_id'], batchRow['id']);
        expect(item['notes'] as String?, contains('افتتاحي-'));
      },
    );

    test('خصومات: سطر نسبة + سطر مبلغ + رأس 10% موزعة pro-rata', () async {
      final a = await makeProduct('أ', cost: 0, price: 100, qty: 10);
      final b = await makeProduct('ب', cost: 0, price: 100, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [
            CartLine(
              productId: a,
              qty: 2,
              unitPrice: 100,
              lineDiscountType: SaleDiscountType.percent,
              lineDiscountValue: 10,
            ),
            CartLine(
              productId: b,
              qty: 1,
              unitPrice: 100,
              lineDiscountType: SaleDiscountType.amount,
              lineDiscountValue: 10,
            ),
          ],
          invoiceDiscountType: SaleDiscountType.percent,
          invoiceDiscountValue: 10,
          paidCash: 243,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

      final invoice = await row('invoice');
      expect(invoice['subtotal'], 300);
      expect(invoice['discount_amount'], 57); // 30 أسطر + 27 رأس.
      expect(invoice['total'], 243);
      expect(invoice['paid_amount'], 243);

      final itemRows = await handle.db.query('invoice_item', orderBy: 'id ASC');
      // السطر أ: خصم فعلي 20 + 18 = 38 وصافي 162؛ السطر ب: 10 + 9 = 19 و81.
      expect(itemRows[0]['discount_amount'], 38);
      expect(itemRows[0]['discount_percent'], 10);
      expect(itemRows[0]['line_total'], 162);
      expect(itemRows[1]['discount_amount'], 19);
      expect(itemRows[1]['discount_percent'], 0);
      expect(itemRows[1]['line_total'], 81);
      // Σ البنود = الرأس بالضبط (لا انزياح سنت).
      final sum = itemRows.fold<double>(
        0,
        (s, r) => s + (r['line_total'] as num).toDouble(),
      );
      expect(sum, 243);
    });
  });

  // ── أنواع الدفع ──────────────────────────────────────────────────

  group('أنواع الدفع (FR-02-03) والباقي', () {
    test('مختلط: جزء نقدي 40 من 100 + آجل 60 بعملة الفاتورة', () async {
      final customer = await makeCustomer('محمد');
      final pen = await makeProduct('قلم', cost: 0, price: 100, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          customerId: customer,
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 100)],
          paidCash: 40,
          paymentMethod: SalePaymentMethod.mixed,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      final receipt = result.valueOrNull!;
      expect(receipt.payStatus.code, 'mixed');
      expect(receipt.remainingCredit, 60);

      final invoice = await row('invoice');
      expect(invoice['pay_status'], 'mixed');
      expect(invoice['paid_amount'], 40);
      expect(invoice['due_amount'], 60);

      final cash = await row('cash_tx');
      expect(cash['amount'], 40);
      expect(cash['customer_id'], isNull);
      expect((await row('payment_allocation'))['allocated_amount'], 40);

      // رصيد العميل = الآجل فقط (لا خصم مزدوج) — AC-01/FR-03-02.
      expect(await customers.balanceInCurrency(customer, baseCurrencyId), 60);
    });

    test('آجل كامل: لا سند ولا تخصيص، والدين كامل بعملة الفاتورة', () async {
      final customer = await makeCustomer('أحمد');
      final pen = await makeProduct('قلم', cost: 0, price: 100, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          customerId: customer,
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 100)],
          paidCash: 0,
          paymentMethod: SalePaymentMethod.credit,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

      expect(await count('cash_tx'), 0);
      expect(await count('payment_allocation'), 0);
      expect((await row('invoice'))['due_amount'], 100);
      expect(await customers.balanceInCurrency(customer, baseCurrencyId), 100);
    });

    test('نقدي زائد: الباقي 20 يُعاد ولا يدخل الصندوق ولا الدين', () async {
      final pen = await makeProduct('قلم', cost: 0, price: 100, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 100)],
          paidCash: 120,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      final receipt = result.valueOrNull!;
      expect(receipt.changeDue, 20);
      expect(receipt.remainingCredit, 0);

      final invoice = await row('invoice');
      expect(invoice['pay_status'], 'cash');
      expect(invoice['paid_amount'], 100); // CHECK(paid <= total) محفوظ.
      expect(invoice['due_amount'], 0);
      // الصندوق استلم الصافي فقط — الباقي بيد الكاشير.
      expect((await row('cash_tx'))['amount'], 100);
    });

    test('تعارض التعلان مع المبالغ → رفض بلا أي كتابة', () async {
      final pen = await makeProduct('قلم', cost: 0, price: 100, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 100)],
          paidCash: 40,
          paymentMethod: SalePaymentMethod.cash, // يجب مختلط.
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('تسديد الصافي كاملاً'));
      expect(await count('invoice'), 0);
      expect(await count('cash_tx'), 0);
    });
  });

  // ── FEFO / الدفعات ────────────────────────────────────────────────

  group('FEFO (AC-05)', () {
    test('بيع 15 عبر دفعتين: الأقرب انتهاءً تُستهلك أولاً بالكامل', () async {
      final cheese = await makeProduct(
        'جبن',
        cost: 100,
        price: 150,
        qty: 20,
        tracked: true,
      );
      final nearId = (await batches.createBatch(
        productId: cheese,
        warehouseId: warehouseId,
        batchNumber: 'قريبة',
        expiryDate: DateTime(2026, 11, 1),
        costPrice: 100,
        qty: 10,
        now: at,
      )).valueOrNull!;
      final farId = (await batches.createBatch(
        productId: cheese,
        warehouseId: warehouseId,
        batchNumber: 'بعيدة',
        expiryDate: DateTime(2027, 5, 1),
        costPrice: 120,
        qty: 10,
        now: at,
      )).valueOrNull!;

      final result = await sales.postSale(
        cashDraft([
          CartLine(productId: cheese, qty: 15, unitPrice: 150),
        ], paidCash: 2250),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

      // الدفعات: القريبة صفر والبعيدة 5.
      final batchRows = {
        for (final r in await handle.db.query('batch', columns: ['id', 'qty']))
          r['id'] as int: (r['qty'] as num).toDouble(),
      };
      expect(batchRows[nearId], 0);
      expect(batchRows[farId], 5);

      // سطر الفاتورة: batch_id = الدفعة الأولى (FEFO) وملخص الدفعات
      // في الملاحظة، وline_cost بالـ WAC لا بتكلفة الدفعة.
      final item = await row('invoice_item');
      expect(item['batch_id'], nearId);
      expect(item['line_cost'], 1500); // 15 × WAC 100.
      expect(item['notes'] as String, contains('قريبة'));
      expect(item['notes'] as String, contains('بعيدة'));

      // حركة مخزون مستقلة لكل دفعة (سالبان راجعان للفاتورة).
      final movements = await handle.db.query(
        'stock_movement',
        where: "product_id = ? AND movement_type = 'sale'",
        whereArgs: [cheese],
        orderBy: 'id ASC',
      );
      expect(movements, hasLength(2));
      expect((movements[0]['qty'] as num).toDouble(), -10);
      expect(movements[0]['notes'] as String, contains('قريبة'));
      expect((movements[1]['qty'] as num).toDouble(), -5);
      expect(movements[1]['notes'] as String, contains('بعيدة'));
      for (final m in movements) {
        expect(m['ref_type'], 'invoice');
        expect(m['ref_id'], result.valueOrNull!.invoiceId);
        expect(m['unit_cost'], 100); // WAC.
      }

      expect((await row('stock_level'))['qty'], 5);
    });

    test('دفعة منتهية تُستبعد من المتاح → الرفض يسمّي الصنف والمتاح', () async {
      // شكل بيانات واقعي: رصيد الصنف المتتبع من دفعاته (لا افتتاحية) —
      // منتهية 8 + صالحة 4 والدفتر 12 يطابقهما. المتاح للبيع = 4 فقط.
      final drug = await makeProduct(
        'دواء',
        cost: 0,
        price: 10,
        qty: 0,
        tracked: true,
      );
      await batches.createBatch(
        productId: drug,
        warehouseId: warehouseId,
        batchNumber: 'منتهية',
        expiryDate: DateTime(2026, 10, 4), // قبل يوم الإصدار بيومين.
        costPrice: 0,
        qty: 8,
        now: at,
      );
      await batches.createBatch(
        productId: drug,
        warehouseId: warehouseId,
        batchNumber: 'صالحة',
        expiryDate: DateTime(2027, 1, 1),
        costPrice: 0,
        qty: 4,
        now: at,
      );
      await handle.db.insert('stock_level', {
        'product_id': drug,
        'warehouse_id': warehouseId,
        'qty': 12,
      });

      final result = await sales.postSale(
        cashDraft([
          CartLine(productId: drug, qty: 5, unitPrice: 10),
        ], paidCash: 50),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('دواء'));
      expect(result.errorOrNull, contains('المتاح 4'));
      expect(await count('invoice'), 0);
      expect((await row('stock_level'))['qty'], 12);
    });

    test(
      'تنافر الدفاتر (دفعات تكفي والدفتر العام لا يكفي) → رفض وتراجع',
      () async {
        // stock_level = 12 (افتتاحي) بينما الدفعات 20 — الحارس داخل المعاملة
        // يرفض ويرجع كل شيء (الدفعات لم تُمسّ).
        final cheese = await makeProduct(
          'جبن متنافر',
          cost: 0,
          price: 10,
          qty: 12,
          tracked: true,
        );
        await batches.createBatch(
          productId: cheese,
          warehouseId: warehouseId,
          batchNumber: 'أ',
          expiryDate: DateTime(2026, 12, 1),
          costPrice: 0,
          qty: 10,
          now: at,
        );
        await batches.createBatch(
          productId: cheese,
          warehouseId: warehouseId,
          batchNumber: 'ب',
          expiryDate: DateTime(2027, 6, 1),
          costPrice: 0,
          qty: 10,
          now: at,
        );

        final result = await sales.postSale(
          cashDraft([
            CartLine(productId: cheese, qty: 15, unitPrice: 10),
          ], paidCash: 150),
          userId: userId,
          now: at,
        );
        expect(result.isErr, isTrue);
        expect(await count('invoice'), 0);
        final batchQty = {
          for (final r in await handle.db.query(
            'batch',
            columns: ['batch_number', 'qty'],
          ))
            r['batch_number']: (r['qty'] as num).toDouble(),
        };
        expect(batchQty['أ'], 10); // لم تُخصم — التراجع الكامل.
        expect(batchQty['ب'], 10);
        expect((await row('stock_level'))['qty'], 12);
      },
    );
  });

  // ── WAC ───────────────────────────────────────────────────────────

  group('WAC (قاعدة 5.4-3)', () {
    test('line_cost = WAC لحظة البيع ولا يتغير بعد البيع', () async {
      final pen = await makeProduct('قلم', cost: 10, price: 25, qty: 10);
      await sales.postSale(
        cashDraft([
          CartLine(productId: pen, qty: 4, unitPrice: 25),
        ], paidCash: 100),
        userId: userId,
        now: at,
      );
      expect((await row('invoice_item'))['line_cost'], 40);
      expect((await row('invoice'))['cost_total'], 40);
      // البيع لا يغيّر التكلفة المرجّحة إطلاقاً.
      expect((await row('product'))['cost_price'], 10);

      // تغيير التكلفة لاحقاً (شراء مستقبلي مثلاً) لا يمس السطر المؤرشف.
      await handle.db.update(
        'product',
        {'cost_price': 20},
        where: 'id = ?',
        whereArgs: [pen],
      );
      expect((await row('invoice_item'))['line_cost'], 40);
    });
  });

  // ── منع السالب والذرّية ───────────────────────────────────────────

  group('منع السالب المخزوني (5.4-5 / AC-20)', () {
    test('بيع أكثر من المتاح → رفض باسم الصنف والكمية ولا أثر جزئي', () async {
      final pen = await makeProduct('قلم', cost: 0, price: 10, qty: 5);
      final result = await sales.postSale(
        cashDraft([
          CartLine(productId: pen, qty: 10, unitPrice: 10),
        ], paidCash: 100),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('قلم'));
      expect(result.errorOrNull, contains('المتاح 5'));
      // الذرّية: لا فاتورة ولا حركة بيع ولا صندوق ولا تدقيق
      // (حركة الافتتاحي البذرية تبقى — ليست من البيع).
      expect(await count('invoice'), 0);
      expect(await count('invoice_item'), 0);
      expect(await count('stock_movement', where: "movement_type = 'sale'"), 0);
      expect(await count('cash_tx'), 0);
      expect(await count('payment_allocation'), 0);
      expect(await count('audit_log', where: "action = 'sale_post'"), 0);
      expect((await row('stock_level'))['qty'], 5);
    });

    test('فشل سطر متأخر يرجع أسطراً سابقة (معاملة واحدة)', () async {
      final a = await makeProduct('صنف أ', cost: 0, price: 10, qty: 5);
      final b = await makeProduct('صنف ب', cost: 0, price: 10, qty: 3);
      final result = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [
            CartLine(productId: a, qty: 2, unitPrice: 10), // يكفي.
            CartLine(productId: b, qty: 5, unitPrice: 10), // لا يكفي.
          ],
          paidCash: 70,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('صنف ب'));
      expect(await count('invoice'), 0);
      expect(await count('stock_movement', where: "movement_type = 'sale'"), 0);
      final levels = {
        for (final r in await handle.db.query('stock_level'))
          r['product_id'] as int: (r['qty'] as num).toDouble(),
      };
      expect(levels[a], 5); // لم يُخصم رغم أنه كان سيكفي.
      expect(levels[b], 3);
    });

    test('أسطر مكررة لنفس الصنف تُجمع في فحص التوفر', () async {
      final pen = await makeProduct('قلم', cost: 0, price: 10, qty: 5);
      final result = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [
            CartLine(productId: pen, qty: 3, unitPrice: 10),
            CartLine(productId: pen, qty: 3, unitPrice: 10), // 6 > 5.
          ],
          paidCash: 60,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('المتاح 5'));
      expect((await row('stock_level'))['qty'], 5);
    });
  });

  // ── حد الائتمان ──────────────────────────────────────────────────
  // 17-c: السلوك من إعداد parties.credit_limit_action — المستودع يحرس
  // 'block' حصراً (رفض نهائي)؛ 'warn' (الافتراضي) حواره في PaymentSheet
  // («متابعة على أي حال») فلا يمنع الترحيل هنا.

  group('حد الائتمان (FR-03-05)', () {
    test('آجل يتجاوز الحد بسلوك block → رفض ولا فاتورة', () async {
      await settings.set('parties.credit_limit_action', 'block');
      final customer = await makeCustomer('سالم', creditLimit: 100);
      final pen = await makeProduct('قلم', cost: 0, price: 150, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          customerId: customer,
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 150)],
          paidCash: 0,
          paymentMethod: SalePaymentMethod.credit,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('حد الائتمان'));
      expect(await count('invoice'), 0);
      expect(await customers.balanceInCurrency(customer, baseCurrencyId), 0);
    });

    test('بلا حد (null) → ينجح آجلاً كاملاً', () async {
      final customer = await makeCustomer('بلا حد');
      final pen = await makeProduct('قلم', cost: 0, price: 150, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          customerId: customer,
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 150)],
          paidCash: 0,
          paymentMethod: SalePaymentMethod.credit,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
    });

    test('حد 0 بسلوك block → أي آجل يُرفض، والنقدي ينجح', () async {
      await settings.set('parties.credit_limit_action', 'block');
      final customer = await makeCustomer('ممنوع آجلاً', creditLimit: 0);
      final pen = await makeProduct('قلم', cost: 0, price: 50, qty: 10);
      final credit = await sales.postSale(
        SaleDraft(
          customerId: customer,
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 50)],
          paidCash: 0,
          paymentMethod: SalePaymentMethod.credit,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(credit.errorOrNull, contains('حد الائتمان'));

      final cash = await sales.postSale(
        SaleDraft(
          customerId: customer,
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 50)],
          paidCash: 50,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(cash.isOk, isTrue, reason: '${cash.errorOrNull}');
    });

    test('الرصيد القائم يُحتسب: آجلان متتاليان ضد حد واحد (block)', () async {
      await settings.set('parties.credit_limit_action', 'block');
      final customer = await makeCustomer('متراكم', creditLimit: 100);
      final pen = await makeProduct('قلم', cost: 0, price: 60, qty: 10);
      Future<Result<SalePostedReceipt, String>> creditSale() => sales.postSale(
        SaleDraft(
          customerId: customer,
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 60)],
          paidCash: 0,
          paymentMethod: SalePaymentMethod.credit,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect((await creditSale()).isOk, isTrue); // 60 ≤ 100.
      expect((await creditSale()).errorOrNull, contains('حد الائتمان')); // 110.
    });

    test('مختلط يُحتسب جزؤه الآجل فقط ضد الحد', () async {
      final customer = await makeCustomer('مختلط', creditLimit: 100);
      final pen = await makeProduct('قلم', cost: 0, price: 150, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          customerId: customer,
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 150)],
          paidCash: 120, // الآجل 30 فقط.
          paymentMethod: SalePaymentMethod.mixed,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      expect(await customers.balanceInCurrency(customer, baseCurrencyId), 30);
    });

    test(
      '17-c: بسلوك warn (الافتراضي) → التجاوز يمرّ (الحوار في الواجهة)',
      () async {
        // الإعداد غير مضبوط → الافتراضي warn: المستودع لا يمنع؛ التحذير
        // مسؤولية PaymentSheet (حوار «متابعة على أي حال») — FR-03-05.
        final customer = await makeCustomer('مُتَحَدّي الحد', creditLimit: 100);
        final pen = await makeProduct('قلم', cost: 0, price: 150, qty: 10);
        final result = await sales.postSale(
          SaleDraft(
            customerId: customer,
            currencyId: baseCurrencyId,
            lines: [CartLine(productId: pen, qty: 1, unitPrice: 150)],
            paidCash: 0,
            paymentMethod: SalePaymentMethod.credit,
            warehouseId: warehouseId,
            issuedAt: at,
          ),
          userId: userId,
          now: at,
        );
        expect(
          result.isOk,
          isTrue,
          reason: 'warn لا يمنع الترحيل: ${result.errorOrNull}',
        );
        expect(
          await customers.balanceInCurrency(customer, baseCurrencyId),
          150,
        );
      },
    );
  });

  // ── سياسة سعر الصرف ──────────────────────────────────────────────

  group('سياسة سعر الصرف المفقود (FR-08-09 / AC-13)', () {
    test('عملة غير أساس بلا سعر اليوم وبلا fallback → منع الحفظ', () async {
      final pen = await makeProduct('قلم', cost: 0, price: 100, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          currencyId: sarId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 100)],
          paidCash: 100,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('سعر صرف'));
      expect(result.errorOrNull, contains('SAR'));
      expect(await count('invoice'), 0);
      // لا مسار يحفظ بسعر 1 لعملة غير أساس (AC-13).
    });

    test('مع fx.fallback=last_known → آخر سعر + rate_is_fallback=1', () async {
      await settings.set('fx.fallback', 'last_known');
      await rates.setRate(
        currencyId: sarId,
        date: DateTime(2026, 10, 1),
        rate: 530,
        userId: userId,
        now: at,
      );
      final pen = await makeProduct('قلم', cost: 0, price: 100, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          currencyId: sarId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 100)],
          paidCash: 100,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      final receipt = result.valueOrNull!;
      expect(receipt.exchangeRate, 530);
      expect(receipt.rateIsFallback, isTrue); // شارة FR-02-20.

      final invoice = await row('invoice');
      expect(invoice['exchange_rate'], 530);
      expect(invoice['rate_is_fallback'], 1);
      expect(invoice['total_base'], 53000); // 100 SAR × 530.
    });

    test('fallback مفعّل بلا أي سعر تاريخي → رفض', () async {
      await settings.set('fx.fallback', 'last_known');
      final pen = await makeProduct('قلم', cost: 0, price: 100, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          currencyId: sarId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 100)],
          paidCash: 100,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('أي سعر صرف معروف'));
    });

    test('سعر اليوم موجود → Snapshot بلا شارة، والعملة الأساسية 1', () async {
      await rates.setRate(
        currencyId: sarId,
        date: at,
        rate: 560,
        userId: userId,
        now: at,
      );
      final pen = await makeProduct('قلم', cost: 0, price: 100, qty: 20);
      final sar = await sales.postSale(
        SaleDraft(
          currencyId: sarId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 100)],
          paidCash: 100,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(sar.valueOrNull!.exchangeRate, 560);
      expect(sar.valueOrNull!.rateIsFallback, isFalse);

      final yer = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 100)],
          paidCash: 100,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(yer.valueOrNull!.exchangeRate, 1);
      expect(yer.valueOrNull!.rateIsFallback, isFalse);
      // فاتورة SAR: total_base = 100 × 560؛ وفاتورة الأساس: 1:1.
      final sarInvoice = await handle.db.query(
        'invoice',
        where: 'id = ?',
        whereArgs: [sar.valueOrNull!.invoiceId],
      );
      expect(sarInvoice.first['total_base'], 56000);
      final yerInvoice = await handle.db.query(
        'invoice',
        where: 'id = ?',
        whereArgs: [yer.valueOrNull!.invoiceId],
      );
      expect(yerInvoice.first['total_base'], 100);
    });

    test('فصل العملات: الفاتورة والسند والتخصيص كلها بعملة الفاتورة', () async {
      await rates.setRate(
        currencyId: sarId,
        date: at,
        rate: 530,
        userId: userId,
        now: at,
      );
      final customer = await makeCustomer('خالد');
      final pen = await makeProduct('قلم', cost: 0, price: 100, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          customerId: customer,
          currencyId: sarId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 100)],
          paidCash: 40,
          paymentMethod: SalePaymentMethod.mixed,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

      final invoice = await row('invoice');
      expect(invoice['currency_id'], sarId);
      expect(invoice['total'], 100); // بسعر وحدة العملة نفسها.
      expect(invoice['total_base'], 53000);

      final cash = await row('cash_tx');
      expect(cash['currency_id'], sarId);
      expect(cash['amount'], 40); // 40 SAR لا YER.
      expect(cash['exchange_rate'], 530);

      expect((await row('payment_allocation'))['allocated_amount'], 40);

      // الرصيد بعملة الفاتورة حصراً (FR-08-11): 60 SAR و0 YER.
      expect(await customers.balanceInCurrency(customer, sarId), 60);
      expect(await customers.balanceInCurrency(customer, baseCurrencyId), 0);
    });
  });

  // ── الأصناف الخدمية ──────────────────────────────────────────────

  group('الأصناف الخدمية', () {
    test('تُباع بلا مخزون وتكلفتها صفر', () async {
      final delivery = await makeProduct('توصيل', price: 50, service: true);
      final result = await sales.postSale(
        cashDraft([
          CartLine(productId: delivery, qty: 3, unitPrice: 50),
        ], paidCash: 150),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

      final item = await row('invoice_item');
      expect(item['qty'], 3);
      expect(item['line_cost'], 0);
      expect((await row('invoice'))['cost_total'], 0);
      expect(await count('stock_level'), 0);
      expect(await count('stock_movement'), 0);
    });

    test('سلة مختلطة: خدمي + مخزني — الخصم للمخزني فقط', () async {
      final delivery = await makeProduct('توصيل', price: 50, service: true);
      final pen = await makeProduct('قلم', cost: 10, price: 25, qty: 10);
      final result = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [
            CartLine(productId: delivery, qty: 1, unitPrice: 50),
            CartLine(productId: pen, qty: 2, unitPrice: 25),
          ],
          paidCash: 100,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

      expect(await count('stock_level'), 1); // القلم فقط.
      expect((await row('stock_level'))['qty'], 8);
      expect(await count('stock_movement', where: "movement_type = 'sale'"), 1);
      expect((await row('invoice'))['cost_total'], 20);
      expect(await count('invoice_item'), 2);
    });
  });

  // ── رفض الإدخالات المعيبة ────────────────────────────────────────

  group('رفض المدخلات المعيبة', () {
    test('عملة/صنف/عميل غير موجودين + صنف مؤرشف + بلا صندوق افتراضي', () async {
      final pen = await makeProduct('قلم', cost: 0, price: 10, qty: 10);

      final badCurrency = await sales.postSale(
        SaleDraft(
          currencyId: 999,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 10)],
          paidCash: 10,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(badCurrency.errorOrNull, contains('العملة'));

      final badProduct = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: 9999, qty: 1, unitPrice: 10)],
          paidCash: 10,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(badProduct.errorOrNull, contains('الصنف'));

      final badCustomer = await sales.postSale(
        SaleDraft(
          customerId: 999,
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 10)],
          paidCash: 0,
          paymentMethod: SalePaymentMethod.credit,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(badCustomer.errorOrNull, contains('العميل'));

      final archived = await makeProduct('مؤرشف', cost: 0, price: 10, qty: 10);
      await items.archiveItem(archived, userId: userId, now: at);
      final archivedSale = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: archived, qty: 1, unitPrice: 10)],
          paidCash: 10,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(archivedSale.errorOrNull, contains('مؤرشف'));

      await handle.db.update('cashbox', {'is_default': 0});
      final noBox = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 10)],
          paidCash: 10,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(noBox.errorOrNull, contains('صندوق'));
    });

    test('سلة فارغة وخصومات معيبة تُرفض نقياً', () async {
      final empty = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: const [],
          paidCash: 0,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(empty.errorOrNull, contains('بنداً واحداً'));

      final pen = await makeProduct('قلم', cost: 0, price: 10, qty: 10);
      final negative = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [
            CartLine(
              productId: pen,
              qty: 1,
              unitPrice: 10,
              lineDiscountValue: -5,
            ),
          ],
          paidCash: 10,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(negative.errorOrNull, contains('سالباً'));
    });
  });

  // ── القراءات ─────────────────────────────────────────────────────

  group('القراءات (invoiceDetail / recentSales / salesTotals)', () {
    test('تفاصيل فاتورة + آخر المبيعات + إجماليات فترة', () async {
      final customer = await makeCustomer('نور');
      final pen = await makeProduct('قلم', cost: 10, price: 25, qty: 50);
      final book = await makeProduct('دفتر', cost: 15, price: 40, qty: 50);

      final first = await sales.postSale(
        SaleDraft(
          customerId: customer,
          currencyId: baseCurrencyId,
          lines: [
            CartLine(productId: pen, qty: 2, unitPrice: 25),
            CartLine(productId: book, qty: 1, unitPrice: 40),
          ],
          paidCash: 90,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      final second = await sales.postSale(
        SaleDraft(
          currencyId: baseCurrencyId,
          lines: [CartLine(productId: pen, qty: 1, unitPrice: 25)],
          paidCash: 25,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at.add(const Duration(hours: 2)),
        ),
        userId: userId,
        now: at,
      );
      expect(first.isOk && second.isOk, isTrue);

      final detail = await sales.invoiceDetail(first.valueOrNull!.invoiceId);
      expect(detail, isNotNull);
      expect(detail!.customerName, 'نور');
      expect(detail.currencyCode, 'YER');
      expect(detail.invoice.invoiceNo, 'INV-2026-00001');
      expect(detail.items, hasLength(2));
      expect(detail.items.first.lineDesc, 'قلم');
      expect(detail.items.first.lineCost, 20);

      expect(await sales.invoiceDetail(9999), isNull);

      final recent = await sales.recentSales();
      expect(recent.map((s) => s.invoiceNo), [
        'INV-2026-00002',
        'INV-2026-00001',
      ]);
      expect(recent.first.customerName, isNull);
      expect(recent.last.customerName, 'نور');

      final forCustomer = await sales.recentSales(customerId: customer);
      expect(forCustomer, hasLength(1));
      expect(forCustomer.single.invoiceNo, 'INV-2026-00001');
      expect(forCustomer.single.total, 90);

      final totals = await sales.salesTotals(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 31),
      );
      expect(totals.invoiceCount, 2);
      expect(totals.salesBase, 115);
      expect(totals.costTotal, 45); // 20 + 15 + 10.
      expect(totals.cashCollected, 115);
      expect(totals.grossProfit, 70);
    });
  });
}
