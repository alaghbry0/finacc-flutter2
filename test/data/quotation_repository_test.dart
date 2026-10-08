/// اختبارات عروض الأسعار — FR-02-11 / AC-17:
/// إنشاء QTE بلا أي أثر مالي/مخزوني، القوائم والتفاصيل، الحالات
/// (sent/rejected)، والتحويل الذرّي إلى فاتورة بيع (بما فيه رفض التحويل
/// عند نقص المخزون وبقاء العرض كما هو).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/customer_repository.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/quotation_repository.dart';
import 'package:mobile_app/data/repositories/sale_repository.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:mobile_app/domain/models/quotation.dart';
import 'package:mobile_app/domain/models/sale.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;
  late QuotationRepository quotations;
  late SaleRepository sales;
  late ItemRepository items;
  late CustomerRepository customers;
  late ExchangeRateRepository rates;
  late int warehouseId;
  late int userId;
  late int baseCurrencyId;
  late int sarId;
  final at = DateTime.utc(2026, 10, 6, 12);

  setUp(() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    quotations = QuotationRepository(handle.db);
    sales = SaleRepository(handle.db);
    items = ItemRepository(handle.db);
    customers = CustomerRepository(handle.db);
    rates = ExchangeRateRepository(handle.db);
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
  }) async {
    final result = await items.createItem(
      ItemDraft(
        name: name,
        costPrice: cost,
        openingQty: qty,
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

  QuotationDraft quoteDraft(
    List<QuotationLine> lines, {
    int? customerId,
    int? currencyId,
    SaleDiscountType invoiceDiscountType = SaleDiscountType.amount,
    double invoiceDiscountValue = 0,
    DateTime? validUntil,
    DateTime? issuedAt,
  }) => QuotationDraft(
    customerId: customerId,
    currencyId: currencyId ?? baseCurrencyId,
    warehouseId: warehouseId,
    lines: lines,
    invoiceDiscountType: invoiceDiscountType,
    invoiceDiscountValue: invoiceDiscountValue,
    validUntil: validUntil,
    issuedAt: issuedAt ?? at,
  );

  Future<int> count(String table, {String? where}) async {
    final rows = await handle.db.rawQuery(
      'SELECT COUNT(*) AS n FROM $table${where == null ? '' : ' WHERE $where'}',
    );
    return rows.first['n'] as int;
  }

  // ── الإنشاء ──────────────────────────────────────────────────────

  group('createQuotation (FR-02-11)', () {
    test(
      'QTE-2026-00001 + بنود وأرقام صحيحة + بلا أي أثر مالي/مخزوني',
      () async {
        final customer = await makeCustomer('سالم');
        final pen = await makeProduct('قلم', cost: 10, price: 25, qty: 50);
        final book = await makeProduct('دفتر', cost: 15, price: 40, qty: 50);

        final result = await quotations.createQuotation(
          quoteDraft(
            [
              QuotationLine(
                productId: pen,
                qty: 2,
                unitPrice: 25,
                lineDiscountType: SaleDiscountType.percent,
                lineDiscountValue: 10,
              ),
              QuotationLine(productId: book, qty: 1, unitPrice: 40),
            ],
            customerId: customer,
            invoiceDiscountType: SaleDiscountType.percent,
            invoiceDiscountValue: 5,
            validUntil: at.add(const Duration(days: 14)),
          ),
          userId: userId,
          now: at,
        );
        expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
        final quotation = result.valueOrNull!;

        expect(quotation.quotationNo, 'QTE-2026-00001');
        expect(quotation.status.code, 'draft');
        expect(quotation.convertedInvoiceId, isNull);
        expect(quotation.validUntil, isNotNull);
        // الأسطر: 2×25 بخصم 10% = 45، و40 → صافي أسطر 85؛ رأس 5% = 4.25.
        expect(quotation.subtotal, 90);
        expect(quotation.discountAmount, 9.25); // 5 أسطر + 4.25 رأس.
        expect(quotation.total, 80.75);

        // عمود الرأس والبنود كما حُسبت.
        final row = await handle.db.query('quotation');
        expect(row.first['quotation_no'], 'QTE-2026-00001');
        expect(row.first['status'], 'draft');
        expect(row.first['total'], 80.75);
        expect(row.first['exchange_rate'], 1);
        expect(row.first['customer_id'], customer);

        final itemRows = await handle.db.query(
          'quotation_item',
          orderBy: 'id ASC',
        );
        expect(itemRows, hasLength(2));
        // قلم: خصم فعلي 5 + نصيب الرأس 2.25 = 7.25 وصافي 42.75.
        expect(itemRows[0]['line_desc'], 'قلم');
        expect(itemRows[0]['discount_percent'], 10);
        expect(itemRows[0]['discount_amount'], 7.25);
        expect(itemRows[0]['line_total'], 42.75);
        // دفتر: خصم 2 (رأس فقط) وصافي 38.
        expect(itemRows[1]['discount_amount'], 2);
        expect(itemRows[1]['line_total'], 38);

        // عرض السعر غير ملزم: لا أي أثر مالي أو مخزوني.
        expect((await handle.db.query('stock_level')).first['qty'], 50);
        expect(
          await count('stock_movement', where: "movement_type = 'sale'"),
          0,
        );
        expect(await count('cash_tx'), 0);
        expect(await count('payment_allocation'), 0);
        expect(await count('invoice'), 0);

        expect(
          await count('audit_log', where: "action = 'quotation_create'"),
          1,
        );
      },
    );

    test('تسلسل QTE مستقل عن INV ورفض المدخلات المعيبة', () async {
      final pen = await makeProduct('قلم', cost: 0, price: 10, qty: 100);
      final first = await quotations.createQuotation(
        quoteDraft([QuotationLine(productId: pen, qty: 1, unitPrice: 10)]),
        userId: userId,
        now: at,
      );
      final second = await quotations.createQuotation(
        quoteDraft([QuotationLine(productId: pen, qty: 2, unitPrice: 10)]),
        userId: userId,
        now: at,
      );
      expect(first.valueOrNull!.quotationNo, 'QTE-2026-00001');
      expect(second.valueOrNull!.quotationNo, 'QTE-2026-00002');

      // لا يستهلك QTE من عداد INV ولا العكس.
      final sale = await sales.postSale(
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
      expect(sale.valueOrNull!.invoiceNo, 'INV-2026-00001');

      final empty = await quotations.createQuotation(
        quoteDraft(const []),
        userId: userId,
        now: at,
      );
      expect(empty.errorOrNull, contains('بنداً واحداً'));

      final unknownProduct = await quotations.createQuotation(
        quoteDraft([QuotationLine(productId: 999, qty: 1, unitPrice: 10)]),
        userId: userId,
        now: at,
      );
      expect(unknownProduct.errorOrNull, contains('الصنف'));

      final unknownCurrency = await quotations.createQuotation(
        quoteDraft([
          QuotationLine(productId: pen, qty: 1, unitPrice: 10),
        ], currencyId: 999),
        userId: userId,
        now: at,
      );
      expect(unknownCurrency.errorOrNull, contains('العملة'));
    });

    test('عرض بعملة SAR: نفس سياسة سعر الصرف المفقود (FR-08-09)', () async {
      final pen = await makeProduct('قلم', cost: 0, price: 10, qty: 100);
      final blocked = await quotations.createQuotation(
        quoteDraft([
          QuotationLine(productId: pen, qty: 1, unitPrice: 10),
        ], currencyId: sarId),
        userId: userId,
        now: at,
      );
      expect(blocked.errorOrNull, contains('سعر صرف'));

      await rates.setRate(
        currencyId: sarId,
        date: at,
        rate: 560,
        userId: userId,
        now: at,
      );
      final ok = await quotations.createQuotation(
        quoteDraft([
          QuotationLine(productId: pen, qty: 1, unitPrice: 10),
        ], currencyId: sarId),
        userId: userId,
        now: at,
      );
      expect(ok.isOk, isTrue, reason: '${ok.errorOrNull}');
      expect(ok.valueOrNull!.exchangeRate, 560);
    });
  });

  // ── القوائم والتفاصيل والحالات ───────────────────────────────────

  group('القراءات والحالات', () {
    test(
      'listQuotations: ترتيب أحدث أولاً + فلاتر العميل والحالة والحد',
      () async {
        final customerA = await makeCustomer('أ');
        final customerB = await makeCustomer('ب');
        final pen = await makeProduct('قلم', cost: 0, price: 10, qty: 100);
        final q1 = (await quotations.createQuotation(
          quoteDraft([
            QuotationLine(productId: pen, qty: 1, unitPrice: 10),
          ], customerId: customerA),
          userId: userId,
          now: at,
        )).valueOrNull!;
        final q2 = (await quotations.createQuotation(
          quoteDraft([
            QuotationLine(productId: pen, qty: 2, unitPrice: 10),
          ], customerId: customerB),
          userId: userId,
          now: at.add(const Duration(hours: 1)),
        )).valueOrNull!;

        final all = await quotations.listQuotations();
        expect(all.map((q) => q.quotationNo), [
          'QTE-2026-00002',
          'QTE-2026-00001',
        ]);
        expect(all.first.customerName, 'ب');
        expect(all.first.currencyCode, 'YER');
        expect(all.first.total, 20);

        final forA = await quotations.listQuotations(customerId: customerA);
        expect(forA.single.id, q1.id);

        final sent = await quotations.markSent(q1.id, userId: userId, now: at);
        expect(sent.valueOrNull!.status.code, 'sent');
        final sentOnly = await quotations.listQuotations(
          status: QuotationStatus.sent,
        );
        expect(sentOnly.single.id, q1.id);

        final limited = await quotations.listQuotations(limit: 1);
        expect(limited, hasLength(1));
        expect(limited.single.id, q2.id);
      },
    );

    test('quotationDetail: الرأس والبنود وأسماء العميل/العملة', () async {
      final customer = await makeCustomer('سالم');
      final pen = await makeProduct('قلم', cost: 0, price: 25, qty: 50);
      final created = (await quotations.createQuotation(
        quoteDraft([
          QuotationLine(productId: pen, qty: 2, unitPrice: 25),
        ], customerId: customer),
        userId: userId,
        now: at,
      )).valueOrNull!;

      final detail = await quotations.quotationDetail(created.id);
      expect(detail, isNotNull);
      expect(detail!.customerName, 'سالم');
      expect(detail.currencyCode, 'YER');
      expect(detail.quotation.total, 50);
      expect(detail.items, hasLength(1));
      expect(detail.items.single.lineDesc, 'قلم');
      expect(detail.items.single.qty, 2);
      expect(detail.items.single.lineTotal, 50);

      expect(await quotations.quotationDetail(9999), isNull);
    });

    test(
      'markSent من sent يُرفض، وcancelQuotation يجعل الحالة rejected',
      () async {
        final pen = await makeProduct('قلم', cost: 0, price: 10, qty: 100);
        final created = (await quotations.createQuotation(
          quoteDraft([QuotationLine(productId: pen, qty: 1, unitPrice: 10)]),
          userId: userId,
          now: at,
        )).valueOrNull!;

        expect(
          (await quotations.markSent(created.id, userId: userId, now: at)).isOk,
          isTrue,
        );
        expect(
          (await quotations.markSent(
            created.id,
            userId: userId,
            now: at,
          )).errorOrNull,
          contains('sent'),
        );

        // المُرسَل يبقى قابلاً للتحويل (draft أو sent — FR-02-11).
        final fromSent = await quotations.convertToInvoice(
          created.id,
          paidCash: 10,
          userId: userId,
          now: at,
        );
        expect(fromSent.isOk, isTrue, reason: '${fromSent.errorOrNull}');

        final second = (await quotations.createQuotation(
          quoteDraft([QuotationLine(productId: pen, qty: 1, unitPrice: 10)]),
          userId: userId,
          now: at,
        )).valueOrNull!;
        final cancelled = await quotations.cancelQuotation(
          second.id,
          userId: userId,
          now: at,
        );
        expect(cancelled.valueOrNull!.status.code, 'rejected');
        // قيد التدقيق يميز الإلغاء عن رفض العميل.
        expect(
          await count('audit_log', where: "action = 'quotation_cancel'"),
          1,
        );

        // الملغى لا يتحول.
        final convert = await quotations.convertToInvoice(
          second.id,
          paidCash: 10,
          userId: userId,
          now: at,
        );
        expect(convert.errorOrNull, contains('غير قابل للتحويل'));
        expect(await count('invoice'), 1); // فاتورة التحويل الأول فقط.
      },
    );
  });

  // ── التحويل إلى فاتورة ───────────────────────────────────────────

  group('convertToInvoice (AC-17)', () {
    test(
      'تحويل نقدي كامل: فاتورة INV + مخزون + ربط متبادل + لا تكرار',
      () async {
        final customer = await makeCustomer('سالم');
        final pen = await makeProduct('قلم', cost: 10, price: 25, qty: 50);
        final quotation = (await quotations.createQuotation(
          quoteDraft([
            QuotationLine(productId: pen, qty: 2, unitPrice: 25),
            QuotationLine(productId: pen, qty: 1, unitPrice: 25),
          ], customerId: customer),
          userId: userId,
          now: at,
        )).valueOrNull!;

        final result = await quotations.convertToInvoice(
          quotation.id,
          paidCash: 75, // ≥ الصافي → نقدي مستنتج.
          userId: userId,
          now: at,
        );
        expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
        final receipt = result.valueOrNull!;

        // فاتورة كاملة بنفس الأرقام.
        expect(receipt.invoiceNo, 'INV-2026-00001');
        expect(receipt.totals.grandTotal, 75);
        expect((await handle.db.query('stock_level')).first['qty'], 47);
        expect(await count('invoice_item'), 2); // لا تكرار في الإدخال.
        expect((await handle.db.query('cash_tx')).first['amount'], 75);

        // الربط المتبادل: العرض converted + converted_invoice_id، والفاتورة
        // تحمل quotation_id.
        final quoteRow = (await handle.db.query(
          'quotation',
          where: 'id = ?',
          whereArgs: [quotation.id],
        )).first;
        expect(quoteRow['status'], 'converted');
        expect(quoteRow['converted_invoice_id'], receipt.invoiceId);
        final invoiceRow = (await handle.db.query(
          'invoice',
          where: 'id = ?',
          whereArgs: [receipt.invoiceId],
        )).first;
        expect(invoiceRow['quotation_id'], quotation.id);
        expect(invoiceRow['customer_id'], customer);

        // التحويل الثاني مرفوض.
        final again = await quotations.convertToInvoice(
          quotation.id,
          paidCash: 75,
          userId: userId,
          now: at,
        );
        expect(again.errorOrNull, contains('غير قابل للتحويل'));
        expect(await count('invoice'), 1);
      },
    );

    test(
      'تحويل بنفس الأسعار والخصومات الفعلية: الأرقام تتطابق حرفياً',
      () async {
        final a = await makeProduct('أ', cost: 0, price: 100, qty: 10);
        final b = await makeProduct('ب', cost: 0, price: 100, qty: 10);
        final quotation = (await quotations.createQuotation(
          quoteDraft(
            [
              QuotationLine(
                productId: a,
                qty: 2,
                unitPrice: 100,
                lineDiscountType: SaleDiscountType.percent,
                lineDiscountValue: 10,
              ),
              QuotationLine(
                productId: b,
                qty: 1,
                unitPrice: 100,
                lineDiscountType: SaleDiscountType.amount,
                lineDiscountValue: 10,
              ),
            ],
            invoiceDiscountType: SaleDiscountType.percent,
            invoiceDiscountValue: 10,
          ),
          userId: userId,
          now: at,
        )).valueOrNull!;
        expect(quotation.total, 243);

        // تحويل آجل (paidCash = 0 → credit مستنتج).
        final result = await quotations.convertToInvoice(
          quotation.id,
          paidCash: 0,
          userId: userId,
          now: at,
        );
        expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
        expect(result.valueOrNull!.payStatus, SalePaymentMethod.credit);

        final invoice = (await handle.db.query('invoice')).first;
        expect(invoice['subtotal'], 300);
        expect(invoice['discount_amount'], 57);
        expect(invoice['total'], 243);
        expect(invoice['due_amount'], 243);

        final items = await handle.db.query('invoice_item', orderBy: 'id ASC');
        expect(items[0]['discount_amount'], 38);
        expect(items[0]['line_total'], 162);
        expect(items[1]['discount_amount'], 19);
        expect(items[1]['line_total'], 81);
      },
    );

    test('تحويل مختلط: جزء نقدي وجزء آجل على حساب العميل', () async {
      final customer = await makeCustomer('نور');
      final pen = await makeProduct('قلم', cost: 0, price: 100, qty: 10);
      final quotation = (await quotations.createQuotation(
        quoteDraft([
          QuotationLine(productId: pen, qty: 1, unitPrice: 100),
        ], customerId: customer),
        userId: userId,
        now: at,
      )).valueOrNull!;

      final result = await quotations.convertToInvoice(
        quotation.id,
        paidCash: 40,
        userId: userId,
        now: at,
      );
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      expect(result.valueOrNull!.payStatus, SalePaymentMethod.mixed);
      expect(await customers.balanceInCurrency(customer, baseCurrencyId), 60);

      // نوع الدفع المعلن الصريح يجب أن يطابق المبالغ.
      final mismatch = await quotations.convertToInvoice(
        quotation.id,
        paidCash: 0,
        paymentMethod: SalePaymentMethod.cash,
        userId: userId,
        now: at,
      );
      expect(mismatch.errorOrNull, isNotNull);
    });

    test('نقص المخزون عند التحويل → رفض والعرض يبقى draft (ذرّية)', () async {
      final pen = await makeProduct('قلم', cost: 0, price: 10, qty: 5);
      final quotation = (await quotations.createQuotation(
        quoteDraft([QuotationLine(productId: pen, qty: 10, unitPrice: 10)]),
        userId: userId,
        now: at,
      )).valueOrNull!;

      final result = await quotations.convertToInvoice(
        quotation.id,
        paidCash: 100,
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, contains('المتاح 5'));

      // التراجع شمل تعليم العرض أيضاً — ما زال draft وقابلاً للتحويل بعد
      // توفير المخزون.
      final quoteRow = (await handle.db.query(
        'quotation',
        where: 'id = ?',
        whereArgs: [quotation.id],
      )).first;
      expect(quoteRow['status'], 'draft');
      expect(quoteRow['converted_invoice_id'], isNull);
      expect(await count('invoice'), 0);
      expect((await handle.db.query('stock_level')).first['qty'], 5);

      // بعد توفير الكمية ينجح التحويل (نفس العرض).
      await handle.db.update(
        'stock_level',
        {'qty': 20},
        where: 'product_id = ?',
        whereArgs: [pen],
      );
      final retry = await quotations.convertToInvoice(
        quotation.id,
        paidCash: 100,
        userId: userId,
        now: at,
      );
      expect(retry.isOk, isTrue, reason: '${retry.errorOrNull}');
    });

    test(
      'عرض بعملة SAR: الفاتورة بسعر يوم التحويل (Snapshot FR-08-05)',
      () async {
        final pen = await makeProduct('قلم', cost: 0, price: 100, qty: 10);
        // سعر يوم إنشاء العرض.
        await rates.setRate(
          currencyId: sarId,
          date: DateTime(2026, 10, 5),
          rate: 530,
          userId: userId,
          now: at,
        );
        final quotation = (await quotations.createQuotation(
          quoteDraft(
            [QuotationLine(productId: pen, qty: 1, unitPrice: 100)],
            currencyId: sarId,
            issuedAt: DateTime(2026, 10, 5, 12),
          ),
          userId: userId,
          now: DateTime(2026, 10, 5, 12),
        )).valueOrNull!;
        expect(quotation.exchangeRate, 530);

        // يوم التحويل سعر آخر — الفاتورة تأخذ سعر يومها هي.
        await rates.setRate(
          currencyId: sarId,
          date: DateTime(2026, 10, 6),
          rate: 560,
          userId: userId,
          now: at,
        );
        final result = await quotations.convertToInvoice(
          quotation.id,
          paidCash: 100,
          userId: userId,
          now: at,
        );
        expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
        expect(result.valueOrNull!.exchangeRate, 560);
        expect(result.valueOrNull!.rateIsFallback, isFalse);

        final invoice = (await handle.db.query('invoice')).first;
        expect(invoice['currency_id'], sarId);
        expect(invoice['exchange_rate'], 560);
        expect(invoice['total_base'], 56000);
        expect((await handle.db.query('cash_tx')).first['currency_id'], sarId);
      },
    );

    test('تحويل عرض غير موجود أو بلا بنود', () async {
      final missing = await quotations.convertToInvoice(
        999,
        paidCash: 10,
        userId: userId,
        now: at,
      );
      expect(missing.errorOrNull, contains('غير موجود'));
    });
  });
}
