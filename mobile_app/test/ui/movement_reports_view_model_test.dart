/// اختبارات نماذج عرض تقارير الحركة والمبيعات (الشريحة 10): حالة
/// «اختر صنفاً» قبل التحديد، التحميل المشروط بالصنف، نطاقات الفترات
/// المسبقة والمدى المخصص، حالة الخطأ، ملخص المخزون، وأبعاد المبيعات
/// مع الإجمالي — بلحظة «الآن» محقونة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/movement_reports_repository.dart';
import 'package:mobile_app/ui/features/reports/view_models/movement_reports_view_model.dart';
import 'package:mobile_app/ui/features/reports/views/widgets/period_preset_bar.dart';
import 'package:sqflite/sqflite.dart';

import '../helpers/app_for_tests.dart';

/// لحظة «الآن» المحقونة — ثابتة فتبقى النطاقات حتمية.
final DateTime _now = DateTime(2026, 10, 8, 15);

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late Database db;
  late MovementReportsRepository repo;
  late int warehouseId;
  late int cashboxId;
  late int rice;

  setUp(() async {
    final seeded = await openSeededApp();
    app = seeded.$1;
    db = app.db;
    repo = MovementReportsRepository(db);
    warehouseId = (await db.query('warehouse', limit: 1)).first['id'] as int;
    cashboxId = (await db.query('cashbox', limit: 1)).first['id'] as int;

    rice = await db.insert('product', {
      'name': 'أرز',
      'cost_price': 100,
      'created_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-01T00:00:00Z',
    });

    Future<void> move(String type, double qty, String movedAt) async {
      await db.insert('stock_movement', {
        'product_id': rice,
        'warehouse_id': warehouseId,
        'movement_type': type,
        'qty': qty,
        'unit_cost': 100,
        'ref_type': 'invoice',
        'ref_id': 1,
        'moved_at': movedAt,
        'created_at': movedAt,
      });
    }

    // افتتاحي قبل الشهر + ثلاث حركات داخله (اليوم/03/05).
    await move('opening', 10, '2026-09-20T09:00:00Z');
    await move('purchase', 5, '2026-10-03T10:00:00Z');
    await move('sale_return', 2, '2026-10-05T10:00:00Z');
    await move('sale', -3, '2026-10-08T10:00:00Z');

    final ahmed = await db.insert('customer', {
      'name': 'أحمد',
      'created_at': '2026-09-01T00:00:00Z',
    });

    Future<int> invoice(
      String no,
      String issuedAt, {
      int? customerId,
      String status = 'completed',
      List<({int? productId, double qty, double lineTotal})> lines = const [],
    }) async {
      final invoiceId = await db.insert('invoice', {
        'invoice_no': no,
        'doc_type': 'sale',
        'pay_status': 'cash',
        'status': status,
        'warehouse_id': warehouseId,
        'cashbox_id': cashboxId,
        'customer_id': customerId,
        'issued_at': issuedAt,
        'currency_id': 1,
        'exchange_rate': 1,
        'total': lines.fold<double>(0, (sum, l) => sum + l.lineTotal),
        'total_base': lines.fold<double>(0, (sum, l) => sum + l.lineTotal),
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

    // اليوم: أحمد 300 (سطر أرز 200 + سطر حر 100) + نقدي 50 + مسودة 999.
    await invoice(
      'VM-1',
      '2026-10-08T11:00:00Z',
      customerId: ahmed,
      lines: [
        (productId: rice, qty: 2, lineTotal: 200.0),
        (productId: null, qty: 1, lineTotal: 100.0),
      ],
    );
    await invoice(
      'VM-2',
      '2026-10-08T12:00:00Z',
      lines: [(productId: null, qty: 1, lineTotal: 50.0)],
    );
    await invoice(
      'VM-3',
      '2026-10-08T13:00:00Z',
      status: 'draft',
      lines: [(productId: null, qty: 1, lineTotal: 999.0)],
    );
    // يناير: 500 (داخل السنة حصراً).
    await invoice(
      'VM-4',
      '2026-01-15T10:00:00Z',
      customerId: ahmed,
      lines: [(productId: null, qty: 1, lineTotal: 500.0)],
    );
  });

  tearDown(() async {
    await app.close();
  });

  CompanyRepository companies() => CompanyRepository(db);

  // ─────────────────────────────────────────────────────────────────────
  // FR-09-03 — نموذج حركة صنف
  // ─────────────────────────────────────────────────────────────────────

  test('حركة صنف: لا صنف بعد — حالة «اختر صنفاً» لا تقرير فيها', () async {
    final vm = ItemMovementViewModel(
      movementRepo: repo,
      companyRepo: companies(),
      reference: _now,
    );
    await vm.load();
    final s = vm.state;
    expect(s.loading, isFalse);
    expect(s.error, isNull);
    expect(s.needsProduct, isTrue);
    expect(s.productId, isNull);
    expect(s.report, isNull);
    // نطاق الفترة مهيأ رغم غياب الصنف (الشهر افتراضياً).
    expect(s.from, DateTime(2026, 10, 1));
    expect(s.to, DateTime(2026, 10, 8));
    vm.dispose();
  });

  test('حركة صنف: setProduct يحمّل بفتح الشهر وعملة الأساس', () async {
    final vm = ItemMovementViewModel(
      movementRepo: repo,
      companyRepo: companies(),
      reference: _now,
    );
    await vm.load();
    await vm.setProduct(rice);
    final s = vm.state;
    expect(s.loading, isFalse);
    expect(s.error, isNull);
    expect(s.productId, rice);
    expect(s.report, isNotNull);
    expect(s.report!.openingBalance, 10);
    expect(s.report!.rows, hasLength(3), reason: 'شراء + مرتجع + بيع');
    expect(s.report!.totalIn, 7);
    expect(s.report!.totalOut, 3);
    expect(vm.currencyCode, 'YER');
    expect(vm.decimals, 0);
    vm.dispose();
  });

  test('حركة صنف: فترة اليوم — صف اليوم حصراً بتراكمه الكامل', () async {
    final vm = ItemMovementViewModel(
      movementRepo: repo,
      companyRepo: companies(),
      productId: rice,
      reference: _now,
    );
    await vm.load();
    await vm.setPeriod(ReportPeriod.today);
    final s = vm.state;
    expect(s.period, ReportPeriod.today);
    expect(s.from, DateTime(2026, 10, 8));
    expect(s.to, DateTime(2026, 10, 8));
    expect(s.report!.rows, hasLength(1), reason: 'حركة البيع اليوم فقط');
    // التراكم: 10 + 5 + 2 − 3 = 14.
    expect(s.report!.rows.first.balanceAfter, 14);
    vm.dispose();
  });

  test('حركة صنف: صنف مفقود → حالة خطأ عربية بلا تقرير', () async {
    final vm = ItemMovementViewModel(
      movementRepo: repo,
      companyRepo: companies(),
      productId: 999999,
      reference: _now,
    );
    await vm.load();
    final s = vm.state;
    expect(s.loading, isFalse);
    expect(s.error, isA<StateError>());
    expect(s.error.toString(), contains('غير موجود'));
    expect(s.report, isNull);
    vm.dispose();
  });

  // ─────────────────────────────────────────────────────────────────────
  // FR-09-04 — نموذج ملخص المخزون
  // ─────────────────────────────────────────────────────────────────────

  test('ملخص المخزون: التحميل الابتدائي بالشهر والإجمالي والعملة', () async {
    final vm = StockSummaryViewModel(
      movementRepo: repo,
      companyRepo: companies(),
      reference: _now,
    );
    await vm.load();
    final s = vm.state;
    expect(s.loading, isFalse);
    expect(s.error, isNull);
    expect(s.period, ReportPeriod.month);
    expect(s.from, DateTime(2026, 10, 1));
    expect(s.to, DateTime(2026, 10, 8));
    expect(s.rows, hasLength(1));
    expect(s.rows!.first.name, 'أرز');
    // وارد = شراء 5 (المرتجع عمود مستقل)؛ الرصيد = 14؛ القيمة = 1400.
    expect(s.rows!.first.qtyIn, 5);
    expect(s.rows!.first.qtyReturns, 2);
    expect(s.rows!.first.endBalance, 14);
    expect(s.rows!.first.valueAtCost, 1400);
    expect(s.totalValueAtCost, 1400);
    expect(vm.currencyCode, 'YER');
    expect(vm.decimals, 0);
    expect(s.isEmpty, isFalse);
    vm.dispose();
  });

  test('ملخص المخزون: مدى مخصص ضيق → فراغ احتفالي', () async {
    final vm = StockSummaryViewModel(
      movementRepo: repo,
      companyRepo: companies(),
      reference: _now,
    );
    await vm.load();
    await vm.setCustomRange(DateTime(2026, 10, 1), DateTime(2026, 10, 2));
    final s = vm.state;
    expect(s.period, ReportPeriod.custom);
    expect(s.from, DateTime(2026, 10, 1));
    expect(s.to, DateTime(2026, 10, 2));
    expect(s.rows, isEmpty);
    expect(s.isEmpty, isTrue);
    vm.dispose();
  });

  test('ملخص المخزون: خطأ المستودع → حالة خطأ بلا صفوف', () async {
    final vm = StockSummaryViewModel(
      movementRepo: _FailingRepo(db),
      companyRepo: companies(),
      reference: _now,
    );
    await vm.load();
    final s = vm.state;
    expect(s.loading, isFalse);
    expect(s.error, isNotNull);
    expect(s.rows, isNull);
    expect(s.isEmpty, isFalse);
    vm.dispose();
  });

  // ─────────────────────────────────────────────────────────────────────
  // FR-09-06 — نموذج المبيعات حسب
  // ─────────────────────────────────────────────────────────────────────

  test(
    'المبيعات حسب: الافتراضي العميل — الصفوف والإجمالي والنسبة null',
    () async {
      final vm = SalesByViewModel(
        movementRepo: repo,
        companyRepo: companies(),
        reference: _now,
      );
      await vm.load();
      final s = vm.state;
      expect(s.loading, isFalse);
      expect(s.error, isNull);
      expect(s.dimension, SalesByDimension.customer);
      expect(s.rows, hasLength(2), reason: 'أحمد + النقدي (المسودة خارج)');
      expect(s.rows!.first.label, 'أحمد');
      expect(s.rows!.first.salesBase, 300);
      expect(s.rows!.first.invoiceCount, 1);
      expect(s.rows!.last.label, '');
      expect(s.rows!.last.salesBase, 50);
      expect(s.totalSalesBase, 350);
      // لا مبيعات في الفترة السابقة المساوية → النسبة null.
      expect(s.rows!.first.changePct, isNull);
      expect(vm.currencyCode, 'YER');
      expect(vm.decimals, 0);
      vm.dispose();
    },
  );

  test('المبيعات حسب: تبديل البعد إلى الصنف يعيد التحميل', () async {
    final vm = SalesByViewModel(
      movementRepo: repo,
      companyRepo: companies(),
      reference: _now,
    );
    await vm.load();
    await vm.setDimension(SalesByDimension.item);
    final s = vm.state;
    expect(s.dimension, SalesByDimension.item);
    // سطر الأرز حصراً (السطر الحر مستبعد بعد الصنف).
    expect(s.rows, hasLength(1));
    expect(s.rows!.first.label, 'أرز');
    expect(s.rows!.first.salesBase, 200);
    expect(s.totalSalesBase, 200);
    vm.dispose();
  });

  test('المبيعات حسب: فترة السنة تلتقط فاتورة يناير', () async {
    final vm = SalesByViewModel(
      movementRepo: repo,
      companyRepo: companies(),
      reference: _now,
    );
    await vm.load();
    await vm.setPeriod(ReportPeriod.year);
    final s = vm.state;
    expect(s.period, ReportPeriod.year);
    expect(s.from, DateTime(2026, 1, 1));
    expect(s.to, DateTime(2026, 10, 8));
    final ahmed = s.rows!.firstWhere((r) => r.label == 'أحمد');
    expect(ahmed.salesBase, 800, reason: '300 اليوم + 500 يناير');
    expect(ahmed.invoiceCount, 2);
    vm.dispose();
  });
}

/// مستودع يفشل دائماً — لاختبار حالة الخطأ.
class _FailingRepo extends MovementReportsRepository {
  _FailingRepo(super.db);

  @override
  Future<List<StockSummaryRow>> stockSummary({
    required DateTime from,
    required DateTime to,
    int? warehouseId,
  }) async {
    throw StateError('فشل مفتعل للاختبار');
  }
}
