/// جزء من تقسيم R18-D3a لمستودع المشتريات — مستخرج حرفياً من
/// purchase_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/numbers.dart';
import '../../../domain/services/purchase_pricing.dart' show roundCost;
import 'purchase_flow_types.dart';

// ─────────────────────────────────────────────────────────────────────

/// **WAC (قاعدة 5.4-3)** — يقرأ التكلفة والكمية الكلية داخل المعاملة
/// ثم يحدّث `product.cost_price` بدقة أربع منازل:
///
/// - `qty_old > 0`:
///   `new = (qty_old×cost_old + qty_new×cost_new)/(qty_old + qty_new)`
/// - `qty_old ≤ 0`: `new = cost_new` مباشرة (لا متوسط على مخزون معدوم).
///
/// `qty_old` = Σ stock_level.qty عبر كل المخازن (القرار 1 بالرأس).
Future<void> applyWac(
  DatabaseExecutor txn, {
  required int productId,
  required double qtyNew,
  required double costNew,
  required DateTime now,
}) async {
  final rows = await txn.rawQuery(
    'SELECT p.cost_price AS cost, '
    '       COALESCE((SELECT SUM(sl.qty) FROM stock_level sl '
    '                 WHERE sl.product_id = p.id), 0) AS qty '
    'FROM product p WHERE p.id = ?',
    [productId],
  );
  if (rows.isEmpty) {
    throw PurchaseFlowError('الصنف رقم #$productId غير موجود.');
  }
  final costOld = (rows.first['cost'] as num?)?.toDouble() ?? 0;
  final qtyOld = (rows.first['qty'] as num?)?.toDouble() ?? 0;
  double newCost;
  if (qtyOld <= qtyEpsilon) {
    newCost = costNew; // المخزون معدوم/سالب دفترياً → التكلفة الجديدة.
  } else {
    newCost = roundCost(
      (qtyOld * costOld + qtyNew * costNew) / (qtyOld + qtyNew),
    );
  }
  if (newCost < 0) newCost = 0; // حارس نظري (لا تكلفة سالبة).
  await txn.update(
    'product',
    {'cost_price': newCost, 'updated_at': now.toUtc().toIso8601String()},
    where: 'id = ?',
    whereArgs: [productId],
  );
}

/// يحمل معلومات الأصناف المطلوبة (استعلام واحد) — مرآة البيع.
Future<Map<int, PurchaseProductInfo>> loadPurchaseProducts(
  Database db,
  Set<int> ids,
) async {
  if (ids.isEmpty) return const {};
  final rows = await db.rawQuery(
    'SELECT id, name, is_service, track_batches, is_archived, unit_id '
    'FROM product '
    'WHERE id IN (${List.filled(ids.length, '?').join(',')})',
    ids.toList(),
  );
  return {
    for (final row in rows)
      row['id'] as int: PurchaseProductInfo(
        id: row['id'] as int,
        name: row['name'] as String,
        isService: (row['is_service'] as int? ?? 0) == 1,
        trackBatches: (row['track_batches'] as int? ?? 0) == 1,
        isArchived: (row['is_archived'] as int? ?? 0) == 1,
        unitId: row['unit_id'] as int?,
      ),
  };
}

