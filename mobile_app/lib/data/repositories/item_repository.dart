/// مستودع الأصناف — جداول `product` / `product_price` / `stock_level` /
/// `stock_movement` / `category` / `unit` (§5.3) — المرحلة 2 (FR-01).
///
/// القواعد الملزمة هنا:
/// - **الذرّية**: الإنشاء/التعديل/الأرشفة كل منها معاملة واحدة — فشل أي
///   خطوة يرجع الكل ولا يُكتب شيء.
/// - **لا حذف أبداً** (FR-01-15): الأرشفة `is_archived = 1` بديل الحذف.
/// - **الأصناف الخدمية** بلا أي صفوف مخزون (`stock_level`/`stock_movement`).
/// - **توليد الباركود** EAN-13 بنطاق المتجر 200–299 عند فراغ الباركود،
///   مع حتى 5 محاولات عند تصادم التفرد (FR-01-02).
/// - **كل قيم SQL عبر معاملات `?`** — لا دمج نصي لمدخلات المستخدم.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/item.dart';
import '../../domain/services/barcode_ean13.dart';

/// مستودع الأصناف والمخزون والفئات والوحدات.
class ItemRepository {
  /// [barcodeGenerator] قابل للحقن للاختبارات (مولّد متحكم به لتجربة
  /// إعادة المحاولة عند تصادم الباركود).
  ItemRepository(this._db, {Ean13Generator? barcodeGenerator})
    : _generator = barcodeGenerator ?? const Ean13Generator();

  final Database _db;
  final Ean13Generator _generator;

  // ─────────────────────────────────────────────────────────────────────
  // الإنشاء / التعديل / الأرشفة
  // ─────────────────────────────────────────────────────────────────────

