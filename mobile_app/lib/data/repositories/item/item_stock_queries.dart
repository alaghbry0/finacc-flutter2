/// استعلامات مخزون الأصناف وحركاتها (بطاقة الحركات/فحص الوجود) —
/// جزء من تقسيم R19-D3d لمستودع الأصناف: منقولة حرفياً من
/// item_repository.dart (الواجهة العامة والسلوك ثابتان — المستودع
/// يفوِّض بتواقيعه نفسها).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/item.dart';

/// **بطاقة الصنف** (FR-09-03): كل حركات الصنف مع الرصيد التتابعي بعد
/// كل حركة، مرتبة الأحدث أولاً.
///
/// [from]/[to]/[warehouseId] تصفي النافذة المعروضة، بينما يُحسب
/// `remainingAfter` على التاريخ الكامل غير المصفّى (رصيد محاسبي صحيح).
Future<List<ItemMovementEntry>> loadItemMovements(
  Database db,
  int productId, {
  DateTime? from,
  DateTime? to,
  int? warehouseId,
  int limit = 200,
}) async {
  final rows = await db.rawQuery(
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
Future<bool> itemHasMovements(Database db, int productId) async {
  final rows = await db.rawQuery(
    'SELECT EXISTS(SELECT 1 FROM stock_movement WHERE product_id = ?) AS ok',
    [productId],
  );
  return (rows.first['ok'] as int) == 1;
}
