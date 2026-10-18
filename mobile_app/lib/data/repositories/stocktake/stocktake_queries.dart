/// قراءات كشف الجرد (المخازن/كشف العدّ/سجل الجرد) — جزء من تقسيم
/// R20-D3a لمستودع الجرد (نمط R19-D3d): منقولة حرفياً من
/// stocktake_repository.dart (الواجهة العامة والسلوك ثابتان — المستودع
/// يفوِّض بتواقيعه نفسها).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/numbers.dart';
import 'stocktake_models.dart';

/// المخازن غير المؤرشفة (الافتراضي أولاً) — لاختيار «المخزن المحدد».
Future<List<StocktakeWarehouse>> stocktakeWarehouses(Database db) async {
  final rows = await db.query(
    'warehouse',
    columns: ['id', 'name', 'is_default'],
    where: 'is_archived = 0',
    orderBy: 'is_default DESC, id ASC',
  );
  return [
    for (final row in rows)
      StocktakeWarehouse(
        id: row['id'] as int,
        name: row['name'] as String,
        isDefault: (row['is_default'] as num?)?.toInt() == 1,
      ),
  ];
}

/// كشف الجرد للمخزن: كل الأصناف غير الخدمية غير المؤرشفة — الرصيد
/// الدفتري من `stock_level` (0 عند الغياب) ولقطة تكلفة العرض من
/// `product.cost_price` (WAC أساس)، مرتّبة بالاسم.
Future<List<StocktakeLineDraft>> loadStocktakeDraft(
  Database db,
  int warehouseId,
) async {
  final rows = await db.rawQuery(
    '''
      SELECT p.id AS product_id, p.name AS product_name,
             p.cost_price AS unit_cost,
             u.name AS unit_name,
             COALESCE(sl.qty, 0) AS book_qty
      FROM product p
      LEFT JOIN unit u ON u.id = p.unit_id
      LEFT JOIN stock_level sl
             ON sl.product_id = p.id AND sl.warehouse_id = ?
      WHERE p.is_service = 0 AND p.is_archived = 0
      ORDER BY p.name COLLATE NOCASE ASC, p.id ASC
      ''',
    <Object?>[warehouseId],
  );
  return [
    for (final row in rows)
      StocktakeLineDraft(
        productId: row['product_id'] as int,
        name: row['product_name'] as String,
        unitName: row['unit_name'] as String?,
        bookQty: roundTo3((row['book_qty'] as num?)?.toDouble() ?? 0),
        unitCost: (row['unit_cost'] as num?)?.toDouble() ?? 0,
      ),
  ];
}

/// سجل عمليات الجرد الأخيرة للمخزن (الأحدث أولاً) مع عدد الأسطر.
Future<List<StocktakeHistoryRow>> stocktakeHistory(
  Database db, {
  required int warehouseId,
  int limit = 20,
}) async {
  final rows = await db.rawQuery(
    '''
      SELECT s.id, s.counted_at, s.total_diff, s.notes,
             (SELECT COUNT(*) FROM stocktake_line l
               WHERE l.stocktake_id = s.id) AS lines_count
      FROM stocktake s
      WHERE s.warehouse_id = ?
      ORDER BY s.counted_at DESC, s.id DESC
      LIMIT ?
      ''',
    <Object?>[warehouseId, limit],
  );
  return [for (final row in rows) StocktakeHistoryRow.fromMap(row)];
}
