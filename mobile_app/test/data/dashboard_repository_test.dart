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
      expect(series[i].date.compareTo(series[i - 1].date), greaterThan(0),
          reason: 'التواريخ يجب أن تكون تصاعدية بلا تكرار');
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
}
