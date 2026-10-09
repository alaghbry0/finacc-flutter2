/// اختبارات بونص الشراء (موجة R16-a — دعم كامل للمشتريات): **القرار
/// التحاسبي الموثّق**: المستلم الكلي = qty + freeQty (الدفعة الواردة
/// وstock_level وحركة المخزون بالكلي) و**WAC = إجمالي التكلفة ÷
/// المستلم الكلي** — البونص يخفّض التكلفة الوحدوية (المحاكاة الملزمة:
/// شراء 10+2 مجاني بتكلفة 1200 → دفعة 12 وحدة بوحدة تكلفة 100)،
/// والمورد يُستحق من qty المدفوعة حصراً (total/due بلا أثر للبونص) —
/// مرآة «المنصرف الكلي» للبيع. ويغطي خلط WAC، والمرتجع Snapshot
/// (تكلفة الوحدة = line_cost ÷ الكلي)، وحياد التسعير النقي.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/purchase_repository.dart';
import 'package:mobile_app/data/repositories/return_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/data/repositories/supplier_repository.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:mobile_app/domain/models/purchase.dart';
import 'package:mobile_app/domain/services/purchase_pricing.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;
  late PurchaseRepository purchases;
  late ReturnRepository returns;
  late ItemRepository items;
  late SupplierRepository suppliers;
  late SettingsRepository settings;
  late int warehouseId;
  late int userId;
  late int baseCurrencyId;
  late int supplierId;
  final at = DateTime.utc(2026, 10, 6, 12);

  setUp(() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    purchases = PurchaseRepository(handle.db);
    returns = ReturnRepository(handle.db);
    items = ItemRepository(handle.db);
    suppliers = SupplierRepository(handle.db);
    settings = SettingsRepository(handle.db);
    warehouseId =
        (await handle.db.rawQuery('SELECT id FROM warehouse LIMIT 1'))
            .first['id'] as int;
    userId =
        (await handle.db.rawQuery('SELECT id FROM app_user LIMIT 1'))
            .first['id'] as int;
    baseCurrencyId =
        (await handle.db.rawQuery('SELECT id FROM currency WHERE is_base = 1'))
            .first['id'] as int;
    final supplierResult = await suppliers.createSupplier(
      SupplierDraft(name: 'مورد البونص'),
      userId: userId,
      now: at,
    );
    supplierId = supplierResult.valueOrNull!;
  });

  tearDown(() async {
    await handle.close();
  });

  Future<int> makeProduct(
    String name, {
    double cost = 0,
    double qty = 0,
    bool tracked = false,
  }) async {
    final result = await items.createItem(
      ItemDraft(
        name: name,
        costPrice: cost,
        openingQty: qty,
        trackBatches: tracked,
        prices: [ItemPrice(currencyId: baseCurrencyId, price: 100)],
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
  }) => PurchaseDraft(
    supplierId: supplierId,
    currencyId: baseCurrencyId,
    lines: lines,
    paidCash: paidCash,
    paymentMethod: method,
    warehouseId: warehouseId,
    issuedAt: at,
  );

  Future<int> firstItemId(int invoiceId) async {
    final rows = await handle.db.rawQuery(
      'SELECT id FROM invoice_item WHERE invoice_id = ? ORDER BY id LIMIT 1',
      [invoiceId],
    );
    return rows.first['id'] as int;
  }

  // ── التسعير النقي: حياد تام للبونص ───────────────────────────────

  group('PurchasePricing — البونص سلامة حصراً (مرآة البيع)', () {
    test('نفس البنود ببونص وبلا بونص: كل الإجماليات متطابقة حرفياً', () {
      final without = PurchasePricing.priceCart([
        PurchaseLine(productId: 1, qty: 10, unitCost: 120),
      ]);
      final withBonus = PurchasePricing.priceCart([
        PurchaseLine(productId: 1, qty: 10, unitCost: 120, freeQty: 2),
      ]);
      expect(withBonus.totals.subtotal, without.totals.subtotal);
      expect(withBonus.totals.grandTotal, without.totals.grandTotal);
      expect(withBonus.totals.itemsCount, without.totals.itemsCount);
      expect(withBonus.lines.single.netFinal, without.lines.single.netFinal);
      expect(withBonus.lines.single.unitCostEffective, 120);
    });

    test('validateCart يرفض بونص سالباً وأدق من ثلاث منازل برسالة تحدد البند',
        () {
      expect(
        PurchasePricing.validateCart([
          PurchaseLine(productId: 1, qty: 1, unitCost: 10, freeQty: -1),
        ]),
        contains('كمية بونص البند 1 لا يمكن أن تكون سالبة'),
      );
      expect(
        PurchasePricing.validateCart([
          PurchaseLine(productId: 1, qty: 1, unitCost: 10, freeQty: 0.0005),
        ]),
        contains('لا تقبل دقة أعلى من ثلاث منازل'),
      );
      // السليم يمر (ثالث منزلة كاملة).
      expect(
        PurchasePricing.validateCart([
          PurchaseLine(productId: 1, qty: 1, unitCost: 10, freeQty: 1.005),
        ]),
        isNull,
      );
    });
  });

  // ── المحاكاة الملزمة: 10+2 مجاني بتكلفة 1200 → 12 وحدة WAC=100 ──

  group('postPurchase — المستلم الكلي وWAC المخفوض (قرار R16-a)', () {
    test('شراء 10+2 مجاني بتكلفة 1200: رصيد 12 وحركة +12 وWAC=100 والمورد 1200',
        () async {
      final item = await makeProduct('شامبو بونص');
      final result = await purchases.postPurchase(
        draft(
          [PurchaseLine(productId: item, qty: 10, unitCost: 120, freeQty: 2)],
          paidCash: 1200,
          method: PurchasePaymentMethod.cash,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      final receipt = result.valueOrNull!;

      // المورد يُستحق من المدفوع حصراً — كأن البونص غير موجود إطلاقاً.
      expect(receipt.totals.subtotal, 1200);
      expect(receipt.totals.grandTotal, 1200);
      expect(receipt.remainingCredit, 0);

      // رأس الفاتورة: الصافي بالمدفوع وقيمة المخزون الوارد = 1200.
      final invoice = await row('invoice');
      expect(invoice['total'], 1200);
      expect(invoice['total_base'], 1200);
      expect(invoice['cost_total'], 1200);

      // السطر: qty=10 وfree_qty=2 وline_cost = الكلي × 100 = 1200.
      final line = await row('invoice_item');
      expect(line['qty'], 10);
      expect((line['free_qty'] as num?)?.toDouble(), 2);
      expect(line['line_total'], 1200);
      expect(line['line_cost'], 1200);

      // المخزون استقبل الكلي: 12 وحدة بحركة موجبة بتكلفة 100 موسومة
      // بالبونص (تتبع/تدقيق).
      expect(await stockQty(item), 12);
      final movement = await row(
        'stock_movement',
        where: "product_id = $item AND movement_type = 'purchase'",
      );
      expect((movement['qty'] as num).toDouble(), 12);
      expect(movement['unit_cost'], 100);
      expect(movement['notes'] as String, contains('بونص: 2'));

      // **WAC = إجمالي التكلفة ÷ المستلم الكلي = 1200 ÷ 12 = 100** —
      // البونص خفّض التكلفة الوحدوية من 120 إلى 100.
      expect(await productCost(item), 100);
    });

    test('متتبع بدفعة: الدفعة الواردة تستقبل 12 وحدة بتكلفة 100', () async {
      final item = await makeProduct('دواء بونص', tracked: true);
      final result = await purchases.postPurchase(
        draft([
          PurchaseLine(
            productId: item,
            qty: 10,
            unitCost: 120,
            freeQty: 2,
            batchNo: 'BON-2027',
            expiryDate: DateTime(2027, 6, 1),
          ),
        ]),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

      final batch = await row('batch');
      expect((batch['qty'] as num).toDouble(), 12, reason: 'الدفعة بالكلي');
      expect(batch['cost_price'], 100, reason: 'تكلفة الوحدة الوحدوية');
      expect(await stockQty(item), 12);
      expect(await productCost(item), 100);
      // السطر موصول بالدفعة وملاحظته تحمل البونص.
      final line = await row('invoice_item');
      expect(line['batch_id'], batch['id']);
      expect(line['notes'] as String, contains('بونص: 2'));
    });

    test('خلط WAC: قديم 5×80 + وارد 12×100 → WAC = 1600/17 = 94.1176', () async {
      final item = await makeProduct('خلط بونص', cost: 80, qty: 5);
      final result = await purchases.postPurchase(
        draft([PurchaseLine(productId: item, qty: 10, unitCost: 120, freeQty: 2)]),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');

      expect(await stockQty(item), 17);
      expect(await productCost(item), closeTo(94.1176, 0.00005));
    });

    test('بونص كسري: 0.5 مجاني يدخل الكلي بدقة NUMERIC(12,3)', () async {
      final item = await makeProduct('بونص كسري');
      final result = await purchases.postPurchase(
        draft([PurchaseLine(productId: item, qty: 4, unitCost: 100, freeQty: 0.5)]),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      expect(await stockQty(item), 4.5);
      // 400 ÷ 4.5 = 88.8889.
      expect(await productCost(item), closeTo(88.8889, 0.00005));
    });

    test('آجل ببونص: دين المورد من المدفوع حصراً (لا تضخيم بال مجاني)', () async {
      final item = await makeProduct('آجل بونص');
      final result = await purchases.postPurchase(
        draft([PurchaseLine(productId: item, qty: 10, unitCost: 120, freeQty: 2)]),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      final invoice = await row('invoice');
      expect(invoice['pay_status'], 'credit');
      expect(invoice['total'], 1200);
      expect(invoice['due_amount'], 1200, reason: 'الدين بالمدفوع فقط');
      expect(invoice['paid_amount'], 0);
    });
  });

  // ── المرتجع: Snapshot تكلفة الوحدة = line_cost ÷ المستلم الكلي ────

  group('postPurchaseReturn — بونص الشراء (مرآة قرار 8 للبيع)', () {
    test('مرتجع وحدة من شراء 10+2: تكلفة الوحدة 100 (1200÷12) والرد 120', () async {
      final item = await makeProduct('مرتجع بونص');
      final purchase = await purchases.postPurchase(
        draft([PurchaseLine(productId: item, qty: 10, unitCost: 120, freeQty: 2)]),
        userId: userId,
        now: at,
      );
      expect(purchase.isOk, isTrue);
      final purchaseId = purchase.valueOrNull!.invoiceId;

      final returnResult = await returns.postPurchaseReturn(
        PurchaseReturnDraft(
          originalInvoiceId: purchaseId,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(purchaseId), qty: 1),
          ],
          refundMethod: ReturnRefundMethod.credit,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(returnResult.isOk, isTrue, reason: '${returnResult.errorOrNull}');

      // الرد النقدي للمورد من وحدة مدفوعة واحدة = 120 (unit_price الأصلي).
      expect(returnResult.valueOrNull!.refundTotal, 120);
      // تكلفة الوحدة المنقولة Snapshot = 1200 ÷ 12 = 100 — الوحدات تخرج
      // بقيمتها الصحيحة بلا تضخيم.
      final returnLine = await row(
        'invoice_item',
        where: "invoice_id = (SELECT id FROM invoice WHERE doc_type = 'purchase_return')",
      );
      expect(returnLine['line_cost'], 100);
      // المخزون 12 − 1 = 11 وWAC يبقى 100.
      expect(await stockQty(item), 11);
      expect(await productCost(item), 100);
    });

    test('سقف الإرجاع = المدفوع حصراً: 11 وحدة من 10+2 مرفوضة', () async {
      final item = await makeProduct('سقف بونص');
      final purchase = await purchases.postPurchase(
        draft([PurchaseLine(productId: item, qty: 10, unitCost: 120, freeQty: 2)]),
        userId: userId,
        now: at,
      );
      final purchaseId = purchase.valueOrNull!.invoiceId;

      final returnResult = await returns.postPurchaseReturn(
        PurchaseReturnDraft(
          originalInvoiceId: purchaseId,
          lines: [
            ReturnLineInput(invoiceItemId: await firstItemId(purchaseId), qty: 11),
          ],
          refundMethod: ReturnRefundMethod.credit,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(returnResult.isErr, isTrue);
      expect(returnResult.errorOrNull, contains('تتجاوز المتاح للإرجاع'));
      // والمخزون لم يُمسّ (ذرّية).
      expect(await stockQty(item), 12);
    });
  });

  // ── غياب البونص: سلوك ما قبل R16-a حرفياً ────────────────────────

  test('بلا بونص: السلوك مطابق لما قبل R16-a (free_qty=0 وحياد كامل)', () async {
    final item = await makeProduct('بلا بونص');
    final result = await purchases.postPurchase(
      draft(
        [PurchaseLine(productId: item, qty: 4, unitCost: 25)],
        paidCash: 100,
        method: PurchasePaymentMethod.cash,
      ),
      userId: userId,
      now: at,
    );
    expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
    final line = await row('invoice_item');
    expect((line['free_qty'] as num?)?.toDouble(), 0);
    expect(line['line_cost'], 100);
    expect(line['notes'], isNull, reason: 'لا وسم بونص');
    expect(await stockQty(item), 4);
    expect(await productCost(item), 25);
    final movement = await row(
      'stock_movement',
      where: "product_id = $item AND movement_type = 'purchase'",
    );
    expect((movement['qty'] as num).toDouble(), 4);
    expect(movement['unit_cost'], 25);
    expect(movement['notes'] as String, isNot(contains('بونص')));
    // المفتاح المتقاعد غير موجود أصلاً (هجرة v6).
    expect(await settings.raw('sale.free_qty'), isNull);
  });
}