  /// **إنشاء صنف ذرّياً**: صف `product` + أسعار `product_price` +
  /// (لغير الخدمي مع كمية افتتاحية) `stock_level` وحركة `opening`
  /// + (للمتتبع للدفعات) صف `batch` افتتاحي بصلاحية بعيدة
  /// + قيد تدقيق `item_create` — كلها في معاملة واحدة.
  ///
  /// - الباركود الفارغ يولّد EAN-13 داخلياً (حتى 5 محاولات عند التصادم).
  /// - الصنف الخدمي لا يُنشئ أي صفوف مخزون مهما كانت [ItemDraft.openingQty].
  /// - **المتتبع للدفعات**: الرصيد الافتتاحي يُدفَّع أيضاً دفعةً
  ///   (`expiry_date = 9999-12-31`) — بدونها يبقى الكتاب (stock_level)
  ///   حاملاً كمية تعجز FEFO عن تخصيصها فيُرفض البيع بمتاح = 0
  ///   رغم رصيد كتابي كبير (خلل الموجة 4 — مُصلح هنا وهجرةً v2).
  Future<Result<int, String>> createItem(
    ItemDraft draft, {
    required int warehouseId,
    required int userId,
    DateTime? now,
  }) async {
    final validation = _validateDraft(draft);
    if (validation != null) return Err(validation);
    final at = now ?? DateTime.now();
    final iso = at.toUtc().toIso8601String();
    try {
      return await _db.transaction((txn) async {
        var barcode = draft.barcode?.trim() ?? '';
        if (barcode.isEmpty) {
          final generated = await _generateUniqueBarcode(txn);
          if (generated == null) {
            return const Err<int, String>(
              'تعذر توليد باركود فريد بعد 5 محاولات — أعد المحاولة',
            );
          }
          barcode = generated;
        }

        final productId = await txn.insert('product', {
          'name': draft.name.trim(),
          'barcode': barcode,
          'category_id': draft.categoryId,
          'unit_id': draft.unitId,
          'cost_price': draft.costPrice,
          'min_stock': draft.minStock,
          'is_service': draft.isService ? 1 : 0,
          'track_batches': draft.trackBatches ? 1 : 0,
          'notes': draft.notes,
          'created_at': iso,
          'updated_at': iso,
          'created_by': userId,
        });

        for (final price in draft.prices) {
          await txn.insert('product_price', {
            'product_id': productId,
            'currency_id': price.currencyId,
            'price': price.price,
            'price_level': price.priceLevel,
            'margin_percent': price.marginPercent,
            'updated_at': iso,
          });
        }

        if (!draft.isService && draft.openingQty > 0) {
          await txn.insert('stock_level', {
            'product_id': productId,
            'warehouse_id': warehouseId,
            'qty': draft.openingQty,
          });
          await txn.insert('stock_movement', {
            'product_id': productId,
            'warehouse_id': warehouseId,
            'movement_type': 'opening',
            'qty': draft.openingQty,
            'unit_cost': draft.costPrice,
            'ref_type': 'opening',
            'moved_at': iso,
            'notes': 'رصيد افتتاحي',
            'created_at': iso,
            'created_by': userId,
          });
          if (draft.trackBatches) {
            // الدفتر (stock_level) وحده لا يكفي للمتتبع: توافر البيع
            // يُحسب من دفعات FEFO النشطة — فنسجّل الرصيد الافتتاحي دفعةً
            // بصلاحية بعيدة (تُستهلك أخيراً ولا تمنع البيع أبداً).
            await txn.insert('batch', {
              'product_id': productId,
              'warehouse_id': warehouseId,
              'batch_number': 'افتتاحي-$productId',
              'expiry_date': '9999-12-31',
              'cost_price': draft.costPrice,
              'qty': draft.openingQty,
              'created_at': iso,
              'updated_at': iso,
            });
          }
        }

        await _audit(
          txn,
          action: 'item_create',
          entityId: productId,
          details: 'name=${draft.name.trim()} barcode=$barcode',
          userId: userId,
          at: at,
        );
        return Ok<int, String>(productId);
      });
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e));
    }
  }

  /// **تعديل صنف ذرّياً**: استبدال كامل لحقول الصنف + الأسعار (حذف ثم
  /// إدراج داخل المعاملة) + قيد تدقيق `item_update`.
  ///
  /// - [ItemDraft.openingQty] **يُتجاهل** هنا — المخزون يُعدَّل بحركات
  ///   (شراء/بيع/جرد) لا بتعديل مباشر.
  /// - الباركود الفارغ في المسودة **يمسح** باركود الصنف (استبدال كامل؛
  ///   لا توليد تلقائي عند التعديل).
  Future<Result<Item, String>> updateItem(
    int id,
    ItemDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final validation = _validateDraft(draft);
    if (validation != null) return Err(validation);
    final at = now ?? DateTime.now();
    final iso = at.toUtc().toIso8601String();
    try {
      return await _db.transaction((txn) async {
        final affected = await txn.update(
          'product',
          {
            'name': draft.name.trim(),
            'barcode': draft.barcode?.trim(),
            'category_id': draft.categoryId,
            'unit_id': draft.unitId,
            'cost_price': draft.costPrice,
            'min_stock': draft.minStock,
            'is_service': draft.isService ? 1 : 0,
            'track_batches': draft.trackBatches ? 1 : 0,
            'notes': draft.notes,
            'updated_at': iso,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        if (affected == 0) {
          return const Err<Item, String>('الصنف غير موجود');
        }

        // استبدال الأسعار كاملة — نفس المعاملة (الكل أو لا شيء).
        await txn.delete(
          'product_price',
          where: 'product_id = ?',
          whereArgs: [id],
        );
        for (final price in draft.prices) {
          await txn.insert('product_price', {
            'product_id': id,
            'currency_id': price.currencyId,
            'price': price.price,
            'price_level': price.priceLevel,
            'margin_percent': price.marginPercent,
            'updated_at': iso,
          });
        }

        await _audit(
          txn,
          action: 'item_update',
          entityId: id,
          details: 'name=${draft.name.trim()}',
          userId: userId,
          at: at,
        );

        final fresh = await txn.query(
          'product',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        return Ok<Item, String>(Item.fromRow(fresh.first));
      });
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e));
    }
  }

  /// **أرشفة صنف** (FR-01-15: لا حذف — الأرشفة تُخفي الصنف من البحث
  /// والبيع مع بقاء التاريخ الكامل) + قيد تدقيق `item_archive`.
  Future<Result<void, String>> archiveItem(
    int id, {
    required int userId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    try {
      return await _db.transaction((txn) async {
        final rows = await txn.query(
          'product',
          columns: ['name'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) {
          return const Err<void, String>('الصنف غير موجود');
        }
        await txn.update(
          'product',
          {'is_archived': 1, 'updated_at': at.toUtc().toIso8601String()},
          where: 'id = ?',
          whereArgs: [id],
        );
        await _audit(
          txn,
          action: 'item_archive',
          entityId: id,
          details: 'name=${rows.first['name']}',
          userId: userId,
          at: at,
        );
        return const Ok<void, String>(null);
      });
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e));
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // البحث والاستعلام
  // ─────────────────────────────────────────────────────────────────────

  /// **البحث السريع** (FR-01-04): الاسم أو الباركود `LIKE %q%` مع إجمالي
  /// المخزون وسعر تجزئة اختياري — المؤرشف مستثنى إلا بطلب صريح.
  ///
  /// [currencyIdForPrice] يضمّن سعر التجزئة بعملة محددة (null = بلا سعر).
  /// خيارات التصنيف/الحد/الإزاحة تدعم التمرير المتدرج في قائمة الأصناف.
  Future<List<ItemStockInfo>> searchItems(
    String query, {
    int? categoryId,
    bool includeArchived = false,
    int limit = 50,
    int offset = 0,
    int? currencyIdForPrice,
  }) async {
    final args = <Object>[];
    final hasPrice = currencyIdForPrice != null;
    final priceJoin = hasPrice
        ? 'LEFT JOIN product_price pr ON pr.product_id = p.id '
              "AND pr.price_level = 'retail' AND pr.currency_id = ?"
        : '';
    final priceColumn = hasPrice
        ? 'pr.price AS retail_price'
        : 'NULL AS retail_price';
    if (hasPrice) args.add(currencyIdForPrice);

    final like = '%${_escapeLike(query.trim())}%';
    args
      ..add(like)
      ..add(like);

    final conditions = [
      "(p.name LIKE ? ESCAPE '\\' OR p.barcode LIKE ? ESCAPE '\\')",
      if (!includeArchived) 'p.is_archived = 0',
      if (categoryId != null) 'p.category_id = ?',
    ];
    if (categoryId != null) args.add(categoryId);
    args
      ..add(limit)
      ..add(offset);

    final rows = await _db.rawQuery('''
      SELECT p.*, COALESCE(s.total_qty, 0) AS total_qty, $priceColumn
      FROM product p
      LEFT JOIN (
        SELECT product_id, SUM(qty) AS total_qty
        FROM stock_level GROUP BY product_id
      ) s ON s.product_id = p.id
      $priceJoin
      WHERE ${conditions.join(' AND ')}
      ORDER BY p.is_archived ASC, p.name ASC
      LIMIT ? OFFSET ?
    ''', args);

    final results = [
      for (final row in rows)
        ItemStockInfo(
          item: Item.fromRow(row),
          totalQty: (row['total_qty'] as num?)?.toDouble() ?? 0,
          retailPrice: (row['retail_price'] as num?)?.toDouble(),
        ),
    ];
    await _fillWarehouseQty(results);
    return results;
  }

  /// **بحث الباركود الدقيق** (FR-01-03: شاشة نتيجة المسح / POS):
  /// مطابقة تامة، المؤرشف مستثنى دائماً. [currencyId] يضمّن سعر التجزئة.
  Future<ItemStockInfo?> findByBarcode(String code, {int? currencyId}) async {
    // ترتيب المعاملات يطابق ترتيب العلامات في SQL: علامة الوصلة (العملة)
    // تسبق علامة الشرط (الباركود).
    final args = <Object>[];
    final hasPrice = currencyId != null;
    final priceJoin = hasPrice
        ? 'LEFT JOIN product_price pr ON pr.product_id = p.id '
              "AND pr.price_level = 'retail' AND pr.currency_id = ?"
        : '';
    final priceColumn = hasPrice
        ? 'pr.price AS retail_price'
        : 'NULL AS retail_price';
    if (hasPrice) args.add(currencyId);
    args.add(code.trim());
    final rows = await _db.rawQuery('''
      SELECT p.*, COALESCE(s.total_qty, 0) AS total_qty, $priceColumn
      FROM product p
      LEFT JOIN (
        SELECT product_id, SUM(qty) AS total_qty
        FROM stock_level GROUP BY product_id
      ) s ON s.product_id = p.id
      $priceJoin
      WHERE p.barcode = ? AND p.is_archived = 0
      LIMIT 1
    ''', args);
    if (rows.isEmpty) return null;
    final result = ItemStockInfo(
      item: Item.fromRow(rows.first),
      totalQty: (rows.first['total_qty'] as num?)?.toDouble() ?? 0,
      retailPrice: (rows.first['retail_price'] as num?)?.toDouble(),
    );
    await _fillWarehouseQty([result]);
    return result;
  }

  /// **تفاصيل صنف كاملة** (FR-01-03): الصنف + كل الأسعار بكل العملات +
  /// المخزون لكل مستودع + آخر 20 حركة (بطاقة الصنف).
  ///
  /// يعمل حتى للأصناف المؤرشفة (الوصول بالمعرّف مباشرة).
  Future<ItemFullDetail?> detail(int id) async {
    final rows = await _db.query(
      'product',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final priceRows = await _db.rawQuery(
      '''
      SELECT pp.currency_id, pp.price, pp.price_level, pp.margin_percent,
             c.code AS currency_code, c.name AS currency_name
      FROM product_price pp
      JOIN currency c ON c.id = pp.currency_id
      WHERE pp.product_id = ?
      ORDER BY c.is_base DESC, c.code ASC, pp.price_level ASC
    ''',
      [id],
    );

    final stockRows = await _db.rawQuery(
      '''
      SELECT sl.warehouse_id, w.name AS warehouse_name, sl.qty
      FROM stock_level sl
      JOIN warehouse w ON w.id = sl.warehouse_id
      WHERE sl.product_id = ?
      ORDER BY w.is_default DESC, w.name ASC
    ''',
      [id],
    );

    return ItemFullDetail(
      item: Item.fromRow(rows.first),
      prices: [
        for (final row in priceRows)
          ItemPriceLine(
            currencyId: row['currency_id'] as int,
            currencyCode: row['currency_code'] as String,
            currencyName: row['currency_name'] as String,
            price: (row['price'] as num?)?.toDouble() ?? 0,
            priceLevel: row['price_level'] as String,
            marginPercent: (row['margin_percent'] as num?)?.toDouble() ?? 0,
          ),
      ],
      stockByWarehouse: [
        for (final row in stockRows)
          WarehouseStock(
            warehouseId: row['warehouse_id'] as int,
            warehouseName: row['warehouse_name'] as String,
            qty: (row['qty'] as num?)?.toDouble() ?? 0,
          ),
      ],
      recentMovements: await itemMovements(id, limit: 20),
    );
  }

  /// **أصناف تحت حد الطلب** (FR-01-12): غير الخدمي وغير المؤرشف حيث
  /// إجمالي المخزون ≤ `min_stock` (أو ≤ [minThresholdOverride] لكل الأصناف).
  /// الأصناف بلا أي صف مخزون تعتبر كميتها صفراً فتُدرج (نفاد تام).
  Future<List<ItemStockInfo>> lowStockItems({
    double? minThresholdOverride,
  }) async {
    final args = <Object>[];
    final thresholdCondition = minThresholdOverride == null
        ? 'COALESCE(s.total_qty, 0) <= p.min_stock'
        : 'COALESCE(s.total_qty, 0) <= ?';
    if (minThresholdOverride != null) args.add(minThresholdOverride);

    final rows = await _db.rawQuery('''
      SELECT p.*, COALESCE(s.total_qty, 0) AS total_qty
      FROM product p
      LEFT JOIN (
        SELECT product_id, SUM(qty) AS total_qty
        FROM stock_level GROUP BY product_id
      ) s ON s.product_id = p.id
      WHERE p.is_service = 0 AND p.is_archived = 0 AND $thresholdCondition
      ORDER BY COALESCE(s.total_qty, 0) ASC, p.name ASC
    ''', args);

    final results = [
      for (final row in rows)
        ItemStockInfo(
          item: Item.fromRow(row),
          totalQty: (row['total_qty'] as num?)?.toDouble() ?? 0,
        ),
    ];
    await _fillWarehouseQty(results);
    return results;
  }

  /// **بطاقة الصنف** (FR-09-03): كل حركات الصنف مع الرصيد التتابعي بعد
  /// كل حركة، مرتبة الأحدث أولاً.
  ///
  /// [from]/[to]/[warehouseId] تصفي النافذة المعروضة، بينما يُحسب
  /// `remainingAfter` على التاريخ الكامل غير المصفّى (رصيد محاسبي صحيح).
  Future<List<ItemMovementEntry>> itemMovements(
    int productId, {
    DateTime? from,
    DateTime? to,
    int? warehouseId,
    int limit = 200,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM stock_movement WHERE product_id = ? '
      'ORDER BY moved_at ASC, id ASC',
      [productId],
    );

    var running = 0.0;
    final chronological = <ItemMovementEntry>[];
    for (final row in rows) {
      running += (row['qty'] as num?)?.toDouble() ?? 0;
      chronological.add(
        ItemMovementEntry.fromRow({...row, 'remaining_after': running}),
      );
    }

    final filtered = chronological.where((entry) {
      if (from != null && entry.movedAt.isBefore(from)) return false;
      if (to != null && entry.movedAt.isAfter(to)) return false;
      return true;
    }).toList();

    // تصفية المخزن تحتاج عمود warehouse_id الذي لا يحمله النموذج —
    // نعيد الفحص من الصفوف الخام مباشرة.
    Iterable<ItemMovementEntry> window = filtered;
    if (warehouseId != null) {
      final ids = rows
          .where((row) => row['warehouse_id'] == warehouseId)
          .map((row) => row['id'] as int)
          .toSet();
      window = filtered.where((entry) => ids.contains(entry.id));
    }
    if (filtered.length > limit) {
      window = window.skip(filtered.length - limit);
    }
    // الأحدث أولاً للعرض (الأرصدة محسوبة على الترتيب الزمني الكامل).
    return window.toList().reversed.toList();
  }

  /// هل للصنف حركات مخزون؟ (يحرس قرار الأرشفة مقابل أي تنظيف مستقبلي).
  Future<bool> hasMovements(int productId) async {
    final rows = await _db.rawQuery(
      'SELECT EXISTS(SELECT 1 FROM stock_movement WHERE product_id = ?) AS ok',
      [productId],
    );
    return (rows.first['ok'] as int) == 1;
  }

  // ─────────────────────────────────────────────────────────────────────
  // الفئات والوحدات (FR-01-05 / FR-13-06)
  // ─────────────────────────────────────────────────────────────────────

  /// فئات الأصناف (المستوى الأول والثاني معاً — الترتيب بالاسم).
  Future<List<ItemCategory>> listCategories() async {
    final rows = await _db.query(
      'category',
      columns: ['id', 'name', 'parent_id'],
      where: 'is_archived = 0',
      orderBy: 'name ASC',
    );
    return rows.map(ItemCategory.fromRow).toList();
  }

  /// ينشئ فئة — شجرة بمستويين حصراً (FR-01-05): الجذر ثم الأبناء،
  /// ولا يُقبل ابن لابن. الاسم فريد (فحص مسبق — المخطط لا يفرضه).
  Future<Result<int, String>> createCategory(
    String name, {
    int? parentId,
    DateTime? now,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Err('اسم الفئة مطلوب');
    final at = (now ?? DateTime.now()).toUtc().toIso8601String();

    if (parentId != null) {
      final parentRows = await _db.rawQuery(
        'SELECT parent_id FROM category WHERE id = ?',
        [parentId],
      );
      if (parentRows.isEmpty) return const Err('الفئة الأصل غير موجودة');
      if (parentRows.first['parent_id'] != null) {
        return const Err('لا يمكن إنشاء أكثر من مستويين في شجرة الفئات');
      }
    }

    final duplicate = await _db.rawQuery(
      'SELECT 1 FROM category WHERE name = ? LIMIT 1',
      [trimmed],
    );
    if (duplicate.isNotEmpty) return const Err('اسم الفئة مستخدم مسبقاً');

    final id = await _db.insert('category', {
      'name': trimmed,
      'parent_id': parentId,
      'created_at': at,
      'updated_at': at,
    });
    return Ok(id);
  }

  /// وحدات القياس (قطعة/كرتون/… — مرتبة بالاسم).
  Future<List<ItemUnit>> listUnits() async {
    final rows = await _db.query(
      'unit',
      columns: ['id', 'name', 'factor', 'base_unit_id'],
      where: 'is_archived = 0',
      orderBy: 'name ASC',
    );
    return rows.map(ItemUnit.fromRow).toList();
  }

  /// ينشئ وحدة قياس — [factor] معامل التحويل إلى الوحدة الأساسية
  /// (1 كرتون = 24 قطعة → factor = 24 — FR-13-06).
  Future<Result<int, String>> createUnit(
    String name, {
    double factor = 1,
    DateTime? now,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Err('اسم الوحدة مطلوب');
    if (factor <= 0) return const Err('معامل التحويل يجب أن يكون أكبر من صفر');
    final at = (now ?? DateTime.now()).toUtc().toIso8601String();

    final duplicate = await _db.rawQuery(
      'SELECT 1 FROM unit WHERE name = ? LIMIT 1',
      [trimmed],
    );
    if (duplicate.isNotEmpty) return const Err('اسم الوحدة مستخدم مسبقاً');

    final id = await _db.insert('unit', {
      'name': trimmed,
      'factor': factor,
      'created_at': at,
      'updated_at': at,
    });
    return Ok(id);
  }

  // ─────────────────────────────────────────────────────────────────────
  // مساعدات خاصة
  // ─────────────────────────────────────────────────────────────────────

  /// يتحقق من مسودة الصنف ويعيد رسالة الخطأ العربية أو null.
  String? _validateDraft(ItemDraft draft) {
    if (draft.name.trim().isEmpty) return 'اسم الصنف مطلوب';
    if (draft.costPrice < 0) return 'سعر التكلفة لا يمكن أن يكون سالباً';
    if (draft.minStock < 0) return 'حد إعادة الطلب لا يمكن أن يكون سالباً';
    if (draft.openingQty < 0) return 'الكمية الافتتاحية لا يمكن أن تكون سالبة';
    final seen = <String>{};
    for (final price in draft.prices) {
      if (price.price < 0) return 'سعر البيع لا يمكن أن يكون سالباً';
      if (!seen.add('${price.currencyId}:${price.priceLevel}')) {
        return 'سعر مكرر لنفس العملة والمستوى';
      }
    }
    return null;
  }

  /// يولّد باركوداً داخلياً فريداً — حتى 5 محاولات عند التصادم (FR-01-02).
  Future<String?> _generateUniqueBarcode(DatabaseExecutor txn) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final candidate = _generator.generate();
      final clash = await txn.rawQuery(
        'SELECT 1 FROM product WHERE barcode = ? LIMIT 1',
        [candidate],
      );
      if (clash.isEmpty) return candidate;
    }
    return null;
  }

  /// يملأ خريطة الكمية لكل مخزن لصفحة نتائج (استعلام واحد مجمّع) —
  /// يعيد بناء العناصر بخريطة قابلة للقراءة بدل القيمة الافتراضية الثابتة.
  Future<void> _fillWarehouseQty(List<ItemStockInfo> results) async {
    if (results.isEmpty) return;
    final ids = results.map((r) => r.item.id).toList();
    final rows = await _db.rawQuery(
      'SELECT product_id, warehouse_id, qty FROM stock_level '
      'WHERE product_id IN (${List.filled(ids.length, '?').join(',')})',
      ids,
    );
    final byProduct = <int, Map<int, double>>{};
    for (final row in rows) {
      final productId = row['product_id'] as int;
      final warehouseId = row['warehouse_id'] as int;
      final qty = (row['qty'] as num?)?.toDouble() ?? 0;
      byProduct.putIfAbsent(productId, () => <int, double>{})[warehouseId] =
          qty;
    }
    for (var i = 0; i < results.length; i++) {
      final info = results[i];
      results[i] = ItemStockInfo(
        item: info.item,
        totalQty: info.totalQty,
        warehouseQty: byProduct[info.item.id] ?? const <int, double>{},
        retailPrice: info.retailPrice,
      );
    }
  }

  /// قيد تدقيق داخل المعاملة (نمط user_repository — الإضافة فقط).
  Future<void> _audit(
    DatabaseExecutor txn, {
    required String action,
    int? entityId,
    required String details,
    required int userId,
    required DateTime at,
  }) async {
    await txn.insert('audit_log', {
      'user_id': userId,
      'action': action,
      'entity': 'product',
      'entity_id': entityId,
      'details': details,
      'at': at.toUtc().toIso8601String(),
    });
  }

  /// يصوغ خطأ قاعدة البيانات بكلمات المستخدم (نمط §6.3 دون رمي).
  String _describeDbError(DatabaseException e) {
    if (e.isUniqueConstraintError()) {
      final text = e.toString();
      if (text.contains('barcode')) {
        return 'الباركود مستخدم مسبقاً لصنف آخر';
      }
      if (text.contains('product_price')) {
        return 'سعر مكرر لنفس العملة والمستوى';
      }
      return 'قيمة مكررة تخالف قيد التفرد في القاعدة';
    }
    return 'تعذر حفظ الصنف في القاعدة: $e';
  }
}

/// يهرّب محارف LIKE الخاصة (٪/_/\) حتى يبقى بحث المستخدم حرفياً.
String _escapeLike(String input) =>
    input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
