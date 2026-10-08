/// اختبارات مستودع لوحة التحكم — سباكة SQL جاهزة للشرائح القادمة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/dashboard_repository.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late DashboardRepository repo;

  setUp(() async {
    app = await openUniqueFileApp();
    repo = DashboardRepository(app.db);
  });

  tearDown(() async {
    await app.close();
  });

  test('todayStats: أصفار كاملة على قاعدة حديثة التأسيس', () async {
    final stats = await repo.todayStats(DateTime(2026, 10, 6, 15));
    expect(stats.sales, 0);
    expect(stats.profit, 0);
    expect(stats.invoiceCount, 0);
    expect(stats.netCash, 0);
  });

  test('last30DaysSales: 30 نقطة متصلة بترتيب تصاعدي وأصفار', () async {
    final now = DateTime(2026, 10, 6, 15);
    final series = await repo.last30DaysSales(now);
    expect(series, hasLength(30));
    expect(series.first.date, '2026-09-07');
    expect(series.last.date, '2026-10-06');
    for (var i = 1; i < series.length; i++) {
      expect(
        series[i].date.compareTo(series[i - 1].date),
        greaterThan(0),
        reason: 'التواريخ يجب أن تكون تصاعدية بلا تكرار',
      );
    }
    expect(series.every((p) => p.total == 0), isTrue);
  });

  test('lowStockCount: صفر بلا أصناف (عدّاد FR-09-12)', () async {
    expect(await repo.lowStockCount(), 0);
  });

  test('todayStats يقرأ يوم الجهاز المحلي (حدّ تاريخ اليوم)', () async {
    // إدخال فاتورة بيع مكتملة «اليوم» عبر SQL مباشرة (السباكة جاهزة).
    final warehouseId = await app.db.insert('warehouse', {
      'name': 'w',
      'is_default': 1,
      'created_at': '2026-10-06T00:00:00Z',
      'updated_at': '2026-10-06T00:00:00Z',
    });
    final cashboxId = await app.db.insert('cashbox', {
      'name': 'c',
      'currency_id': 1,
      'is_default': 1,
      'created_at': '2026-10-06T00:00:00Z',
      'updated_at': '2026-10-06T00:00:00Z',
    });
    await app.db.insert('invoice', {
      'invoice_no': 'INV-2026-000001',
      'doc_type': 'sale',
      'pay_status': 'cash',
      'status': 'completed',
      'warehouse_id': warehouseId,
      'cashbox_id': cashboxId,
      'issued_at': '2026-10-06T10:30:00Z',
      'exchange_rate': 1.0,
      'total': 250.0,
      'total_base': 250.0,
      'cost_total': 180.0,
      'currency_id': 1,
    });
    final stats = await repo.todayStats(DateTime(2026, 10, 6, 15));
    expect(stats.sales, 250.0);
    expect(stats.profit, 70.0);
    expect(stats.invoiceCount, 1);
    expect(stats.netCash, 0, reason: 'لا حركة صندوق — الفاتورة غير نقدية هنا');
  });

  // ── 17-c: مبيعات الشهر + أعلى الأصناف مبيعاً ─────────────────────

  late int dashWarehouseId;
  late int dashCashboxId;

  setUp(() async {
    dashWarehouseId = await app.db.insert('warehouse', {
      'name': 'w',
      'is_default': 1,
      'created_at': '2026-10-06T00:00:00Z',
      'updated_at': '2026-10-06T00:00:00Z',
    });
    dashCashboxId = await app.db.insert('cashbox', {
      'name': 'c',
      'currency_id': 1,
      'is_default': 1,
      'created_at': '2026-10-06T00:00:00Z',
      'updated_at': '2026-10-06T00:00:00Z',
    });
  });

  /// يبذر صنفاً ويعيد معرّفه.
  Future<int> makeProduct(String name) => app.db.insert('product', {
    'name': name,
    'created_at': '2026-10-06T00:00:00Z',
    'updated_at': '2026-10-06T00:00:00Z',
  });

  /// يبذر فاتورة بيع بعملة/سعر صرف مع بنودها ويعيد معرّفها.
  Future<int> makeSaleInvoice({
    required String no,
    required String issuedAt,
    required List<({int? productId, double qty, double lineTotal})> lines,
    String status = 'completed',
    double totalBase = 0,
    double exchangeRate = 1.0,
  }) async {
    final invoiceId = await app.db.insert('invoice', {
      'invoice_no': no,
      'doc_type': 'sale',
      'pay_status': lines.isEmpty ? 'cash' : 'credit',
      'status': status,
      'warehouse_id': dashWarehouseId,
      'cashbox_id': dashCashboxId,
      'issued_at': issuedAt,
      'exchange_rate': exchangeRate,
      'total': lines.fold<double>(0, (sum, l) => sum + l.lineTotal),
      'total_base': totalBase == 0
          ? lines.fold<double>(0, (sum, l) => sum + l.lineTotal) * exchangeRate
          : totalBase,
      'currency_id': 1,
    });
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      await app.db.insert('invoice_item', {
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

  test(
    'monthStats: هذا الشهر مقابل السابق بالنسبة، والمسودة/الإبطال مستبعدان',
    () async {
      // نوفمبر 2026 = 450 (فاتورتان مكتملتان)؛ أكتوبر 2026 = 300.
      // مسودة نوفمبر (50) وإبطال نوفمبر (70) لا يُحتسبان أبداً.
      await makeSaleInvoice(
        no: 'INV-2026-000101',
        issuedAt: '2026-11-02T10:00:00Z',
        lines: [(productId: null, qty: 1, lineTotal: 200)],
        totalBase: 200,
      );
      await makeSaleInvoice(
        no: 'INV-2026-000102',
        issuedAt: '2026-11-28T18:00:00Z',
        lines: [(productId: null, qty: 1, lineTotal: 250)],
        totalBase: 250,
      );
      await makeSaleInvoice(
        no: 'INV-2026-000103',
        issuedAt: '2026-11-15T12:00:00Z',
        status: 'draft',
        lines: [(productId: null, qty: 1, lineTotal: 50)],
        totalBase: 50,
      );
      await makeSaleInvoice(
        no: 'INV-2026-000104',
        issuedAt: '2026-11-20T12:00:00Z',
        status: 'void',
        lines: [(productId: null, qty: 1, lineTotal: 70)],
        totalBase: 70,
      );
      await makeSaleInvoice(
        no: 'INV-2026-000105',
        issuedAt: '2026-10-09T10:00:00Z',
        lines: [(productId: null, qty: 1, lineTotal: 300)],
        totalBase: 300,
      );

      final stats = await repo.monthStats(DateTime(2026, 11, 30, 23));
      expect(stats.thisMonthSales, 450);
      expect(stats.previousMonthSales, 300);
      expect(stats.invoiceCountThisMonth, 2);
      expect(stats.changePct, closeTo(50.0, 0.001), reason: '(450−300)/300');
    },
  );

  test('monthStats: صفر الشهر السابق → نسبة null (واجهة «جديد»)', () async {
    await makeSaleInvoice(
      no: 'INV-2026-000110',
      issuedAt: '2026-12-05T10:00:00Z',
      lines: [(productId: null, qty: 1, lineTotal: 80)],
      totalBase: 80,
    );
    final stats = await repo.monthStats(DateTime(2026, 12, 15, 9));
    expect(stats.thisMonthSales, 80);
    expect(stats.previousMonthSales, 0);
    expect(stats.changePct, isNull);
    expect(stats.invoiceCountThisMonth, 1);
  });

  test('monthStats: قلب السنة — يناير يقارن ديسمبر السنة السابقة', () async {
    await makeSaleInvoice(
      no: 'INV-2025-000120',
      issuedAt: '2025-12-31T23:00:00Z',
      lines: [(productId: null, qty: 1, lineTotal: 100)],
      totalBase: 100,
    );
    await makeSaleInvoice(
      no: 'INV-2026-000121',
      issuedAt: '2026-01-02T08:00:00Z',
      lines: [(productId: null, qty: 1, lineTotal: 50)],
      totalBase: 50,
    );
    final stats = await repo.monthStats(DateTime(2026, 1, 10, 10));
    expect(stats.thisMonthSales, 50);
    expect(stats.previousMonthSales, 100);
    expect(stats.changePct, closeTo(-50.0, 0.001));
  });

  test(
    'topItems: تجميع الكمية عبر الفواتير + وصلة الاسم + الإيراد بالأساس',
    () async {
      final rice = await makeProduct('أرز بسمتي');
      final oil = await makeProduct('زيت دوار الشمس');
      final sugar = await makeProduct('سكر');
      // فاتورة بعملة أجنبية (سعر 2): الإيراد الأساس = line_total × 2.
      await makeSaleInvoice(
        no: 'INV-2026-000130',
        issuedAt: '2026-11-01T10:00:00Z',
        exchangeRate: 2.0,
        lines: [
          (productId: rice, qty: 4.0, lineTotal: 100.0),
          (productId: oil, qty: 1.0, lineTotal: 30.0),
          // سطر حر (product_id NULL) — مستبعد عمداً.
          (productId: null, qty: 9.0, lineTotal: 999.0),
        ],
      );
      await makeSaleInvoice(
        no: 'INV-2026-000131',
        issuedAt: '2026-11-03T10:00:00Z',
        lines: [(productId: rice, qty: 6.0, lineTotal: 150.0)],
      );
      // مسودة وإبطال بنفس الأصناف — لا يُحتسبان.
      await makeSaleInvoice(
        no: 'INV-2026-000132',
        issuedAt: '2026-11-05T10:00:00Z',
        status: 'draft',
        lines: [(productId: sugar, qty: 50.0, lineTotal: 500.0)],
      );
      await makeSaleInvoice(
        no: 'INV-2026-000133',
        issuedAt: '2026-11-06T10:00:00Z',
        status: 'void',
        lines: [(productId: rice, qty: 100.0, lineTotal: 1000.0)],
      );

      final items = await repo.topItems(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      expect(
        items,
        hasLength(2),
        reason: 'الأرز والزيت فقط (الحر/المسودة/الإبطال خارج)',
      );
      expect(items.first.name, 'أرز بسمتي');
      expect(items.first.qtySold, 10, reason: '4 + 6 عبر فاتورتين');
      expect(
        items.first.revenueBase,
        closeTo(350.0, 0.001),
        reason: '100×2 + 150×1',
      );
      expect(items[1].name, 'زيت دوار الشمس');
      expect(items[1].qtySold, 1);
      expect(items[1].revenueBase, closeTo(60.0, 0.001), reason: '30 × 2');
    },
  );

  test('topItems: فلترة الفترة + حد limit', () async {
    final a = await makeProduct('صنف أ');
    final b = await makeProduct('صنف ب');
    final c = await makeProduct('صنف ج');
    await makeSaleInvoice(
      no: 'INV-2026-000140',
      issuedAt: '2026-10-15T10:00:00Z',
      lines: [(productId: a, qty: 5.0, lineTotal: 50.0)],
    );
    await makeSaleInvoice(
      no: 'INV-2026-000141',
      issuedAt: '2026-11-10T10:00:00Z',
      lines: [
        (productId: b, qty: 3.0, lineTotal: 30.0),
        (productId: c, qty: 2.0, lineTotal: 20.0),
      ],
    );

    // نافذة أكتوبر حصراً: صنف أ وحده.
    final october = await repo.topItems(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
    );
    expect(october, hasLength(1));
    expect(october.first.name, 'صنف أ');

    // نافذة نوفمبر بحد 1: الأعلى كميّاً (ب).
    final limited = await repo.topItems(
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
      limit: 1,
    );
    expect(limited, hasLength(1));
    expect(limited.first.name, 'صنف ب');
  });

  test('topItems: فراغ احتفالي عند لا مبيعات', () async {
    final items = await repo.topItems(
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );
    expect(items, isEmpty);
  });
}
