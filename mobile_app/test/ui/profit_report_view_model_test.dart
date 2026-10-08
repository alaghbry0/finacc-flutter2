/// اختبارات نموذج عرض تقرير الأرباح والخسائر (FR-09-02 — الشريحة 10):
/// التحميل الابتدائي، نطاقات الفترات المسبقة (اليوم/الأسبوع/الشهر/
/// الربع/السنة) بلحظة «الآن» محقونة، المدى المخصص، حالة الخطأ، وبقاء
/// الفترة عبر إعادة التحميل.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/profit_report_repository.dart';
import 'package:mobile_app/ui/features/reports/view_models/profit_report_view_model.dart';
import 'package:mobile_app/ui/features/reports/views/widgets/period_preset_bar.dart';

import '../helpers/app_for_tests.dart';

/// لحظة «الآن» المحقونة — ثابتة فتبقى النطاقات حتمية.
final DateTime _now = DateTime(2026, 10, 8, 15);

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late ProfitReportRepository repo;

  setUp(() async {
    final seeded = await openSeededApp();
    app = seeded.$1;
    repo = ProfitReportRepository(app.db);
    final db = app.db;
    final warehouseId =
        (await db.query('warehouse', limit: 1)).first['id'] as int;
    final cashboxId = (await db.query('cashbox', limit: 1)).first['id'] as int;
    // فاتورة «اليوم» (08-10-2026): 1000/600 — داخل كل النطاقات الجارية.
    await db.insert('invoice', {
      'invoice_no': 'VM-P-1',
      'doc_type': 'sale',
      'pay_status': 'cash',
      'status': 'completed',
      'issued_at': '2026-10-08T10:00:00Z',
      'warehouse_id': warehouseId,
      'cashbox_id': cashboxId,
      'currency_id': 1,
      'exchange_rate': 1,
      'total': 1000,
      'total_base': 1000,
      'cost_total': 600,
    });
    // فاتورة يناير: 500/300 — داخل السنة والمدى المخصص فقط.
    await db.insert('invoice', {
      'invoice_no': 'VM-P-2',
      'doc_type': 'sale',
      'pay_status': 'cash',
      'status': 'completed',
      'issued_at': '2026-01-15T10:00:00Z',
      'warehouse_id': warehouseId,
      'cashbox_id': cashboxId,
      'currency_id': 1,
      'exchange_rate': 1,
      'total': 500,
      'total_base': 500,
      'cost_total': 300,
    });
  });

  tearDown(() async {
    await app.close();
  });

  ProfitReportViewModel buildVm() => ProfitReportViewModel(
    profitRepo: repo,
    companyRepo: CompanyRepository(app.db),
    reference: _now,
  );

  test('التحميل الابتدائي: الشهر افتراضياً بعملة الأساس ومنازلها', () async {
    final vm = buildVm();
    await vm.load();
    final s = vm.state;
    expect(s.loading, isFalse);
    expect(s.error, isNull);
    expect(s.period, ReportPeriod.month);
    expect(s.from, DateTime(2026, 10, 1));
    expect(s.to, DateTime(2026, 10, 8));
    expect(s.report, isNotNull);
    expect(s.report!.sales, 1000);
    expect(s.currencyCode, 'YER');
    expect(s.decimals, 0);
    expect(s.isEmpty, isFalse);
    vm.dispose();
  });

  test('فترة اليوم: من == إلى == يوم «الآن»', () async {
    final vm = buildVm();
    await vm.load();
    await vm.setPeriod(ReportPeriod.today);
    final s = vm.state;
    expect(s.period, ReportPeriod.today);
    expect(s.from, DateTime(2026, 10, 8));
    expect(s.to, DateTime(2026, 10, 8));
    expect(s.report!.sales, 1000);
    vm.dispose();
  });

  test('فترة الأسبوع: آخر ٧ أيام (من 02-10 إلى 08-10)', () async {
    final vm = buildVm();
    await vm.load();
    await vm.setPeriod(ReportPeriod.week);
    final s = vm.state;
    expect(s.period, ReportPeriod.week);
    expect(s.from, DateTime(2026, 10, 2));
    expect(s.to, DateTime(2026, 10, 8));
    expect(s.report!.sales, 1000);
    vm.dispose();
  });

  test('فترة الربع: الربع الرابع يبدأ 01-10 (قلب حدود الأرباع)', () async {
    final vm = buildVm();
    await vm.load();
    await vm.setPeriod(ReportPeriod.quarter);
    final s = vm.state;
    expect(s.period, ReportPeriod.quarter);
    expect(s.from, DateTime(2026, 10, 1));
    expect(s.report!.sales, 1000);
    vm.dispose();
  });

  test('فترة السنة: من 01-01 تشمل فاتورة يناير (1500)', () async {
    final vm = buildVm();
    await vm.load();
    await vm.setPeriod(ReportPeriod.year);
    final s = vm.state;
    expect(s.period, ReportPeriod.year);
    expect(s.from, DateTime(2026, 1, 1));
    expect(s.to, DateTime(2026, 10, 8));
    expect(s.report!.sales, 1500);
    vm.dispose();
  });

  test('مدى مخصص: يناير حصراً + فترة فارغة احتفالية', () async {
    final vm = buildVm();
    await vm.load();
    await vm.setCustomRange(DateTime(2026, 1, 10), DateTime(2026, 1, 20));
    final s = vm.state;
    expect(s.period, ReportPeriod.custom);
    expect(s.from, DateTime(2026, 1, 10));
    expect(s.to, DateTime(2026, 1, 20));
    expect(s.report!.sales, 500, reason: 'فاتورة 15-01 داخل المدى');

    // مدى بلا أي حركة → الحالة الفارغة.
    await vm.setCustomRange(DateTime(2026, 3, 1), DateTime(2026, 3, 31));
    expect(vm.state.isEmpty, isTrue);
    expect(vm.state.report!.hasAnyActivity, isFalse);
    vm.dispose();
  });

  test('حالة الخطأ: فشل المستودع يرفع الخطأ دون تقرير', () async {
    final vm = ProfitReportViewModel(
      profitRepo: _ThrowingProfitRepo(app.db),
      companyRepo: CompanyRepository(app.db),
      reference: _now,
    );
    await vm.load();
    final s = vm.state;
    expect(s.loading, isFalse);
    expect(s.error, isNotNull);
    expect(s.report, isNull);
    expect(s.period, ReportPeriod.month);
    vm.dispose();
  });

  test('إعادة التحميل تبقي الفترة والمدى (سحب للتحديث)', () async {
    final vm = buildVm();
    await vm.load();
    await vm.setPeriod(ReportPeriod.year);
    await vm.refresh();
    final s = vm.state;
    expect(s.period, ReportPeriod.year);
    expect(s.from, DateTime(2026, 1, 1));
    expect(s.report, isNotNull);
    expect(s.report!.sales, 1500);
    expect(s.loading, isFalse);
    vm.dispose();
  });
}

/// مستودع يفشل دائماً — لاختبار حالة الخطأ بمعزل عن SQL حقيقي.
class _ThrowingProfitRepo extends ProfitReportRepository {
  _ThrowingProfitRepo(super.db);

  @override
  Future<ProfitReport> report({required DateTime from, required DateTime to}) {
    throw StateError('فشل مفتعل لاختبار حالة الخطأ');
  }
}
