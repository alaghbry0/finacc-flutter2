/// استعلامات قراءة الأصناف (بحث/باركود/تفاصيل/حد الطلب) — جزء من
/// تقسيم R19-D3d لمستودع الأصناف: منقولة حرفياً من item_repository.dart
/// (الواجهة العامة والسلوك ثابتان — المستودع يفوِّض بتواقيعه نفسها).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/item.dart';
import 'item_stock_queries.dart';

/// **البحث السريع** (FR-01-04): الاسم أو الباركود `LIKE %q%` مع إجمالي
/// المخزون وسعر تجزئة اختياري — المؤرشف مستثنى إلا بطلب صريح.
///
/// [currencyIdForPrice] يضمّن سعر التجزئة بعملة محددة (null = بلا سعر).
/// خيارات التصنيف/الحد/الإزاحة تدعم التمرير المتدرج في قائمة الأصناف.
Future<List<ItemStockInfo>> searchItemsPage(
  Database db,
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

  final rows = await db.rawQuery('''
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
  await _fillWarehouseQty(db, results);
  return results;
}

/// **بحث الباركود الدقيق** (FR-01-03: شاشة نتيجة المسح / POS):
/// مطابقة تامة، المؤرشف مستثنى دائماً. [currencyId] يضمّن سعر التجزئة.
Future<ItemStockInfo?> itemByBarcode(
  Database db,
  String code, {
  int? currencyId,
}) async {
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
  final rows = await db.rawQuery('''
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
  await _fillWarehouseQty(db, [result]);
  return result;
}

/// **تفاصيل صنف كاملة** (FR-01-03): الصنف + كل الأسعار بكل العملات +
/// المخزون لكل مستودع + آخر 20 حركة (بطاقة الصنف).
///
/// يعمل حتى للأصناف المؤرشفة (الوصول بالمعرّف مباشرة).
Future<ItemFullDetail?> itemDetail(Database db, int id) async {
  final rows = await db.query(
    'product',
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  if (rows.isEmpty) return null;

  final priceRows = await db.rawQuery(
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

  final stockRows = await db.rawQuery(
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
    recentMovements: await loadItemMovements(db, id, limit: 20),
  );
}

/// **أصناف تحت حد الطلب** (FR-01-12): غير الخدمي وغير المؤرشف حيث
/// إجمالي المخزون ≤ `min_stock` (أو ≤ [minThresholdOverride] لكل الأصناف).
/// الأصناف بلا أي صف مخزون تعتبر كميتها صفراً فتُدرج (نفاد تام).
Future<List<ItemStockInfo>> listLowStockItems(
  Database db, {
  double? minThresholdOverride,
}) async {
  final args = <Object>[];
  final thresholdCondition = minThresholdOverride == null
      ? 'COALESCE(s.total_qty, 0) <= p.min_stock'
      : 'COALESCE(s.total_qty, 0) <= ?';
  if (minThresholdOverride != null) args.add(minThresholdOverride);

  final rows = await db.rawQuery('''
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
  await _fillWarehouseQty(db, results);
  return results;
}

// ─────────────────────────────────────────────────────────────────────
// مساعدات خاصة
// ─────────────────────────────────────────────────────────────────────

/// يملأ خريطة الكمية لكل مخزن لصفحة نتائج (استعلام واحد مجمّع) —
/// يعيد بناء العناصر بخريطة قابلة للقراءة بدل القيمة الافتراضية الثابتة.
Future<void> _fillWarehouseQty(Database db, List<ItemStockInfo> results) async {
  if (results.isEmpty) return;
  final ids = results.map((r) => r.item.id).toList();
  final rows = await db.rawQuery(
    'SELECT product_id, warehouse_id, qty FROM stock_level '
    'WHERE product_id IN (${List.filled(ids.length, '?').join(',')})',
    ids,
  );
  final byProduct = <int, Map<int, double>>{};
  for (final row in rows) {
    final productId = row['product_id'] as int;
    final warehouseId = row['warehouse_id'] as int;
    final qty = (row['qty'] as num?)?.toDouble() ?? 0;
    byProduct.putIfAbsent(productId, () => <int, double>{})[warehouseId] = qty;
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

/// يهرّب محارف LIKE الخاصة (٪/_/\) حتى يبقى بحث المستخدم حرفياً.
String _escapeLike(String input) =>
    input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
