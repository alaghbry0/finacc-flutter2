/// اختبارات مستودع الأصناف — المرحلة 2 (FR-01): الذرّية، الباركود
/// التلقائي وإعادة المحاولة، البحث السريع، حد الطلب، الفئات والوحدات.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/services/barcode_ean13.dart';

import '../helpers/app_for_tests.dart';

/// مولّد متحكم به لاختبار إعادة المحاولة عند تصادم الباركود.
class _SequentialGenerator extends Ean13Generator {
  _SequentialGenerator(this._codes);

  final List<String> _codes;
  var _next = 0;

  @override
  String generate({Random? random}) => _codes[_next++];
}

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;
  late ItemRepository repo;
  late int warehouseId;
  late int userId;
  late int yerId;
  late int sarId;
  final at = DateTime.utc(2026, 10, 6, 12);

  setUp(() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    repo = ItemRepository(handle.db);
    warehouseId =
        (await handle.db.rawQuery('SELECT id FROM warehouse LIMIT 1'))
                .first['id']
            as int;
    userId =
        (await handle.db.rawQuery('SELECT id FROM app_user LIMIT 1'))
                .first['id']
            as int;
    yerId =
        (await handle.db.rawQuery("SELECT id FROM currency WHERE code = 'YER'"))
                .first['id']
            as int;
    sarId =
        (await handle.db.rawQuery("SELECT id FROM currency WHERE code = 'SAR'"))
                .first['id']
            as int;
  });

  tearDown(() async {
    await handle.close();
  });

  ItemDraft draft(
    String name, {
    String? barcode,
    int? categoryId,
    double cost = 100,
    double minStock = 0,
    bool service = false,
    bool trackBatches = false,
    double qty = 0,
    List<ItemPrice> prices = const [],
  }) => ItemDraft(
    name: name,
    barcode: barcode,
    categoryId: categoryId,
    costPrice: cost,
    minStock: minStock,
    isService: service,
    trackBatches: trackBatches,
    openingQty: qty,
    prices: prices,
  );

  Future<int> createOk(ItemDraft d) async {
    final result = await repo.createItem(
      d,
      warehouseId: warehouseId,
      userId: userId,
      now: at,
    );
    expect(result.isOk, isTrue, reason: 'الإنشاء يجب أن ينجح');
    return result.valueOrNull!;
  }

  group('createItem — الإنشاء الذرّي', () {
    test(
      'منتج + أسعار + مخزون + حركة افتتاح + قيد تدقيق في معاملة واحدة',
      () async {
        final id = await createOk(
          draft(
            'أرز بسمتي 5كغ',
            barcode: '2000000000008',
            cost: 4500,
            minStock: 5,
            qty: 20,
            prices: [ItemPrice(currencyId: yerId, price: 5000)],
          ),
        );

        final products = await handle.db.query('product');
        expect(products, hasLength(1));
        expect(products.first['id'], id);
        expect(products.first['name'], 'أرز بسمتي 5كغ');
        expect(products.first['barcode'], '2000000000008');
        expect(products.first['cost_price'], 4500);
        expect(products.first['min_stock'], 5);
        expect(products.first['is_service'], 0);
        expect(products.first['created_by'], userId);

        final prices = await handle.db.query('product_price');
        expect(prices, hasLength(1));
        expect(prices.first['product_id'], id);
        expect(prices.first['currency_id'], yerId);
        expect(prices.first['price'], 5000);
        expect(prices.first['price_level'], 'retail');

        final stock = await handle.db.query('stock_level');
        expect(stock, hasLength(1));
        expect(stock.first['warehouse_id'], warehouseId);
        expect(stock.first['qty'], 20);

        final movements = await handle.db.query('stock_movement');
        expect(movements, hasLength(1));
        expect(movements.first['movement_type'], 'opening');
        expect(movements.first['qty'], 20);
        expect(movements.first['unit_cost'], 4500);
        expect(movements.first['ref_type'], 'opening');

        final audit = await handle.db.query(
          'audit_log',
          where: "action = 'item_create'",
        );
        expect(audit, hasLength(1));
        expect(audit.first['entity'], 'product');
        expect(audit.first['entity_id'], id);
        expect(audit.first['details'], contains('barcode=2000000000008'));
        expect(audit.first['user_id'], userId);
      },
    );

    test(
      'الصنف الخدمي: لا أي صفوف مخزون مهما كانت الكمية الافتتاحية',
      () async {
        await createOk(
          draft(
            'تركيب سخان ماء',
            service: true,
            qty: 10,
            prices: [ItemPrice(currencyId: yerId, price: 15000)],
          ),
        );
        expect(await handle.db.query('stock_level'), isEmpty);
        expect(await handle.db.query('stock_movement'), isEmpty);

        final found = await repo.searchItems('سخان');
        expect(found, hasLength(1));
        expect(found.single.item.isService, isTrue);
        expect(found.single.totalQty, 0);
      },
    );

    test(
      'توليد باركود EAN-13 تلقائي عند الفراغ — فريد وصالح بنطاق 2xx',
      () async {
        for (var i = 0; i < 3; i++) {
          await createOk(draft('صنف تلقائي $i'));
        }
        final rows = await handle.db.query('product', columns: ['barcode']);
        final barcodes = rows.map((r) => r['barcode'] as String).toList();
        expect(barcodes.toSet(), hasLength(3));
        for (final code in barcodes) {
          expect(Ean13Generator.isValidEan13(code), isTrue, reason: code);
          expect(code.startsWith('2'), isTrue);
        }
      },
    );

    test(
      'تصادم الباركود المولّد: حتى 5 محاولات ثم يُعتمد البديل (FR-01-02)',
      () async {
        // الصنف المشغول بالباركود الأول.
        await handle.db.insert('product', {
          'name': 'مشغول',
          'barcode': '2000000000008',
          'cost_price': 0,
          'min_stock': 0,
          'is_service': 0,
          'track_batches': 0,
          'track_serials': 0,
          'is_archived': 0,
        });
        final retryRepo = ItemRepository(
          handle.db,
          barcodeGenerator: _SequentialGenerator([
            '2000000000008', // تصادم مع المشغول.
            '2000000000015', // البديل الصالح.
          ]),
        );
        final result = await retryRepo.createItem(
          draft('بعد التصادم'),
          warehouseId: warehouseId,
          userId: userId,
          now: at,
        );
        expect(result.isOk, isTrue);
        final row = (await handle.db.query(
          'product',
          where: "name = 'بعد التصادم'",
        )).first;
        expect(row['barcode'], '2000000000015');
      },
    );

    test('باركود مكرر → Err عربية ولا يُكتب الصنف الثاني', () async {
      await createOk(draft('أول', barcode: '2000000000008'));
      final second = await repo.createItem(
        draft('ثانٍ', barcode: '2000000000008'),
        warehouseId: warehouseId,
        userId: userId,
        now: at,
      );
      expect(second.isErr, isTrue);
      expect(second.errorOrNull, contains('الباركود'));
      expect(await handle.db.query('product'), hasLength(1));
    });

    test('اسم فارغ → «اسم الصنف مطلوب»', () async {
      final result = await repo.createItem(
        draft('   '),
        warehouseId: warehouseId,
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, 'اسم الصنف مطلوب');
      expect(await handle.db.query('product'), isEmpty);
    });

    test('سعر سالب أو سعر مكرر (عملة×مستوى) → Err', () async {
      final negative = await repo.createItem(
        draft('سالب', prices: [ItemPrice(currencyId: yerId, price: -5)]),
        warehouseId: warehouseId,
        userId: userId,
        now: at,
      );
      expect(negative.errorOrNull, contains('سالباً'));

      final duplicate = await repo.createItem(
        draft(
          'مكرر',
          prices: [
            ItemPrice(currencyId: yerId, price: 5),
            ItemPrice(currencyId: yerId, price: 6),
          ],
        ),
        warehouseId: warehouseId,
        userId: userId,
        now: at,
      );
      expect(duplicate.errorOrNull, contains('مكرر'));
    });

    test('المتتبع للدفعات: الرصيد الافتتاحي يُدفَّع دفعةً بصلاحية بعيدة '
        '(إصلاح رفض البيع بمتاح = 0)', () async {
      final trackedId = await createOk(
        draft('لبن طويل الأجل 1ل', cost: 900, qty: 24, trackBatches: true),
      );

      final batches = await handle.db.query(
        'batch',
        where: 'product_id = ?',
        whereArgs: [trackedId],
      );
      expect(batches, hasLength(1), reason: 'الرصيد الافتتاحي دفعة حقيقية');
      expect(batches.first['warehouse_id'], warehouseId);
      expect(batches.first['qty'], 24);
      expect(batches.first['expiry_date'], '9999-12-31');
      expect(batches.first['cost_price'], 900);

      // الدفتر يوافق مجموع الدفعات — لا انفصال كتابي/دفوعات.
      final level = await handle.db.query(
        'stock_level',
        where: 'product_id = ?',
        whereArgs: [trackedId],
      );
      expect(level.first['qty'], 24);

      // غير المتتبع: كمية افتتاحية بلا أي صف دفعة (السلوك الأصلي).
      final plainId = await createOk(draft('سكر 1كغ', cost: 700, qty: 30));
      expect(
        await handle.db.query(
          'batch',
          where: 'product_id = ?',
          whereArgs: [plainId],
        ),
        isEmpty,
      );

      // الخدمي المتتبع (حالة غريبة لكن مسموحة): لا صفوف إطلاقاً.
      final serviceId = await createOk(
        draft('توصيل', service: true, trackBatches: true),
      );
      expect(
        await handle.db.query(
          'batch',
          where: 'product_id = ?',
          whereArgs: [serviceId],
        ),
        isEmpty,
      );
    });
  });

  group('updateItem — التعديل الذرّي', () {
    test('استبدال الحقول والأسعار + تجاهل الكمية الافتتاحية + تدقيق', () async {
      final id = await createOk(
        draft(
          'أرز بسمتي',
          barcode: '2000000000008',
          cost: 4500,
          qty: 20,
          prices: [ItemPrice(currencyId: yerId, price: 5000)],
        ),
      );

      final updated = await repo.updateItem(
        id,
        draft(
          'أرز ممتاز',
          barcode: '2000000000008',
          cost: 4600,
          minStock: 3,
          qty: 99, // تُتجاهل في التعديل.
          prices: [
            ItemPrice(currencyId: yerId, price: 5200),
            ItemPrice(currencyId: sarId, price: 65),
          ],
        ),
        userId: userId,
        now: at,
      );
      expect(updated.isOk, isTrue);
      expect(updated.valueOrNull!.name, 'أرز ممتاز');
      expect(updated.valueOrNull!.costPrice, 4600);
      expect(updated.valueOrNull!.minStock, 3);

      // الأسعار استُبدلت كاملة (1 ← 2) بلا بقايا.
      final priceRows = await handle.db.query('product_price');
      expect(priceRows, hasLength(2));
      final pricesByCurrency = {
        for (final row in priceRows) row['currency_id'] as int: row['price'],
      };
      expect(pricesByCurrency[yerId], 5200);
      expect(pricesByCurrency[sarId], 65);

      // الكمية الافتتاحية المتجاهلة: المخزون والحركات كما هما.
      expect(await handle.db.query('stock_level'), hasLength(1));
      expect(await handle.db.query('stock_movement'), hasLength(1));

      expect(
        await handle.db.query('audit_log', where: "action = 'item_update'"),
        hasLength(1),
      );
    });

    test('باركود مكرر مع صنف آخر → Err دون مساس بالأصل', () async {
      final id = await createOk(draft('الأصلي', barcode: '2000000000008'));
      await createOk(draft('الآخر', barcode: '2000000000015'));
      final result = await repo.updateItem(
        id,
        draft('الأصلي المعدل', barcode: '2000000000015'),
        userId: userId,
        now: at,
      );
      expect(result.isErr, isTrue);
      expect(result.errorOrNull, contains('الباركود'));
      expect((await handle.db.query('product')).first['name'], 'الأصلي');
    });

    test('معرّف غير موجود → Err', () async {
      final result = await repo.updateItem(
        9999,
        draft('شبح'),
        userId: userId,
        now: at,
      );
      expect(result.errorOrNull, 'الصنف غير موجود');
    });
  });

  group('archiveItem — الأرشفة بدل الحذف (FR-01-15)', () {
    test('is_archived=1 + تدقيق + اختفاء من البحث والمسح', () async {
      final id = await createOk(
        draft('أرز بسمتي', barcode: '2000000000008', qty: 5),
      );
      final result = await repo.archiveItem(id, userId: userId, now: at);
      expect(result.isOk, isTrue);

      expect((await handle.db.query('product')).first['is_archived'], 1);
      expect(
        await handle.db.query('audit_log', where: "action = 'item_archive'"),
        hasLength(1),
      );
      // لا حذف: الصف موجود والاسم محفوظ.
      expect(
        (await handle.db.query('product', columns: ['name'])).first['name'],
        'أرز بسمتي',
      );

      expect(await repo.searchItems('أرز'), isEmpty);
      expect(
        await repo.searchItems('أرز', includeArchived: true),
        hasLength(1),
      );
      expect(await repo.findByBarcode('2000000000008'), isNull);
      // التفاصيل تعمل للمؤرشف (وصول مباشر بالمعرّف).
      expect((await repo.detail(id))!.item.isArchived, isTrue);
    });

    test('معرّف غير موجود → Err', () async {
      expect(
        (await repo.archiveItem(9999, userId: userId, now: at)).errorOrNull,
        'الصنف غير موجود',
      );
    });
  });

  group('searchItems — البحث السريع (FR-01-04)', () {
    test('بحث جزئي بالاسم أو الباركود + أسعار بعملة محددة', () async {
      await createOk(
        draft(
          'أرز بسمتي 5كغ',
          barcode: '2000000000008',
          qty: 20,
          prices: [ItemPrice(currencyId: yerId, price: 5000)],
        ),
      );
      await createOk(draft('عدس أحمر', barcode: '2999999999991', qty: 8));

      // جزئي بالاسم.
      final byName = await repo.searchItems('بسمتي');
      expect(byName, hasLength(1));
      expect(byName.single.item.name, 'أرز بسمتي 5كغ');
      expect(byName.single.totalQty, 20);

      // جزئي بالباركود.
      final byBarcode = await repo.searchItems('2000000');
      expect(byBarcode, hasLength(1));
      expect(byBarcode.single.item.barcode, '2000000000008');

      // سعر التجزئة بعملة محددة (YER موجود — SAR لا سعر له).
      final withYer = await repo.searchItems('أرز', currencyIdForPrice: yerId);
      expect(withYer.single.retailPrice, 5000);
      final withSar = await repo.searchItems('أرز', currencyIdForPrice: sarId);
      expect(withSar.single.retailPrice, isNull);
      final withNone = await repo.searchItems('أرز');
      expect(withNone.single.retailPrice, isNull);

      // خريطة الكمية لكل مخزن مملوءة.
      expect(withYer.single.warehouseQty[warehouseId], 20);

      // بحث فارغ = الكل.
      expect(await repo.searchItems(''), hasLength(2));
    });

    test('محارف LIKE الخاصة تعامل حرفياً لا كأنماط', () async {
      await createOk(draft('صنف %100'));
      expect(await repo.searchItems('%100'), hasLength(1));
      // «%1» الحرفي جزء من «%100» فيطابق، بينما «%7» لا وجود له.
      expect(await repo.searchItems('%1'), hasLength(1));
      expect(await repo.searchItems('%7'), hasLength(0));
    });

    test('تصفية بالفئة + حد وإزاحة للتمرير المتدرج', () async {
      final cat = await repo.createCategory('مواد غذائية');
      final catId = cat.valueOrNull!;
      await createOk(draft('صنف 01', categoryId: catId));
      await createOk(draft('صنف 02', categoryId: catId));
      await createOk(draft('صنف 03'));
      await createOk(draft('صنف 04'));
      await createOk(draft('صنف 05'));

      final inCategory = await repo.searchItems('', categoryId: catId);
      expect(inCategory, hasLength(2));
      expect(inCategory.map((i) => i.item.name), everyElement(contains('0')));

      final page = await repo.searchItems('', limit: 2, offset: 1);
      expect(page, hasLength(2));
      expect(page.map((i) => i.item.name), ['صنف 02', 'صنف 03']);
    });
  });

  group('findByBarcode — مسح الباركود (FR-01-03)', () {
    test('مطابقة تامة مع السعر والكمية، وفارغ عند عدم الوجود', () async {
      await createOk(
        draft(
          'أرز بسمتي',
          barcode: '2000000000008',
          qty: 7,
          prices: [ItemPrice(currencyId: yerId, price: 5000)],
        ),
      );
      final found = await repo.findByBarcode(
        '2000000000008',
        currencyId: yerId,
      );
      expect(found, isNotNull);
      expect(found!.item.name, 'أرز بسمتي');
      expect(found.totalQty, 7);
      expect(found.retailPrice, 5000);
      expect(await repo.findByBarcode('9999999999999'), isNull);
    });
  });

  group('detail — بطاقة الصنف', () {
    test('الأسعار بكل العملات + المخزون لكل مستودع + آخر الحركات', () async {
      final id = await createOk(
        draft(
          'أرز بسمتي',
          barcode: '2000000000008',
          qty: 20,
          prices: [
            ItemPrice(currencyId: yerId, price: 5000),
            ItemPrice(currencyId: sarId, price: 62),
          ],
        ),
      );
      // مستودع ثانٍ بكمية يدوية + حركتا بيع/شراء لاحقتان.
      final secondWarehouseId = await handle.db.insert('warehouse', {
        'name': 'مخزن فرعي',
        'is_default': 0,
        'is_archived': 0,
      });
      await handle.db.insert('stock_level', {
        'product_id': id,
        'warehouse_id': secondWarehouseId,
        'qty': 5,
      });
      await handle.db.insert('stock_movement', {
        'product_id': id,
        'warehouse_id': warehouseId,
        'movement_type': 'sale',
        'qty': -4,
        'unit_cost': 4500,
        'moved_at': '2026-10-07T09:00:00Z',
      });
      await handle.db.insert('stock_movement', {
        'product_id': id,
        'warehouse_id': warehouseId,
        'movement_type': 'purchase',
        'qty': 6,
        'unit_cost': 4600,
        'moved_at': '2026-10-08T09:00:00Z',
      });

      final detail = await repo.detail(id);
      expect(detail, isNotNull);
      expect(detail!.item.name, 'أرز بسمتي');
      expect(detail.prices, hasLength(2));
      expect(detail.prices.first.currencyCode, 'YER');
      expect(
        detail.prices.map((p) => p.currencyCode),
        containsAll(['YER', 'SAR']),
      );
      expect(detail.stockByWarehouse, hasLength(2));
      expect(detail.totalQty, 25);
      // آخر 20 حركة — الأحدث أولاً مع الرصيد التتابعي.
      expect(detail.recentMovements, hasLength(3));
      expect(detail.recentMovements.first.movementType, 'purchase');
      expect(detail.recentMovements.first.remainingAfter, 22);
      expect(detail.recentMovements.last.movementType, 'opening');
      expect(detail.recentMovements.last.remainingAfter, 20);
    });

    test('معرّف غير موجود → null', () async {
      expect(await repo.detail(9999), isNull);
    });
  });

  group('lowStockItems — حد إعادة الطلب (FR-01-12)', () {
    test('المخزون ≤ الحد: مشمول، والخدمي والمؤرشف مستثنيان', () async {
      await createOk(draft('تحت الحد', minStock: 5, qty: 3));
      await createOk(draft('فوق الحد', minStock: 5, qty: 10));
      await createOk(draft('نافد تماماً', minStock: 0, qty: 0));
      await createOk(draft('خدمة', service: true, minStock: 5, qty: 0));
      final archivedId = await createOk(draft('مؤرشف', minStock: 5, qty: 0));
      await repo.archiveItem(archivedId, userId: userId, now: at);

      final low = await repo.lowStockItems();
      expect(
        low.map((i) => i.item.name),
        containsAll(['تحت الحد', 'نافد تماماً']),
      );
      expect(low.map((i) => i.item.name), isNot(contains('فوق الحد')));
      expect(low.map((i) => i.item.name), isNot(contains('خدمة')));
      expect(low.map((i) => i.item.name), isNot(contains('مؤرشف')));
    });

    test('عتبة موحّدة تتجاوز حد كل صنف', () async {
      await createOk(draft('تحت الحد', minStock: 5, qty: 3));
      await createOk(draft('فوق الحد', minStock: 5, qty: 10));
      final withOverride = await repo.lowStockItems(minThresholdOverride: 50);
      expect(
        withOverride.map((i) => i.item.name),
        containsAll(['تحت الحد', 'فوق الحد']),
      );
    });
  });

  group('itemMovements / hasMovements — بطاقة الصنف (FR-09-03)', () {
    test('الرصيد التتابعي + تصفية الفترة والمخزن + الأحدث أولاً', () async {
      final id = await createOk(draft('أرز بسمتي', qty: 10));
      final otherWarehouseId = await handle.db.insert('warehouse', {
        'name': 'مخزن فرعي',
        'is_default': 0,
        'is_archived': 0,
      });
      await handle.db.insert('stock_movement', {
        'product_id': id,
        'warehouse_id': otherWarehouseId,
        'movement_type': 'sale',
        'qty': -4,
        'unit_cost': 100,
        'moved_at': '2026-10-07T09:00:00Z',
      });
      await handle.db.insert('stock_movement', {
        'product_id': id,
        'warehouse_id': warehouseId,
        'movement_type': 'purchase',
        'qty': 6,
        'unit_cost': 110,
        'moved_at': '2026-10-08T09:00:00Z',
      });

      final all = await repo.itemMovements(id);
      expect(all, hasLength(3));
      expect(all.first.movementType, 'purchase'); // الأحدث أولاً.
      // الأرصدة التتابعية على التاريخ الكامل: 10 ثم 6 ثم 12.
      final byType = {for (final m in all) m.movementType: m};
      expect(byType['opening']!.remainingAfter, 10);
      expect(byType['sale']!.remainingAfter, 6);
      expect(byType['purchase']!.remainingAfter, 12);

      // تصفية الفترة (after 2026-10-07) — نافذة داخل الترتيب الزمني.
      final filtered = await repo.itemMovements(
        id,
        from: DateTime.utc(2026, 10, 7, 12),
      );
      expect(filtered, hasLength(1));
      expect(filtered.single.movementType, 'purchase');
      expect(filtered.single.remainingAfter, 12, reason: 'رصيد كامل التاريخ');

      // تصفية المخزن.
      final inMain = await repo.itemMovements(id, warehouseId: warehouseId);
      expect(inMain, hasLength(2));
      expect(inMain.map((m) => m.movementType), isNot(contains('sale')));

      expect(await repo.hasMovements(id), isTrue);
    });

    test('hasMovements: خطأ لصنف بلا حركات', () async {
      final id = await createOk(draft('بلا حركة', qty: 0));
      expect(await repo.hasMovements(id), isFalse);
    });
  });

  group('الفئات والوحدات (FR-01-05 / FR-13-06)', () {
    test('فئات بمستويين حصراً + فحص التكرار والأصل المفقود', () async {
      final root = await repo.createCategory('مواد غذائية', now: at);
      expect(root.isOk, isTrue);
      final rootId = root.valueOrNull!;

      final child = await repo.createCategory('أرز', parentId: rootId, now: at);
      expect(child.isOk, isTrue);
      final childId = child.valueOrNull!;

      // الابن لا يأتيه أبناء — مستويان فقط.
      final grandchild = await repo.createCategory(
        'بسمتي',
        parentId: childId,
        now: at,
      );
      expect(grandchild.isErr, isTrue);
      expect(grandchild.errorOrNull, contains('مستويين'));

      // اسم مكرر.
      final duplicate = await repo.createCategory('مواد غذائية', now: at);
      expect(duplicate.errorOrNull, contains('مستخدم مسبقاً'));

      // أصل مفقود.
      final orphan = await repo.createCategory('يتيم', parentId: 999, now: at);
      expect(orphan.errorOrNull, 'الفئة الأصل غير موجودة');

      // اسم فارغ.
      expect(
        (await repo.createCategory('  ', now: at)).errorOrNull,
        'اسم الفئة مطلوب',
      );

      final list = await repo.listCategories();
      expect(list, hasLength(2));
      final childModel = list.firstWhere((c) => c.name == 'أرز');
      expect(childModel.parentId, rootId);
      expect(childModel.isRoot, isFalse);
    });

    test('وحدات بمعامل تحويل + فحص التكرار والمعامل غير الصالح', () async {
      final piece = await repo.createUnit('قطعة', now: at);
      expect(piece.isOk, isTrue);
      final carton = await repo.createUnit('كرتون', factor: 24, now: at);
      expect(carton.isOk, isTrue);

      expect(
        (await repo.createUnit('كرتون', now: at)).errorOrNull,
        contains('مستخدم مسبقاً'),
      );
      expect(
        (await repo.createUnit('صندوق', factor: 0, now: at)).errorOrNull,
        contains('أكبر من صفر'),
      );
      expect(
        (await repo.createUnit('  ', now: at)).errorOrNull,
        'اسم الوحدة مطلوب',
      );

      final units = await repo.listUnits();
      expect(units, hasLength(2));
      expect(
        units.firstWhere((u) => u.name == 'كرتون').factor,
        24,
        reason: '1 كرتون = 24 قطعة (FR-13-06)',
      );
    });
  });
}
