/// بطاقة حركة صنف واحد (FR-09-03) — جزء من تقسيم R20-D3a لمستودع
/// تقارير الحركة (نمط R19-D3d): منقولة حرفياً من
/// movement_reports_repository.dart (الواجهة العامة والسلوك ثابتان —
/// المستودع يفوِّض بتواقيعه نفسها).
///
/// ## قرارات معمارية موثقة (منقولة من رأس المستودع الأصلي):
/// 1. **حدود الفترة على مستوى اليوم**: `date(moved_at)` `BETWEEN` شاملة
///    الطرفين — نفس اصطلاح `profit_report_repository` (لا ساعات/دقائق
///    تُقصّ من أطراف اليوم).
/// 2. **الكمية موقّعة أصلاً في المخطط** (§5.4): البيع ومرتجع الشراء
///    والتحويل الصادر سالبة، والشراء والافتتاحي ومرتجع البيع والتحويل
///    الوارد موجبة — فالرصيد التراكمي = مجموعCumul بسيط.
/// 3. **الباقي التراكمي يُحسب في Dart تصاعدياً** (moved_at ثم id) ثم
///    **تُعرض الصفوف تنازلياً** (الأحدث أولاً) — مسؤولية الشاشة.
/// 4. **رصيد ما قبل الفترة** = SUM(qty) للحركات قبل `from` حصراً (بفلتر
///    المخزن إن وجد) — نقطة انطلاق السلسلة التراكمية.
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/dates.dart';
import 'movement_report_models.dart';

/// بطاقة حركة صنف [productId] في الفترة [from]..[to] (شاملة الطرفين
/// على مستوى اليوم) — [warehouseId] اختياري (null = كل المخازن).
///
/// يرمي [StateError] إن كان الصنف غير موجود (محذوف/معرّف غريب).
Future<ItemMovementReport> loadItemMovementReport(
  Database db, {
  required int productId,
  required DateTime from,
  required DateTime to,
  int? warehouseId,
}) async {
  final fromDay = dateOnly(from);
  final toDay = dateOnly(to);

  // (أ) الصنف: الاسم والتكلفة الحالية (WAC) — أو خطأ إن غاب.
  final productRows = await db.rawQuery(
    'SELECT name, cost_price FROM product WHERE id = ?',
    <Object?>[productId],
  );
  if (productRows.isEmpty) {
    throw StateError('الصنف رقم $productId غير موجود');
  }
  final name = (productRows.first['name'] as String?) ?? '';
  final unitCostNow =
      (productRows.first['cost_price'] as num?)?.toDouble() ?? 0;

  // (ب) رصيد ما قبل الفترة (نقطة انطلاق السلسلة التراكمية).
  final openingRows = await db.rawQuery(
    'SELECT COALESCE(SUM(qty), 0) AS opening FROM stock_movement '
    'WHERE product_id = ? AND date(moved_at) < ?'
    '${warehouseId != null ? ' AND warehouse_id = ?' : ''}',
    <Object?>[productId, fromDay, ?warehouseId],
  );
  final opening = (openingRows.first['opening'] as num?)?.toDouble() ?? 0;

  // (ج) حركات الفترة تصاعدياً (moved_at ثم id) — الترتيب الذي يُحسب
  // عليه الرصيد التراكمي (العرض التنازلي مسؤولية الشاشة).
  final movementRows = await db.rawQuery(
    'SELECT id, movement_type, qty, unit_cost, ref_type, ref_id, '
    'moved_at, notes FROM stock_movement '
    'WHERE product_id = ? AND date(moved_at) >= ? AND date(moved_at) <= ?'
    '${warehouseId != null ? ' AND warehouse_id = ?' : ''} '
    'ORDER BY moved_at ASC, id ASC',
    <Object?>[productId, fromDay, toDay, ?warehouseId],
  );

  // (د) السلسلة التراكمية في Dart (قرار 3 برأس الملف).
  var balance = opening;
  final rows = <ItemMovementRow>[];
  for (final row in movementRows) {
    final qty = (row['qty'] as num?)?.toDouble() ?? 0;
    balance += qty;
    rows.add(
      ItemMovementRow(
        movedAt: DateTime.parse(row['moved_at'] as String),
        movementType: (row['movement_type'] as String?) ?? '',
        qty: qty,
        unitCost: (row['unit_cost'] as num?)?.toDouble() ?? 0,
        refType: row['ref_type'] as String?,
        refId: row['ref_id'] as int?,
        notes: row['notes'] as String?,
        balanceAfter: balance,
      ),
    );
  }

  return ItemMovementReport(
    productId: productId,
    name: name,
    unitCostNow: unitCostNow,
    openingBalance: opening,
    from: DateTime(from.year, from.month, from.day),
    to: DateTime(to.year, to.month, to.day),
    rows: List<ItemMovementRow>.unmodifiable(rows),
  );
}
