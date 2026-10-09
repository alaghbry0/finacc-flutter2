/// اختبار البونص في تقارير الحركة (موجة UX-4): **الصادر لصنف ببونص =
/// qty + free** — ترحيل فاتورة حقيقية 3 مدفوعة + 2 مجاني عبر
/// `SaleRepository.postSale` ثم قراءة تقارير الحركة الحقيقية:
/// بطاقة حركة الصنف (FR-09-03) تُظهر صف بيع واحداً بكمية −5 (المنصرف
/// الكلي) برصيد تراكمي صحيح، وملخص حركة المخزون (FR-09-04) يجعل
/// qtyOut = 5 — لا 3 — والحركة موسومة «بونص» للتتبع.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/movement_reports_repository.dart';
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
  late MovementReportsRepository repo;
  late int warehouseId;
  late int userId;
  late int baseId;

  setUp(() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    items = ItemRepository(handle.db);
    sales = SaleRepository(handle.db);
    repo = MovementReportsRepository(handle.db);
    userId = (await seeded.$2.findAdminUserId())!;
    warehouseId = (await seeded.$2.findDefaultWarehouseId())!;
    baseId = (await seeded.$2.listActiveCurrencies())
        .firstWhere((c) => c.isBase)
        .id;
  });

  tearDown(() async {
    await handle.close();
  });

  test(
    'بيع ببونص: الصادر بالبطاقة والملخص = المدفوع + المجاني (3+2) بحركة موسومة',
    () async {
      // صنف مخزني حقيقي: افتتاحي 30 بتكلفة 40 وسعر 100 (حركة الافتتاحي
      // بتاريخ 2026-10-06 — قبل فترة نوفمبر فتدخل الرصيد الافتتاحي فقط).
      final created = await items.createItem(
        ItemDraft(
          name: 'أرز بسمتي',
          costPrice: 40,
          openingQty: 30,
          prices: [ItemPrice(currencyId: baseId, price: 100)],
        ),
        warehouseId: warehouseId,
        userId: userId,
        now: at,
      );
      final rice = created.valueOrNull!;

      // فاتورة نقدية: 3 مدفوعة + 2 مجاني بسعر 100 (الصافي 300 حصراً).
      final issuedAt = DateTime.utc(2026, 11, 10, 10);
      final posted = await sales.postSale(
        SaleDraft(
          currencyId: baseId,
          lines: [
            CartLine(productId: rice, qty: 3, unitPrice: 100, freeQty: 2),
          ],
          paidCash: 300,
          paymentMethod: SalePaymentMethod.cash,
          warehouseId: warehouseId,
          issuedAt: issuedAt,
        ),
        userId: userId,
        now: issuedAt,
      );
      expect(posted.isOk, isTrue, reason: '${posted.errorOrNull}');
      // الإيراد من المدفوع حصراً (القرار التحاسبي — §3).
      expect(posted.valueOrNull!.totals.grandTotal, 300);

      // (1) بطاقة حركة الصنف: صف بيع واحد بكمية −5 (لا −3) والرصيد 25.
      final card = await repo.itemMovement(
        productId: rice,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      expect(card.openingBalance, 30, reason: 'الافتتاحي قبل الفترة');
      expect(card.rows, hasLength(1), reason: 'حركة البيع وحدها داخل الفترة');
      expect(card.rows.single.movementType, 'sale');
      expect(card.rows.single.qty, -5, reason: 'المنصرف الكلي 3+2 بسالب واحد');
      expect(card.rows.single.balanceAfter, 25, reason: '30 − 5');
      expect(card.totalOut, 5, reason: 'الصادر = qty + free');
      expect(card.totalIn, 0);

      // (2) ملخص حركة المخزون: صادر 5 (لا 3) ورصيد ختامي 25.
      final summary = await repo.stockSummary(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      expect(summary, hasLength(1));
      expect(summary.single.qtyOut, 5, reason: 'FR-09-04: الصادر بالمجاني');
      expect(summary.single.endBalance, 25);
      expect(summary.single.valueAtCost, 1000, reason: '25 × 40');

      // (3) الحركة نفسها موسومة بالبونص (تتبع/تدقيق — مخزونياً لا نقدياً).
      final movements = await handle.db.query(
        'stock_movement',
        where: "product_id = ? AND movement_type = 'sale'",
        whereArgs: [rice],
      );
      expect(movements, hasLength(1));
      expect(movements.single['notes'] as String?, contains('بونص'));
    },
  );
}