/// فحص توفر المخزون مسبقاً لإبطال الشراء (5.4-5 — مرآة PRN): لكل صنف
/// غير خدمي، المستلم الكلي (qty + free_qty) لا يتجاوز المتاح بمخزن
/// الفاتورة: العادي من `stock_level` والمتتبع من مجموع دفعاته غير
/// المؤرشفة (المنتهية مشمولة — الخروج منها جائز للمورد).
Future<String?> checkVoidStock(
  Database db,

  List<Map<String, Object?>> itemRows,
  Map<int, PurchaseProductInfo> products,
  int warehouseId,
) async {
  final requested = <int, double>{};
  final names = <int, String>{};
  for (final item in itemRows) {
    final productId = item['product_id'] as int?;
    if (productId == null) continue;
    final info = products[productId];
    if (info == null || info.isService) continue;
    final qty = (item['qty'] as num?)?.toDouble() ?? 0;
    final free = (item['free_qty'] as num?)?.toDouble() ?? 0;
    requested[productId] = (requested[productId] ?? 0) + qty + free;
    names[productId] = info.name;
  }
  if (requested.isEmpty) return null;
  final ids = requested.keys.toList();
  final inClause = List.filled(ids.length, '?').join(',');

  final plainRows = await db.rawQuery(
    'SELECT product_id, qty FROM stock_level '
    'WHERE warehouse_id = ? AND product_id IN ($inClause)',
    [warehouseId, ...ids],
  );
  final plainQty = {
    for (final row in plainRows)
      row['product_id'] as int: (row['qty'] as num?)?.toDouble() ?? 0,
  };
  final batchRows = await db.rawQuery(
    'SELECT product_id, SUM(qty) AS q FROM batch '
    'WHERE warehouse_id = ? AND product_id IN ($inClause) '
    '  AND qty > 0 AND is_archived = 0 GROUP BY product_id',
    [warehouseId, ...ids],
  );
  final batchQty = {
    for (final row in batchRows)
      row['product_id'] as int: (row['q'] as num?)?.toDouble() ?? 0,
  };

  for (final entry in requested.entries) {
    final tracked = products[entry.key]!.trackBatches;
    final available = tracked
        ? (batchQty[entry.key] ?? 0)
        : (plainQty[entry.key] ?? 0);
    if (available + qtyEpsilon < entry.value) {
      return 'لا يمكن إبطال الفاتورة: الكمية غير متوفرة للصنف '
          '«${names[entry.key]}» — المتاح ${formatNum(available)} والمطلوب '
          'إخراجه ${formatNum(entry.value)} (ما بِيع من الوارد لا يُبطَل '
          'شراؤه — لا يسمح النظام بمخزون سالب).';
    }
  }
  return null;
}

/// يقرأ حالة WAC (التكلفة + الكمية الكلية عبر المخازن) داخل المعاملة —
/// نفس استعلام `applyWac` (القرار 1) بصيغة `return_repository`.
Future<({double cost, double qty})> readPurchaseWacState(
  DatabaseExecutor txn,
  int productId,
) async {
  final rows = await txn.rawQuery(
    'SELECT p.cost_price AS cost, '
    '       COALESCE((SELECT SUM(sl.qty) FROM stock_level sl '
    '                 WHERE sl.product_id = p.id), 0) AS qty '
    'FROM product p WHERE p.id = ?',
    [productId],
  );
  return (
    cost: (rows.first['cost'] as num?)?.toDouble() ?? 0,
    qty: (rows.first['qty'] as num?)?.toDouble() ?? 0,
  );
}

/// يركّب الملاحظة الداخلية: مرجع فاتورة المورد كبادئة موثَّقة ثم ملاحظة
/// المستخدم (القرار 5).
String? composeInternalNotes(String? supplierRef, String? notes) {
  final ref = supplierRef?.trim() ?? '';
  final body = notes?.trim() ?? '';
  if (ref.isEmpty && body.isEmpty) return null;
  if (ref.isEmpty) return body;
  if (body.isEmpty) return 'فاتورة المورد: $ref';
  return 'فاتورة المورد: $ref — $body';
}

/// يصوغ خطأ قاعدة البيانات بكلمات المستخدم (نمط sale_repository).
String describePurchaseDbError(DatabaseException e) {
  if (e.isUniqueConstraintError()) {
    final text = e.toString();
    if (text.contains('invoice_no')) {
      return 'تعارض في رقم فاتورة الشراء — أعد الحفظ';
    }
    if (text.contains('payment_allocation')) {
      return 'تخصيص مدفوعات مكرر لنفس السند والفاتورة';
    }
    return 'قيمة مكررة تخالف قيد التفرد في القاعدة';
  }
  if (isPurchaseCheckFailure(e)) {
    final text = e.toString();
    if (text.contains('stock_level')) {
      return 'المخزون لا يسمح بهذه الكمية (رصيد سالب ممنوع)';
    }
    if (text.contains('due_amount') || text.contains('paid_amount')) {
      return 'مبالغ الدفع غير متسقة مع إجمالي فاتورة الشراء';
    }
    return 'قيمة تخالف قيد سلامة محاسبي في القاعدة';
  }
  return 'تعذر حفظ فاتورة الشراء في القاعدة: $e';
}
