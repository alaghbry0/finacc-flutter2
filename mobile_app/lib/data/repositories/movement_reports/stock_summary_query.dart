/// ملخص حركة المخزون (FR-09-04) — جزء من تقسيم R20-D3a لمستودع تقارير
/// الحركة (نمط R19-D3d): منقولة حرفياً من movement_reports_repository.dart
/// (الواجهة العامة والسلوك ثابتان — المستودع يفوِّض بتواقيعه نفسها).
///
/// ## قرارات معمارية موثقة (منقولة من رأس المستودع الأصلي):
/// 1. **حدود الفترة على مستوى اليوم**: `date(moved_at)` `BETWEEN` شاملة
///    الطرفين — نفس اصطلاح `profit_report_repository` (لا ساعات/دقائق
///    تُقصّ من أطراف اليوم).
/// 2. **أعمدة تدفق إجمالية**: «وارد» = شراء + افتتاحي + **الجزء الموجب**
///    من تسويات الجرد؛ «صادر» = |بيع + مرتجع شراء|؛ «مرتجع» = مرتجع
///    بيع (وارد)؛ «تسوية» = صافي تسوية الجرد بإشارته.
///    **الرصيد الختامي مصدر الحقيقة**: SUM لكل الحركات (أي نوع، شاملة
///    التحويلات والتسويات اليدوية) حتى `to` — لا يُشتق من الأعمدة
///    (التسوية الموجبة تظهر في «وارد» و«تسوية» معاً بقرار FR).
/// 3. `manual_adjust` بلا منتج واجهة في V1 (نفس قرار 10-b) — يدخل
///    الرصيد الختامي حصراً لا أعمدة التدفق.
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/dates.dart';
import 'movement_report_models.dart';

/// ملخص الحركة لكل صنف **تحرّك** في الفترة [from]..[to] (شاملة
/// الطرفين)، مرتّباً بقيمة المخزون تنازلياً — [warehouseId] اختياري.
///
/// الأصناف الساكنة (بلا حركة في الفترة) غير مشمولة عمداً (FR: ملخص
/// الحركة). الرصيد الختامي يقرأ كل الحركات حتى `to` (القرار 2).
Future<List<StockSummaryRow>> loadStockSummary(
  Database db, {
  required DateTime from,
  required DateTime to,
  int? warehouseId,
}) async {
  final fromDay = dateOnly(from);
  final toDay = dateOnly(to);
  final warehouseClause = warehouseId != null ? ' AND sm.warehouse_id = ?' : '';

  // (أ) أعمدة التدفق لكل صنف متحرك في الفترة (GROUP BY واحد).
  final flowRows = await db.rawQuery(
    '''
      SELECT sm.product_id AS productId, p.name AS name,
             p.cost_price AS costPrice,
             COALESCE(SUM(CASE
               WHEN sm.movement_type IN ('purchase','opening')
                 OR (sm.movement_type = 'stocktake_adjust' AND sm.qty > 0)
               THEN sm.qty ELSE 0 END), 0) AS qtyIn,
             COALESCE(SUM(CASE
               WHEN sm.movement_type IN ('sale','purchase_return')
               THEN -sm.qty ELSE 0 END), 0) AS qtyOut,
             COALESCE(SUM(CASE
               WHEN sm.movement_type = 'sale_return'
               THEN sm.qty ELSE 0 END), 0) AS qtyReturns,
             COALESCE(SUM(CASE
               WHEN sm.movement_type = 'stocktake_adjust'
               THEN sm.qty ELSE 0 END), 0) AS qtyAdjustNet
      FROM stock_movement sm
      JOIN product p ON p.id = sm.product_id
      WHERE date(sm.moved_at) >= ? AND date(sm.moved_at) <= ?$warehouseClause
      GROUP BY sm.product_id, p.name, p.cost_price
      ''',
    <Object?>[fromDay, toDay, ?warehouseId],
  );

  if (flowRows.isEmpty) return const <StockSummaryRow>[];

  // (ب) الأرصدة الختامية لكل صنف ظهر — كل الحركات حتى `to` (أي نوع).
  final productIds = <Object?>[
    for (final row in flowRows) row['productId'] as int,
  ];
  final placeholders = List.filled(productIds.length, '?').join(', ');
  final balanceRows = await db.rawQuery(
    'SELECT product_id, COALESCE(SUM(qty), 0) AS endQty '
    'FROM stock_movement '
    'WHERE product_id IN ($placeholders) AND date(moved_at) <= ?'
    '${warehouseId != null ? ' AND warehouse_id = ?' : ''} '
    'GROUP BY product_id',
    <Object?>[...productIds, toDay, ?warehouseId],
  );
  final endByProduct = <int, double>{
    for (final row in balanceRows)
      row['product_id'] as int: (row['endQty'] as num?)?.toDouble() ?? 0,
  };

  // (ج) الصفوف + القيمة بالتكلفة + الترتيب بالقيمة تنازلياً.
  final rows = <StockSummaryRow>[];
  for (final row in flowRows) {
    final endBalance = endByProduct[row['productId'] as int] ?? 0;
    final costPrice = (row['costPrice'] as num?)?.toDouble() ?? 0;
    rows.add(
      StockSummaryRow(
        productId: row['productId'] as int,
        name: (row['name'] as String?) ?? '',
        qtyIn: (row['qtyIn'] as num?)?.toDouble() ?? 0,
        qtyOut: (row['qtyOut'] as num?)?.toDouble() ?? 0,
        qtyReturns: (row['qtyReturns'] as num?)?.toDouble() ?? 0,
        qtyAdjustNet: (row['qtyAdjustNet'] as num?)?.toDouble() ?? 0,
        endBalance: endBalance,
        valueAtCost: endBalance * costPrice,
      ),
    );
  }
  rows.sort((a, b) {
    if (a.valueAtCost != b.valueAtCost) {
      return b.valueAtCost.compareTo(a.valueAtCost);
    }
    return a.name.compareTo(b.name);
  });

  return rows;
}
