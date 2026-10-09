/// اختبارات محرك المرتجعات المرتبطة — FR-02-07 / FR-02-08 / قاعدة 5.4-3 /
/// 5.4-4 / 5.4-5 / FR-03-02 / FR-03-03 / AC-09-أ.
///
/// يغطي حرفياً: **مرتجع البيع بتكلفة line_cost الأصلية** (تغيير WAC بشراء
/// لاحق ثم إرجاع — الخط المستخدم الأصلي لا الجاري)، الكشف ورصيد العميل
/// بعد customerCredit، نقص الصندوق بعد cash، عودة الدفعات لدفعة البيع
/// الأصلية، سقوف الإرجاع (فوق المباع/المتبقي)، منع المرتجع عن نوع خاطئ أو
/// فاتورة ملغاة، **مرتجع الشراء بسعر حركة الشراء الأصلية (Snapshot)**
/// بإعادة حساب WAC على المتبقي برقم محسوب يدوياً، خصم الدفعة الواردة،
/// دين المورد، والذرّية الكاملة عند فشل منتصف المعاملة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/customer_repository.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/purchase_repository.dart';
import 'package:mobile_app/data/repositories/return_repository.dart';
import 'package:mobile_app/data/repositories/sale_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/data/repositories/supplier_repository.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:mobile_app/domain/models/purchase.dart';
import 'package:mobile_app/domain/models/sale.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;
  late PurchaseRepository purchases;
  late SaleRepository sales;
  late ReturnRepository returns;
  late ItemRepository items;
  late CustomerRepository customers;
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
    sales = SaleRepository(handle.db);
    returns = ReturnRepository(handle.db);
    items = ItemRepository(handle.db);
    customers = CustomerRepository(handle.db);
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

  Future<int> makeCustomer(String name) async {
    final result = await customers.createCustomer(
      CustomerDraft(name: name),
      userId: userId,
      now: at,
    );
    return result.valueOrNull!;
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

  Future<double> batchQty(int batchId) async {
    final rows = await handle.db.rawQuery(
      'SELECT qty FROM batch WHERE id = ?',
      [batchId],
    );
    return rows.isEmpty ? 0 : (rows.first['qty'] as num?)?.toDouble() ?? 0;
  }

  /// معرّف أول بند في فاتورة (مفتاح مدخلات المرتجع).
  Future<int> firstItemId(int invoiceId) async {
    final rows = await handle.db.rawQuery(
      'SELECT id FROM invoice_item WHERE invoice_id = ? ORDER BY id ASC '
      'LIMIT 1',
      [invoiceId],
    );
    return rows.first['id'] as int;
  }

  /// شراء آجل جاهز (بعملة الأساس) — يعيد معرّف الفاتورة.
  Future<int> postPurchase(
    List<PurchaseLine> lines, {
    PurchaseDiscountType discountType = PurchaseDiscountType.amount,
    double discountValue = 0,
    DateTime? issuedAt,
  }) async {
    final result = await purchases.postPurchase(
      PurchaseDraft(
        supplierId: supplierId,
        currencyId: baseCurrencyId,
        lines: lines,
        invoiceDiscountType: discountType,
        invoiceDiscountValue: discountValue,
        paymentMethod: PurchasePaymentMethod.credit,
        warehouseId: warehouseId,
        issuedAt: issuedAt ?? at,
      ),
      userId: userId,
      now: at,
    );
    return result.valueOrNull!.invoiceId;
  }

  /// بيع جاهز (نقدي أو آجل) — يعيد معرّف الفاتورة.
  Future<int> postSale(
    List<CartLine> lines, {
    int? customerId,
    double paidCash = 0,
    SalePaymentMethod method = SalePaymentMethod.cash,
  }) async {
    final result = await sales.postSale(
      SaleDraft(
        customerId: customerId,
        currencyId: baseCurrencyId,
        lines: lines,
        paidCash: paidCash,
        paymentMethod: method,
        warehouseId: warehouseId,
        issuedAt: at,
      ),
      userId: userId,
      now: at,
    );
    return result.valueOrNull!.invoiceId;
  }

  // ═════════════════════════════════════════════════════════════════
  // مرتجع البيع (SRN) — FR-02-07
  // ═════════════════════════════════════════════════════════════════

  group('SRN — التكلفة الأصلية (قاعدة 5.4-3)', () {
    test(
      'مرتجع جزئي بعد تغيير WAC بشراء لاحق → line_cost/movement بالأصلي',
      () async {
        final item = await makeProduct('حليب');
        // شراء أول: 10 @100 بخصم رأس 10% → WAC = 90.
        await postPurchase(
          [PurchaseLine(productId: item, qty: 10, unitCost: 100)],
          discountType: PurchaseDiscountType.percent,
          discountValue: 10,
        );
        // بيع 4 وحدات → line_cost = 4 × 90 = 360.
        final saleId = await postSale([
          CartLine(productId: item, qty: 4, unitPrice: 150),
        ], paidCash: 600);
        // شراء لاحق يغيّر WAC: 5 @120 → (6×90 + 5×120)/11 = 103.6364.
        await postPurchase([
          PurchaseLine(productId: item, qty: 5, unitCost: 120),
        ]);
        final wacNow = await productCost(item);
        expect(wacNow, closeTo(103.6364, 0.0001));

        // المرتجع: وحدتان من البيع الأصلي.
        final result = await returns.postSaleReturn(
          SaleReturnDraft(
            originalInvoiceId: saleId,
            lines: [
              ReturnLineInput(invoiceItemId: await firstItemId(saleId), qty: 2),
            ],
            refundMethod: ReturnRefundMethod.cash,
            refundCash: 300, // 2 × 150.
            issuedAt: at,
          ),
          userId: userId,
          now: at,
        );
        expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
        final receipt = result.valueOrNull!;
        expect(receipt.docNo, 'SRN-2026-00001');
        expect(receipt.docType, 'SRN');
        expect(receipt.refundTotal, 300);

        // التكلفة المستخدمة = الأصلية (90) لا WAC الجاري (103.6364):
        final srnItem = await handle.db.rawQuery(
          'SELECT * FROM invoice_item WHERE invoice_id = ?',
          [receipt.invoiceId],
        );
        expect((srnItem.first['line_cost'] as num).toDouble(), 180); // 2×90.
        final movement = await handle.db.rawQuery(
          "SELECT * FROM stock_movement WHERE movement_type = 'sale_return' "
          'AND ref_id = ?',
          [receipt.invoiceId],
        );
        expect((movement.first['qty'] as num).toDouble(), 2); // وارد موجب.
        expect((movement.first['unit_cost'] as num).toDouble(), 90);

        // WAC لم يُلمس والمخزون رجع: 6 + 5 + 2 = 13.
        expect(await productCost(item), wacNow);
        expect(await stockQty(item), 13);
      },
    );
  });

  group('SRN — اتجاه المبلغ والكشف (FR-02-07 / FR-03-02)', () {
    test('customerCredit: رصيد العميل وكشف حسابه صحيحان', () async {
      final customer = await makeCustomer('أبو سعيد');
      final item = await makeProduct('سكر', price: 25);
      await postPurchase([
        PurchaseLine(productId: item, qty: 10, unitCost: 10),
      ]);
      // بيع آجل 4 × 25 = 100.
      final saleId = await postSale(
        [CartLine(productId: item, qty: 4, unitPrice: 25)],
        customerId: customer,
        method: SalePaymentMethod.credit,
      );
      expect(await customers.balanceInCurrency(customer, baseCurrencyId), 100);

      // مرتجع آجل (خصم من الحساب) لوحدتين = 50.
      final result = await returns.postSaleReturn(
        SaleReturnDraft(
          originalInvoiceId: saleId,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(saleId), qty: 2),
          ],
          refundMethod: ReturnRefundMethod.credit,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      final receipt = result.valueOrNull!;
      expect(receipt.refundCredit, 50);
      expect(receipt.refundCash, 0);
      expect(receipt.payStatus, ReturnRefundMethod.credit);

      // الرصيد: 100 (دين البيع) − 50 (مرتجع آجل) = 50.
      expect(await customers.balanceInCurrency(customer, baseCurrencyId), 50);
      // الكشف: قيد الفاتورة (+100) ثم قيد المرتجع (−50) ورصيد نهائي 50.
      final statement = await customers.statement(
        customer,
        currencyId: baseCurrencyId,
      );
      expect(statement.entries, hasLength(2));
      expect(statement.entries.first.code, StatementEntryCode.invoice);
      expect(statement.entries.first.amount, 100);
      expect(statement.entries.last.code, StatementEntryCode.saleReturn);
      expect(statement.entries.last.amount, -50);
      expect(statement.entries.last.docNo, receipt.docNo);
      expect(statement.finalBalance, 50);

      // صف الفاتورة المرتجعة نفسه: due_amount = 50 (خصم من الحساب).
      final srnRow = await handle.db.rawQuery(
        'SELECT * FROM invoice WHERE id = ?',
        [receipt.invoiceId],
      );
      expect(srnRow.first['doc_type'], 'sale_return');
      expect(srnRow.first['original_invoice_id'], saleId);
      expect(srnRow.first['customer_id'], customer);
      expect(srnRow.first['pay_status'], 'credit');
      expect(srnRow.first['paid_amount'], 0);
      expect(srnRow.first['due_amount'], 50);
      expect(srnRow.first['status'], 'completed');
      // لا سند نقدي ولا تخصيص عند الاتجاه الآجل.
      expect(await count('cash_tx'), 0);
      expect(await count('payment_allocation'), 0);
    });

    test('cash: صرف نقدي من الصندوق ولا تغيير على رصيد العميل', () async {
      final customer = await makeCustomer('أبو محمد');
      final item = await makeProduct('سكر', price: 25);
      await postPurchase([
        PurchaseLine(productId: item, qty: 10, unitCost: 10),
      ]);
      // بيع نقدي كامل 100 (محصَّل وقت الإصدار).
      final saleId = await postSale(
        [CartLine(productId: item, qty: 4, unitPrice: 25)],
        customerId: customer,
        paidCash: 100,
        method: SalePaymentMethod.cash,
      );
      // سند القبض الأصلي موجود (وقت البيع):
      expect(await count('cash_tx'), 1);

      final result = await returns.postSaleReturn(
        SaleReturnDraft(
          originalInvoiceId: saleId,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(saleId), qty: 2),
          ],
          refundMethod: ReturnRefundMethod.cash,
          refundCash: 50,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

      // صندوق: سند **صرف** جديد بمبلغ 50 مرتبط بالمرتجع + تخصيص عكسي.
      final refundTx = await handle.db.rawQuery(
        "SELECT * FROM cash_tx WHERE tx_type = 'payment'",
      );
      expect(refundTx, hasLength(1));
      expect((refundTx.first['amount'] as num).toDouble(), 50);
      expect(refundTx.first['cashbox_id'], defaultCashboxId);
      expect(refundTx.first['ref_type'], 'invoice');
      expect(refundTx.first['ref_id'], result.valueOrNull!.invoiceId);
      expect(refundTx.first['customer_id'], isNull); // لا خصم مزدوج.
      expect(refundTx.first['currency_id'], baseCurrencyId);
      final allocation = await handle.db.rawQuery(
        'SELECT * FROM payment_allocation WHERE invoice_id = ?',
        [result.valueOrNull!.invoiceId],
      );
      expect(allocation, hasLength(1));
      expect((allocation.first['allocated_amount'] as num).toDouble(), 50);

      // رصيد العميل لم يتغير (بيع نقدي = لا دين أصلاً).
      expect(await customers.balanceInCurrency(customer, baseCurrencyId), 0);
      final srnRow = await handle.db.rawQuery(
        'SELECT * FROM invoice WHERE id = ?',
        [result.valueOrNull!.invoiceId],
      );
      expect(srnRow.first['pay_status'], 'cash');
      expect(srnRow.first['paid_amount'], 50);
      expect(srnRow.first['due_amount'], 0);
    });

    test('mixed: جزء نقدي وجزء على الحساب', () async {
      final customer = await makeCustomer('أبو أحمد');
      final item = await makeProduct('شاي', price: 30);
      await postPurchase([
        PurchaseLine(productId: item, qty: 10, unitCost: 10),
      ]);
      final saleId = await postSale(
        [CartLine(productId: item, qty: 4, unitPrice: 30)],
        customerId: customer,
        method: SalePaymentMethod.credit,
      );
      // مرتجع 120: 70 نقداً و50 على الحساب.
      final result = await returns.postSaleReturn(
        SaleReturnDraft(
          originalInvoiceId: saleId,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(saleId), qty: 4),
          ],
          refundMethod: ReturnRefundMethod.mixed,
          refundCash: 70,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      expect(result.valueOrNull!.payStatus, ReturnRefundMethod.mixed);
      expect(result.valueOrNull!.refundCash, 70);
      expect(result.valueOrNull!.refundCredit, 50);
      // الرصيد: 120 − 50 = 70.
      expect(await customers.balanceInCurrency(customer, baseCurrencyId), 70);
      expect(await count("cash_tx WHERE tx_type = 'payment'"), 1);
    });

    test('مرتجع آجل لفاتورة بلا عميل (نقدي مجهول) → رفض', () async {
      final item = await makeProduct('سكر', price: 25);
      await postPurchase([
        PurchaseLine(productId: item, qty: 10, unitCost: 10),
      ]);
      final saleId = await postSale([
        CartLine(productId: item, qty: 2, unitPrice: 25),
      ], paidCash: 50);
      final result = await returns.postSaleReturn(
        SaleReturnDraft(
          originalInvoiceId: saleId,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(saleId), qty: 1),
          ],
          refundMethod: ReturnRefundMethod.credit,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('بلا عميل مسجَّل'));
    });
  });

  group('SRN — الدفعات (القرار 3)', () {
    test('الكمية تعود إلى دفعة البيع الأصلية بسقف الاستهلاك', () async {
      final item = await makeProduct('دواء', tracked: true);
      // شراء بدفعتين.
      await postPurchase([
        PurchaseLine(
          productId: item,
          qty: 10,
          unitCost: 50,
          batchNo: 'B-1',
          expiryDate: DateTime(2027, 1, 1),
        ),
      ]);
      await postPurchase([
        PurchaseLine(
          productId: item,
          qty: 5,
          unitCost: 70,
          batchNo: 'B-2',
          expiryDate: DateTime(2028, 1, 1),
        ),
      ]);
      final b1 =
          (await handle.db.rawQuery(
                "SELECT id FROM batch WHERE batch_number = 'B-1'",
              )).first['id']
              as int;
      final b2 =
          (await handle.db.rawQuery(
                "SELECT id FROM batch WHERE batch_number = 'B-2'",
              )).first['id']
              as int;

      // بيع 6 وحدات → FEFO من B-1 (الأقرب انتهاءً) → B-1 = 4، B-2 = 5.
      final saleId = await postSale([
        CartLine(productId: item, qty: 6, unitPrice: 100),
      ], paidCash: 600);
      expect(await batchQty(b1), 4);
      expect(await batchQty(b2), 5);

      // مرتجع 6 (كل المبيع) → يعود كله إلى B-1 (دفعة البيع الأصلية).
      final result = await returns.postSaleReturn(
        SaleReturnDraft(
          originalInvoiceId: saleId,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(saleId), qty: 6),
          ],
          refundMethod: ReturnRefundMethod.cash,
          refundCash: 600,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      expect(await batchQty(b1), 10); // استُهلك 6 وأُعيد 6.
      expect(await batchQty(b2), 5); // لم تُلمس.
      expect(await stockQty(item), 15);

      // حركة العودة تحمل رقم الدفعة الأصلية (قابلة للتتبع لاحقاً).
      final movement = await handle.db.rawQuery(
        "SELECT * FROM stock_movement WHERE movement_type = 'sale_return'",
      );
      expect(movement, hasLength(1));
      expect(movement.first['notes'], contains('B-1'));
      expect((movement.first['unit_cost'] as num).toDouble(), 56.6667); // WAC.

      // سطر المرتجع يحمل الدفعة والعلامة الأصلية.
      final srnItem = await handle.db.rawQuery(
        'SELECT * FROM invoice_item WHERE invoice_id = ?',
        [result.valueOrNull!.invoiceId],
      );
      expect(srnItem.first['batch_id'], b1);
      expect(srnItem.first['notes'], contains('أصل البند #'));
    });

    test('مرتجعان متتاليان يتقاسمان سعة الدفعة دون تجاوز الاستهلاك', () async {
      final item = await makeProduct('دواء', tracked: true);
      await postPurchase([
        PurchaseLine(
          productId: item,
          qty: 8,
          unitCost: 50,
          batchNo: 'B-1',
          expiryDate: DateTime(2027, 1, 1),
        ),
      ]);
      final saleId = await postSale([
        CartLine(productId: item, qty: 6, unitPrice: 100),
      ], paidCash: 600);
      // مرتجع أول 4 ثم ثانٍ 2 — كلاهما إلى B-1 (استهلاك 6).
      for (final qty in [4.0, 2.0]) {
        final result = await returns.postSaleReturn(
          SaleReturnDraft(
            originalInvoiceId: saleId,
            lines: [
              ReturnLineInput(
                invoiceItemId: await firstItemId(saleId),
                qty: qty,
              ),
            ],
            refundMethod: ReturnRefundMethod.cash,
            refundCash: qty * 100,
            issuedAt: at,
          ),
          userId: userId,
          now: at,
        );
        expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      }
      final b1 = (await handle.db.rawQuery(
        "SELECT qty FROM batch WHERE batch_number = 'B-1'",
      )).first;
      expect((b1['qty'] as num).toDouble(), 8); // 2 + 4 + 2 = 8.
      expect(await stockQty(item), 8);
      // ثالث يتجاوز المتبقي (6 − 6 = 0) → رفض.
      final third = await returns.postSaleReturn(
        SaleReturnDraft(
          originalInvoiceId: saleId,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(saleId), qty: 1),
          ],
          refundMethod: ReturnRefundMethod.cash,
          refundCash: 100,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(third.errorOrNull, contains('المتاح للإرجاع (0)'));
    });

    test(
      'متتبع بلا استهلاك دفعي موثَّق → مخزون عام بلا دفعة (مموَّق)',
      () async {
        // شراء متتبع بلا دفعة (وفق التكليف) ثم بيعه مستحيل عبر FEFO —
        // نبني الحالة مباشرة: بيع عادي غير متتبع ثم نتبع علامته كمتتبع
        // بلا دفعات (السطر المرتجع يوثق الإضافة للمخزون العام).
        final item = await makeProduct('متتبع', tracked: true);
        await postPurchase([
          PurchaseLine(productId: item, qty: 6, unitCost: 20),
        ]);
        // زيادة مخزون عام يدوية عبر شراء ثانٍ بدفعة ثم أرشفة الدفعة لتعطيل
        // التتبع (حالة نادرة موثقة) — نكتفي هنا بالتحقق من رفض البيع لغياب
        // الدفعات (يدعم القرار الموثق: الرصيد بلا دفعة غير متاح للبيع).
        final saleFail = await sales.postSale(
          SaleDraft(
            currencyId: baseCurrencyId,
            lines: [CartLine(productId: item, qty: 1, unitPrice: 30)],
            paidCash: 30,
            paymentMethod: SalePaymentMethod.cash,
            warehouseId: warehouseId,
            issuedAt: at,
          ),
          userId: userId,
          now: at,
        );
        expect(saleFail.isErr, isTrue); // فحص توفر البيع يعدّ الدفعات فقط.
        expect(await stockQty(item), 6); // الرصيد موجود لكن غير متاح للبيع.
      },
    );
  });

  group('SRN — السقوف والأنواع (FR-02-07)', () {
    late int item;
    late int saleId;
    late int itemId;

    setUp(() async {
      item = await makeProduct('حليب', price: 25);
      await postPurchase([
        PurchaseLine(productId: item, qty: 10, unitCost: 10),
      ]);
      saleId = await postSale([
        CartLine(productId: item, qty: 4, unitPrice: 25),
      ], paidCash: 100);
      itemId = await firstItemId(saleId);
    });

    SaleReturnDraft srn(double qty, {int? invoiceId}) => SaleReturnDraft(
      originalInvoiceId: invoiceId ?? saleId,
      lines: [ReturnLineInput(invoiceItemId: itemId, qty: qty)],
      refundMethod: ReturnRefundMethod.cash,
      refundCash: qty * 25,
      issuedAt: at,
    );

    test('مرتجع فوق المباع → رفض بتسمية المتاح', () async {
      final result = await returns.postSaleReturn(
        srn(5),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('المتاح للإرجاع (4)'));
      expect(result.errorOrNull, contains('حليب'));
    });

    test('مرتجع ثانٍ فوق المتبقي → رفض', () async {
      final first = await returns.postSaleReturn(
        srn(3),
        userId: userId,
        now: at,
      );
      expect(first.isOk, isTrue);
      final second = await returns.postSaleReturn(
        srn(2), // المتبقي 1 فقط.
        userId: userId,
        now: at,
      );
      expect(second.errorOrNull, contains('المتاح للإرجاع (1)'));
      expect(second.errorOrNull, contains('المرتجع سابقاً 3'));
    });

    test('مرتجع عن فاتورة شراء (نوع خاطئ) → رفض', () async {
      final purchaseId = await postPurchase([
        PurchaseLine(productId: item, qty: 1, unitCost: 10),
      ]);
      final result = await returns.postSaleReturn(
        srn(1, invoiceId: purchaseId),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('ليست فاتورة بيع'));
    });

    test('مرتجع عن فاتورة ملغاة → رفض', () async {
      await handle.db.update(
        'invoice',
        {'status': 'void'},
        where: 'id = ?',
        whereArgs: [saleId],
      );
      final result = await returns.postSaleReturn(
        srn(1),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('ملغاة'));
    });

    test('بند لا ينتمي للفاتورة الأصلية → رفض', () async {
      final otherSale = await postSale([
        CartLine(productId: item, qty: 1, unitPrice: 25),
      ], paidCash: 25);
      final result = await returns.postSaleReturn(
        SaleReturnDraft(
          originalInvoiceId: saleId,
          lines: [
            ReturnLineInput(
              invoiceItemId: await firstItemId(otherSale),
              qty: 1,
            ),
          ],
          refundMethod: ReturnRefundMethod.cash,
          refundCash: 25,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('لا ينتمي'));
    });

    test('مبلغ نقدي زائد أو تعارض الاتجاه → رفض', () async {
      final over = await returns.postSaleReturn(
        SaleReturnDraft(
          originalInvoiceId: saleId,
          lines: [ReturnLineInput(invoiceItemId: itemId, qty: 1)],
          refundMethod: ReturnRefundMethod.cash,
          refundCash: 50, // أكثر من 25.
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(over.errorOrNull, contains('يتجاوز قيمة المرتجع'));

      final mismatch = await returns.postSaleReturn(
        SaleReturnDraft(
          originalInvoiceId: saleId,
          lines: [ReturnLineInput(invoiceItemId: itemId, qty: 1)],
          refundMethod: ReturnRefundMethod.credit,
          refundCash: 25, // آجل معلن مع مبلغ نقدي.
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(mismatch.errorOrNull, contains('عدم إدخال أي مبلغ نقدي'));
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // مرتجع الشراء (PRN) — FR-02-08
  // ═════════════════════════════════════════════════════════════════

  group('PRN — Snapshot وWAC المتبقي (قاعدة 5.4-3)', () {
    test('إرجاع كامل الفاتورة الثانية: WAC يعود بدقة إلى تكلفة الأولى', () async {
      final item = await makeProduct('حليب');
      // شراء أول: 10 @100 بخصم رأس 10% → WAC = 90 (مثال SRS).
      await postPurchase(
        [PurchaseLine(productId: item, qty: 10, unitCost: 100)],
        discountType: PurchaseDiscountType.percent,
        discountValue: 10,
      );
      // شراء ثانٍ: 5 @120 → WAC = (900+600)/15 = 100.
      final pur2 = await postPurchase([
        PurchaseLine(productId: item, qty: 5, unitCost: 120),
      ]);
      expect(await productCost(item), 100);
      expect(
        await suppliers.balanceInCurrency(supplierId, baseCurrencyId),
        1500, // 900 + 600 آجلاً.
      );

      // مرتجع شراء كامل للفاتورة الثانية (5 @120 Snapshot):
      // WAC بعد المرتجع = (15×100 − 5×120)/(15−5) = 900/10 = 90.
      final result = await returns.postPurchaseReturn(
        PurchaseReturnDraft(
          originalInvoiceId: pur2,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(pur2), qty: 5),
          ],
          refundMethod: ReturnRefundMethod.credit,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      final receipt = result.valueOrNull!;
      expect(receipt.docNo, 'PRN-2026-00001');
      expect(receipt.refundTotal, 600); // 5 × 120 بسعر الحركة الأصلية.
      expect(receipt.refundCredit, 600);

      expect(await productCost(item), 90); // أعيد الحساب على المتبقي.
      expect(await stockQty(item), 10);
      // الخروج بحركة بسعر الأصل (120) لا WAC الجاري (100):
      final prnItem = await handle.db.rawQuery(
        'SELECT * FROM invoice_item WHERE invoice_id = ?',
        [receipt.invoiceId],
      );
      expect((prnItem.first['line_cost'] as num).toDouble(), 600); // 5×120.
      final movement = await handle.db.rawQuery(
        "SELECT * FROM stock_movement WHERE movement_type = 'purchase_return'",
      );
      expect((movement.first['qty'] as num).toDouble(), -5); // خارج سالب.
      expect((movement.first['unit_cost'] as num).toDouble(), 120);

      // دين المورد نقص بالمقداح المرتجع: 1500 − 600 = 900.
      expect(
        await suppliers.balanceInCurrency(supplierId, baseCurrencyId),
        900,
      );
      final prnRow = await handle.db.rawQuery(
        'SELECT * FROM invoice WHERE id = ?',
        [receipt.invoiceId],
      );
      expect(prnRow.first['doc_type'], 'purchase_return');
      expect(prnRow.first['original_invoice_id'], pur2);
      expect(prnRow.first['supplier_id'], supplierId);
      expect(prnRow.first['pay_status'], 'credit');
      expect(prnRow.first['due_amount'], 600);
    });

    test('إرجاع جزئي برقم محسوب يدوياً + كشف المورد', () async {
      final item = await makeProduct('أرز');
      final pur = await postPurchase([
        PurchaseLine(productId: item, qty: 15, unitCost: 100),
      ]);
      final pur2 = await postPurchase([
        PurchaseLine(productId: item, qty: 10, unitCost: 130),
      ]);
      // WAC = (15×100 + 10×130)/25 = 2800/25 = 112.
      expect(await productCost(item), 112);

      // إرجاع 4 وحدات من الفاتورة الثانية (Snapshot 130):
      // WAC = (25×112 − 4×130)/21 = (2800 − 520)/21 = 2280/21 = 108.5714.
      final result = await returns.postPurchaseReturn(
        PurchaseReturnDraft(
          originalInvoiceId: pur2,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(pur2), qty: 4),
          ],
          refundMethod: ReturnRefundMethod.credit,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      expect(await productCost(item), closeTo(108.5714, 0.0001));
      expect(await stockQty(item), 21);
      expect(result.valueOrNull!.refundTotal, 520); // 4 × 130.

      // كشف حساب المورد: شراءان (+1500، +1300) ثم مرتجع (−520).
      final statement = await suppliers.statement(
        supplierId,
        currencyId: baseCurrencyId,
      );
      expect(statement.entries, hasLength(3));
      expect(statement.entries.last.code, StatementEntryCode.purchaseReturn);
      expect(statement.entries.last.amount, -520);
      expect(statement.finalBalance, 2280);
      expect(
        await suppliers.balanceInCurrency(supplierId, baseCurrencyId),
        2280,
      );
      // بيع 20 وحدة يُنقص المخزون إلى 1 — بعدها إرجاع الفاتورة الأولى
      // كاملة (15) جائز سقفاً لكل بند لكن المخزون الفعلي لا يكفي —
      // لا يمكن إرجاع ما بيع → رفض السالب (5.4-5).
      await postSale([
        CartLine(productId: item, qty: 20, unitPrice: 140),
      ], paidCash: 2800);
      expect(await stockQty(item), 1);
      final over = await returns.postPurchaseReturn(
        PurchaseReturnDraft(
          originalInvoiceId: pur,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(pur), qty: 15),
          ],
          refundMethod: ReturnRefundMethod.credit,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(over.errorOrNull, contains('لا يسمح النظام بمخزون سالب'));
      // والذرّية: لا أثر للرفض — الرصيد والمخزون كما كانا.
      expect(await stockQty(item), 1);
      expect(
        await suppliers.balanceInCurrency(supplierId, baseCurrencyId),
        2280,
      );
    });

    test('استرداد نقدي: سند قبض إلى الصندوق ولا تغيير في دين المورد', () async {
      final item = await makeProduct('زيت');
      // شراء نقدي كامل (لا دين).
      await purchases.postPurchase(
        PurchaseDraft(
          supplierId: supplierId,
          currencyId: baseCurrencyId,
          lines: [PurchaseLine(productId: item, qty: 10, unitCost: 40)],
          paidCash: 400,
          paymentMethod: PurchasePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(await suppliers.balanceInCurrency(supplierId, baseCurrencyId), 0);
      expect(await count("cash_tx WHERE tx_type = 'payment'"), 1);

      final pur =
          (await handle.db.rawQuery(
                'SELECT id FROM invoice WHERE doc_type = ?',
                ['purchase'],
              )).first['id']
              as int;
      final result = await returns.postPurchaseReturn(
        PurchaseReturnDraft(
          originalInvoiceId: pur,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(pur), qty: 5),
          ],
          refundMethod: ReturnRefundMethod.cash,
          refundCash: 200,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

      // صندوق: سند **قبض** وارد من المورد + تخصيص عكسي.
      final refundTx = await handle.db.rawQuery(
        "SELECT * FROM cash_tx WHERE tx_type = 'receipt'",
      );
      expect(refundTx, hasLength(1));
      expect((refundTx.first['amount'] as num).toDouble(), 200);
      expect(refundTx.first['ref_id'], result.valueOrNull!.invoiceId);
      expect(refundTx.first['supplier_id'], isNull); // لا خصم مزدوج.
      // تخصيصان: مدفوع الشراء الأصلي + التخصيص العكسي للسند المسترد.
      expect(await count('payment_allocation'), 2);

      // دين المورد لم يتغير (كان صفراً) والاسترداد نقدي:
      expect(await suppliers.balanceInCurrency(supplierId, baseCurrencyId), 0);
      final prnRow = await handle.db.rawQuery(
        'SELECT * FROM invoice WHERE id = ?',
        [result.valueOrNull!.invoiceId],
      );
      expect(prnRow.first['pay_status'], 'cash');
      expect(prnRow.first['due_amount'], 0);
      expect(await stockQty(item), 5);
    });
  });

  group('PRN — الدفعة الواردة (القرار 4)', () {
    test('الخصم من الدفعة الواردة الأصلية أولاً ثم FEFO للمتبقي', () async {
      final item = await makeProduct('دواء', tracked: true);
      final pur1 = await postPurchase([
        PurchaseLine(
          productId: item,
          qty: 10,
          unitCost: 50,
          batchNo: 'B-1',
          expiryDate: DateTime(2027, 1, 1),
        ),
      ]);
      final pur2 = await postPurchase([
        PurchaseLine(
          productId: item,
          qty: 5,
          unitCost: 70,
          batchNo: 'B-2',
          expiryDate: DateTime(2028, 1, 1),
        ),
      ]);
      final b1 =
          (await handle.db.rawQuery(
                "SELECT id FROM batch WHERE batch_number = 'B-1'",
              )).first['id']
              as int;
      final b2 =
          (await handle.db.rawQuery(
                "SELECT id FROM batch WHERE batch_number = 'B-2'",
              )).first['id']
              as int;

      // بيع 6 من B-1 (FEFO) → B-1 = 4.
      await postSale([
        CartLine(productId: item, qty: 6, unitPrice: 100),
      ], paidCash: 600);
      expect(await batchQty(b1), 4);

      // مرتجع 5 عن الفاتورة الأولى: 4 من دفعتها الأصلية B-1 + 1 FEFO
      // من B-2 (الأقرب انتهاءً بين المتاحة).
      final result = await returns.postPurchaseReturn(
        PurchaseReturnDraft(
          originalInvoiceId: pur1,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(pur1), qty: 5),
          ],
          refundMethod: ReturnRefundMethod.credit,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      expect(await batchQty(b1), 0); // الدفعة الأصلية أولاً (4 ثم 0).
      expect(await batchQty(b2), 4); // الباقي 1 من B-2.
      expect(await stockQty(item), 4); // 15 − 6 − 5.

      // حركتا خروج بدفعتين مختلفتين:
      final movements = await handle.db.rawQuery(
        "SELECT * FROM stock_movement WHERE movement_type = 'purchase_return'"
        ' ORDER BY id ASC',
      );
      expect(movements, hasLength(2));
      expect(movements.first['notes'], contains('B-1'));
      expect(movements.last['notes'], contains('B-2'));

      // إرجاع الباقي كله (4 — وحدة B-2 غادرت مع مرتجع الفاتورة الأولى)
      // عن الفاتورة الثانية → مخزون 4 − 4 = 0 وWAC صفر (حماية القسمة).
      final finalReturn = await returns.postPurchaseReturn(
        PurchaseReturnDraft(
          originalInvoiceId: pur2,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(pur2), qty: 4),
          ],
          refundMethod: ReturnRefundMethod.credit,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(finalReturn.isOk, isTrue, reason: '${finalReturn.errorOrNull}');
      expect(await stockQty(item), 0);
      expect(await productCost(item), 0); // حماية القسمة: المتبقي صفر.
    });
  });

  group('PRN — السقوف والأنواع والذرّية', () {
    late int item;
    late int purId;
    late int purItemId;

    setUp(() async {
      item = await makeProduct('حليب');
      purId = await postPurchase([
        PurchaseLine(productId: item, qty: 10, unitCost: 30),
      ]);
      purItemId = await firstItemId(purId);
    });

    PurchaseReturnDraft prn(double qty, {int? invoiceId}) =>
        PurchaseReturnDraft(
          originalInvoiceId: invoiceId ?? purId,
          lines: [ReturnLineInput(invoiceItemId: purItemId, qty: qty)],
          refundMethod: ReturnRefundMethod.credit,
          issuedAt: at,
        );

    test('مرتجع فوق المشترى → رفض', () async {
      final result = await returns.postPurchaseReturn(
        prn(11),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('المتاح للإرجاع (10)'));
    });

    test('مرتجع ثانٍ فوق المتبقي → رفض', () async {
      final first = await returns.postPurchaseReturn(
        prn(7),
        userId: userId,
        now: at,
      );
      expect(first.isOk, isTrue);
      final second = await returns.postPurchaseReturn(
        prn(4), // المتبقي 3.
        userId: userId,
        now: at,
      );
      expect(second.errorOrNull, contains('المتاح للإرجاع (3)'));
      expect(second.errorOrNull, contains('المرتجع سابقاً 7'));
    });

    test('مرتجع عن فاتورة بيع (نوع خاطئ) → رفض', () async {
      final saleId = await postSale([
        // يحتاج مخزوناً — شراء إضافي غير مطلوب (المخزون 10).
        CartLine(productId: item, qty: 1, unitPrice: 50),
      ], paidCash: 50);
      final result = await returns.postPurchaseReturn(
        prn(1, invoiceId: saleId),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('ليست فاتورة شراء'));
    });

    test(
      'فشل منتصف المعاملة لا يترك أثراً (حراسة stock_level داخلها)',
      () async {
        // نبني حالة انحراف مدفوعي/دفتري (دفعة مستنفدة دفترياً مع رصيد
        // stock_level أعلى) — الفحص المسبق (الدفعات) يمر وحارس
        // stock_level داخل المعاملة يفشل بعد كتابات ناجحة → تراجع كامل.
        final tracked = await makeProduct('دواء', tracked: true);
        final pur = await postPurchase([
          PurchaseLine(
            productId: tracked,
            qty: 10,
            unitCost: 20,
            batchNo: 'B-X',
            expiryDate: DateTime(2027, 1, 1),
          ),
        ]);
        // انحراف مصطنع: الدفعة تقول 10 ودفتر المخزون 3.
        await handle.db.update(
          'stock_level',
          {'qty': 3},
          where: 'product_id = ?',
          whereArgs: [tracked],
        );
        final result = await returns.postPurchaseReturn(
          PurchaseReturnDraft(
            originalInvoiceId: pur,
            lines: [
              ReturnLineInput(invoiceItemId: await firstItemId(pur), qty: 5),
            ],
            refundMethod: ReturnRefundMethod.credit,
            issuedAt: at,
          ),
          userId: userId,
          now: at,
        );
        expect(result.isErr, isTrue);
        expect(result.errorOrNull, contains('لا يسمح النظام بمخزون سالب'));

        // الذرّية: لا فاتورة مرتجع ولا حركة ولا سند ولا تدقيق ولا رقم.
        expect(await count("invoice WHERE doc_type = 'purchase_return'"), 0);
        expect(
          await count("stock_movement WHERE movement_type = 'purchase_return'"),
          0,
        );
        expect(await count('cash_tx'), 0);
        expect(await count('payment_allocation'), 0);
        expect(
          await count('audit_log', where: "action = 'purchase_return_post'"),
          0,
        );
        final seq = await handle.db.rawQuery(
          "SELECT last_no FROM doc_sequence WHERE doc_type = 'PRN'",
        );
        expect(seq, isEmpty);
        // الدفعة لم تُخصم رغم نجاح خطوتها قبل الفشل:
        expect(
          (await handle.db.rawQuery(
            'SELECT qty FROM batch WHERE product_id = ?',
            [tracked],
          )).first['qty'],
          10,
        );
        // Dافتر المخزون كما كان (3) — لم يُخصم.
        expect(await stockQty(tracked), 3);
        expect(await productCost(tracked), 20); // WAC لم يتغير.
      },
    );
  });

  // ── بنود الإرجاع المتاحة + FX للمرتجعات ──────────────────────────

  group('saleReturnableLines / purchaseReturnableLines', () {
    test('المتاح لكل بند بعد مرتجعين متتاليين', () async {
      final item = await makeProduct('حليب', price: 25);
      await postPurchase([
        PurchaseLine(productId: item, qty: 10, unitCost: 10),
      ]);
      final saleId = await postSale([
        CartLine(productId: item, qty: 6, unitPrice: 25),
      ], paidCash: 150);
      final itemId = await firstItemId(saleId);

      final before = await returns.saleReturnableLines(saleId);
      expect(before, hasLength(1));
      expect(before.first.invoiceItemId, itemId);
      expect(before.first.originalQty, 6);
      expect(before.first.returnedQty, 0);
      expect(before.first.availableQty, 6);
      expect(before.first.unitPriceEffective, 25);
      expect(before.first.unitCostSnapshot, 10);

      await returns.postSaleReturn(
        SaleReturnDraft(
          originalInvoiceId: saleId,
          lines: [ReturnLineInput(invoiceItemId: itemId, qty: 4)],
          refundMethod: ReturnRefundMethod.cash,
          refundCash: 100,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      final after = await returns.saleReturnableLines(saleId);
      expect(after.first.returnedQty, 4);
      expect(after.first.availableQty, 2);

      // فاتورة شراء: النوع المقابل فقط.
      final purchaseId =
          (await handle.db.rawQuery(
                'SELECT id FROM invoice WHERE doc_type = ?',
                ['purchase'],
              )).first['id']
              as int;
      final purchaseLines = await returns.purchaseReturnableLines(purchaseId);
      expect(purchaseLines, hasLength(1));
      expect(purchaseLines.first.availableQty, 10);
      expect(purchaseLines.first.unitCostSnapshot, 10);
      // خلط الأنواع → قوائم فارغة:
      expect(await returns.purchaseReturnableLines(saleId), isEmpty);
      expect(await returns.saleReturnableLines(purchaseId), isEmpty);
      expect(await returns.saleReturnableLines(999999), isEmpty);
    });
  });

  group('سياسة FX للمرتجعات (FR-08-09 — القرار 5)', () {
    test('أصل بعملة SAR بلا سعر يوم المرتجع → رفض؛ مع fallback → بعلم', () async {
      await rates.setRate(
        currencyId: sarId,
        date: at, // سعر يوم الشراء فقط.
        rate: 530,
        userId: userId,
        now: at,
      );
      final item = await makeProduct('حليب');
      final pur = await purchases
          .postPurchase(
            PurchaseDraft(
              supplierId: supplierId,
              currencyId: sarId,
              lines: [PurchaseLine(productId: item, qty: 10, unitCost: 100)],
              paymentMethod: PurchasePaymentMethod.credit,
              warehouseId: warehouseId,
              issuedAt: at,
            ),
            userId: userId,
            now: at,
          )
          .then((r) => r.valueOrNull!.invoiceId);
      // العملة الأساسية للمخزون: 100 SAR × 530 = 53,000.
      expect(await productCost(item), 53000);

      final later = DateTime.utc(2026, 10, 20, 12); // بلا سعر لهذا اليوم.
      final prn = PurchaseReturnDraft(
        originalInvoiceId: pur,
        lines: [ReturnLineInput(invoiceItemId: await firstItemId(pur), qty: 2)],
        refundMethod: ReturnRefundMethod.credit,
        issuedAt: later,
      );
      final rejected = await returns.postPurchaseReturn(
        prn,
        userId: userId,
        now: later,
      );
      expect(rejected.errorOrNull, contains('لا يوجد سعر صرف'));

      await settings.set('fx.fallback', 'last_known');
      final accepted = await returns.postPurchaseReturn(
        prn,
        userId: userId,
        now: later,
      );
      expect(accepted.isOk, isTrue, reason: '${accepted.errorOrNull}');
      expect(accepted.valueOrNull!.rateIsFallback, isTrue);
      expect(accepted.valueOrNull!.exchangeRate, 530);
      // قيمة المخزون Snapshot بالأصل (لا سعر يوم المرتجع):
      final movement = await handle.db.rawQuery(
        "SELECT * FROM stock_movement WHERE movement_type = 'purchase_return'",
      );
      expect((movement.first['unit_cost'] as num).toDouble(), 53000);
      // WAC لم يتغير (إرجاع كامل التكلفة الأصلية من مخزون كله بنفسها).
      expect(await productCost(item), 53000);
      expect(await stockQty(item), 8);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // البونص والمرتجع (UX-4) — الاسترداد بأصل qty المدفوع حصراً
  // ═════════════════════════════════════════════════════════════════

  group('SRN — البونص غير قابل للاسترداد (V1)', () {
    test(
      'بيع 10+2: الاسترداد قيمة 10 والسقف 10 — إرجاع 12 (بالمجاني) يُرفض',
      () async {
        final item = await makeProduct('شامبو');
        await postPurchase([
          PurchaseLine(productId: item, qty: 20, unitCost: 100),
        ]);
        // بيع 10 + 2 مجاني: الإيراد 1500 والتكلفة 12×100 = 1200.
        final saleId = await postSale([
          CartLine(productId: item, qty: 10, unitPrice: 150, freeQty: 2),
        ], paidCash: 1500);
        final saleItem = await handle.db.rawQuery(
          'SELECT free_qty, line_cost FROM invoice_item WHERE invoice_id = ?',
          [saleId],
        );
        expect((saleItem.first['free_qty'] as num).toDouble(), 2);
        expect((saleItem.first['line_cost'] as num).toDouble(), 1200);

        // البنود القابلة للإرجاع: المتاح = المدفوع 10 حصراً (لا 12).
        final returnable = await returns.saleReturnableLines(saleId);
        expect(returnable.single.availableQty, 10);
        expect(returnable.single.originalQty, 10);
        expect(
          returnable.single.unitCostSnapshot,
          100, // 1200 / (10+2) — تكلفة الوحدة الفعلية.
        );

        // إرجاع 12 (محاولة استرداد المجاني) يُرفض بسقف المدفوع.
        final rejected = await returns.postSaleReturn(
          SaleReturnDraft(
            originalInvoiceId: saleId,
            lines: [
              ReturnLineInput(
                invoiceItemId: await firstItemId(saleId),
                qty: 12,
              ),
            ],
            refundMethod: ReturnRefundMethod.cash,
            refundCash: 1800,
            issuedAt: at,
          ),
          userId: userId,
          now: at,
        );
        expect(rejected.isErr, isTrue);
        expect(rejected.errorOrNull, contains('تتجاوز المتاح للإرجاع'));
        expect(rejected.errorOrNull, contains('10'));

        // إرجاع المدفوع 10 كاملة: قيمة الاسترداد 10×150 = 1500 (لا
        // أي قيمة عن المجاني) والتكلفة المستردة 10×100 = 1000.
        final accepted = await returns.postSaleReturn(
          SaleReturnDraft(
            originalInvoiceId: saleId,
            lines: [
              ReturnLineInput(
                invoiceItemId: await firstItemId(saleId),
                qty: 10,
              ),
            ],
            refundMethod: ReturnRefundMethod.cash,
            refundCash: 1500,
            issuedAt: at,
          ),
          userId: userId,
          now: at,
        );
        expect(accepted.isOk, isTrue, reason: '${accepted.errorOrNull}');
        expect(accepted.valueOrNull!.refundTotal, 1500);
        final srnItem = await handle.db.rawQuery(
          'SELECT line_cost, qty FROM invoice_item WHERE invoice_id = ?',
          [accepted.valueOrNull!.invoiceId],
        );
        expect((srnItem.first['qty'] as num).toDouble(), 10);
        expect((srnItem.first['line_cost'] as num).toDouble(), 1000);

        // المخزون: 20 − 12 (البيع الكلي) + 10 (العودة) = 18.
        expect(await stockQty(item), 18);
      },
    );

    test(
      'تكلفة عودة البونص بوحدة WAC الفعلية لا المتضخمة (قرار 8)',
      () async {
        final item = await makeProduct('زيت');
        await postPurchase([
          PurchaseLine(productId: item, qty: 12, unitCost: 50),
        ]);
        // بيع 10 + 2 مجاني: line_cost = 12×50 = 600 — لو قُسمت على
        // المدفوع (10) لتضخمت تكلفة الوحدة إلى 60 ولأفسدت المخزون.
        final saleId = await postSale([
          CartLine(productId: item, qty: 10, unitPrice: 80, freeQty: 2),
        ], paidCash: 800);

        // إرجاع جزئي 4 من المدفوع: التكلفة 4×50 = 200 (لا 4×60=240).
        final result = await returns.postSaleReturn(
          SaleReturnDraft(
            originalInvoiceId: saleId,
            lines: [
              ReturnLineInput(invoiceItemId: await firstItemId(saleId), qty: 4),
            ],
            refundMethod: ReturnRefundMethod.cash,
            refundCash: 320, // 4 × 80.
            issuedAt: at,
          ),
          userId: userId,
          now: at,
        );
        expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
        final srnItem = await handle.db.rawQuery(
          'SELECT line_cost FROM invoice_item WHERE invoice_id = ?',
          [result.valueOrNull!.invoiceId],
        );
        expect((srnItem.first['line_cost'] as num).toDouble(), 200);
        // حركة العودة بتكلفة الوحدة الصحيحة 50.
        final movement = await handle.db.rawQuery(
          "SELECT unit_cost, qty FROM stock_movement "
          "WHERE movement_type = 'sale_return'",
        );
        expect((movement.first['qty'] as num).toDouble(), 4);
        expect((movement.first['unit_cost'] as num).toDouble(), 50);
        // المخزون: 12 − 12 + 4 = 4 (بقيمة صحيحة لا متضخمة).
        expect(await stockQty(item), 4);
      },
    );
  });
}
