/// اختبارات البونص في تقرير الأرباح والخسائر (موجة UX-4 — القرار
/// التحاسبي UX-audit-invoice §3 كما نُفّذ في `SaleRepository.postSale`):
/// بذرة بفترتين متقابلتين بصنفين — فاتورة «شامبو 10 مدفوعة + 2 مجاني»
/// وسطر «صابون 10» بلا بونص:
///
/// - **(أ) COGS يشمل المنصرف الكلي** (12×WAC): الربح ينخفض بالمقدار
///   الحرفي 2×WAC مقارنة بنفس الفاتورة بلا بونص — المجاني وحدات حقيقية
///   خرجت من المخزون وتكلفتها داخل `cost_total`.
/// - **(ب) المبيعات (total_base) كأن البونص غير موجود**: الإيراد من
///   الكمية المدفوعة حصراً (10×السعر) — البونص لا يوسّع المبيعات ريالاً.
///
/// البذر عبر `postSale` الحقيقي (لا إدراج مباشر) ليثبت السلسلة كاملة:
/// السلة بالبونص → line_cost=(qty+free)×WAC → cost_total → التقرير.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/profit_report_repository.dart';
import 'package:mobile_app/data/repositories/sale_repository.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/sale.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  final at = DateTime.utc(2026, 10, 6, 12);

  late AppDatabase handle;
  late ItemRepository items;
  late SaleRepository sales;
  late ProfitReportRepository repo;
  late int warehouseId;
  late int userId;
  late int baseId;

  setUp(() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    items = ItemRepository(handle.db);
    sales = SaleRepository(handle.db);
    repo = ProfitReportRepository(handle.db);
    userId = (await seeded.$2.findAdminUserId())!;
    warehouseId = (await seeded.$2.findDefaultWarehouseId())!;
    baseId = (await seeded.$2.listActiveCurrencies())
        .firstWhere((c) => c.isBase)
        .id;
  });

  tearDown(() async {
    await handle.close();
  });

  /// صنفا الاختبار: «شامبو» WAC 60 بسعر 100 و«صابون» WAC 25 بسعر 50
  /// (مخزون 60 لكل منهما — يكفي المنصرف الكلي 12 و10).
  Future<(int, int)> seedProducts() async {
    final shampoo = await items.createItem(
      ItemDraft(
        name: 'شامبو',
        costPrice: 60,
        openingQty: 60,
        prices: [ItemPrice(currencyId: baseId, price: 100)],
      ),
      warehouseId: warehouseId,
      userId: userId,
      now: at,
    );
    final soap = await items.createItem(
      ItemDraft(
        name: 'صابون',
        costPrice: 25,
        openingQty: 60,
        prices: [ItemPrice(currencyId: baseId, price: 50)],
      ),
      warehouseId: warehouseId,
      userId: userId,
      now: at,
    );
    return (shampoo.valueOrNull!, soap.valueOrNull!);
  }

  /// فاتورة نقدية بعملة الأساس: سطر شامبو 10 (± [freeQty] بونص) + سطر
  /// صابون 10 بلا بونص أبداً — الصافي 1500 في الحالتين.
  Future<void> postInvoices({
    required int shampoo,
    required int soap,
    required double freeQty,
    required DateTime issuedAt,
  }) async {
    final result = await sales.postSale(
      SaleDraft(
        currencyId: baseId,
        lines: [
          CartLine(
            productId: shampoo,
            qty: 10,
            unitPrice: 100,
            freeQty: freeQty,
          ),
          CartLine(productId: soap, qty: 10, unitPrice: 50),
        ],
        paidCash: 1500,
        paymentMethod: SalePaymentMethod.cash,
        warehouseId: warehouseId,
        issuedAt: issuedAt,
      ),
      userId: userId,
      now: issuedAt,
    );
    expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
  }

  test(
    '(أ) COGS يشمل المنصرف الكلي 12×WAC — الربح ينخفض بالمقدار الحرفي 2×WAC',
    () async {
      final (shampoo, soap) = await seedProducts();
      // نوفمبر: الشاميو ببونص (10+2 → COGS 12×60) والصابون بلا بونص.
      await postInvoices(
        shampoo: shampoo,
        soap: soap,
        freeQty: 2,
        issuedAt: DateTime.utc(2026, 11, 15, 10),
      );
      // ديسمبر: نفس الفاتورة تماماً بلا بونص (10 → COGS 10×60).
      await postInvoices(
        shampoo: shampoo,
        soap: soap,
        freeQty: 0,
        issuedAt: DateTime.utc(2026, 12, 15, 10),
      );

      final november = await repo.report(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      final december = await repo.report(
        from: DateTime(2026, 12, 1),
        to: DateTime(2026, 12, 31),
      );

      // الصابون بلا بونص بالفترتين (10×25 = 250) — كل الفارق من الشاميو.
      expect(november.cogs, 970, reason: '12×60 + 10×25 — المجاني داخل COGS');
      expect(december.cogs, 850, reason: '10×60 + 10×25');
      expect(november.cogs - december.cogs, 120, reason: '2×WAC(60) حرفياً');

      // الربح ينخفض بالمقدار نفسه (المبيعات متطابقة بين الفترتين).
      expect(november.profit, 530, reason: '1500 − 970');
      expect(december.profit, 650, reason: '1500 − 850');
      expect(december.profit - november.profit, 120, reason: 'هبوط حرفي 2×WAC');
    },
  );

  test(
    '(ب) المبيعات (total_base) كأن البونص غير موجود — الإيراد من المدفوع حصراً',
    () async {
      final (shampoo, soap) = await seedProducts();
      await postInvoices(
        shampoo: shampoo,
        soap: soap,
        freeQty: 2,
        issuedAt: DateTime.utc(2026, 11, 15, 10),
      );
      await postInvoices(
        shampoo: shampoo,
        soap: soap,
        freeQty: 0,
        issuedAt: DateTime.utc(2026, 12, 15, 10),
      );

      final november = await repo.report(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      final december = await repo.report(
        from: DateTime(2026, 12, 1),
        to: DateTime(2026, 12, 31),
      );

      // 10×100 + 10×50 = 1500 بالفترتين — البونص لم يُوسّع المبيعات ريالاً.
      expect(november.sales, 1500);
      expect(december.sales, 1500);
      expect(
        november.sales,
        december.sales,
        reason: 'فاتورة ببونص = فاتورة بلا بونص بالمبيعات حرفياً',
      );
      expect(november.netSales, 1500);
      expect(november.salesReturns, 0);
      expect(november.salesInvoiceCount, 1);
      // والفاتورة نفسها حُفظت بهذا الإيراد (لا أثر للمجاني بالرأس).
      final invoiceRow = await handle.db.rawQuery(
        "SELECT total, total_base, cost_total FROM invoice "
        "WHERE doc_type = 'sale' AND date(issued_at) = '2026-11-15'",
      );
      expect(invoiceRow, hasLength(1));
      expect(invoiceRow.first['total'], 1500);
      expect(invoiceRow.first['total_base'], 1500);
      expect(invoiceRow.first['cost_total'], 970);
    },
  );
}
