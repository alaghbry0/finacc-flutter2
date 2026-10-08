/// اختبارات مستودع الدفعات — FEFO (FR-01-10 / AC-05) وتنبيهات الصلاحية
/// (FR-09-15): الترتيب، التقسيم عبر الدفعات، تخطي المنتهية، النقص،
/// وحارس السالب عند التطبيق.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/batch_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/domain/models/batch.dart';
import 'package:mobile_app/domain/models/item.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;
  late ItemRepository items;
  late BatchRepository batches;
  late int warehouseId;
  late int userId;
  final at = DateTime.utc(2026, 10, 6, 12);

  setUp(() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    items = ItemRepository(handle.db);
    batches = BatchRepository(handle.db);
    warehouseId =
        (await handle.db.rawQuery('SELECT id FROM warehouse LIMIT 1'))
                .first['id']
            as int;
    userId =
        (await handle.db.rawQuery('SELECT id FROM app_user LIMIT 1'))
                .first['id']
            as int;
  });

  tearDown(() async {
    await handle.close();
  });

  /// ينشئ صنفاً متتبعاً للدفعات ويعيد معرّفه.
  Future<int> trackedProduct(String name) async {
    final result = await items.createItem(
      ItemDraft(name: name, trackBatches: true, costPrice: 100),
      warehouseId: warehouseId,
      userId: userId,
      now: at,
    );
    return result.valueOrNull!;
  }

  /// معرّف دفعة برقمها.
  Future<int> batchId(String number) async =>
      (await handle.db.query(
            'batch',
            columns: ['id'],
            where: 'batch_number = ?',
            whereArgs: [number],
          )).first['id']
          as int;

  test('createBatch: تحقق المدخلات ثم صف كامل بالحقول', () async {
    final productId = await trackedProduct('حليب');

    expect(
      (await batches.createBatch(
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: '  ',
        expiryDate: DateTime(2027, 1, 10),
        qty: 5,
        now: at,
      )).errorOrNull,
      'رقم الدفعة مطلوب',
    );
    expect(
      (await batches.createBatch(
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'B1',
        expiryDate: DateTime(2027, 1, 10),
        qty: 0,
        now: at,
      )).errorOrNull,
      contains('أكبر من صفر'),
    );
    expect(
      (await batches.createBatch(
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'B1',
        expiryDate: DateTime(2027, 1, 10),
        costPrice: -1,
        qty: 5,
        now: at,
      )).errorOrNull,
      contains('سالبة'),
    );

    final ok = await batches.createBatch(
      productId: productId,
      warehouseId: warehouseId,
      batchNumber: 'B-100',
      expiryDate: DateTime(2027, 1, 10),
      costPrice: 95.5,
      qty: 12,
      now: at,
    );
    expect(ok.isOk, isTrue);

    final rows = await handle.db.query('batch');
    expect(rows, hasLength(1));
    expect(rows.first['product_id'], productId);
    expect(rows.first['batch_number'], 'B-100');
    expect(rows.first['expiry_date'], '2027-01-10');
    expect(rows.first['cost_price'], 95.5);
    expect(rows.first['qty'], 12);
    // المستودع النقي: لا لمس المخزون العام إطلاقاً.
    expect(await handle.db.query('stock_level'), isEmpty);
    expect(await handle.db.query('stock_movement'), isEmpty);
  });

  test('batchesForProduct: ترتيب FEFO + استبعاد المؤرشفة والصفرية', () async {
    final productId = await trackedProduct('عصير');
    // تُنشأ «البعيدة» أولاً — الترتيب يجب أن يقلبه FEFO.
    await batches.createBatch(
      productId: productId,
      warehouseId: warehouseId,
      batchNumber: 'بعيدة',
      expiryDate: DateTime(2027, 6, 1),
      qty: 10,
      now: at,
    );
    await batches.createBatch(
      productId: productId,
      warehouseId: warehouseId,
      batchNumber: 'قريبة',
      expiryDate: DateTime(2026, 10, 16),
      qty: 4,
      now: at,
    );
    // منتهية مؤرشفة (كمية > 0) — مستبعدة بالأرشفة.
    await batches.createBatch(
      productId: productId,
      warehouseId: warehouseId,
      batchNumber: 'منتهية',
      expiryDate: DateTime(2026, 10, 4),
      qty: 8,
      now: at,
    );
    await handle.db.update(
      'batch',
      {'is_archived': 1},
      where: 'batch_number = ?',
      whereArgs: ['منتهية'],
    );
    // كمية صفرية غير مؤرشفة — مستبعدة بالكمية.
    await batches.createBatch(
      productId: productId,
      warehouseId: warehouseId,
      batchNumber: 'صفرية',
      expiryDate: DateTime(2026, 11, 1),
      qty: 1,
      now: at,
    );
    await handle.db.update(
      'batch',
      {'qty': 0},
      where: 'batch_number = ?',
      whereArgs: ['صفرية'],
    );

    final list = await batches.batchesForProduct(
      productId,
      now: DateTime(2026, 10, 6),
    );
    expect(list.map((b) => b.batchNumber), ['قريبة', 'بعيدة']);
    expect(list.first.daysToExpiry, 10);
    expect(list.last.daysToExpiry, 238);
    expect(list.first.qty, 4);
    expect(list.first.isExpired, isFalse);
  });

  group('allocateFefo + applyAllocation — قلب FEFO (AC-05)', () {
    test(
      '15 من دفعتين (10 قريبة + 10 بعيدة): القريبة أولاً ثم التقسيم',
      () async {
        final productId = await trackedProduct('جبن');
        final nearId = (await batches.createBatch(
          productId: productId,
          warehouseId: warehouseId,
          batchNumber: 'قريبة',
          expiryDate: DateTime(2026, 11, 1),
          costPrice: 100,
          qty: 10,
          now: at,
        )).valueOrNull!;
        final farId = (await batches.createBatch(
          productId: productId,
          warehouseId: warehouseId,
          batchNumber: 'بعيدة',
          expiryDate: DateTime(2027, 5, 1),
          costPrice: 120,
          qty: 10,
          now: at,
        )).valueOrNull!;

        late FefoResult result;
        await handle.db.transaction((txn) async {
          result = await batches.allocateFefo(
            txn,
            productId: productId,
            warehouseId: warehouseId,
            qty: 15,
            asOf: at,
          );
          await batches.applyAllocation(txn, result.allocations, now: at);
        });

        expect(result.shorted, isFalse);
        expect(result.remaining, 0);
        expect(result.allocatedQty, 15);
        expect(result.allocations, hasLength(2));
        // القريبة استُهلكت كاملة أولاً ثم 5 من البعيدة.
        expect(result.allocations.first.batchId, nearId);
        expect(result.allocations.first.qty, 10);
        expect(result.allocations.first.costPrice, 100);
        expect(result.allocations.first.costValue, 1000);
        expect(result.allocations.last.batchId, farId);
        expect(result.allocations.last.qty, 5);

        // الخصم طُبّق فعلاً.
        final qtyById = {
          for (final row in await handle.db.query(
            'batch',
            columns: ['id', 'qty'],
          ))
            row['id'] as int: (row['qty'] as num).toDouble(),
        };
        expect(qtyById[nearId], 0);
        expect(qtyById[farId], 5);
      },
    );

    test(
      'الدفعة المنتهية قبل asOf تُتخطى (منع البيع من دفعة منتهية)',
      () async {
        final productId = await trackedProduct('دواء');
        await batches.createBatch(
          productId: productId,
          warehouseId: warehouseId,
          batchNumber: 'منتهية',
          expiryDate: DateTime(2026, 10, 4), // قبل asOf بيومين.
          costPrice: 80,
          qty: 8,
          now: at,
        );
        final result = await handle.db.transaction((txn) {
          return batches.allocateFefo(
            txn,
            productId: productId,
            warehouseId: warehouseId,
            qty: 5,
            asOf: at,
          );
        });
        expect(result.allocations, isEmpty);
        expect(result.shorted, isTrue);
        expect(result.remaining, 5);

        // السماح الصريح يشملها.
        final included = await handle.db.transaction((txn) {
          return batches.allocateFefo(
            txn,
            productId: productId,
            warehouseId: warehouseId,
            qty: 5,
            asOf: at,
            includeExpired: true,
          );
        });
        expect(included.shorted, isFalse);
        expect(included.allocatedQty, 5);
      },
    );

    test('النقص: 20 من 12 متاحة → shorted وremaining=8 والحصص جزئية', () async {
      final productId = await trackedProduct('شامبو');
      await batches.createBatch(
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'أ',
        expiryDate: DateTime(2026, 12, 1),
        qty: 6,
        now: at,
      );
      await batches.createBatch(
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'ب',
        expiryDate: DateTime(2027, 3, 1),
        qty: 6,
        now: at,
      );
      final result = await handle.db.transaction((txn) {
        return batches.allocateFefo(
          txn,
          productId: productId,
          warehouseId: warehouseId,
          qty: 20,
          asOf: at,
        );
      });
      expect(result.shorted, isTrue);
      expect(result.remaining, 8);
      expect(result.allocatedQty, 12);
      expect(result.allocations.map((a) => a.qty), [6, 6]);
    });

    test('حارس السالب: خصم أكثر من كمية الدفعة يرمي ويتراجع الكل', () async {
      final productId = await trackedProduct('زيت');
      await batches.createBatch(
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'وحيدة',
        expiryDate: DateTime(2027, 1, 1),
        qty: 5,
        now: at,
      );
      final doomed = BatchAllocation(
        batchId: await batchId('وحيدة'),
        batchNumber: 'وحيدة',
        expiryDate: DateTime(2027, 1, 1),
        qty: 6,
        costPrice: 0,
      );
      await expectLater(
        handle.db.transaction(
          (txn) => batches.applyAllocation(txn, [doomed], now: at),
        ),
        throwsStateError,
      );
      // المعاملة تراجعت — الكمية كما كانت رغم محاولة الخصم.
      expect((await handle.db.query('batch')).first['qty'], 5);
    });

    test('عزل تام: صنف آخر أو مخزن آخر لا يجد دفعات هذا الصنف', () async {
      final a = await trackedProduct('صنف أ');
      final b = await trackedProduct('صنف ب');
      await batches.createBatch(
        productId: a,
        warehouseId: warehouseId,
        batchNumber: 'دفعة أ',
        expiryDate: DateTime(2027, 1, 1),
        qty: 10,
        now: at,
      );
      final forB = await handle.db.transaction((txn) {
        return batches.allocateFefo(
          txn,
          productId: b,
          warehouseId: warehouseId,
          qty: 1,
          asOf: at,
        );
      });
      expect(forB.shorted, isTrue);
      expect(forB.allocations, isEmpty);
    });
  });

  group('expiryAlerts / expiryBuckets — تنبيهات الصلاحية (FR-09-15)', () {
    test('دفعات 10/40/70 يوماً + منتهية: النوافذ والسلالم', () async {
      final productId = await trackedProduct('لبن');
      await batches.createBatch(
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'خلال 10',
        expiryDate: DateTime(2026, 10, 16),
        qty: 4,
        now: at,
      );
      await batches.createBatch(
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'خلال 40',
        expiryDate: DateTime(2026, 11, 15),
        qty: 6,
        now: at,
      );
      await batches.createBatch(
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'خلال 70',
        expiryDate: DateTime(2026, 12, 15),
        qty: 2,
        now: at,
      );
      await batches.createBatch(
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'منتهية',
        expiryDate: DateTime(2026, 10, 4),
        qty: 9,
        now: at,
      );

      final within30 = await batches.expiryAlerts(
        withinDays: 30,
        now: DateTime(2026, 10, 6),
      );
      expect(within30.map((a) => a.batchNumber), ['منتهية', 'خلال 10']);
      expect(within30.first.daysToExpiry, -2);
      expect(within30.first.isExpired, isTrue);
      expect(within30.first.productName, 'لبن');
      expect(within30.first.qty, 9);

      final within60 = await batches.expiryAlerts(
        withinDays: 60,
        now: DateTime(2026, 10, 6),
      );
      expect(within60.map((a) => a.batchNumber), [
        'منتهية',
        'خلال 10',
        'خلال 40',
      ]);

      final buckets = await batches.expiryBuckets(now: DateTime(2026, 10, 6));
      expect(buckets, {'expired': 1, '30': 1, '60': 1, '90': 1});
    });

    test('تصفية المخزن: تنبيهات المخزن المحدد فقط', () async {
      final productId = await trackedProduct('جبن');
      final secondWarehouseId = await handle.db.insert('warehouse', {
        'name': 'مخزن فرعي',
        'is_default': 0,
        'is_archived': 0,
      });
      await batches.createBatch(
        productId: productId,
        warehouseId: secondWarehouseId,
        batchNumber: 'بالفرعي',
        expiryDate: DateTime(2026, 10, 20),
        qty: 3,
        now: at,
      );

      final inMain = await batches.expiryAlerts(
        withinDays: 30,
        warehouseId: warehouseId,
        now: DateTime(2026, 10, 6),
      );
      expect(inMain, isEmpty);

      final all = await batches.expiryAlerts(
        withinDays: 30,
        now: DateTime(2026, 10, 6),
      );
      expect(all.single.batchNumber, 'بالفرعي');
      expect(all.single.warehouseId, secondWarehouseId);
    });
  });
}
