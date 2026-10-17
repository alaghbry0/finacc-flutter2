/// جزء من تقسيم R18-D3a لمستودع المبيعات — مستخرج حرفياً من
/// sale_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/dates.dart';
import '../../../domain/core/numbers.dart';
import '../../../domain/models/sale.dart';
import 'sale_flow_types.dart';

// ─────────────────────────────────────────────────────────────────────

/// يحمل معلومات الأصناف المطلوبة (استعلام واحد).
Future<Map<int, SaleProductInfo>> loadSaleProducts(
  Database db,
  Set<int> ids,
) async {
  if (ids.isEmpty) return const {};
  final rows = await db.rawQuery(
    'SELECT id, name, cost_price, is_service, track_batches, is_archived, '
    'unit_id FROM product '
    'WHERE id IN (${List.filled(ids.length, '?').join(',')})',
    ids.toList(),
  );
  return {
    for (final row in rows)
      row['id'] as int: SaleProductInfo(
        id: row['id'] as int,
        name: row['name'] as String,
        costPrice: (row['cost_price'] as num?)?.toDouble() ?? 0,
        isService: (row['is_service'] as int? ?? 0) == 1,
        trackBatches: (row['track_batches'] as int? ?? 0) == 1,
        isArchived: (row['is_archived'] as int? ?? 0) == 1,
        unitId: row['unit_id'] as int?,
      ),
  };
}

/// يقرأ WAC (cost_price) داخل المعاملة — لحظة الاستهلاك (5.4-3).
Future<double> readCostInside(DatabaseExecutor txn, int productId) async {
  final rows = await txn.query(
    'product',
    columns: ['cost_price'],
    where: 'id = ?',
    whereArgs: [productId],
    limit: 1,
  );
  return (rows.first['cost_price'] as num?)?.toDouble() ?? 0;
}

/// فحص توفر المخزون المسبق (قاعدة 5.4-5): يجمع المطلوب لكل صنف غير
/// خدمي عبر الأسطر (الأسطر المكررة تُجمع) ويقارنه بالمتاح:
/// العادي من `stock_level`، والمتتبع من دفعات FEFO النشطة غير المنتهية.
///
/// البونص (UX-4): المجموع **بالمنصرف الكلي** qty + freeQty — المجاني
/// وحدات تخرج من المخزون مثل المدفوع تماماً.
Future<String?> checkSaleAvailability(
  Database db,

  List<CartLine> lines,
  Map<int, SaleProductInfo> products,
  int warehouseId,
  DateTime asOf,
) async {
  final requested = <int, double>{};
  final requestedFree = <int, double>{};
  for (final line in lines) {
    final info = products[line.productId]!;
    if (info.isService) continue;
    requested[info.id] = (requested[info.id] ?? 0) + line.qty + line.freeQty;
    if (line.freeQty > qtyEpsilon) {
      requestedFree[info.id] = (requestedFree[info.id] ?? 0) + line.freeQty;
    }
  }
  if (requested.isEmpty) return null;

  final cutoff = dateOnly(asOf);
  final ids = requested.keys.toList();
  final inClause = List.filled(ids.length, '?').join(',');

  // العادي: دفتر stock_level هو الحقيقة.
  final plainRows = await db.rawQuery(
    'SELECT product_id, qty FROM stock_level '
    'WHERE warehouse_id = ? AND product_id IN ($inClause)',
    [warehouseId, ...ids],
  );
  final plainQty = {
    for (final row in plainRows)
      row['product_id'] as int: (row['qty'] as num?)?.toDouble() ?? 0,
  };

  // المتتبع: مجموع الدفعات النشطة غير المنتهية (نفس شرط FEFO).
  final batchRows = await db.rawQuery(
    'SELECT product_id, SUM(qty) AS q FROM batch '
    'WHERE warehouse_id = ? AND product_id IN ($inClause) '
    '  AND qty > 0 AND is_archived = 0 AND expiry_date >= ? '
    'GROUP BY product_id',
    [warehouseId, ...ids, cutoff],
  );
  final batchQty = {
    for (final row in batchRows)
      row['product_id'] as int: (row['q'] as num?)?.toDouble() ?? 0,
  };

  for (final entry in requested.entries) {
    final info = products[entry.key]!;
    final available = info.trackBatches
        ? (batchQty[entry.key] ?? 0)
        : (plainQty[entry.key] ?? 0);
    if (available + qtyEpsilon < entry.value) {
      final free = requestedFree[entry.key] ?? 0;
      return 'الكمية غير متوفرة للصنف «${info.name}»: المتاح '
          '${formatNum(available)} والمطلوب ${formatNum(entry.value)}'
          '${free > qtyEpsilon ? ' (منها ${formatNum(free)} مجاني)' : ''} — '
          'لا يسمح النظام بمخزون سالب.';
    }
  }
  return null;
}

/// يصوغ خطأ قاعدة البيانات بكلمات المستخدم (نمط item_repository).
String describeSaleDbError(DatabaseException e) {
  if (e.isUniqueConstraintError()) {
    final text = e.toString();
    if (text.contains('invoice_no')) {
      return 'تعارض في رقم الفاتورة — أعد الحفظ';
    }
    if (text.contains('payment_allocation')) {
      return 'تخصيص مدفوعات مكرر لنفس السند والفاتورة';
    }
    return 'قيمة مكررة تخالف قيد التفرد في القاعدة';
  }
  if (isSaleCheckFailure(e)) {
    final text = e.toString();
    if (text.contains('stock_level')) {
      return 'المخزون لا يسمح بخصم بهذه الكمية (رصيد سالب ممنوع)';
    }
    if (text.contains('due_amount') || text.contains('paid_amount')) {
      return 'مبالغ الدفع غير متسقة مع إجمالي الفاتورة';
    }
    return 'قيمة تخالف قيد سلامة محاسبي في القاعدة';
  }
  return 'تعذر حفظ الفاتورة في القاعدة: $e';
}
