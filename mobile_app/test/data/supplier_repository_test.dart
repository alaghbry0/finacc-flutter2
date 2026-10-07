/// اختبارات مستودع الموردين — مرآة العملاء باتجاه الشراء (FR-03-03):
/// صيغة الرصيد وكشف الحساب وقائمة المبالغ المتبقية والأرشفة.
///
/// تُحقن صفوف فواتير شراء وسندات صرف خامّة للتحقق من الصيغ مباشرة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/supplier_repository.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:sqflite/sqflite.dart';

import '../helpers/app_for_tests.dart';

var _docCounter = 0;

/// يحقن صف فاتورة خاماً مرتبطاً بمورد.
Future<int> insertInvoiceRow(
  Database db, {
  required int warehouseId,
  required int supplierId,
  required int currencyId,
  required String docType,
  required double dueAmount,
  String status = 'completed',
  DateTime? issuedAt,
}) async {
  return db.insert('invoice', {
    'invoice_no': 'T-PUR-${_docCounter++}',
    'doc_type': docType,
    'pay_status': 'credit',
    'status': status,
    'issued_at': (issuedAt ?? DateTime.utc(2026, 10, 5, 10)).toIso8601String(),
    'warehouse_id': warehouseId,
    'supplier_id': supplierId,
    'currency_id': currencyId,
    'exchange_rate': 1,
    'total': dueAmount,
    'due_amount': dueAmount,
  });
}

