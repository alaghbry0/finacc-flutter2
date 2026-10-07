/// اختبارات مستودع العملاء — صيغة الرصيد FR-03-02 (AC-02) وكشف الحساب
/// FR-03-04 وحد الائتمان FR-03-05 والأرشفة FR-03-09.
///
/// تُحقن صفوف فواتير وسندات خامّة (invoice / cash_tx) للتحقق من الصيغ
/// مباشرة — محرك البيع يأتي في موجة لاحقة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/customer_repository.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:sqflite/sqflite.dart';

import '../helpers/app_for_tests.dart';

var _docCounter = 0;

/// يحقن صف فاتورة خاماً بقيم صالحة للقيود الرقمية (CHECK constraints).
Future<int> insertInvoiceRow(
  Database db, {
  required int warehouseId,
  required int customerId,
  required int currencyId,
  required String docType,
  required double dueAmount,
  double? total,
  String status = 'completed',
  String payStatus = 'credit',
  DateTime? issuedAt,
}) async {
  return db.insert('invoice', {
    'invoice_no': 'T-INV-${_docCounter++}',
    'doc_type': docType,
    'pay_status': payStatus,
    'status': status,
    'issued_at': (issuedAt ?? DateTime.utc(2026, 10, 5, 10)).toIso8601String(),
    'warehouse_id': warehouseId,
    'customer_id': customerId,
    'currency_id': currencyId,
    'exchange_rate': 1,
    'total': total ?? dueAmount,
    'due_amount': dueAmount,
  });
}

