/// اختبارات إبطال الفاتورة (FR-02-15 — R17-c): **حركات معاكسة كاملة**
/// داخل معاملة واحدة — لا حذف فيزيائي لأي صف:
/// - بيع: المخزون (ودفعاته) يعود، سند الإصدار يُبطَل (is_voided=1 +
///   سطر معاكس بـ reversal_of)، تخصيصات السندات اللاحقة تُسترد بحركة
///   حقيقية، رصيد العميل يعود (status='void' يستبعه من صيغة FR-03-02)،
///   قيد audit موجود، والرقم لا يُعاد.
/// - شراء: المستلم الكلي (qty + freeQty) يخرج، WAC يعود بصيغة PRN،
///   الصندوق يعود، دين المورد يسقط، ورفض قطعي عند نقص المخزون
///   (5.4-5) أو وجود مرتجعات مرتبطة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/cash_repository.dart';
import 'package:mobile_app/data/repositories/customer_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/purchase_repository.dart';
import 'package:mobile_app/data/repositories/return_repository.dart';
import 'package:mobile_app/data/repositories/sale_repository.dart';
import 'package:mobile_app/data/repositories/supplier_repository.dart';
import 'package:mobile_app/domain/models/cash.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:mobile_app/domain/models/purchase.dart';
import 'package:mobile_app/domain/models/sale.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;
  late SaleRepository sales;
  late PurchaseRepository purchases;
  late ReturnRepository returns;
  late ItemRepository items;
  late CustomerRepository customers;
  late SupplierRepository suppliers;
  late CashRepository cash;
  late int warehouseId;
  late int userId;
  late int baseCurrencyId;
  late int defaultCashboxId;
  final at = DateTime.utc(2026, 10, 6, 12);
  final voidAt = DateTime.utc(2026, 10, 6, 15);

  setUp(() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    sales = SaleRepository(handle.db);
    purchases = PurchaseRepository(handle.db);
    returns = ReturnRepository(handle.db);
    items = ItemRepository(handle.db);
    customers = CustomerRepository(handle.db);
    suppliers = SupplierRepository(handle.db);
    cash = CashRepository(handle.db);
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

  Future<int> makeProduct(
    String name, {
    double cost = 0,
    double price = 0,
    double qty = 0,
    bool tracked = false,
  }) async {
    final result = await items.createItem(
      ItemDraft(
        name: name,
        costPrice: cost,
        openingQty: qty,
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

  Future<int> makeSupplier(String name) async {
    final result = await suppliers.createSupplier(
      SupplierDraft(name: name),
      userId: userId,
      now: at,
    );
    return result.valueOrNull!;
  }

  Future<double> boxBalance() async {
    final boxes = await cash.listBoxes();
    final box = boxes.firstWhere((b) => b.box.id == defaultCashboxId);
    return box.nativeBalance;
  }

  Future<double> customerBalance(int customerId) =>
      customers.balanceInCurrency(customerId, baseCurrencyId);

  Future<double> stockQty(int productId) async {
    final rows = await handle.db.rawQuery(
      'SELECT qty FROM stock_level WHERE product_id = ? AND warehouse_id = ?',
      [productId, warehouseId],
    );
    return rows.isEmpty ? 0 : (rows.first['qty'] as num?)?.toDouble() ?? 0;
  }

  Future<double> productCost(int productId) async {
    final rows = await handle.db.rawQuery(
      'SELECT cost_price FROM product WHERE id = ?',
      [productId],
    );
    return (rows.first['cost_price'] as num?)?.toDouble() ?? 0;
  }

  Future<Map<String, Object?>> row(String table, {String? where}) async {
    final rows = await handle.db.query(table, where: where, limit: 1);
    return rows.first;
  }

  Future<List<Map<String, Object?>>> rows(
    String table, {
    String? where,
    String? orderBy,
  }) => handle.db.query(table, where: where, orderBy: orderBy);

  SaleDraft saleDraft(
    List<CartLine> lines, {
    double paidCash = 0,
    int? customerId,
    SalePaymentMethod method = SalePaymentMethod.cash,
  }) => SaleDraft(
    customerId: customerId,
    currencyId: baseCurrencyId,
    lines: lines,
    paidCash: paidCash,
    paymentMethod: method,
    warehouseId: warehouseId,
    issuedAt: at,
  );

  PurchaseDraft purchaseDraft(
    List<PurchaseLine> lines, {
    double paidCash = 0,
    required int supplierId,
    PurchasePaymentMethod method = PurchasePaymentMethod.cash,
  }) => PurchaseDraft(
    supplierId: supplierId,
    currencyId: baseCurrencyId,
    lines: lines,
    paidCash: paidCash,
    paymentMethod: method,
    warehouseId: warehouseId,
    issuedAt: at,
  );

  // ── إبطال بيعة مختلطة: كل شيء يعود لما قبلها ─────────────────────

  group('voidInvoice (بيع) — الحركات المعاكسة الكاملة', () {
    test('بيعة مختلطة (60 نقد + 40 آجل): مخزون وصندوق ورصيد العميل تعود، '
        'status=void، audit، وسند الإصدار معكوس بـ reversal_of', () async {
      final pen = await makeProduct('قلم', cost: 10, price: 25, qty: 50);
      final customer = await makeCustomer('عميل الإبطال');
      final result = await sales.postSale(
        saleDraft(
          [CartLine(productId: pen, qty: 4, unitPrice: 25)],
          paidCash: 60,
          customerId: customer,
          method: SalePaymentMethod.mixed,
        ),
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      final invoiceId = result.valueOrNull!.invoiceId;

      // ما قبل الإبطال: المخزون نقص والصندوق زاد والعميل استحق.
      expect(await stockQty(pen), 46);
      expect(await boxBalance(), 60);
      expect(await customerBalance(customer), 40);

      final voidResult = await sales.voidInvoice(
        invoiceId,
        userId: userId,
        reason: 'خطأ في الإدخال',
        now: voidAt,
      );
      expect(voidResult.isOk, isTrue, reason: '${voidResult.errorOrNull}');
      final receipt = voidResult.valueOrNull!;
      expect(receipt.invoiceNo, 'INV-2026-00001');
      expect(receipt.docType, 'sale');
      expect(receipt.cashReversalCount, 1);
      expect(receipt.reversedCash, 60);
      expect(receipt.reversedQty, 4);

      // (أ) المخزون عاد لما قبل الفاتورة + حركة عودة موجبة.
      expect(await stockQty(pen), 50);
      final returnMoves = await rows(
        'stock_movement',
        where: "movement_type = 'sale_return' AND ref_id = $invoiceId",
      );
      expect(returnMoves, hasLength(1));
      expect((returnMoves.first['qty'] as num).toDouble(), 4);
      expect((returnMoves.first['unit_cost'] as num).toDouble(), 10);
      expect(
        returnMoves.first['notes'] as String,
        allOf(contains('إبطال'), contains('INV-2026-00001')),
      );

      // (ب) الصندوق عاد: سند الإصدار ملغى (is_voided=1) وسطر معاكس
      //     حي مربوط به عبر reversal_of (نمط voidMovement حرفياً).
      expect(await boxBalance(), 0);
      final issuance = await row(
        'cash_tx',
        where:
            "ref_type = 'invoice' AND ref_id = $invoiceId "
            'AND voucher_no IS NULL AND is_voided = 1',
      );
      final reversal = await row(
        'cash_tx',
        where: 'reversal_of = ${issuance['id']}',
      );
      expect(issuance['tx_type'], 'receipt');
      expect((issuance['amount'] as num).toDouble(), 60);
      expect(reversal['tx_type'], 'payment');
      expect((reversal['amount'] as num).toDouble(), 60);
      expect(reversal['is_voided'], 0);
      expect(reversal['reversal_of'], issuance['id']);
      expect(
        reversal['description'] as String,
        contains('إبطال تحصيل INV-2026-00001'),
      );
      expect(reversal['description'] as String, contains('خطأ في الإدخال'));
      // رابط التخصيص حُذف (رابط لا حركة مالية — نمط voidMovement).
      expect(
        await handle.db.rawQuery(
          'SELECT COUNT(*) AS n FROM payment_allocation WHERE invoice_id = ?',
          [invoiceId],
        ),
        [
          {'n': 0},
        ],
      );

      // (ج) رصيد العميل عاد (الفاتورة مستبعدة من صيغة FR-03-02).
      expect(await customerBalance(customer), 0);

      // (د) الحالة void والسجل باقٍ — لا حذف فيزيائي.
      final invoice = await row('invoice', where: 'id = $invoiceId');
      expect(invoice['status'], 'void');
      expect(invoice['invoice_no'], 'INV-2026-00001');
      expect(invoice['total'], 100); // لقطة تاريخية بلا مساس.

      // (هـ) قيد التدقيق موجود برقم الفاتورة والسبب.
      final audit = await row(
        'audit_log',
        where: "action = 'void_invoice' AND entity_id = $invoiceId",
      );
      expect(audit['entity'], 'invoice');
      expect(audit['user_id'], userId);
      expect(audit['details'] as String, contains('INV-2026-00001'));
      expect(audit['details'] as String, contains('reason=خطأ في الإدخال'));
      expect(audit['details'] as String, contains('reversed_cash=60'));
    });

    test('بيعة آجلة سُدِّدت بسند RVT: الإبطال يسترد المبلغ بحركة حقيقية '
        '(الصندوق يصفّي) ويحذف رابط التخصيص', () async {
      final pen = await makeProduct('دفتر', cost: 4, price: 10, qty: 30);
      final customer = await makeCustomer('عميل السند');
      final sale = await sales.postSale(
        saleDraft(
          [CartLine(productId: pen, qty: 10, unitPrice: 10)],
          paidCash: 0,
          customerId: customer,
          method: SalePaymentMethod.credit,
        ),
        userId: userId,
        now: at,
      );
      expect(sale.isOk, isTrue, reason: '${sale.errorOrNull}');
      final invoiceId = sale.valueOrNull!.invoiceId;

      // سند قبض RVT بتخصيص FIFO على الفاتورة.
      final voucher = await cash.createVoucher(
        VoucherDraft(
          partyType: VoucherPartyType.customer,
          partyId: customer,
          cashboxId: defaultCashboxId,
          amount: 100,
          currencyId: baseCurrencyId,
          txDate: at,
          allocateFifo: true,
        ),
        userId: userId,
        now: at,
      );
      expect(voucher.isOk, isTrue, reason: '${voucher.errorOrNull}');
      expect(await boxBalance(), 100);
      expect(await customerBalance(customer), 0);

      final voidResult = await sales.voidInvoice(
        invoiceId,
        userId: userId,
        now: voidAt,
      );
      expect(voidResult.isOk, isTrue, reason: '${voidResult.errorOrNull}');
      expect(voidResult.valueOrNull!.voucherRefundCount, 1);
      expect(voidResult.valueOrNull!.reversedCash, 100);

      // الصندوق صفّى: سند القبض حي (+100) وحركة الاسترداد الحقيقية
      // (−100) — لا is_voided ولا reversal_of عليها (تُحسب في الأرصدة).
      expect(await boxBalance(), 0);
      final refund = await row(
        'cash_tx',
        where:
            "tx_type = 'payment' AND ref_type = 'invoice' "
            'AND ref_id = $invoiceId AND reversal_of IS NULL '
            'AND is_voided = 0',
      );
      expect((refund['amount'] as num).toDouble(), 100);
      expect(
        refund['description'] as String,
        contains(voucher.valueOrNull!.voucherNo),
      );
      expect(
        await handle.db.rawQuery(
          'SELECT COUNT(*) AS n FROM payment_allocation WHERE invoice_id = ?',
          [invoiceId],
        ),
        [
          {'n': 0},
        ],
      );
      // رصيد العميل صفر والفاتورة ملغاة.
      expect(await customerBalance(customer), 0);
      final invoice = await row('invoice', where: 'id = $invoiceId');
      expect(invoice['status'], 'void');
    });

    test('متتبع بدفعة: الإبطال يعيد الكمية لدفعة البيع الأصلية', () async {
      final drug = await makeProduct(
        'دواء متتبع',
        cost: 5,
        price: 20,
        qty: 10,
        tracked: true,
      );
      final sale = await sales.postSale(
        saleDraft([
          CartLine(productId: drug, qty: 3, unitPrice: 20),
        ], paidCash: 60),
        userId: userId,
        now: at,
      );
      expect(sale.isOk, isTrue, reason: '${sale.errorOrNull}');
      final invoiceId = sale.valueOrNull!.invoiceId;

      // الدفعة الافتتاحية نقصت 3.
      final batchBefore = await row('batch');
      final batchId = batchBefore['id'] as int;
      expect((batchBefore['qty'] as num).toDouble(), 7);

      final voidResult = await sales.voidInvoice(
        invoiceId,
        userId: userId,
        now: voidAt,
      );
      expect(voidResult.isOk, isTrue, reason: '${voidResult.errorOrNull}');

      final batchAfter = await row('batch', where: 'id = $batchId');
      expect((batchAfter['qty'] as num).toDouble(), 10);
      expect(await stockQty(drug), 10);
      // حركة العودة موسومة بالدفعة (نمط SRN).
      final moves = await rows(
        'stock_movement',
        where: "movement_type = 'sale_return' AND ref_id = $invoiceId",
      );
      expect(moves, hasLength(1));
      expect(moves.first['notes'] as String, contains('رقم الدفعة'));
    });

    test(
      'بيعة ببونص: الإبطال يعيد المنصرف الكلي (المدفوع + المجاني)',
      () async {
        final soap = await makeProduct('شامبو', cost: 8, price: 20, qty: 20);
        final sale = await sales.postSale(
          saleDraft([
            CartLine(productId: soap, qty: 5, unitPrice: 20, freeQty: 2),
          ], paidCash: 100),
          userId: userId,
          now: at,
        );
        expect(sale.isOk, isTrue, reason: '${sale.errorOrNull}');
        expect(await stockQty(soap), 13); // المنصرف الكلي 7.

        final voidResult = await sales.voidInvoice(
          sale.valueOrNull!.invoiceId,
          userId: userId,
          now: voidAt,
        );
        expect(voidResult.isOk, isTrue, reason: '${voidResult.errorOrNull}');
        expect(voidResult.valueOrNull!.reversedQty, 7);
        expect(await stockQty(soap), 20);
      },
    );
  });

  // ── حارسا البيع ───────────────────────────────────────────────────

  group('voidInvoice (بيع) — الحارسان', () {
    test('فاتورة عليها مرتجع مكتمل → رفض برسالة تسمّي المرتجعات', () async {
      final pen = await makeProduct('قلم مرتجع', cost: 1, price: 5, qty: 50);
      final sale = await sales.postSale(
        saleDraft([
          CartLine(productId: pen, qty: 4, unitPrice: 5),
        ], paidCash: 20),
        userId: userId,
        now: at,
      );
      final invoiceId = sale.valueOrNull!.invoiceId;
      final itemRow = await row(
        'invoice_item',
        where: 'invoice_id = $invoiceId',
      );
      final returnResult = await returns.postSaleReturn(
        SaleReturnDraft(
          originalInvoiceId: invoiceId,
          lines: [ReturnLineInput(invoiceItemId: itemRow['id'] as int, qty: 1)],
          refundMethod: ReturnRefundMethod.cash,
          refundCash: 5,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(returnResult.isOk, isTrue, reason: '${returnResult.errorOrNull}');

      final voidResult = await sales.voidInvoice(
        invoiceId,
        userId: userId,
        now: voidAt,
      );
      expect(voidResult.isErr, isTrue);
      expect(voidResult.errorOrNull, contains('مرتجعات مكتملة'));
      // لا شيء تغيّر: الحالة مكتملة والمخزون كما تركه المرتجع (50−4+1=47).
      final invoice = await row('invoice', where: 'id = $invoiceId');
      expect(invoice['status'], 'completed');
      expect(await stockQty(pen), 47);
    });

    test('إبطال ملغاة سابقاً → رفض «لا تُبطل مرتين»', () async {
      final pen = await makeProduct('قلم مزدوج', cost: 1, price: 5, qty: 50);
      final sale = await sales.postSale(
        saleDraft([
          CartLine(productId: pen, qty: 1, unitPrice: 5),
        ], paidCash: 5),
        userId: userId,
        now: at,
      );
      final invoiceId = sale.valueOrNull!.invoiceId;
      final first = await sales.voidInvoice(
        invoiceId,
        userId: userId,
        now: voidAt,
      );
      expect(first.isOk, isTrue, reason: '${first.errorOrNull}');

      final second = await sales.voidInvoice(
        invoiceId,
        userId: userId,
        now: voidAt,
      );
      expect(second.isErr, isTrue);
      expect(second.errorOrNull, contains('ملغاة سابقاً'));
    });

    test('الرقم لا يُعاد: الفاتورة بعد الإبطال تأخذ رقماً أعلى', () async {
      final pen = await makeProduct('قلم الترقيم', cost: 1, price: 5, qty: 50);
      final first = await sales.postSale(
        saleDraft([
          CartLine(productId: pen, qty: 1, unitPrice: 5),
        ], paidCash: 5),
        userId: userId,
        now: at,
      );
      expect(first.valueOrNull!.invoiceNo, 'INV-2026-00001');
      expect(
        (await sales.voidInvoice(
          first.valueOrNull!.invoiceId,
          userId: userId,
          now: voidAt,
        )).isOk,
        isTrue,
      );

      final second = await sales.postSale(
        saleDraft([
          CartLine(productId: pen, qty: 1, unitPrice: 5),
        ], paidCash: 5),
        userId: userId,
        now: voidAt,
      );
      expect(second.valueOrNull!.invoiceNo, 'INV-2026-00002');
    });
  });

  // ── إبطال الشراء ──────────────────────────────────────────────────

  group('voidInvoice (شراء) — الوارد وWAC والصندوق', () {
    test('شراء نقدي ببونص (10+2 بتكلفة 1200): المستلم الكلي 12 يخرج، '
        'WAC يعود، الصندوق يعود، status=void، وaudit موجود', () async {
      final supplier = await makeSupplier('مورد الإبطال');
      final item = await makeProduct('شامبو شراء');
      final purchase = await purchases.postPurchase(
        purchaseDraft(
          [PurchaseLine(productId: item, qty: 10, unitCost: 120, freeQty: 2)],
          paidCash: 1200,
          supplierId: supplier,
        ),
        userId: userId,
        now: at,
      );
      expect(purchase.isOk, isTrue, reason: '${purchase.errorOrNull}');
      final invoiceId = purchase.valueOrNull!.invoiceId;

      // ما قبل الإبطال (قرار R16-a): 12 وحدة WAC=100 والصندوق −1200.
      expect(await stockQty(item), 12);
      expect(await productCost(item), 100);
      expect(await boxBalance(), -1200);

      final voidResult = await purchases.voidInvoice(
        invoiceId,
        userId: userId,
        reason: 'إرجاع كامل للمورد',
        now: voidAt,
      );
      expect(voidResult.isOk, isTrue, reason: '${voidResult.errorOrNull}');
      final receipt = voidResult.valueOrNull!;
      expect(receipt.invoiceNo, 'PUR-2026-00001');
      expect(receipt.docType, 'purchase');
      expect(receipt.reversedQty, 12);
      expect(receipt.reversedCash, 1200);

      // المستلم الكلي خرج كاملاً (المدفوع + المجاني) وWAC صفر.
      expect(await stockQty(item), 0);
      expect(await productCost(item), 0);
      expect(await boxBalance(), 0);

      // حركة الخروج سالبة بالمستلم الكلي وبسعر Snapshot 100.
      final outMoves = await rows(
        'stock_movement',
        where: "movement_type = 'purchase_return' AND ref_id = $invoiceId",
      );
      expect(outMoves, hasLength(1));
      expect((outMoves.first['qty'] as num).toDouble(), -12);
      expect((outMoves.first['unit_cost'] as num).toDouble(), 100);
      expect(
        outMoves.first['notes'] as String,
        // نفس صيغة تأكيد البيع (السطر 238): الملاحظة تحمل رقم الفاتورة
        // ومؤشر الإبطال — الترتيب يتبع فرع التنفيذ (بلا دفعة تتبع).
        allOf(contains('إبطال'), contains('PUR-2026-00001')),
      );

      // سند الإصدار معكوس بنمط voidMovement (is_voided + reversal_of).
      final issuance = await row(
        'cash_tx',
        where:
            "ref_type = 'invoice' AND ref_id = $invoiceId "
            'AND voucher_no IS NULL AND is_voided = 1',
      );
      expect(issuance['tx_type'], 'payment');
      final reversal = await row(
        'cash_tx',
        where: 'reversal_of = ${issuance['id']}',
      );
      expect(reversal['tx_type'], 'receipt');
      expect((reversal['amount'] as num).toDouble(), 1200);

      // الحالة والتدقيق والدين (آجل معدوم أصلاً — نقدي).
      final invoice = await row('invoice', where: 'id = $invoiceId');
      expect(invoice['status'], 'void');
      final audit = await row(
        'audit_log',
        where: "action = 'void_invoice' AND entity_id = $invoiceId",
      );
      expect(audit['details'] as String, contains('PUR-2026-00001'));
      expect(audit['details'] as String, contains('reason=إرجاع كامل للمورد'));
    });

    test('شراء فوق مخزون قائم: WAC يعود لما قبل الفاتورة (صيغة PRN)', () async {
      final supplier = await makeSupplier('مورد الخلط');
      final item = await makeProduct('خلط إبطال', cost: 80, qty: 5);
      final purchase = await purchases.postPurchase(
        purchaseDraft(
          [PurchaseLine(productId: item, qty: 10, unitCost: 120)],
          paidCash: 1200,
          supplierId: supplier,
        ),
        userId: userId,
        now: at,
      );
      expect(purchase.isOk, isTrue, reason: '${purchase.errorOrNull}');
      expect(await stockQty(item), 15);
      expect(await productCost(item), closeTo(106.6667, 0.00005));

      final voidResult = await purchases.voidInvoice(
        purchase.valueOrNull!.invoiceId,
        userId: userId,
        now: voidAt,
      );
      expect(voidResult.isOk, isTrue, reason: '${voidResult.errorOrNull}');

      // (5×80 + 10×120)/15 − إبطال → 5 وحدات بتكلفة 80 كما كانت.
      expect(await stockQty(item), 5);
      expect(await productCost(item), closeTo(80, 0.001));
    });

    test('شراء آجل: دين المورد يسقط مع الإبطال', () async {
      final supplier = await makeSupplier('مورد الآجل');
      final item = await makeProduct('آجل إبطال');
      final purchase = await purchases.postPurchase(
        purchaseDraft(
          [PurchaseLine(productId: item, qty: 4, unitCost: 25)],
          paidCash: 0,
          supplierId: supplier,
          method: PurchasePaymentMethod.credit,
        ),
        userId: userId,
        now: at,
      );
      expect(purchase.isOk, isTrue, reason: '${purchase.errorOrNull}');
      // دين المورد 100 قبل الإبطال (صيغة FR-03-03).
      final before = await suppliers.balanceInCurrency(
        supplier,
        baseCurrencyId,
      );
      expect(before, 100);

      final voidResult = await purchases.voidInvoice(
        purchase.valueOrNull!.invoiceId,
        userId: userId,
        now: voidAt,
      );
      expect(voidResult.isOk, isTrue, reason: '${voidResult.errorOrNull}');
      expect(await suppliers.balanceInCurrency(supplier, baseCurrencyId), 0);
      expect(await stockQty(item), 0);
    });

    test('ما بِيع من الوارد لا يُبطَل شراؤه: نقص المخزون → رفض ذرّي', () async {
      final supplier = await makeSupplier('مورد المبيع');
      final item = await makeProduct('مبيع من الوارد');
      final purchase = await purchases.postPurchase(
        purchaseDraft(
          [PurchaseLine(productId: item, qty: 10, unitCost: 30)],
          paidCash: 300,
          supplierId: supplier,
        ),
        userId: userId,
        now: at,
      );
      expect(purchase.isOk, isTrue, reason: '${purchase.errorOrNull}');
      final invoiceId = purchase.valueOrNull!.invoiceId;

      // بِيع 4 من الوارد → المتاح 6 < المطلوب إخراجه 10.
      final sale = await sales.postSale(
        saleDraft([
          CartLine(productId: item, qty: 4, unitPrice: 50),
        ], paidCash: 200),
        userId: userId,
        now: at,
      );
      expect(sale.isOk, isTrue, reason: '${sale.errorOrNull}');
      expect(await stockQty(item), 6);
      final boxBefore = await boxBalance();

      final voidResult = await purchases.voidInvoice(
        invoiceId,
        userId: userId,
        now: voidAt,
      );
      expect(voidResult.isErr, isTrue);
      expect(voidResult.errorOrNull, contains('لا يمكن إبطال الفاتورة'));
      // ذرّية: لا شيء تغيّر.
      expect(await stockQty(item), 6);
      expect(await boxBalance(), boxBefore);
      final invoice = await row('invoice', where: 'id = $invoiceId');
      expect(invoice['status'], 'completed');
      expect(
        await handle.db.rawQuery(
          'SELECT COUNT(*) AS n FROM audit_log '
          "WHERE action = 'void_invoice' AND entity_id = ?",
          [invoiceId],
        ),
        [
          {'n': 0},
        ],
      );
    });

    test('شراء عليها مرتجع PRN مكتمل → رفض', () async {
      final supplier = await makeSupplier('مورد المرتجع');
      final item = await makeProduct('شراء مرتجع');
      final purchase = await purchases.postPurchase(
        purchaseDraft(
          [PurchaseLine(productId: item, qty: 10, unitCost: 30)],
          supplierId: supplier,
          method: PurchasePaymentMethod.credit,
        ),
        userId: userId,
        now: at,
      );
      final invoiceId = purchase.valueOrNull!.invoiceId;
      final itemRow = await row(
        'invoice_item',
        where: 'invoice_id = $invoiceId',
      );
      final returnResult = await returns.postPurchaseReturn(
        PurchaseReturnDraft(
          originalInvoiceId: invoiceId,
          lines: [ReturnLineInput(invoiceItemId: itemRow['id'] as int, qty: 1)],
          refundMethod: ReturnRefundMethod.credit,
          issuedAt: at,
        ),
        userId: userId,
        now: at,
      );
      expect(returnResult.isOk, isTrue, reason: '${returnResult.errorOrNull}');

      final voidResult = await purchases.voidInvoice(
        invoiceId,
        userId: userId,
        now: voidAt,
      );
      expect(voidResult.isErr, isTrue);
      expect(voidResult.errorOrNull, contains('مرتجعات شراء مكتملة'));
      expect(await stockQty(item), 9);
    });
  });
}
