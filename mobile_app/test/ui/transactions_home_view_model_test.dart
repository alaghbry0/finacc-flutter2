/// اختبارات مركز المعاملات (V3 — هيكل Simple Invoice Manager):
/// التطبيع عبر التبويبات + مرشح الحالة + البحث + النطاق الزمني +
/// الفرز + استبعاد الملغى + شريط الشهر — فوق قاعدة حقيقية مؤسَّسة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/cash_repository.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/dashboard_repository.dart';
import 'package:mobile_app/data/repositories/purchase_repository.dart';
import 'package:mobile_app/data/repositories/quotation_repository.dart';
import 'package:mobile_app/data/repositories/sale_repository.dart';
import 'package:mobile_app/ui/features/home/view_models/transactions_home_view_model.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  /// جهاز كامل: قاعدة مؤسَّسة + بذور معاملات خام عبر SQL (التطبيع
  /// محل الاختبار — الترحيل الكامل له اختباراته في مستودعات البيع).
  Future<(TransactionsHomeViewModel, AppDatabase)> boot() async {
    final app = await openUniqueFileApp();
    await CompanyRepository(
      app.db,
    ).executeSetup(testDraft(), DateTime.utc(2026, 10, 1, 9));
    final db = app.db;

    final baseCurrency =
        (await db.rawQuery(
          'SELECT id FROM currency WHERE is_base = 1 LIMIT 1',
        )).first['id'] as int;
    final warehouse =
        (await db.rawQuery('SELECT id FROM warehouse LIMIT 1')).first['id']
            as int;
    final cashbox =
        (await db.rawQuery('SELECT id FROM cashbox LIMIT 1')).first['id']
            as int;

    final customerAhmed =
        await db.insert('customer', {'name': 'أحمد سالم'});
    final customerNoor =
        await db.insert('customer', {'name': 'شركة النور'});
    await db.insert('supplier', {'name': 'مورد المصنع'});

    final now = DateTime.now();
    String iso(DateTime dt) => dt.toIso8601String();

    // فواتير بيع: نقدي/مختلط/آجل + واحدة ملغاة (تُستبعد).
    Future<int> saleInvoice(
      String no,
      String payStatus, {
      int? customerId,
      double total = 1000,
      double paid = 0,
      String status = 'completed',
    }) => db.insert('invoice', {
      'invoice_no': no,
      'doc_type': 'sale',
      'pay_status': payStatus,
      'status': status,
      'issued_at': iso(now),
      'customer_id': customerId,
      'warehouse_id': warehouse,
      'currency_id': baseCurrency,
      'exchange_rate': 1,
      'total': total,
      'total_base': total,
      'paid_amount': paid,
      'due_amount': total - paid,
    });

    await saleInvoice('INV1', 'credit', customerId: customerAhmed,
        total: 5000);
    await saleInvoice(
      'INV2', 'mixed',
      customerId: customerNoor,
      total: 12700,
      paid: 5000,
    );
    await saleInvoice('INV3', 'cash', total: 300, paid: 300);
    await saleInvoice('INVV', 'cash', total: 99, status: 'void');

    await db.insert('quotation', {
      'quotation_no': 'QTE1',
      'customer_id': customerNoor,
      'warehouse_id': warehouse,
      'currency_id': baseCurrency,
      'exchange_rate': 1,
      'issued_at': iso(now),
      'status': 'sent',
      'total': 800,
    });

    await db.insert('invoice', {
      'invoice_no': 'PUR1',
      'doc_type': 'purchase',
      'pay_status': 'credit',
      'status': 'completed',
      'issued_at': iso(now),
      'supplier_id': 1,
      'warehouse_id': warehouse,
      'currency_id': baseCurrency,
      'exchange_rate': 1,
      'total': 4000,
      'total_base': 4000,
      'paid_amount': 0,
      'due_amount': 4000,
    });

    await db.insert('cash_tx', {
      'tx_type': 'receipt',
      'cashbox_id': cashbox,
      'currency_id': baseCurrency,
      'amount': 5000,
      'exchange_rate': 1,
      'voucher_no': 'RVT1',
      'tx_date': iso(now),
      'customer_id': customerNoor,
    });
    await db.insert('cash_tx', {
      'tx_type': 'payment',
      'cashbox_id': cashbox,
      'currency_id': baseCurrency,
      'amount': 900,
      'exchange_rate': 1,
      'voucher_no': 'PMT1',
      'tx_date': iso(now),
      'supplier_id': 1,
    });

    final vm = TransactionsHomeViewModel(
      saleRepository: SaleRepository(app.db),
      quotationRepository: QuotationRepository(app.db),
      purchaseRepository: PurchaseRepository(app.db),
      cashRepository: CashRepository(app.db),
      dashboardRepository: DashboardRepository(app.db),
    );
    addTearDown(vm.dispose);
    return (vm, app);
  }

  test('تبويب البيع: التطبيع والشارات واستبعاد الملغى وشريط الشهر', () async {
    final (vm, _) = await boot();
    await vm.load();

    expect(vm.state.loading, isFalse);
    expect(vm.state.error, isNull);
    expect(vm.state.rows, hasLength(3)); // الملغاة INVV مستبعدة.

    final byNo = {
      for (final row in vm.state.rows) row.docNo: row,
    };
    expect(byNo['INV1']!.badge, HomeBadge.unpaid);
    expect(byNo['INV2']!.badge, HomeBadge.partial);
    expect(byNo['INV3']!.badge, HomeBadge.paid);
    expect(byNo['INV1']!.partyName, 'أحمد سالم');
    expect(byNo['INV1']!.detailRoute, '/sell/invoices/${byNo['INV1']!.id}');
    expect(byNo['INV2']!.dueAmount, 7700);

    // شريط الشهر: مبيعات الشهر = 5000 + 12700 + 300 (بالأساس).
    expect(vm.state.month, isNotNull);
    expect(vm.state.month!.thisMonthSales, 18000);
    expect(vm.state.month!.invoiceCountThisMonth, 3);
  });

  test('مرشح الحالة: مدفوع/جزئي/غير مدفوع فوق تبويب البيع', () async {
    final (vm, _) = await boot();
    await vm.load();

    vm.setStatusFilter(HomeStatusFilter.paid);
    expect(vm.state.rows.map((r) => r.docNo), ['INV3']);

    vm.setStatusFilter(HomeStatusFilter.partial);
    expect(vm.state.rows.map((r) => r.docNo), ['INV2']);

    vm.setStatusFilter(HomeStatusFilter.unpaid);
    expect(vm.state.rows.map((r) => r.docNo), ['INV1']);

    vm.setStatusFilter(HomeStatusFilter.all);
    expect(vm.state.rows, hasLength(3));
    expect(vm.state.totalCount, 3);
  });

  test('البحث النصي: برقم المستند وباسم الطرف (غير حساس للحالة)', () async {
    final (vm, _) = await boot();
    await vm.load();

    vm.setQuery('inv2');
    expect(vm.state.rows.map((r) => r.docNo), ['INV2']);
    expect(vm.state.totalCount, 3); // العدد الكلي قبل التصفية.

    vm.setQuery('النور');
    expect(vm.state.rows.map((r) => r.docNo), ['INV2']);

    vm.setQuery('');
    expect(vm.state.rows, hasLength(3));
  });

  test('الفرز: بالمبلغ تنازلياً وبالأقدم أولاً', () async {
    final (vm, _) = await boot();
    await vm.load();

    vm.setSort(HomeSortOption.totalDesc);
    expect(
      vm.state.rows.map((r) => r.docNo).toList(),
      ['INV2', 'INV1', 'INV3'],
    );

    vm.setSort(HomeSortOption.dateAsc);
    expect(vm.state.rows, hasLength(3)); // نفس اللحظة — الترتيب مستقر.
  });

  test('النطاق الزمني: نافذة الأسبوع تُبقي بذور اليوم، والفراغ يستبعد', () async {
    final (vm, app) = await boot();
    await vm.load();

    await vm.setTimeRange(HomeTimeRange.week);
    expect(vm.state.rows, hasLength(3));

    // مستند قديم (قبل سنة) يختفي عند أي نطاق غير «كل الوقت».
    await app.db.insert('invoice', {
      'invoice_no': 'INVOLD',
      'doc_type': 'sale',
      'pay_status': 'cash',
      'status': 'completed',
      'issued_at': DateTime.now()
          .subtract(const Duration(days: 400))
          .toIso8601String(),
      'warehouse_id': 1,
      'currency_id': 1,
      'exchange_rate': 1,
      'total': 50,
      'total_base': 50,
      'paid_amount': 50,
      'due_amount': 0,
    });
    await vm.load();
    expect(vm.state.rows, hasLength(3)); // نافذة الأسبوع ما تزال تستبعد القديم.

    // العودة لكل الوقت تُظهر القديم أيضاً.
    await vm.setTimeRange(HomeTimeRange.all);
    expect(vm.state.rows, hasLength(4)); // كل الوقت يشمل القديم.
  });

  test('تبويبات العروض والمشتريات والسندات: التطبيع الصحيح لكل مصدر',
      () async {
    final (vm, _) = await boot();
    await vm.load();

    await vm.setTab(HomeTab.quotations);
    expect(vm.state.rows, hasLength(1));
    expect(vm.state.rows.first.docNo, 'QTE1');
    expect(vm.state.rows.first.badge, HomeBadge.sent);

    await vm.setTab(HomeTab.purchases);
    expect(vm.state.rows, hasLength(1));
    expect(vm.state.rows.first.docNo, 'PUR1');
    expect(vm.state.rows.first.badge, HomeBadge.unpaid);
    expect(vm.state.rows.first.partyName, 'مورد المصنع');

    await vm.setTab(HomeTab.receipts);
    expect(vm.state.rows, hasLength(1));
    expect(vm.state.rows.first.docNo, 'RVT1');
    expect(vm.state.rows.first.total, 5000);

    await vm.setTab(HomeTab.payments);
    expect(vm.state.rows, hasLength(1));
    expect(vm.state.rows.first.docNo, 'PMT1');
  });

  test('تبويب التقارير بلا استعلامات ولا أخطاء', () async {
    final (vm, _) = await boot();
    await vm.setTab(HomeTab.reports);
    expect(vm.state.loading, isFalse);
    expect(vm.state.error, isNull);
    expect(vm.state.rows, isEmpty);
  });
}
