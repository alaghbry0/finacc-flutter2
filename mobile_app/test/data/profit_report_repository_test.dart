/// اختبارات مستودع تقرير الأرباح والخسائر (FR-09-02 — الشريحة 10):
/// تغطية خريطة الترحيل سطراً سطراً («لكل نوع حركة اختبار وحدة يطابق
/// الجدول» — SRS ملحق و) + الصيغة الذهبية من طرف إلى طرف + حدود
/// الفترة والاستبعادات (مسودة/إبطال/معاكسة) وقرار manual_adjust.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/profit_report_repository.dart';

import '../helpers/app_for_tests.dart';

/// نافذة الاختبار — نوفمبر 2026 كاملاً (شاملة الطرفين بالتاريخ).
final DateTime _from = DateTime(2026, 11, 1);
final DateTime _to = DateTime(2026, 11, 30);

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late ProfitReportRepository repo;
  late int warehouseId;
  late int cashboxId;

  setUp(() async {
    app = await openUniqueFileApp();
    repo = ProfitReportRepository(app.db);
    warehouseId = await app.db.insert('warehouse', {
      'name': 'w',
      'is_default': 1,
      'created_at': '2026-11-01T00:00:00Z',
      'updated_at': '2026-11-01T00:00:00Z',
    });
    cashboxId = await app.db.insert('cashbox', {
      'name': 'c',
      'currency_id': 1, // YER الأساس.
      'is_default': 1,
      'created_at': '2026-11-01T00:00:00Z',
      'updated_at': '2026-11-01T00:00:00Z',
    });
  });

  tearDown(() async {
    await app.close();
  });

  /// يبذر فاتورة (بيع/مرتجع) بقيم أساس مباشرة ويعيد معرّفها.
  Future<int> makeInvoice({
    String docType = 'sale',
    String status = 'completed',
    String issuedAt = '2026-11-15T10:30:00Z',
    required double total,
    required double totalBase,
    double costTotal = 0,
    int currencyId = 1,
    double exchangeRate = 1,
  }) => app.db.insert('invoice', {
    'invoice_no': 'T-$docType-$issuedAt-$totalBase-$currencyId',
    'doc_type': docType,
    'pay_status': 'cash',
    'status': status,
    'issued_at': issuedAt,
    'warehouse_id': warehouseId,
    'cashbox_id': cashboxId,
    'currency_id': currencyId,
    'exchange_rate': exchangeRate,
    'total': total,
    'total_base': totalBase,
    'cost_total': costTotal,
  });

  /// يبذر حركة نقدية ويعيد معرّفها.
  Future<int> makeCashTx({
    required String txType,
    required double amount,
    String txDate = '2026-11-15T12:00:00Z',
    double exchangeRate = 1,
    int isVoided = 0,
    int? reversalOf,
    double fxGainLoss = 0,
  }) => app.db.insert('cash_tx', {
    'tx_type': txType,
    'cashbox_id': cashboxId,
    'currency_id': 1,
    'amount': amount,
    'exchange_rate': exchangeRate,
    'fx_gain_loss': fxGainLoss,
    'tx_date': txDate,
    'is_voided': isVoided,
    'reversal_of': reversalOf,
  });

  /// يبذر حركة مخزون ويعيد معرّفها.
  Future<int> makeMove({
    required double qty,
    required double unitCost,
    String movementType = 'stocktake_adjust',
    String movedAt = '2026-11-15T09:00:00Z',
  }) async {
    final productId = await app.db.insert('product', {
      'name': 'صنف ${qty}_$unitCost',
      'created_at': '2026-11-01T00:00:00Z',
      'updated_at': '2026-11-01T00:00:00Z',
    });
    return app.db.insert('stock_movement', {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'movement_type': movementType,
      'qty': qty,
      'unit_cost': unitCost,
      'moved_at': movedAt,
    });
  }

  Future<ProfitReport> report() => repo.report(from: _from, to: _to);

  test('بيع نقدي صرف: مبيعات 1000 وتكلفة 600 وربح 400', () async {
    await makeInvoice(total: 1000, totalBase: 1000, costTotal: 600);
    final r = await report();
    expect(r.sales, 1000);
    expect(r.cogs, 600);
    expect(r.salesReturns, 0);
    expect(r.netSales, 1000);
    expect(r.netCogs, 600);
    expect(r.profit, 400);
    expect(r.netForOwner, 400);
    expect(r.salesInvoiceCount, 1);
    expect(r.hasAnyActivity, isTrue);
  });

  test('المسودة والمُبطلة مستبعدان تماماً من كل السطور', () async {
    await makeInvoice(
      status: 'draft',
      total: 999,
      totalBase: 999,
      costTotal: 500,
    );
    await makeInvoice(
      status: 'void',
      total: 777,
      totalBase: 777,
      costTotal: 300,
    );
    final r = await report();
    expect(r.sales, 0);
    expect(r.cogs, 0);
    expect(r.salesInvoiceCount, 0);
    expect(r.hasAnyActivity, isFalse);
  });

  test('مرتجع بيع: (1000−200) − (600−120) = ربح 320', () async {
    await makeInvoice(total: 1000, totalBase: 1000, costTotal: 600);
    await makeInvoice(
      docType: 'sale_return',
      total: 200,
      totalBase: 200,
      costTotal: 120,
    );
    final r = await report();
    expect(r.salesReturns, 200);
    expect(r.returnCost, 120);
    expect(r.netSales, 800);
    expect(r.netCogs, 480);
    expect(r.profit, 320);
    expect(r.returnInvoiceCount, 1);
  });

  test('فاتورة بعملة أجنبية تُحتسب بالأساس حصراً (لا خلط عملات)', () async {
    // SAR: الإجمالي 500 بسعر 0.1 → total_base = 50 حصراً.
    await makeInvoice(
      total: 500,
      totalBase: 50,
      costTotal: 30,
      currencyId: 2,
      exchangeRate: 0.1,
    );
    final r = await report();
    expect(r.sales, 50, reason: 'بالقيمة الأساسية total_base فقط');
    expect(r.cogs, 30);
    expect(r.profit, 20);
  });

  test('مصروف نقدي 1000 → المصاريف 1000 والربح −1000', () async {
    await makeCashTx(txType: 'expense', amount: 1000);
    final r = await report();
    expect(r.expenses, 1000);
    expect(r.profit, -1000);
    expect(r.netForOwner, -1000);
  });

  test(
    'مسحوبات المالك بند مستقل: ليست مصروفاً وتُخصم من صافي المالك',
    () async {
      await makeInvoice(total: 1000, totalBase: 1000, costTotal: 600);
      await makeCashTx(txType: 'owner_draw', amount: 500);
      final r = await report();
      expect(r.ownerDrawings, 500);
      expect(r.expenses, 0, reason: 'المسحوبات خارج المصاريف (ملحق و)');
      expect(r.profit, 400, reason: 'المسحوبات لا تدخل في الربح');
      expect(r.netForOwner, -100, reason: '400 − 500');
    },
  );

  test('فروق الصرف: ربح +30 وخسارة −20 → السطر +10 يدخل الربح', () async {
    await makeCashTx(txType: 'box_transfer', amount: 100, fxGainLoss: 30);
    await makeCashTx(txType: 'receipt', amount: 200, fxGainLoss: -20);
    final r = await report();
    expect(r.fxGainLoss, 10);
    expect(r.profit, 10);
  });

  test('المصروف المُبطل والمعاكس مستبعدان (إشارات ملحق و)', () async {
    // مُبطلة صريحة: is_voided = 1.
    await makeCashTx(txType: 'expense', amount: 500, isVoided: 1);
    // ثنائي الإبطال الواقعي (نمط cash_repository): أصل مُبطل +
    // معاكسته receipt حية تُستبعد عبر reversal_of.
    final originalId = await makeCashTx(
      txType: 'expense',
      amount: 300,
      isVoided: 1,
    );
    await makeCashTx(txType: 'receipt', amount: 300, reversalOf: originalId);
    // حارس reversal_of وحده: مصروف حيّ غير مبطل لكنه معاكسة — مستبعد.
    await makeCashTx(txType: 'expense', amount: 700, reversalOf: originalId);
    final r = await report();
    expect(r.expenses, 0);
    expect(r.profit, 0);
    expect(r.hasAnyActivity, isFalse);
  });

  test(
    'تسويات الجرد: زيادة +2×150=300 وعجز −1×200=200 (بمقداره الموجب)',
    () async {
      await makeMove(qty: 2, unitCost: 150);
      await makeMove(qty: -1, unitCost: 200);
      final r = await report();
      expect(r.stockSurplus, 300);
      expect(r.stockShortage, 200);
      expect(r.profit, 100, reason: '300 − 200');
    },
  );

  test('فترة فارغة → أصفار كاملة ولا نشاط (الحالة الاحتفالية)', () async {
    final r = await report();
    expect(r.sales, 0);
    expect(r.salesReturns, 0);
    expect(r.cogs, 0);
    expect(r.returnCost, 0);
    expect(r.stockSurplus, 0);
    expect(r.stockShortage, 0);
    expect(r.expenses, 0);
    expect(r.fxGainLoss, 0);
    expect(r.ownerDrawings, 0);
    expect(r.profit, 0);
    expect(r.netForOwner, 0);
    expect(r.hasAnyActivity, isFalse);
  });

  test('الصيغة الذهبية: كل السطور معاً → ربح 280 وصافي المالك 180', () async {
    // إيراد: بيع 1000/600 + مرتجع 200/120 → 800 − 480 = 320.
    await makeInvoice(total: 1000, totalBase: 1000, costTotal: 600);
    await makeInvoice(
      docType: 'sale_return',
      total: 200,
      totalBase: 200,
      costTotal: 120,
    );
    // تسويات: زيادة 300 − عجز 200 = +100.
    await makeMove(qty: 2, unitCost: 150);
    await makeMove(qty: -1, unitCost: 200);
    // مصاريف: 150 (بسعر 1).
    await makeCashTx(txType: 'expense', amount: 150);
    // فروق صرف: +30 − 20 = +10.
    await makeCashTx(txType: 'box_transfer', amount: 100, fxGainLoss: 30);
    await makeCashTx(txType: 'receipt', amount: 200, fxGainLoss: -20);
    // مسحوبات: 100.
    await makeCashTx(txType: 'owner_draw', amount: 100);

    final r = await report();
    expect(r.netSales, 800);
    expect(r.netCogs, 480);
    expect(r.profit, 280, reason: '320 + 100 − 150 + 10');
    expect(r.netForOwner, 180, reason: '280 − 100');
  });

  test('حدود الفترة: من == إلى — اليوم نفسه داخل وما جاوره خارج', () async {
    final day = DateTime(2026, 11, 15);
    await makeInvoice(
      issuedAt: '2026-11-15T00:01:00Z',
      total: 100,
      totalBase: 100,
    );
    await makeInvoice(
      issuedAt: '2026-11-14T23:59:00Z',
      total: 999,
      totalBase: 999,
    );
    await makeInvoice(
      issuedAt: '2026-11-16T00:00:00Z',
      total: 888,
      totalBase: 888,
    );
    await makeCashTx(
      txType: 'expense',
      amount: 10,
      txDate: '2026-11-15T23:59:59Z',
    );
    await makeCashTx(
      txType: 'expense',
      amount: 700,
      txDate: '2026-11-16T00:00:01Z',
    );
    final r = await repo.report(from: day, to: day);
    expect(r.sales, 100);
    expect(r.salesInvoiceCount, 1);
    expect(r.expenses, 10);
    expect(r.profit, 90);
  });

  test(
    'حركات manual_adjust بلا منتج في V1 → خارج سطري الجرد (قرار موثق)',
    () async {
      await makeMove(qty: 5, unitCost: 50, movementType: 'manual_adjust');
      await makeMove(qty: -3, unitCost: 40, movementType: 'manual_adjust');
      final r = await report();
      expect(r.stockSurplus, 0);
      expect(r.stockShortage, 0);
      expect(r.profit, 0);
    },
  );
}
