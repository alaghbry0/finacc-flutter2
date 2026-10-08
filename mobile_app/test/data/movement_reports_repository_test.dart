/// اختبارات مستودع تقارير الحركة والمبيعات (الشريحة 10 —
/// FR-09-03/04/06): الرصيد التراكمي عبر حركات مختلطة، مرشح المخزن،
/// تجميع ملخص المخزون بالنهاية والقيمة والترتيب، تجميعات المبيعات
/// بالأبعاد الأربعة مع تحويل SAR إلى الأساس، النسبة مقابل الفترة
/// السابقة، واستبعاد المسودة/الإبطال.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/movement_reports_repository.dart';
import 'package:sqflite/sqflite.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late Database db;
  late MovementReportsRepository repo;
  late int warehouseId;
  late int cashboxId;
  late int yer;
  late int sar;

  setUp(() async {
    final seeded = await openSeededApp();
    app = seeded.$1;
    db = app.db;
    repo = MovementReportsRepository(db);
    warehouseId = (await db.query('warehouse', limit: 1)).first['id'] as int;
    cashboxId = (await db.query('cashbox', limit: 1)).first['id'] as int;
    final currencies = <String, int>{
      for (final row in await db.query('currency'))
        row['code'] as String: row['id'] as int,
    };
    yer = currencies['YER']!;
    sar = currencies['SAR']!;
  });

  tearDown(() async {
    await app.close();
  });

  /// يبذر صنفاً ويعيد معرّفه.
  Future<int> makeProduct(String name, {double cost = 0}) =>
      db.insert('product', {
        'name': name,
        'cost_price': cost,
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-01T00:00:00Z',
      });

  /// يبذر حركة مخزون موقّعة.
  Future<void> move(
    int productId,
    String type,
    double qty,
    String movedAt, {
    int? warehouse,
    double unitCost = 0,
    String? notes,
  }) async {
    await db.insert('stock_movement', {
      'product_id': productId,
      'warehouse_id': warehouse ?? warehouseId,
      'movement_type': type,
      'qty': qty,
      'unit_cost': unitCost,
      'ref_type': 'invoice',
      'ref_id': 1,
      'moved_at': movedAt,
      'notes': notes,
      'created_at': movedAt,
    });
  }

  /// يبذر فاتورة ببنودها ويعيد معرّفها.
  Future<int> makeInvoice({
    required String no,
    required String issuedAt,
    required List<({int? productId, double qty, double lineTotal})> lines,
    String docType = 'sale',
    String status = 'completed',
    int? customerId,
    int currency = -1,
    double exchangeRate = 1,
  }) async {
    final invoiceId = await db.insert('invoice', {
      'invoice_no': no,
      'doc_type': docType,
      'pay_status': 'cash',
      'status': status,
      'warehouse_id': warehouseId,
      'cashbox_id': cashboxId,
      'customer_id': customerId,
      'issued_at': issuedAt,
      'currency_id': currency == -1 ? yer : currency,
      'exchange_rate': exchangeRate,
      'total': lines.fold<double>(0, (sum, l) => sum + l.lineTotal),
      'total_base':
          lines.fold<double>(0, (sum, l) => sum + l.lineTotal) * exchangeRate,
    });
    for (final line in lines) {
      await db.insert('invoice_item', {
        'invoice_id': invoiceId,
        'product_id': line.productId,
        'qty': line.qty,
        'unit_price': line.lineTotal / line.qty,
        'line_total': line.lineTotal,
        'line_cost': 0,
        'created_at': issuedAt,
      });
    }
    return invoiceId;
  }

  // ─────────────────────────────────────────────────────────────────────
  // FR-09-03 — بطاقة حركة صنف
  // ─────────────────────────────────────────────────────────────────────

  test('itemMovement: الرصيد التراكمي الدقيق عبر حركات مختلطة (افتتاحي قبل الفترة)', () async {
    final rice = await makeProduct('أرز بسمتي', cost: 150);
    // افتتاحي قبل الفترة → نقطة انطلاق السلسلة.
    await move(rice, 'opening', 10, '2026-10-05T09:00:00Z');
    // الحركات داخل الفترة (نوفمبر).
    await move(rice, 'sale', -3, '2026-11-03T10:00:00Z', unitCost: 150);
    await move(rice, 'purchase', 5, '2026-11-08T11:30:00Z', unitCost: 150);
    await move(rice, 'sale_return', 2, '2026-11-12T08:00:00Z', unitCost: 150);
    await move(
      rice,
      'stocktake_adjust',
      -1,
      '2026-11-20T16:45:00Z',
      unitCost: 150,
    );

    final report = await repo.itemMovement(
      productId: rice,
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );

    expect(report.productId, rice);
    expect(report.name, 'أرز بسمتي');
    expect(report.unitCostNow, 150);
    expect(report.openingBalance, 10, reason: 'الافتتاحي قبل الفترة');
    expect(report.rows, hasLength(4));
    // ترتيب تصاعدي زمنياً — وهو أساس حساب التراكم.
    expect(report.rows.map((r) => r.movementType).toList(), [
      'sale',
      'purchase',
      'sale_return',
      'stocktake_adjust',
    ]);
    // الأرصدة التراكمية حرفياً: 10−3=7، +5=12، +2=14، −1=13.
    expect(report.rows.map((r) => r.balanceAfter).toList(), [
      7.0,
      12.0,
      14.0,
      13.0,
    ]);
    expect(report.rows.first.qty, -3);
    expect(report.rows.first.balanceAfter, 7);
    expect(report.totalIn, 7, reason: 'شراء 5 + مرتجع 2');
    expect(report.totalOut, 4, reason: 'بيع 3 + تسوية 1');
  });

  test('itemMovement: تساوي moved_at يُكسر بترتيب الإدراج (id ASC)', () async {
    final sugar = await makeProduct('سكر');
    await move(sugar, 'sale', -2, '2026-11-05T10:00:00Z');
    await move(sugar, 'purchase', 6, '2026-11-05T10:00:00Z');
    await move(sugar, 'sale', -1, '2026-11-05T10:00:00Z');

    final report = await repo.itemMovement(
      productId: sugar,
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );
    expect(report.rows.map((r) => r.qty).toList(), [-2.0, 6.0, -1.0]);
    expect(report.rows.map((r) => r.balanceAfter).toList(), [-2.0, 4.0, 3.0]);
  });

  test(
    'itemMovement: مرشح المخزن — الحركات والافتتاحي من مخزنه حصراً',
    () async {
      final otherWarehouse = await db.insert('warehouse', {
        'name': 'فرع عدن',
        'is_default': 0,
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-01T00:00:00Z',
      });
      final oil = await makeProduct('زيت دوار الشمس');
      // الافتتاحي موزّع على المخزنين.
      await move(
        oil,
        'opening',
        8,
        '2026-10-02T09:00:00Z',
        warehouse: warehouseId,
      );
      await move(
        oil,
        'opening',
        4,
        '2026-10-02T09:00:00Z',
        warehouse: otherWarehouse,
      );
      // حركة في كل مخزن داخل الفترة.
      await move(
        oil,
        'sale',
        -3,
        '2026-11-04T10:00:00Z',
        warehouse: warehouseId,
      );
      await move(
        oil,
        'sale',
        -1,
        '2026-11-05T10:00:00Z',
        warehouse: otherWarehouse,
      );

      final mainOnly = await repo.itemMovement(
        productId: oil,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
        warehouseId: warehouseId,
      );
      expect(mainOnly.openingBalance, 8);
      expect(mainOnly.rows, hasLength(1));
      expect(mainOnly.rows.first.qty, -3);
      expect(mainOnly.rows.first.balanceAfter, 5);

      final branchOnly = await repo.itemMovement(
        productId: oil,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
        warehouseId: otherWarehouse,
      );
      expect(branchOnly.openingBalance, 4);
      expect(branchOnly.rows, hasLength(1));
      expect(branchOnly.rows.first.balanceAfter, 3);

      // بلا مرشح: كل شيء معاً.
      final all = await repo.itemMovement(
        productId: oil,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      expect(all.openingBalance, 12);
      expect(all.rows, hasLength(2));
    },
  );

  test('itemMovement: لا حركات إطلاقاً — افتتاحي صفري وصفوف فارغة', () async {
    final ghost = await makeProduct('صنف صامت');
    final report = await repo.itemMovement(
      productId: ghost,
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );
    expect(report.openingBalance, 0);
    expect(report.rows, isEmpty);
    expect(report.totalIn, 0);
    expect(report.totalOut, 0);
  });

  test('itemMovement: صنف غير موجود يرمي StateError عربية', () async {
    expect(
      () => repo.itemMovement(
        productId: 999999,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('غير موجود'),
        ),
      ),
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  // FR-09-04 — ملخص حركة المخزون
  // ─────────────────────────────────────────────────────────────────────

  test(
    'stockSummary: تجميع الأعمدة بالنوع + الرصيد + القيمة بالتكلفة',
    () async {
      final sugar = await makeProduct('سكر', cost: 200);
      // افتتاحي قبل الفترة (لا يدخل أعمدة التدفق لكنه يدخل الرصيد).
      await move(sugar, 'opening', 5, '2026-10-01T09:00:00Z');
      // تدفقات الفترة.
      await move(sugar, 'purchase', 10, '2026-11-02T10:00:00Z');
      await move(sugar, 'sale', -4, '2026-11-05T10:00:00Z');
      await move(sugar, 'sale_return', 2, '2026-11-07T10:00:00Z');
      await move(sugar, 'purchase_return', -1, '2026-11-09T10:00:00Z');
      await move(sugar, 'stocktake_adjust', -1, '2026-11-15T10:00:00Z');
      await move(sugar, 'stocktake_adjust', 3, '2026-11-20T10:00:00Z');

      final rows = await repo.stockSummary(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      expect(rows, hasLength(1));
      final row = rows.first;
      // وارد = شراء 10 + الجزء الموجب من التسويات 3 (الافتتاحي قبل الفترة
      // لا يدخل — قرار 5 برأس المستودع).
      expect(row.qtyIn, 13);
      // صادر = |بيع 4 + مرتجع شراء 1|.
      expect(row.qtyOut, 5);
      expect(row.qtyReturns, 2);
      expect(row.qtyAdjustNet, 2, reason: '−1 + 3');
      // الرصيد الختامي = 5 + 10 − 4 + 2 − 1 − 1 + 3 = 14.
      expect(row.endBalance, 14);
      expect(row.valueAtCost, 2800, reason: '14 × 200');
    },
  );

  test('stockSummary: الترتيب بالقيمة تنازلياً والساكن مستبعد', () async {
    final a = await makeProduct('ثلاجة', cost: 1000); // رصيد 3 → 3000
    final b = await makeProduct('مروحة', cost: 250); // رصيد 4 → 1000
    await makeProduct('صنف ساكن', cost: 999); // بلا حركة → مستبعد
    await move(a, 'purchase', 3, '2026-11-02T10:00:00Z');
    await move(b, 'purchase', 4, '2026-11-03T10:00:00Z');

    final rows = await repo.stockSummary(
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );
    expect(rows, hasLength(2), reason: 'الساكن خارج التقرير');
    expect(rows.first.name, 'ثلاجة');
    expect(rows.first.valueAtCost, 3000);
    expect(rows.last.name, 'مروحة');
    expect(rows.last.valueAtCost, 1000);
  });

  test('stockSummary: مرشح المخزن — تجميع ورصيد المخزن المحدد', () async {
    final otherWarehouse = await db.insert('warehouse', {
      'name': 'فرع عدن',
      'is_default': 0,
      'created_at': '2026-10-01T00:00:00Z',
      'updated_at': '2026-10-01T00:00:00Z',
    });
    final rice = await makeProduct('أرز', cost: 100);
    await move(rice, 'purchase', 10, '2026-11-02T10:00:00Z');
    await move(
      rice,
      'purchase',
      5,
      '2026-11-03T10:00:00Z',
      warehouse: otherWarehouse,
    );

    final mainOnly = await repo.stockSummary(
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
      warehouseId: warehouseId,
    );
    expect(mainOnly, hasLength(1));
    expect(mainOnly.first.qtyIn, 10);
    expect(mainOnly.first.endBalance, 10, reason: 'حركات المخزن الآخر خارج');

    final all = await repo.stockSummary(
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );
    expect(all.first.qtyIn, 15);
    expect(all.first.endBalance, 15);
  });

  test('stockSummary: فترة بلا حركة — قائمة فارغة', () async {
    final rows = await repo.stockSummary(
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );
    expect(rows, isEmpty);
  });

  // ─────────────────────────────────────────────────────────────────────
  // FR-09-06 — المبيعات حسب
  // ─────────────────────────────────────────────────────────────────────

  test(
    'salesBy(customer): تحويل SAR إلى الأساس + العميل النقدي + الترتيب',
    () async {
      final ahmed = await db.insert('customer', {
        'name': 'أحمد سعيد',
        'created_at': '2026-10-01T00:00:00Z',
      });
      final sara = await db.insert('customer', {
        'name': 'سارة',
        'created_at': '2026-10-01T00:00:00Z',
      });
      // فاتورة SAR بسعر 2: 100 SAR → 200 أساس.
      await makeInvoice(
        no: 'INV-1',
        issuedAt: '2026-11-02T10:00:00Z',
        customerId: ahmed,
        currency: sar,
        exchangeRate: 2,
        lines: [(productId: null, qty: 1, lineTotal: 100)],
      );
      // فاتورة YER لأحمد: 300.
      await makeInvoice(
        no: 'INV-2',
        issuedAt: '2026-11-10T10:00:00Z',
        customerId: ahmed,
        lines: [(productId: null, qty: 1, lineTotal: 300)],
      );
      // نقدي بلا عميل: 50.
      await makeInvoice(
        no: 'INV-3',
        issuedAt: '2026-11-12T10:00:00Z',
        lines: [(productId: null, qty: 1, lineTotal: 50)],
      );
      // سارة: 60.
      await makeInvoice(
        no: 'INV-4',
        issuedAt: '2026-11-14T10:00:00Z',
        customerId: sara,
        lines: [(productId: null, qty: 1, lineTotal: 60)],
      );

      final rows = await repo.salesBy(
        dimension: SalesByDimension.customer,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      expect(rows, hasLength(3));
      expect(rows.first.label, 'أحمد سعيد');
      expect(rows.first.salesBase, 500, reason: '100×2 + 300');
      expect(rows.first.invoiceCount, 2);
      // الترتيب تنازلياً بالمبيعات.
      expect(rows[1].label, 'سارة');
      expect(rows[1].salesBase, 60);
      // العميل النقدي تحت التسمية الفارغة (قرار 10).
      expect(rows.last.label, '');
      expect(rows.last.salesBase, 50);
      expect(rows.last.invoiceCount, 1);
    },
  );

  test('salesBy(category): تجميع الفئات + غير المصنّف مع السطر الحر', () async {
    final grocery = await db.insert('category', {'name': 'بقالة'});
    final drinks = await db.insert('category', {'name': 'مشروبات'});
    final rice = await makeProduct('أرز');
    final juice = await makeProduct('عصير');
    final loose = await makeProduct('صنف بلا فئة');
    await db.update(
      'product',
      {'category_id': grocery},
      where: 'id = ?',
      whereArgs: [rice],
    );
    await db.update(
      'product',
      {'category_id': drinks},
      where: 'id = ?',
      whereArgs: [juice],
    );

    await makeInvoice(
      no: 'INV-1',
      issuedAt: '2026-11-02T10:00:00Z',
      lines: [
        (productId: rice, qty: 2, lineTotal: 200),
        (productId: juice, qty: 1, lineTotal: 40),
      ],
    );
    await makeInvoice(
      no: 'INV-2',
      issuedAt: '2026-11-05T10:00:00Z',
      lines: [
        (productId: rice, qty: 1, lineTotal: 100),
        // صنف بلا فئة + سطر حر → كلاهما في «غير مصنّف».
        (productId: loose, qty: 1, lineTotal: 30),
        (productId: null, qty: 1, lineTotal: 20),
      ],
    );

    final rows = await repo.salesBy(
      dimension: SalesByDimension.category,
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );
    expect(rows, hasLength(3));
    expect(rows.first.label, 'بقالة');
    expect(rows.first.salesBase, 300);
    expect(rows.first.invoiceCount, 2);
    // «غير مصنّف»: الصنف بلا فئة + السطر الحر معاً (قرار 10).
    expect(rows[1].label, '');
    expect(rows[1].salesBase, 50, reason: '30 + 20 سطر حر');
    expect(rows[2].label, 'مشروبات');
    expect(rows[2].salesBase, 40);
  });

  test(
    'salesBy(item): تجميع الأصناف + السطر الحر مستبعد + تحويل العملة',
    () async {
      final rice = await makeProduct('أرز');
      final oil = await makeProduct('زيت');
      await makeInvoice(
        no: 'INV-1',
        issuedAt: '2026-11-02T10:00:00Z',
        lines: [
          (productId: rice, qty: 3, lineTotal: 300),
          (productId: oil, qty: 1, lineTotal: 50),
          // سطر حر — مستبعد عمداً (قرار 10).
          (productId: null, qty: 5, lineTotal: 999),
        ],
      );
      // فاتورة SAR للأرز: 40 SAR × 2 = 80 أساس.
      await makeInvoice(
        no: 'INV-2',
        issuedAt: '2026-11-08T10:00:00Z',
        currency: sar,
        exchangeRate: 2,
        lines: [(productId: rice, qty: 1, lineTotal: 40)],
      );

      final rows = await repo.salesBy(
        dimension: SalesByDimension.item,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      expect(rows, hasLength(2));
      expect(rows.first.label, 'أرز');
      expect(rows.first.salesBase, 380, reason: '300 + 40×2');
      expect(rows.first.invoiceCount, 2);
      expect(rows.last.label, 'زيت');
      expect(rows.last.salesBase, 50);
    },
  );

  test('salesBy(day): تجميع باليوم بترتيب تصاعدي', () async {
    await makeInvoice(
      no: 'INV-1',
      issuedAt: '2026-11-03T18:30:00Z',
      lines: [(productId: null, qty: 1, lineTotal: 100)],
    );
    await makeInvoice(
      no: 'INV-2',
      issuedAt: '2026-11-01T09:00:00Z',
      lines: [(productId: null, qty: 1, lineTotal: 70)],
    );
    await makeInvoice(
      no: 'INV-3',
      issuedAt: '2026-11-03T10:00:00Z',
      lines: [(productId: null, qty: 1, lineTotal: 50)],
    );

    final rows = await repo.salesBy(
      dimension: SalesByDimension.day,
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );
    expect(rows, hasLength(2));
    // تصاعدياً بالتاريخ.
    expect(rows.first.label, '2026-11-01');
    expect(rows.first.salesBase, 70);
    expect(rows.last.label, '2026-11-03');
    expect(rows.last.salesBase, 150, reason: 'فاتورتا اليوم نفسه مجمعتان');
    expect(rows.last.invoiceCount, 2);
  });

  test(
    'salesBy: النسبة مقابل الفترة السابقة المساوية (نمو/انخفاض/صفر سابق)',
    () async {
      final grower = await db.insert('customer', {'name': 'عميل نامٍ'});
      final decliner = await db.insert('customer', {'name': 'عميل متراجع'});
      final newcomer = await db.insert('customer', {'name': 'عميل جديد'});
      // الفترة السابقة [25-10 .. 31-10] (N=7 قبل 01-11).
      await makeInvoice(
        no: 'P-1',
        issuedAt: '2026-10-26T10:00:00Z',
        customerId: grower,
        lines: [(productId: null, qty: 1, lineTotal: 100)],
      );
      await makeInvoice(
        no: 'P-2',
        issuedAt: '2026-10-27T10:00:00Z',
        customerId: decliner,
        lines: [(productId: null, qty: 1, lineTotal: 200)],
      );
      // الفترة الحالية [01-11 .. 07-11].
      await makeInvoice(
        no: 'C-1',
        issuedAt: '2026-11-02T10:00:00Z',
        customerId: grower,
        lines: [(productId: null, qty: 1, lineTotal: 150)],
      );
      await makeInvoice(
        no: 'C-2',
        issuedAt: '2026-11-04T10:00:00Z',
        customerId: decliner,
        lines: [(productId: null, qty: 1, lineTotal: 100)],
      );
      await makeInvoice(
        no: 'C-3',
        issuedAt: '2026-11-05T10:00:00Z',
        customerId: newcomer,
        lines: [(productId: null, qty: 1, lineTotal: 80)],
      );

      final rows = await repo.salesBy(
        dimension: SalesByDimension.customer,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 7),
      );
      final byName = {for (final row in rows) row.label: row};
      expect(byName['عميل نامٍ']!.changePct, closeTo(50.0, 0.001));
      expect(byName['عميل متراجع']!.changePct, closeTo(-50.0, 0.001));
      expect(byName['عميل جديد']!.changePct, isNull, reason: 'صفر السابقة');
    },
  );

  test('salesBy: اليوم يقارن نظيره بالإزاحة نفسها (اليوم − N)', () async {
    // الفترة [08-11 .. 14-11] (N=7): السابق [01-11 .. 07-11].
    // يوم 10-11 (الإزاحة 2) يقارن نظيره 03-11 (الإزاحة 2 نفسها).
    await makeInvoice(
      no: 'P-1',
      issuedAt: '2026-11-03T10:00:00Z',
      lines: [(productId: null, qty: 1, lineTotal: 100)],
    );
    await makeInvoice(
      no: 'C-1',
      issuedAt: '2026-11-10T10:00:00Z',
      lines: [(productId: null, qty: 1, lineTotal: 150)],
    );
    await makeInvoice(
      no: 'C-2',
      issuedAt: '2026-11-12T10:00:00Z',
      lines: [(productId: null, qty: 1, lineTotal: 60)],
    );

    final rows = await repo.salesBy(
      dimension: SalesByDimension.day,
      from: DateTime(2026, 11, 8),
      to: DateTime(2026, 11, 14),
    );
    final byDay = {for (final row in rows) row.label: row};
    expect(byDay['2026-11-10']!.changePct, closeTo(50.0, 0.001));
    // 12-11 لا نظير له في 05-11 → null.
    expect(byDay['2026-11-12']!.changePct, isNull);
  });

  test('salesBy: المسودة والإبطال مستبعدان حصراً', () async {
    final ahmed = await db.insert('customer', {'name': 'أحمد'});
    await makeInvoice(
      no: 'INV-1',
      issuedAt: '2026-11-02T10:00:00Z',
      customerId: ahmed,
      lines: [(productId: null, qty: 1, lineTotal: 100)],
    );
    await makeInvoice(
      no: 'INV-2',
      issuedAt: '2026-11-03T10:00:00Z',
      customerId: ahmed,
      status: 'draft',
      lines: [(productId: null, qty: 1, lineTotal: 500)],
    );
    await makeInvoice(
      no: 'INV-3',
      issuedAt: '2026-11-04T10:00:00Z',
      customerId: ahmed,
      status: 'void',
      lines: [(productId: null, qty: 1, lineTotal: 700)],
    );
    // مرتجع بيع — ليس فاتورة بيع (doc_type مختلف).
    await makeInvoice(
      no: 'SRN-1',
      issuedAt: '2026-11-05T10:00:00Z',
      customerId: ahmed,
      docType: 'sale_return',
      lines: [(productId: null, qty: 1, lineTotal: 90)],
    );

    final rows = await repo.salesBy(
      dimension: SalesByDimension.customer,
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );
    expect(rows, hasLength(1));
    expect(rows.first.salesBase, 100);
    expect(rows.first.invoiceCount, 1);
  });

  test('salesBy: فترة بلا مبيعات — قائمة فارغة', () async {
    final rows = await repo.salesBy(
      dimension: SalesByDimension.customer,
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );
    expect(rows, isEmpty);
  });
}
