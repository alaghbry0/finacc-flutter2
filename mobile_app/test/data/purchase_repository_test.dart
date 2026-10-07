/// اختبارات محرك ترحيل فاتورة الشراء — FR-02-08 / قاعدة 5.4-3 / 5.4-4 /
/// FR-08-09 / AC-03 / AC-09-أ (الجزء الشرائي).
///
/// يغطي حرفياً: الترحيل الكامل (كل الجداول) بتسلسل PUR الذرّي، **مثال WAC
/// النصي للـ SRS** (شراء 10 @100 بخصم رأس 10% → cost_price=90 لا 100، ثم
/// خلط 10×90 + 5×120 → WAC=100)، حالة qty_old ≤ 0 (التكلفة الجديدة
/// مباشرة رغم تكلفة قديمة)، الشراء بعملة SAR بلا سعر اليوم (رفض) ومع
/// fx.fallback (نجاح بعلم — AC-03: التكلفة سُجّلت بسعر يوم الشراء)،
/// الدفعات الواردة بتواريخ صلاحية، اتجاه الصندوق (سند صرف للجزء النقدي)،
/// دين المورد عند الآجل، الأصناف الخدمية، والذرّية الكاملة عند الرفض.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/purchase_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/data/repositories/supplier_repository.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:mobile_app/domain/models/purchase.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;
  late PurchaseRepository purchases;
  late ItemRepository items;
  late SupplierRepository suppliers;
  late ExchangeRateRepository rates;
  late SettingsRepository settings;
  late int warehouseId;
  late int userId;
  late int baseCurrencyId;
  late int sarId;
  late int defaultCashboxId;
  late int supplierId;
  final at = DateTime.utc(2026, 10, 6, 12);

  setUp(() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    purchases = PurchaseRepository(handle.db);
    items = ItemRepository(handle.db);
    suppliers = SupplierRepository(handle.db);
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
    final supplierResult = await suppliers.createSupplier(
      SupplierDraft(name: 'مستوردات النور'),
      userId: userId,
      now: at,
    );
    supplierId = supplierResult.valueOrNull!;
  });

  tearDown(() async {
    await handle.close();
  });

  // ── بذور مساعدة ──────────────────────────────────────────────────

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

  Future<double> productCost(int productId) async {
    final rows = await handle.db.rawQuery(
      'SELECT cost_price FROM product WHERE id = ?',
      [productId],
    );
    return (rows.first['cost_price'] as num?)?.toDouble() ?? 0;
  }

  Future<double> stockQty(int productId) async {
    final rows = await handle.db.rawQuery(
      'SELECT qty FROM stock_level WHERE product_id = ? AND warehouse_id = ?',
      [productId, warehouseId],
    );
    return rows.isEmpty ? 0 : (rows.first['qty'] as num?)?.toDouble() ?? 0;
  }

  PurchaseDraft draft(
    List<PurchaseLine> lines, {
    double paidCash = 0,
    PurchasePaymentMethod method = PurchasePaymentMethod.credit,
    PurchaseDiscountType discountType = PurchaseDiscountType.amount,
    double discountValue = 0,
    int? currencyId,
    String? supplierRef,
  }) => PurchaseDraft(
    supplierId: supplierId,
    currencyId: currencyId ?? baseCurrencyId,
    lines: lines,
    invoiceDiscountType: discountType,
    invoiceDiscountValue: discountValue,
    paidCash: paidCash,
    paymentMethod: method,
    warehouseId: warehouseId,
    issuedAt: at,
    supplierInvoiceRef: supplierRef,
  );

  // ── الترحيل الكامل ────────────────────────────────────────────────

  group('postPurchase — فاتورة نقدي بعملة الأساس (AC-09-أ)', () {
    test('كل الجداول مكتوبة صحيحة: invoice/invoice_item/stock/cash/audit',
        () async {
      final pen = await makeProduct('قلم', cost: 0, price: 25);
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: pen, qty: 4, unitCost: 25)],
          paidCash: 100,
          method: PurchasePaymentMethod.cash,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      final receipt = result.valueOrNull!;

      // التسلسل الذرّي (قاعدة 5.4-1): PUR-YYYY-NNNNN.
      expect(receipt.docNo, 'PUR-2026-00001');
      expect(receipt.totals.subtotal, 100);
      expect(receipt.totals.grandTotal, 100);
      expect(receipt.remainingCredit, 0);
      expect(receipt.exchangeRate, 1);
      expect(receipt.rateIsFallback, isFalse);

      final invoice = await row('invoice');
      expect(invoice['invoice_no'], 'PUR-2026-00001');
      expect(invoice['doc_type'], 'purchase');
      expect(invoice['pay_status'], 'cash');
      expect(invoice['status'], 'completed');
      expect(invoice['issued_at'], at.toUtc().toIso8601String());
      expect(invoice['supplier_id'], supplierId);
      expect(invoice['quotation_id'], isNull);
      expect(invoice['original_invoice_id'], isNull);
      expect(invoice['warehouse_id'], warehouseId);
      expect(invoice['cashbox_id'], defaultCashboxId);
      expect(invoice['currency_id'], baseCurrencyId);
      expect(invoice['exchange_rate'], 1);
      expect(invoice['rate_is_fallback'], 0);
      expect(invoice['subtotal'], 100);
      expect(invoice['discount_amount'], 0);
      expect(invoice['total'], 100);
      expect(invoice['total_base'], 100);
      expect(invoice['paid_amount'], 100);
      expect(invoice['due_amount'], 0);
      expect(invoice['cost_total'], 100); // 4 × 25.
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
      expect(item['line_cost'], 100); // بالعملة الأساسية.
      expect(item['batch_id'], isNull);

      expect(await stockQty(pen), 4);

      final movement = await row(
        'stock_movement',
        where: "product_id = $pen AND movement_type = 'purchase'",
      );
      expect(movement['movement_type'], 'purchase');
      expect((movement['qty'] as num).toDouble(), 4); // الوارد موجب.
      expect(movement['unit_cost'], 25);
      expect(movement['ref_type'], 'invoice');
      expect(movement['ref_id'], receipt.invoiceId);
      expect(movement['warehouse_id'], warehouseId);

      // اتجاه الصندوق معاكس للبيع: سند **صرف** من الصندوق.
      final cash = await row('cash_tx');
      expect(cash['tx_type'], 'payment');
      expect(cash['cashbox_id'], defaultCashboxId);
      expect(cash['currency_id'], baseCurrencyId);
      expect(cash['amount'], 100);
      expect(cash['exchange_rate'], 1);
      expect(cash['ref_type'], 'invoice');
      expect(cash['ref_id'], receipt.invoiceId);
      expect(cash['supplier_id'], isNull); // لا خصم مزدوج من رصيد المورد.

      final allocation = await row('payment_allocation');
      expect(allocation['cash_tx_id'], cash['id']);
      expect(allocation['invoice_id'], receipt.invoiceId);
      expect(allocation['allocated_amount'], 100);

      final audit = await row(
        'audit_log',
        where: "action = 'purchase_post'",
      );
      expect(audit['entity'], 'invoice');
      expect(audit['entity_id'], receipt.invoiceId);
      expect(audit['details'], contains('PUR-2026-00001'));
    });

    test('رقم فاتورة المورد الورقي داخل الملاحظة الداخلية (القرار 5)',
        () async {
      final pen = await makeProduct('قلم');
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: pen, qty: 1, unitCost: 10)],
          paidCash: 10,
          method: PurchasePaymentMethod.cash,
          supplierRef: 'INV-889',
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue);
      final invoice = await row('invoice');
      expect(invoice['notes_internal'], 'فاتورة المورد: INV-889');
    });

    test('التسلسل يتقدم عبر الفواتير ولا يُستهلك عند الرفض', () async {
      final a = await makeProduct('صنف أ');
      final first = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: a, qty: 1, unitCost: 5)],
          paidCash: 5,
          method: PurchasePaymentMethod.cash,
        ),
        userId: userId,
        now: at,
      );
      expect(first.valueOrNull!.docNo, 'PUR-2026-00001');
      // فشل (صنف غير موجود) — لا استهلاك رقم.
      final failed = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: 999999, qty: 1, unitCost: 5)],
          paidCash: 5,
          method: PurchasePaymentMethod.cash,
        ),
        userId: userId,
        now: at,
      );
      expect(failed.isErr, isTrue);
      final second = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: a, qty: 1, unitCost: 5)],
          paidCash: 5,
          method: PurchasePaymentMethod.cash,
        ),
        userId: userId,
        now: at,
      );
      expect(second.valueOrNull!.docNo, 'PUR-2026-00002');
    });
  });

  // ── WAC (قاعدة 5.4-3) — أمثلة SRS الحرفية ────────────────────────

  group('WAC — مثال SRS النصي (5.4-3)', () {
    test('شراء 10 @100 بخصم رأس 10% → cost_price = 90 (لا 100)', () async {
      final item = await makeProduct('حليب', cost: 0);
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: item, qty: 10, unitCost: 100)],
          discountType: PurchaseDiscountType.percent,
          discountValue: 10,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      // التكلفة الفعلية بعد توزيع الخصم pro-rata قبل تحديث WAC:
      expect(await productCost(item), 90);
      expect(await stockQty(item), 10);
      // line_cost بالأساس = 10 × 90:
      final invoiceItem = await row('invoice_item');
      expect(invoiceItem['line_cost'], 900);
      expect(invoiceItem['line_total'], 900); // بعملة الفاتورة.
      expect(invoiceItem['discount_amount'], 100);
      final invoice = await row('invoice');
      expect(invoice['total'], 900);
      expect(invoice['cost_total'], 900);
    });

    test('خلط لاحق: قديم 10×90 + جديد 5×120 → WAC = 100', () async {
      final item = await makeProduct('حليب', cost: 0);
      await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: item, qty: 10, unitCost: 100)],
          discountType: PurchaseDiscountType.percent,
          discountValue: 10,
        ),
        userId: userId,
        now: at,
      );
      final second = await purchases.postPurchase(
        draft([PurchaseLine(productId: item, qty: 5, unitCost: 120)]),
        userId: userId,
        now: at,
      );
      expect(second.isOk, isTrue, reason: '${second.errorOrNull}');
      // (10×90 + 5×120) / 15 = 1600/15... لا: 900+600=1500 /15 = 100.
      expect(await productCost(item), 100);
      expect(await stockQty(item), 15);
      expect(second.valueOrNull!.docNo, 'PUR-2026-00002');
    });

    test('qty_old = 0 مع تكلفة قديمة عالقة → التكلفة الجديدة مباشرة',
        () async {
      // صنف بلا مخزون لكن cost_price قديمة 50 (بقايا) — الشراء يعتمد
      // التكلفة الجديدة مباشرة (5.4-3: qty_old ≤ 0 → cost_new).
      final item = await makeProduct('صنف معدوم', cost: 50);
      expect(await stockQty(item), 0);
      await purchases.postPurchase(
        draft([PurchaseLine(productId: item, qty: 2, unitCost: 10)]),
        userId: userId,
        now: at,
      );
      expect(await productCost(item), 10);
    });

    test('أسطر مكررة لنفس الصنف في فاتورة واحدة = تحديث مدمج', () async {
      final item = await makeProduct('سكر');
      await purchases.postPurchase(
        draft([
          PurchaseLine(productId: item, qty: 10, unitCost: 90),
          PurchaseLine(productId: item, qty: 5, unitCost: 120),
        ]),
        userId: userId,
        now: at,
      );
      // (10×90 + 5×120)/15 = 100.
      expect(await productCost(item), 100);
      expect(await stockQty(item), 15);
      expect(await count('invoice_item'), 2);
    });
  });

  // ── الدفع: آجل/مختلط ودين المورد ────────────────────────────────

  group('الدفع ودين المورد (FR-02-03 / FR-03-03)', () {
    test('شراء آجل كامل → due_amount دين ورصيد المورد يرتفع', () async {
      final pen = await makeProduct('قلم');
      final result = await purchases.postPurchase(
        draft([PurchaseLine(productId: pen, qty: 10, unitCost: 100)]),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.remainingCredit, 1000);
      expect(result.valueOrNull!.payStatus, PurchasePaymentMethod.credit);

      final invoice = await row('invoice');
      expect(invoice['pay_status'], 'credit');
      expect(invoice['paid_amount'], 0);
      expect(invoice['due_amount'], 1000);
      expect(invoice['cashbox_id'], isNull);
      expect(await count('cash_tx'), 0); // لا سند نقدي.
      expect(await count('payment_allocation'), 0);

      // صيغة رصيد المورد (FR-03-03) تقرأ due_amount.
      expect(
        await suppliers.balanceInCurrency(supplierId, baseCurrencyId),
        1000,
      );
    });

    test('شراء مختلط: جزء نقدي (سند صرف) وجزء دين', () async {
      final pen = await makeProduct('قلم');
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: pen, qty: 10, unitCost: 100)],
          paidCash: 400,
          method: PurchasePaymentMethod.mixed,
        ),
        userId: userId,
        now: at,
      );
      expect(result.valueOrNull!.payStatus, PurchasePaymentMethod.mixed);
      final invoice = await row('invoice');
      expect(invoice['pay_status'], 'mixed');
      expect(invoice['paid_amount'], 400);
      expect(invoice['due_amount'], 600);
      final cash = await row('cash_tx');
      expect(cash['tx_type'], 'payment');
      expect(cash['amount'], 400);
      expect(
        await suppliers.balanceInCurrency(supplierId, baseCurrencyId),
        600,
      );
    });

    test('الدفع الزائد فوق الصافي مرفوض (لا «باقٍ» في الشراء)', () async {
      final pen = await makeProduct('قلم');
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: pen, qty: 1, unitCost: 100)],
          paidCash: 150,
          method: PurchasePaymentMethod.cash,
        ),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('يتجاوز صافي الفاتورة'));
      expect(await count('invoice'), 0);
    });

    test('تعارض تعلان الدفع مع الأرقام → رفض', () async {
      final pen = await makeProduct('قلم');
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: pen, qty: 1, unitCost: 100)],
          paidCash: 0,
          method: PurchasePaymentMethod.cash,
        ),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('تسديد الصافي كاملاً'));
    });
  });

  // ── الدفعات الواردة (FR-01-10) ──────────────────────────────────

  group('الدفعات الواردة بتواريخ الصلاحية', () {
    test('متتبع + رقم دفعة + صلاحية → صف batch بالتكلفة الفعلية', () async {
      final item = await makeProduct('دواء', tracked: true);
      final result = await purchases.postPurchase(
        draft([
          PurchaseLine(
            productId: item,
            qty: 10,
            unitCost: 50,
            batchNo: 'B-2027-01',
            expiryDate: DateTime(2027, 6, 1),
          ),
        ]),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

      final batch = await row('batch');
      expect(batch['product_id'], item);
      expect(batch['warehouse_id'], warehouseId);
      expect(batch['batch_number'], 'B-2027-01');
      expect(batch['expiry_date'], '2027-06-01');
      expect(batch['cost_price'], 50); // التكلفة الفعلية بالأساس.
      expect(batch['qty'], 10);

      final invoiceItem = await row('invoice_item');
      expect(invoiceItem['batch_id'], batch['id']);
      expect(invoiceItem['notes'], contains('B-2027-01'));

      expect(await stockQty(item), 10);
      expect(await productCost(item), 50);
      final movement = await row(
        'stock_movement',
        where: "product_id = $item AND movement_type = 'purchase'",
      );
      expect(movement['notes'], contains('B-2027-01'));
      expect(movement['notes'], contains('2027-06-01'));
    });

    test('فاتورتا شراء بدفعتين مختلفتين → دفعتان وWAC مدمج', () async {
      final item = await makeProduct('دواء', tracked: true);
      await purchases.postPurchase(
        draft([
          PurchaseLine(
            productId: item,
            qty: 10,
            unitCost: 50,
            batchNo: 'B-1',
            expiryDate: DateTime(2027, 1, 1),
          ),
        ]),
        userId: userId,
        now: at,
      );
      await purchases.postPurchase(
        draft([
          PurchaseLine(
            productId: item,
            qty: 5,
            unitCost: 70,
            batchNo: 'B-2',
            expiryDate: DateTime(2028, 1, 1),
          ),
        ]),
        userId: userId,
        now: at,
      );
      expect(await count('batch'), 2);
      // (10×50 + 5×70)/15 = 850/15 = 56.6667.
      expect(await productCost(item), 56.6667);
      expect(await stockQty(item), 15);
    });

    test('متتبع بلا دفعة → مخزون عام بلا دفعة (وفق التكليف)', () async {
      final item = await makeProduct('متتبع بلا دفعة', tracked: true);
      final result = await purchases.postPurchase(
        draft([PurchaseLine(productId: item, qty: 3, unitCost: 20)]),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue);
      expect(await count('batch'), 0);
      expect(await stockQty(item), 3);
      final invoiceItem = await row('invoice_item');
      expect(invoiceItem['batch_id'], isNull);
      expect(invoiceItem['notes'], isNull);
    });

    test('دفعة بلا تاريخ صلاحية → رفض (عمود expiry NOT NULL)', () async {
      final item = await makeProduct('دواء', tracked: true);
      final result = await purchases.postPurchase(
        draft([
          PurchaseLine(productId: item, qty: 1, unitCost: 10, batchNo: 'B-X'),
        ]),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('تاريخ الصلاحية'));
      expect(await count('invoice'), 0);
    });

    test('رقم دفعة لصنف غير متتبع → رفض', () async {
      final item = await makeProduct('عادي');
      final result = await purchases.postPurchase(
        draft([
          PurchaseLine(
            productId: item,
            qty: 1,
            unitCost: 10,
            batchNo: 'B-X',
            expiryDate: DateTime(2027, 1, 1),
          ),
        ]),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('لا يتتبع الدفعات'));
    });
  });

  // ── سياسة الصرف (FR-08-09 / AC-03) ──────────────────────────────

  group('سياسة سعر الصرف المفقود (FR-08-09 / AC-13 / AC-03)', () {
    test('شراء بعملة SAR بلا سعر اليوم → رفض بلا أي كتابة', () async {
      final pen = await makeProduct('قلم');
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: pen, qty: 1, unitCost: 100)],
          currencyId: sarId,
          paidCash: 100,
          method: PurchasePaymentMethod.cash,
        ),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('لا يوجد سعر صرف'));
      expect(result.errorOrNull, contains('SAR'));
      expect(await count('invoice'), 0);
      expect(await count('cash_tx'), 0);
    });

    test('مع fx.fallback → آخر سعر + rate_is_fallback=1 (AC-03)', () async {
      await settings.set('fx.fallback', 'last_known');
      await rates.setRate(
        currencyId: sarId,
        date: DateTime(2026, 10, 1),
        rate: 530,
        userId: userId,
        now: at,
      );
      final item = await makeProduct('حليب');
      // شراء بعملة SAR: 10 @100 بخصم رأس 10% → صافي 900 SAR.
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: item, qty: 10, unitCost: 100)],
          discountType: PurchaseDiscountType.percent,
          discountValue: 10,
          currencyId: sarId,
          paidCash: 900,
          method: PurchasePaymentMethod.cash,
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
      expect(invoice['total'], 900); // بعملة الفاتورة (SAR).
      expect(invoice['total_base'], 477000); // 900 × 530 بالأساس.

      // AC-03: التكلفة سُجّلت بسعر يوم الشراء — WAC بالعملة الأساسية:
      // تكلفة الوحدة الفعلية = (900 SAR × 530)/10 = 47,700 بالأساس.
      expect(await productCost(item), 47700);
      final invoiceItem = await row('invoice_item');
      expect(invoiceItem['line_total'], 900); // SAR.
      expect(invoiceItem['line_cost'], 477000); // بالأساس (10 × 47,700).
      expect(invoiceItem['unit_price'], 100); // تكلفة الوحدة المدخلة (SAR).
      expect(invoice['cost_total'], 477000);

      // السند النقدي بعملة الفاتورة (SAR) بسعرها.
      final cash = await row('cash_tx');
      expect(cash['currency_id'], sarId);
      expect(cash['amount'], 900);
      expect(cash['exchange_rate'], 530);
    });

    test('سعر اليوم موجود → Snapshot بلا شارة', () async {
      await rates.setRate(
        currencyId: sarId,
        date: at,
        rate: 560,
        userId: userId,
        now: at,
      );
      final pen = await makeProduct('قلم');
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: pen, qty: 1, unitCost: 100)],
          currencyId: sarId,
          paidCash: 100,
          method: PurchasePaymentMethod.cash,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.exchangeRate, 560);
      expect(result.valueOrNull!.rateIsFallback, isFalse);
      expect(await productCost(pen), 56000); // 100 SAR × 560.
    });
  });

  // ── الأصناف الخدمية والرفض والذرّية ─────────────────────────────

  group('الأصناف الخدمية والتحقق والذرّية', () {
    test('صنف خدمي: بلا مخزون ولا حركة ولا WAC — line_cost = 0', () async {
      final service = await makeProduct('نقل', service: true);
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: service, qty: 1, unitCost: 300)],
          paidCash: 300,
          method: PurchasePaymentMethod.cash,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue);
      expect(await count('stock_movement'), 0);
      expect(
        await count('stock_level'),
        0,
      ); // بذور الاختبار بلا افتتاحي مخزوني.
      final invoiceItem = await row('invoice_item');
      expect(invoiceItem['line_cost'], 0);
      expect(await productCost(service), 0);
      final invoice = await row('invoice');
      expect(invoice['cost_total'], 0);
    });

    test('صنف غير موجود / مورد غير موجود → رفض نظيف', () async {
      final missing = await purchases.postPurchase(
        draft([PurchaseLine(productId: 999999, qty: 1, unitCost: 5)]),
        userId: userId,
        now: at,
      );
      expect(missing.errorOrNull, contains('غير موجود'));

      final pen = await makeProduct('قلم');
      final badSupplier = await purchases.postPurchase(
        PurchaseDraft(
          supplierId: 999999,
          currencyId: baseCurrencyId,
          lines: [PurchaseLine(productId: pen, qty: 1, unitCost: 5)],
          paymentMethod: PurchasePaymentMethod.credit,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(badSupplier.errorOrNull, contains('المورد'));
    });

    test('الصنف المؤرشف لا يُشترى (FR-01-15)', () async {
      final pen = await makeProduct('قلم قديم');
      await handle.db.update(
        'product',
        {'is_archived': 1},
        where: 'id = ?',
        whereArgs: [pen],
      );
      final result = await purchases.postPurchase(
        draft([PurchaseLine(productId: pen, qty: 1, unitCost: 5)]),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('مؤرشف'));
    });

    test('أي رفض لا يترك أثراً (لا فاتورة ولا سند ولا رقم ولا تدقيق)',
        () async {
      final pen = await makeProduct('قلم');
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: pen, qty: 0, unitCost: 5)], // كمية صفر.
        ),
        userId: userId,
        now: at,
      );
      expect(result.isErr, isTrue);
      expect(await count('invoice'), 0);
      expect(await count('invoice_item'), 0);
      expect(
        await count('stock_movement', where: "movement_type = 'purchase'"),
        0,
      );
      expect(await count('cash_tx'), 0);
      expect(await count('payment_allocation'), 0);
      expect(await count('audit_log', where: "action = 'purchase_post'"), 0);
      final seq = await handle.db.rawQuery(
        "SELECT last_no FROM doc_sequence WHERE doc_type = 'PUR'",
      );
      expect(seq, isEmpty); // الرقم لم يُستهلك إطلاقاً.
    });
  });

  // ── القراءات ─────────────────────────────────────────────────────

  group('القراءات (purchaseDetail / recentPurchases)', () {
    test('تفاصيل كاملة + قائمة أحدث أولاً مع تصفية المورد', () async {
      final pen = await makeProduct('قلم');
      final paper = await makeProduct('ورق');
      final first = await purchases.postPurchase(
        draft([PurchaseLine(productId: pen, qty: 2, unitCost: 10)]),
        userId: userId,
        now: at,
      ).then((r) => r.valueOrNull!);
      final second = await purchases.postPurchase(
        draft([PurchaseLine(productId: paper, qty: 1, unitCost: 30)]),
        userId: userId,
        now: at,
      ).then((r) => r.valueOrNull!);

      final detail = await purchases.purchaseDetail(second.invoiceId);
      expect(detail, isNotNull);
      expect(detail!.invoice.invoiceNo, second.docNo);
      expect(detail.invoice.supplierId, supplierId);
      expect(detail.supplierName, 'مستوردات النور');
      expect(detail.currencyCode, 'YER');
      expect(detail.items, hasLength(1));
      expect(detail.items.first.lineDesc, 'ورق');
      expect(detail.items.first.lineCost, 30);

      expect(await purchases.purchaseDetail(first.invoiceId), isNotNull);
      // معرّف وهمي أو فاتورة من نوع آخر → null.
      expect(await purchases.purchaseDetail(999999), isNull);

      final recent = await purchases.recentPurchases();
      expect(recent, hasLength(2));
      expect(recent.first.invoiceNo, second.docNo); // الأحدث أولاً.
      expect(recent.last.invoiceNo, first.docNo);
      expect(recent.first.supplierName, 'مستوردات النور');
      expect(recent.first.dueAmount, 30);

      final filtered = await purchases.recentPurchases(
        supplierId: supplierId + 999,
      );
      expect(filtered, isEmpty);
    });
  });
}