/// يحقن صف سند نقدي خاماً (قبض مرتبط بعميل افتراضياً).
Future<int> insertCashTxRow(
  Database db, {
  required int cashboxId,
  required int currencyId,
  required double amount,
  int? customerId,
  String txType = 'receipt',
  bool voided = false,
  DateTime? txDate,
}) async {
  return db.insert('cash_tx', {
    'tx_type': txType,
    'cashbox_id': cashboxId,
    'currency_id': currencyId,
    'amount': amount,
    'exchange_rate': 1,
    'voucher_no': 'T-RVT-${_docCounter++}',
    'tx_date': (txDate ?? DateTime.utc(2026, 10, 7, 12)).toIso8601String(),
    'customer_id': customerId,
    'is_voided': voided ? 1 : 0,
  });
}

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late Database db;
  late CustomerRepository repo;
  late int warehouseId;
  late int cashboxId;
  late int adminId;
  late int yer;
  late int sar;
  late int usd;

  setUp(() async {
    app = (await openSeededApp()).$1;
    db = app.db;
    repo = CustomerRepository(db);
    warehouseId = (await db.query('warehouse', limit: 1)).first['id'] as int;
    cashboxId = (await db.query('cashbox', limit: 1)).first['id'] as int;
    adminId = (await db.query('app_user', limit: 1)).first['id'] as int;
    final currencies = {
      for (final row in await db.query('currency'))
        row['code'] as String: row['id'] as int,
    };
    yer = currencies['YER']!;
    sar = currencies['SAR']!;
    usd = currencies['USD']!;
  });

  tearDown(() async {
    await app.close();
  });

  Future<int> createCustomer(CustomerDraft draft, {DateTime? now}) async {
    final result = await repo.createCustomer(
      draft,
      userId: adminId,
      now: now ?? DateTime.utc(2026, 9, 1, 9),
    );
    expect(result.isOk, isTrue, reason: 'إنشاء العميل يجب أن ينجح');
    return result.valueOrNull!;
  }

  // ── الإنشاء والتعديل والأرشفة (FR-03-01 / FR-03-09) ─────────────

  test('إنشاء عميل بلا هاتف ولا رصيد — صف واحد وقيد تدقيق', () async {
    final id = await createCustomer(const CustomerDraft(name: 'عبدالله سالم'));
    final rows = await db.query('customer', where: 'id = ?', whereArgs: [id]);
    expect(rows, hasLength(1));
    expect(rows.first['phone'], isNull);
    expect(rows.first['opening_balance'], 0);
    expect(rows.first['is_archived'], 0);

    final audit = await db.query(
      'audit_log',
      where: "action = 'customer_create' AND entity = 'customer'",
    );
    expect(audit, hasLength(1));
    expect(audit.first['entity_id'], id);
    expect(audit.first['details'], 'name=عبدالله سالم');
    expect(audit.first['user_id'], adminId);

    expect(await repo.balanceInCurrency(id, yer), 0);
    expect(await repo.hasMovements(id), isFalse);
  });

  test('الاسم الفارغ مرفوض — لا كتابة ولا تدقيق', () async {
    final failure = await repo.createCustomer(
      const CustomerDraft(name: '   '),
      userId: adminId,
    );
    expect(failure.isErr, isTrue);
    expect(failure.errorOrNull, contains('مطلوب'));
    expect(await db.query('customer'), isEmpty);
    expect(
      await db.query('audit_log', where: "action = 'customer_create'"),
      isEmpty,
      reason: 'لا قيد تدقيق لعملية فاشلة',
    );
  });

  test(
    'رصيد افتتاحي 500 ريال سعودي بسعر 345 — تُخزَّن كاملة (FR-03-01)',
    () async {
      final id = await createCustomer(
        CustomerDraft(
          name: 'أحمد محمد',
          phone: '777123456',
          openingBalance: 500,
          openingBalanceCurrencyId: sar,
          openingBalanceRate: 345,
        ),
      );
      final rows = await db.query('customer', where: 'id = ?', whereArgs: [id]);
      expect(rows.first['opening_balance'], 500);
      expect(rows.first['opening_balance_currency_id'], sar);
      expect(rows.first['opening_balance_rate'], 345);
      expect(rows.first['opening_balance_date'], '2026-09-01');
      // الرصيد بعملته فقط — لا يتسرب لعملة أخرى (FR-08-11).
      expect(await repo.balanceInCurrency(id, sar), closeTo(500, 0.0001));
      expect(await repo.balanceInCurrency(id, yer), 0);
      expect(await repo.hasMovements(id), isTrue);
    },
  );

  test('رصيد افتتاحي غير صفري بلا عملة أو بلا سعر → مرفوض', () async {
    final noCurrency = await repo.createCustomer(
      const CustomerDraft(name: 'سالم', openingBalance: 100),
      userId: adminId,
    );
    expect(noCurrency.isErr, isTrue);
    expect(noCurrency.errorOrNull, contains('عملة'));

    final noRate = await repo.createCustomer(
      CustomerDraft(
        name: 'سالم',
        openingBalance: 100,
        openingBalanceCurrencyId: sar,
      ),
      userId: adminId,
    );
    expect(noRate.isErr, isTrue);
    expect(noRate.errorOrNull, contains('سعر صرف'));
    expect(await db.query('customer'), isEmpty);
  });

  test('عملة الرصيد الافتتاحي غير الموجودة → مرفوض', () async {
    final failure = await repo.createCustomer(
      CustomerDraft(
        name: 'سالم',
        openingBalance: 100,
        openingBalanceCurrencyId: 999,
        openingBalanceRate: 1,
      ),
      userId: adminId,
    );
    expect(failure.isErr, isTrue);
    expect(failure.errorOrNull, contains('غير موجودة'));
    expect(await db.query('customer'), isEmpty);
  });

  test(
    'updateCustomer يعدّل ويعيد النسخة الجديدة بتدقيق customer_update',
    () async {
      final id = await createCustomer(
        const CustomerDraft(name: 'أحمد محمد', phone: '777123456'),
      );
      final updated = await repo.updateCustomer(
        id,
        CustomerDraft(
          name: 'أحمد محمد الحضرمي',
          phone: '712345678',
          whatsapp: '712345678',
          area: 'الأنوار',
          creditLimit: 1500,
          notes: 'عميل مميز',
        ),
        userId: adminId,
        now: DateTime.utc(2026, 10, 2, 8),
      );
      expect(updated.isOk, isTrue);
      final customer = updated.valueOrNull!;
      expect(customer.name, 'أحمد محمد الحضرمي');
      expect(customer.phone, '712345678');
      expect(customer.area, 'الأنوار');
      expect(customer.creditLimit, closeTo(1500, 0.0001));
      expect(customer.notes, 'عميل مميز');

      final audit = await db.query(
        'audit_log',
        where: "action = 'customer_update'",
      );
      expect(audit, hasLength(1));
      expect(audit.first['entity_id'], id);
    },
  );

  test('updateCustomer لمعرّف غير موجود → خطأ', () async {
    final failure = await repo.updateCustomer(
      999,
      const CustomerDraft(name: 'غير موجود'),
      userId: adminId,
    );
    expect(failure.isErr, isTrue);
    expect(failure.errorOrNull, contains('غير موجود'));
  });

  test(
    'أرشفة عميل له حركات — تُقبل ويُستثنى من القائمة الافتراضية (FR-03-09)',
    () async {
      final id = await createCustomer(
        CustomerDraft(
          name: 'عبدالله',
          openingBalance: 500,
          openingBalanceCurrencyId: sar,
          openingBalanceRate: 345,
        ),
      );
      expect(await repo.hasMovements(id), isTrue);

      final archived = await repo.archiveCustomer(
        id,
        userId: adminId,
        now: DateTime.utc(2026, 10, 6, 12),
      );
      expect(archived.isOk, isTrue);
      final rows = await db.query('customer', where: 'id = ?', whereArgs: [id]);
      expect(rows.first['is_archived'], 1);

      expect(
        (await repo.listWithBalances()).where((b) => b.partyId == id),
        isEmpty,
        reason: 'المؤرشف مستثنى افتراضياً',
      );
      expect(
        (await repo.listWithBalances(includeArchived: true))
            .where((b) => b.partyId == id),
        isNotEmpty,
        reason: 'الطلب الصريح يعيده برصيده',
      );

      final audit = await db.query(
        'audit_log',
        where: "action = 'customer_archive'",
      );
      expect(audit, hasLength(1));
      expect(audit.first['entity_id'], id);
    },
  );

  test('أرشفة معرّف غير موجود → خطأ', () async {
    final failure = await repo.archiveCustomer(999, userId: adminId);
    expect(failure.isErr, isTrue);
  });

  // ── صيغة الرصيد (FR-03-02 / AC-02) ──────────────────────────────

  test(
    'AC-02: افتتاحي 500 + آجلة 1000 − قبض 400 − مرتجع 200 = 900 ريال سعودي',
    () async {
      final id = await createCustomer(
        CustomerDraft(
          name: 'عبدالله سالم',
          openingBalance: 500,
          openingBalanceCurrencyId: sar,
          openingBalanceRate: 345,
        ),
      );
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        customerId: id,
        currencyId: sar,
        docType: 'sale',
        dueAmount: 1000,
      );
      await insertCashTxRow(
        db,
        cashboxId: cashboxId,
        currencyId: sar,
        customerId: id,
        amount: 400,
      );
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        customerId: id,
        currencyId: sar,
        docType: 'sale_return',
        dueAmount: 200,
      );

      expect(await repo.balanceInCurrency(id, sar), closeTo(900, 0.0001));

      final list = await repo.listWithBalances();
      final mine = list.where((b) => b.partyId == id).toList();
      expect(mine, hasLength(1));
      expect(mine.first.currencyCode, 'SAR');
      expect(mine.first.balance, closeTo(900, 0.0001));
      expect(mine.first.lastPaymentDate, isNotNull);
      expect(mine.first.oldestOpenInvoiceDate, isNotNull);
    },
  );

  test(
    'فصل العملات: فاتورة دولارية لا تمس رصيد الريال السعودي (FR-08-11)',
    () async {
      final id = await createCustomer(
        CustomerDraft(
          name: 'عبدالله سالم',
          openingBalance: 500,
          openingBalanceCurrencyId: sar,
          openingBalanceRate: 345,
        ),
      );
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        customerId: id,
        currencyId: sar,
        docType: 'sale',
        dueAmount: 1000,
      );
      await insertCashTxRow(
        db,
        cashboxId: cashboxId,
        currencyId: sar,
        customerId: id,
        amount: 400,
      );
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        customerId: id,
        currencyId: sar,
        docType: 'sale_return',
        dueAmount: 200,
      );
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        customerId: id,
        currencyId: usd,
        docType: 'sale',
        dueAmount: 50,
      );

      expect(await repo.balanceInCurrency(id, sar), closeTo(900, 0.0001));
      expect(await repo.balanceInCurrency(id, usd), closeTo(50, 0.0001));

      final mine = (await repo.listWithBalances())
          .where((b) => b.partyId == id)
          .toList();
      expect(mine, hasLength(2), reason: 'سطر لكل عملة — لا تجميع أبداً');
      expect(mine.map((b) => b.currencyCode).toSet(), {'SAR', 'USD'});
    },
  );

  test(
    'المسودات والملغاة والسند الملغى مستثناة من الرصيد (completed فقط)',
    () async {
      final id = await createCustomer(const CustomerDraft(name: 'سالم'));
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        customerId: id,
        currencyId: yer,
        docType: 'sale',
        dueAmount: 700,
        status: 'void',
      );
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        customerId: id,
        currencyId: yer,
        docType: 'sale',
        dueAmount: 300,
        status: 'draft',
      );
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        customerId: id,
        currencyId: yer,
        docType: 'sale',
        dueAmount: 0,
        total: 500,
        payStatus: 'cash',
      );
      await insertCashTxRow(
        db,
        cashboxId: cashboxId,
        currencyId: yer,
        customerId: id,
        amount: 250,
        voided: true,
      );
      expect(
        await repo.balanceInCurrency(id, yer),
        0,
        reason: 'void + draft + كاش تامة + سند ملغى = لا أثر',
      );
      expect(
        (await repo.listWithBalances())
            .where((b) => b.partyId == id)
            .first
            .balance,
        0,
      );
    },
  );

  test('عميل بلا أي حركة يظهر بسطر واحد برصيد صفر بعملة القاعدة', () async {
    final id = await createCustomer(const CustomerDraft(name: 'خالد'));
    final mine = (await repo.listWithBalances())
        .where((b) => b.partyId == id)
        .toList();
    expect(mine, hasLength(1));
    expect(mine.first.balance, 0);
    expect(mine.first.currencyCode, 'YER');
  });

  // ── حد الائتمان (FR-03-05) ──────────────────────────────────────

  test('FR-03-05: بلا حد لا تجاوز، صفر يمنع الآجل، القيمة حدّية', () async {
    final noLimitId = await createCustomer(const CustomerDraft(name: 'بلا حد'));
    final r1 = await repo.checkCredit(noLimitId, sar, 100000);
    expect(r1.creditLimit, isNull);
    expect(r1.overLimit, isFalse);

    final zeroLimitId = await createCustomer(
      const CustomerDraft(name: 'ممنوع الآجل', creditLimit: 0),
    );
    final r2 = await repo.checkCredit(zeroLimitId, sar, 50);
    expect(r2.creditLimit, 0);
    expect(r2.overLimit, isTrue, reason: 'حد 0: أي آجل تجاوز');
    final r2b = await repo.checkCredit(zeroLimitId, sar, 0);
    expect(r2b.overLimit, isFalse, reason: 'لا إضافة = لا تجاوز');

    final limitedId = await createCustomer(
      const CustomerDraft(name: 'حد 1000', creditLimit: 1000),
    );
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      customerId: limitedId,
      currencyId: sar,
      docType: 'sale',
      dueAmount: 900,
    );
    final r3 = await repo.checkCredit(limitedId, sar, 200);
    expect(r3.balance, closeTo(900, 0.0001));
    expect(r3.overLimit, isTrue, reason: '900 + 200 > 1000');
    final r4 = await repo.checkCredit(limitedId, sar, 50);
    expect(r4.overLimit, isFalse, reason: '900 + 50 ≤ 1000');
  });

  // ── كشف الحساب (FR-03-04) ───────────────────────────────────────

  test(
    'كشف الحساب: ترتيب زمني ورصيد رأسي متحرك والنهائي يطابق الرصيد',
    () async {
      final id = await createCustomer(
        CustomerDraft(
          name: 'عبدالله سالم',
          openingBalance: 500,
          openingBalanceCurrencyId: sar,
          openingBalanceRate: 345,
        ),
      );
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        customerId: id,
        currencyId: sar,
        docType: 'sale',
        dueAmount: 1000,
        issuedAt: DateTime.utc(2026, 10, 5, 10),
      );
      await insertCashTxRow(
        db,
        cashboxId: cashboxId,
        currencyId: sar,
        customerId: id,
        amount: 400,
        txDate: DateTime.utc(2026, 10, 7, 12),
      );
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        customerId: id,
        currencyId: sar,
        docType: 'sale_return',
        dueAmount: 200,
        issuedAt: DateTime.utc(2026, 10, 9, 9),
      );

      final result = await repo.statement(id, currencyId: sar);
      expect(result.currencyCode, 'SAR');
      expect(result.currencyId, sar);
      expect(result.openingBalance, 0, reason: 'بلا فترة: الافتتاحي قيد داخل');
      expect(result.entries.map((e) => e.code), [
        StatementEntryCode.opening,
        StatementEntryCode.invoice,
        StatementEntryCode.receipt,
        StatementEntryCode.saleReturn,
      ]);
      final running = result.entries.map((e) => e.runningBalance).toList();
      expect(running, hasLength(4));
      expect(running[0], closeTo(500, 0.0001));
      expect(running[1], closeTo(1500, 0.0001));
      expect(running[2], closeTo(1100, 0.0001));
      expect(running[3], closeTo(900, 0.0001));
      expect(result.finalBalance, closeTo(900, 0.0001));
      expect(
        result.finalBalance,
        closeTo(await repo.balanceInCurrency(id, sar), 0.0001),
      );
      // الترقيم والتواريخ.
      expect(result.entries[1].docNo, startsWith('T-INV-'));
      expect(result.entries[1].refId, isNotNull);
      expect(result.entries[1].date, DateTime.utc(2026, 10, 5));
      expect(result.entries[0].date, DateTime.utc(2026, 9, 1));
    },
  );

  test('كشف الحساب بفترة: «رصيد ماضٍ» محمول أول القيود (FR-03-04)', () async {
    final id = await createCustomer(
      CustomerDraft(
        name: 'عبدالله سالم',
        openingBalance: 500,
        openingBalanceCurrencyId: sar,
        openingBalanceRate: 345,
      ),
    );
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      customerId: id,
      currencyId: sar,
      docType: 'sale',
      dueAmount: 1000,
      issuedAt: DateTime.utc(2026, 10, 5, 10),
    );
    await insertCashTxRow(
      db,
      cashboxId: cashboxId,
      currencyId: sar,
      customerId: id,
      amount: 400,
      txDate: DateTime.utc(2026, 10, 7, 12),
    );
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      customerId: id,
      currencyId: sar,
      docType: 'sale_return',
      dueAmount: 200,
      issuedAt: DateTime.utc(2026, 10, 9, 9),
    );

    final fromMonth = await repo.statement(
      id,
      currencyId: sar,
      from: DateTime.utc(2026, 10, 1),
    );
    expect(fromMonth.openingBalance, closeTo(500, 0.0001));
    expect(fromMonth.entries, hasLength(4));
    expect(fromMonth.entries.first.code, StatementEntryCode.carryIn);
    expect(fromMonth.entries.first.amount, closeTo(500, 0.0001));
    expect(fromMonth.entries.first.code.label, 'رصيد ماضٍ');
    expect(fromMonth.finalBalance, closeTo(900, 0.0001));

    final fromMiddle = await repo.statement(
      id,
      currencyId: sar,
      from: DateTime.utc(2026, 10, 6),
    );
    expect(fromMiddle.openingBalance, closeTo(1500, 0.0001));
    expect(fromMiddle.entries, hasLength(3));
    expect(fromMiddle.finalBalance, closeTo(900, 0.0001));

    final withTo = await repo.statement(
      id,
      currencyId: sar,
      to: DateTime.utc(2026, 10, 6),
    );
    expect(withTo.entries, hasLength(2));
    expect(withTo.finalBalance, closeTo(1500, 0.0001));
  });

  test('كشف الحساب بعملة أخرى: قيود فارغة ورصيد صفر', () async {
    final id = await createCustomer(
      CustomerDraft(
        name: 'عبدالله سالم',
        openingBalance: 500,
        openingBalanceCurrencyId: sar,
        openingBalanceRate: 345,
      ),
    );
    final result = await repo.statement(id, currencyId: usd);
    expect(result.entries, isEmpty);
    expect(result.finalBalance, 0);
    expect(result.currencyCode, 'USD');
  });

  // ── الأعمال المتعثرة (FR-03-06) ─────────────────────────────────

  test('receivablesList: ترتيب أقدم فاتورة مفتوحة وأيام التأخير', () async {
    final older = await createCustomer(const CustomerDraft(name: 'الأقدم'));
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      customerId: older,
      currencyId: yer,
      docType: 'sale',
      dueAmount: 300,
      issuedAt: DateTime.utc(2026, 9, 10, 10),
    );
    final newer = await createCustomer(const CustomerDraft(name: 'الأحدث'));
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      customerId: newer,
      currencyId: yer,
      docType: 'sale',
      dueAmount: 700,
      issuedAt: DateTime.utc(2026, 10, 1, 10),
    );
    final openingOnly = await createCustomer(
      CustomerDraft(
        name: 'افتتاحي فقط',
        openingBalance: 500,
        openingBalanceCurrencyId: sar,
        openingBalanceRate: 345,
      ),
    );
    final settled = await createCustomer(const CustomerDraft(name: 'مسدد'));
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      customerId: settled,
      currencyId: yer,
      docType: 'sale',
      dueAmount: 100,
      issuedAt: DateTime.utc(2026, 8, 1, 10),
    );
    await insertCashTxRow(
      db,
      cashboxId: cashboxId,
      currencyId: yer,
      customerId: settled,
      amount: 100,
      txDate: DateTime.utc(2026, 8, 2, 10),
    );

    final list = await repo.receivablesList(now: DateTime.utc(2026, 10, 20));
    expect(list, hasLength(3), reason: 'المسدد رصيده صفر فلا يظهر');
    expect(list.map((b) => b.partyId), [
      older,
      newer,
      openingOnly,
    ], reason: 'أقدم فاتورة أولاً ثم بلا فواتير أخيراً');
    expect(list.first.daysLate, 40, reason: '2026-09-10 → 2026-10-20');
    expect(list[1].daysLate, 19, reason: '2026-10-01 → 2026-10-20');
    expect(list[2].daysLate, isNull);
  });

  // ── البحث (FR-03-02) ─────────────────────────────────────────────

  test('البحث بالاسم أو الهاتف — LIKE', () async {
    await createCustomer(
      const CustomerDraft(name: 'أحمد محمد', phone: '777111222'),
    );
    await createCustomer(const CustomerDraft(name: 'خالد سعيد'));
    await createCustomer(const CustomerDraft(name: 'سارة'));

    expect(await repo.listWithBalances(), hasLength(3));
    expect((await repo.listWithBalances(search: 'أحمد')).map((b) => b.name), [
      'أحمد محمد',
    ]);
    expect((await repo.listWithBalances(search: '7771')).map((b) => b.name), [
      'أحمد محمد',
    ]);
    expect(await repo.listWithBalances(search: 'لا يوجد'), isEmpty);
  });
}