/// يحقن صف سند نقدي خاماً (صرف مرتبط بمورد افتراضياً).
Future<int> insertCashTxRow(
  Database db, {
  required int cashboxId,
  required int currencyId,
  required double amount,
  int? supplierId,
  String txType = 'payment',
  bool voided = false,
  DateTime? txDate,
}) async {
  return db.insert('cash_tx', {
    'tx_type': txType,
    'cashbox_id': cashboxId,
    'currency_id': currencyId,
    'amount': amount,
    'exchange_rate': 1,
    'voucher_no': 'T-PMT-${_docCounter++}',
    'tx_date': (txDate ?? DateTime.utc(2026, 10, 7, 12)).toIso8601String(),
    'supplier_id': supplierId,
    'is_voided': voided ? 1 : 0,
  });
}

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late Database db;
  late SupplierRepository repo;
  late int warehouseId;
  late int cashboxId;
  late int adminId;
  late int yer;
  late int sar;
  late int usd;

  setUp(() async {
    app = (await openSeededApp()).$1;
    db = app.db;
    repo = SupplierRepository(db);
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

  Future<int> createSupplier(SupplierDraft draft, {DateTime? now}) async {
    final result = await repo.createSupplier(
      draft,
      userId: adminId,
      now: now ?? DateTime.utc(2026, 9, 1, 9),
    );
    expect(result.isOk, isTrue, reason: 'إنشاء المورد يجب أن ينجح');
    return result.valueOrNull!;
  }

  // ── الإنشاء والتعديل والأرشفة (FR-03-03 / FR-03-09) ─────────────

  test('إنشاء مورد بلا رصيد — صف واحد وقيد تدقيق supplier_create', () async {
    final id = await createSupplier(
      const SupplierDraft(name: 'مؤسسة التجارة الحديثة', phone: '711223344'),
    );
    final rows = await db.query('supplier', where: 'id = ?', whereArgs: [id]);
    expect(rows, hasLength(1));
    expect(rows.first['opening_balance'], 0);

    final audit = await db.query(
      'audit_log',
      where: "action = 'supplier_create' AND entity = 'supplier'",
    );
    expect(audit, hasLength(1));
    expect(audit.first['entity_id'], id);
    expect(audit.first['details'], 'name=مؤسسة التجارة الحديثة');

    expect(await repo.balanceInCurrency(id, yer), 0);
    expect(await repo.hasMovements(id), isFalse);
  });

  test('الاسم الفارغ مرفوض — لا كتابة ولا تدقيق', () async {
    final failure = await repo.createSupplier(
      const SupplierDraft(name: '  '),
      userId: adminId,
    );
    expect(failure.isErr, isTrue);
    expect(await db.query('supplier'), isEmpty);
    expect(
      await db.query('audit_log', where: "action = 'supplier_create'"),
      isEmpty,
      reason: 'لا قيد تدقيق لعملية فاشلة',
    );
  });

  test('رصيد افتتاحي 300 ريال سعودي — تُخزَّن كاملة وتحسب بعملتها', () async {
    final id = await createSupplier(
      SupplierDraft(
        name: 'مورد جدة',
        openingBalance: 300,
        openingBalanceCurrencyId: sar,
        openingBalanceRate: 345,
      ),
    );
    final rows = await db.query('supplier', where: 'id = ?', whereArgs: [id]);
    expect(rows.first['opening_balance'], 300);
    expect(rows.first['opening_balance_date'], '2026-09-01');
    expect(await repo.balanceInCurrency(id, sar), closeTo(300, 0.0001));
    expect(await repo.balanceInCurrency(id, yer), 0);
    expect(await repo.hasMovements(id), isTrue);
  });

  test('رصيد افتتاحي غير صفري ناقص التحقق → مرفوض', () async {
    final noCurrency = await repo.createSupplier(
      const SupplierDraft(name: 'مورد', openingBalance: 100),
      userId: adminId,
    );
    expect(noCurrency.isErr, isTrue);
    final noRate = await repo.createSupplier(
      SupplierDraft(
        name: 'مورد',
        openingBalance: 100,
        openingBalanceCurrencyId: sar,
      ),
      userId: adminId,
    );
    expect(noRate.isErr, isTrue);
    expect(await db.query('supplier'), isEmpty);
  });

  test(
    'updateSupplier يعدّل ويعيد النسخة الجديدة بتدقيق supplier_update',
    () async {
      final id = await createSupplier(
        const SupplierDraft(name: 'مورد جدة', phone: '711223344'),
      );
      final updated = await repo.updateSupplier(
        id,
        const SupplierDraft(
          name: 'مورد جدة للأجهزة',
          phone: '711998877',
          address: 'شارع الملك',
        ),
        userId: adminId,
        now: DateTime.utc(2026, 10, 2, 8),
      );
      expect(updated.isOk, isTrue);
      final supplier = updated.valueOrNull!;
      expect(supplier.name, 'مورد جدة للأجهزة');
      expect(supplier.phone, '711998877');
      expect(supplier.address, 'شارع الملك');

      final audit = await db.query(
        'audit_log',
        where: "action = 'supplier_update'",
      );
      expect(audit, hasLength(1));
      expect(audit.first['entity_id'], id);
    },
  );

  test('updateSupplier لمعرّف غير موجود → خطأ', () async {
    final failure = await repo.updateSupplier(
      999,
      const SupplierDraft(name: 'غير موجود'),
      userId: adminId,
    );
    expect(failure.isErr, isTrue);
  });

  test('أرشفة مورد له حركات — تُقبل ويُستثنى افتراضياً (FR-03-09)', () async {
    final id = await createSupplier(
      SupplierDraft(
        name: 'مورد',
        openingBalance: 300,
        openingBalanceCurrencyId: sar,
        openingBalanceRate: 345,
      ),
    );
    expect(await repo.hasMovements(id), isTrue);
    final archived = await repo.archiveSupplier(
      id,
      userId: adminId,
      now: DateTime.utc(2026, 10, 6, 12),
    );
    expect(archived.isOk, isTrue);
    expect(
      (await repo.listWithBalances()).where((b) => b.partyId == id),
      isEmpty,
    );
    expect(
      (await repo.listWithBalances(includeArchived: true))
          .where((b) => b.partyId == id),
      isNotEmpty,
    );
    final audit = await db.query(
      'audit_log',
      where: "action = 'supplier_archive'",
    );
    expect(audit, hasLength(1));
  });

  // ── صيغة الرصيد (FR-03-03) ──────────────────────────────────────

  test(
    'الرصيد: افتتاحي 300 + شراء 800 − صرف 200 − مرتجع شراء 100 = 800',
    () async {
      final id = await createSupplier(
        SupplierDraft(
          name: 'مورد جدة',
          openingBalance: 300,
          openingBalanceCurrencyId: sar,
          openingBalanceRate: 345,
        ),
      );
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        supplierId: id,
        currencyId: sar,
        docType: 'purchase',
        dueAmount: 800,
      );
      await insertCashTxRow(
        db,
        cashboxId: cashboxId,
        currencyId: sar,
        supplierId: id,
        amount: 200,
      );
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        supplierId: id,
        currencyId: sar,
        docType: 'purchase_return',
        dueAmount: 100,
      );

      expect(await repo.balanceInCurrency(id, sar), closeTo(800, 0.0001));
      final mine = (await repo.listWithBalances())
          .where((b) => b.partyId == id)
          .toList();
      expect(mine, hasLength(1));
      expect(mine.first.currencyCode, 'SAR');
      expect(mine.first.balance, closeTo(800, 0.0001));
      expect(mine.first.lastPaymentDate, isNotNull);
    },
  );

  test('فصل العملات: شراء دولاري لا يمس رصيد الريال السعودي', () async {
    final id = await createSupplier(
      SupplierDraft(
        name: 'مورد',
        openingBalance: 300,
        openingBalanceCurrencyId: sar,
        openingBalanceRate: 345,
      ),
    );
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      supplierId: id,
      currencyId: sar,
      docType: 'purchase',
      dueAmount: 800,
    );
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      supplierId: id,
      currencyId: usd,
      docType: 'purchase',
      dueAmount: 20,
    );

    expect(await repo.balanceInCurrency(id, sar), closeTo(1100, 0.0001));
    expect(await repo.balanceInCurrency(id, usd), closeTo(20, 0.0001));
    final mine = (await repo.listWithBalances())
        .where((b) => b.partyId == id)
        .toList();
    expect(mine, hasLength(2));
    expect(mine.map((b) => b.currencyCode).toSet(), {'SAR', 'USD'});
  });

  test('المسودات والملغاة مستثناة من رصيد المورد (completed فقط)', () async {
    final id = await createSupplier(const SupplierDraft(name: 'مورد'));
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      supplierId: id,
      currencyId: yer,
      docType: 'purchase',
      dueAmount: 500,
      status: 'void',
    );
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      supplierId: id,
      currencyId: yer,
      docType: 'purchase',
      dueAmount: 200,
      status: 'draft',
    );
    await insertCashTxRow(
      db,
      cashboxId: cashboxId,
      currencyId: yer,
      supplierId: id,
      amount: 100,
      voided: true,
    );
    expect(await repo.balanceInCurrency(id, yer), 0);
  });

  // ── كشف الحساب (FR-03-04) ───────────────────────────────────────

  test('كشف حساب المورد: شراء + وصرف ومرتجع − ورصيد رأسي متحرك', () async {
    final id = await createSupplier(
      SupplierDraft(
        name: 'مورد جدة',
        openingBalance: 300,
        openingBalanceCurrencyId: sar,
        openingBalanceRate: 345,
      ),
    );
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      supplierId: id,
      currencyId: sar,
      docType: 'purchase',
      dueAmount: 800,
      issuedAt: DateTime.utc(2026, 10, 5, 10),
    );
    await insertCashTxRow(
      db,
      cashboxId: cashboxId,
      currencyId: sar,
      supplierId: id,
      amount: 200,
      txDate: DateTime.utc(2026, 10, 7, 12),
    );
    await insertInvoiceRow(
      db,
      warehouseId: warehouseId,
      supplierId: id,
      currencyId: sar,
      docType: 'purchase_return',
      dueAmount: 100,
      issuedAt: DateTime.utc(2026, 10, 9, 9),
    );

    final result = await repo.statement(id, currencyId: sar);
    expect(result.currencyCode, 'SAR');
    expect(result.entries.map((e) => e.code), [
      StatementEntryCode.opening,
      StatementEntryCode.purchase,
      StatementEntryCode.payment,
      StatementEntryCode.purchaseReturn,
    ]);
    final running = result.entries.map((e) => e.runningBalance).toList();
    expect(running[0], closeTo(300, 0.0001));
    expect(running[1], closeTo(1100, 0.0001));
    expect(running[2], closeTo(900, 0.0001));
    expect(running[3], closeTo(800, 0.0001));
    expect(result.finalBalance, closeTo(800, 0.0001));
    expect(
      result.finalBalance,
      closeTo(await repo.balanceInCurrency(id, sar), 0.0001),
    );

    final fromMonth = await repo.statement(
      id,
      currencyId: sar,
      from: DateTime.utc(2026, 10, 1),
    );
    expect(fromMonth.openingBalance, closeTo(300, 0.0001));
    expect(fromMonth.entries.first.code, StatementEntryCode.carryIn);
    expect(fromMonth.entries, hasLength(4));
    expect(fromMonth.finalBalance, closeTo(800, 0.0001));
  });

  // ── المبالغ المتبقية للموردين (FR-03-03) ────────────────────────

  test(
    'payablesList: المرتبون بأقدم فاتورة شراء مفتوحة مع أيام التأخير',
    () async {
      final older = await createSupplier(const SupplierDraft(name: 'الأقدم'));
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        supplierId: older,
        currencyId: yer,
        docType: 'purchase',
        dueAmount: 400,
        issuedAt: DateTime.utc(2026, 9, 5, 10),
      );
      final newer = await createSupplier(const SupplierDraft(name: 'الأحدث'));
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        supplierId: newer,
        currencyId: yer,
        docType: 'purchase',
        dueAmount: 600,
        issuedAt: DateTime.utc(2026, 10, 8, 10),
      );
      final settled = await createSupplier(const SupplierDraft(name: 'مسدد'));
      await insertInvoiceRow(
        db,
        warehouseId: warehouseId,
        supplierId: settled,
        currencyId: yer,
        docType: 'purchase',
        dueAmount: 150,
        issuedAt: DateTime.utc(2026, 8, 1, 10),
      );
      await insertCashTxRow(
        db,
        cashboxId: cashboxId,
        currencyId: yer,
        supplierId: settled,
        amount: 150,
        txDate: DateTime.utc(2026, 8, 2, 10),
      );

      final list = await repo.payablesList(now: DateTime.utc(2026, 10, 20));
      expect(list, hasLength(2), reason: 'المسدد لا يظهر');
      expect(list.map((b) => b.partyId), [older, newer]);
      expect(list.first.daysLate, 45, reason: '2026-09-05 → 2026-10-20');
      expect(list[1].daysLate, 12, reason: '2026-10-08 → 2026-10-20');
    },
  );

  // ── البحث ────────────────────────────────────────────────────────

  test('البحث بالاسم أو الهاتف — LIKE', () async {
    await createSupplier(
      const SupplierDraft(name: 'مؤسسة النور', phone: '711000111'),
    );
    await createSupplier(const SupplierDraft(name: 'مستودع صنعاء'));

    expect(await repo.listWithBalances(), hasLength(2));
    expect((await repo.listWithBalances(search: 'النور')).map((b) => b.name), [
      'مؤسسة النور',
    ]);
    expect((await repo.listWithBalances(search: '7110')).map((b) => b.name), [
      'مؤسسة النور',
    ]);
    expect(await repo.listWithBalances(search: 'لا يوجد'), isEmpty);
  });
}
