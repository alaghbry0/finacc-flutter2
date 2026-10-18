/// ترحيل الجرد الذرّي (FR-01-08 + AC-04 — الشريحة 10) — جزء من تقسيم
/// R20-D3a لمستودع الجرد (نمط R19-D3d): منقول حرفياً من
/// stocktake_repository.dart — **المعاملة كاملة داخل هذا الملف الواحد
/// غير مشطورة** (الواجهة العامة والسلوك ثابتان).
///
/// ## قرارات معمارية موثقة (منقولة من رأس المستودع الأصلي):
/// 1. **تكلفة اللقطة تُلتقط داخل معاملة الترحيل** (لا وقت فتح كشف الجرد):
///    `stocktake_line.unit_cost` و`stock_movement.unit_cost` تقرآن
///    `product.cost_price` (WAC بالعملة الأساسية) لحظة الجرد داخل
///    المعاملة — نفس فلسفة إعادة قراءة `book_qty` (الرقم الدفتري
///    الحالي هو المرجع لا نسخة الواجهة). ما يعرضه الكشف أثناء العدّ
///    تكلفة لحظة الفتح للمعاينة فقط؛ المخزَّن هو لقطة وقت الاعتماد
///    الحتمية (متسقة مع الدفاتر عند الترحيل — «قيمة الفرق صحيحة»).
/// 2. **الرصيد الدفتري يُعاد قراءته داخل المعاملة** أيضاً: `bookQty`
///    المارّ في [postStocktake] استشاري فقط (نسخة الواجهة)؛ المخزَّن في
///    `stocktake_line.book_qty` هو قيمة `stock_level` لحظة الترحيل —
///    فلو جرى بيع/شراء أثناء العدّ فالفرق يُحتسب على الدفتر الحالي.
/// 3. **سطر لكل بند مُعدود** (أثر تدقيق كامل): كل الأسطر الممرَّرة
///    تُخزَّن في `stocktake_line` (المطابقة والفروقات معاً)، والبنود
///    **غير المعدودة لا تصل إلى المستودع أصلاً** — نموذج العرض
///    (stocktake_view_model) يمرّر المعدودة حصراً (قرار «العدّ الجزئي
///    جائز»: بلا إدخال = غير مُعدود = لا حركة ولا سطر ولا مساس برصيده).
/// 4. **حركة جرد لكل فرق** (`movement_type='stocktake_adjust'`): الكمية
///    بإشارة الدفتر (موجب = زيادة مخزون، سالب = عجز)، بتكلفة اللقطة،
///    `ref_type='stocktake'` + `ref_id`، و`moved_at` = **تاريخ المستخدم**
///    [countedAt] (لا ساعة الجهاز) — التوقيع المحاسبي الملزم.
/// 5. **قفل الأرصدة**: `stock_level` يُضبط على المقيس لكل بند (INSERT OR
///    IGNORE أولاً للصفوف الغائبة) — قيد `CHECK(qty>=0)` مضمون لأن
///    المستودع يرفض الكمية السالبة قبل المعاملة.
/// 6. **اتساق الدفعات** (track_batches): العجز يُخصم FEFO من الدفعات
///    غير المؤرشفة (الأقرب انتهاءً أولاً — شاملة المنتهية: الجرد يعدّ
///    الموجود فيزيائياً حتى لو انتهت صلاحيته، على عكس البيع الذي يتخطى
///    المنتهية)؛ الزيادة تُضاف إلى الدفعة **الأبعد انتهاءً**؛ ومجموع
///    الدفعات أقل من العجز → **تُصفَّر كل الدفعات** ويبقى الفارق بلا
///    دفعة (الدفعات حقيقة فيزيائية لا تُختلق — المجموع يظل ≤ الرصيد
///    المقفل). لا دفعات أصلاً → تجاوز صامت (زيادة بلا دفعة تُقفل في
///    الرصيد العام فقط).
/// 7. **الكميات بثلاث منازل** (NUMERIC(12,3)): المقيس والفرق يُقرَّبان
///    لثلاث منازل قبل التخزين؛ القيم المالية بمنزلتين (roundMoney)
///    بالعملة الأساسية.
/// 8. [postStocktake] **يرمي [StocktakeException] عربية وصفية** عند فشل
///    التحقق أو القاعدة (نمط الرمي الموثق في تكليف الشريحة) — ونموذج
///    العرض يلتقطها ويعرضها؛ فشل أي خطوة داخل المعاملة يتراجع الكل
///    (ذرّية).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/numbers.dart';
import '../../../domain/services/purchase_pricing.dart' show roundMoney;
import 'stocktake_models.dart';

/// **يرحّل الجرد داخل معاملة واحدة**: إعادة قراءة الدفتري والتكلفة →
/// صف `stocktake` → سطر لكل بند → حركة جرد لكل فرق → قفل الأرصدة →
/// اتساق الدفعات → قيد التدقيق. فشل أي خطوة يتراجع الكل.
///
/// - [countedAt] تاريخ المستخدم (يوقَّع به الجرد وحركاته).
/// - [countedBy] اسم الجانِد (يوقَّع في الملاحظات).
/// - [lines] البنود **المعدودة حصراً** — `(productId, bookQty استشاري،
///   countedQty)`؛ الدفتري المخزَّن والتكلفة يُقرآن داخل المعاملة
///   (القراران 1/2 برأس الملف).
/// - [userId] منفّذ العملية (created_by + قيد التدقيق).
///
/// يرمي [StocktakeException] عربية وصفية عند أي فشل.
Future<int> postStocktake(
  Database db, {
  required int warehouseId,
  required DateTime countedAt,
  required String countedBy,
  String? notes,
  required List<(int productId, double bookQty, double countedQty)> lines,
  required int userId,
}) async {
  final counter = countedBy.trim();
  if (counter.isEmpty) {
    throw const StocktakeException('اسم الجانِد مطلوب — الجرد يُوقَّع باسمه.');
  }
  if (lines.isEmpty) {
    throw const StocktakeException(
      'لا بنود معدودة في هذا الجرد — عدّ صنفاً واحداً على الأقل قبل الاعتماد.',
    );
  }
  for (final (productId, _, counted) in lines) {
    if (counted.isNaN || counted.isInfinite || counted < 0) {
      throw StocktakeException(
        'كمية العدّ للصنف رقم #$productId غير صالحة — الكمية الفعلية '
        'لا تكون سالبة.',
      );
    }
  }

  final countedIso = countedAt.toUtc().toIso8601String();
  final nowIso = DateTime.now().toUtc().toIso8601String();
  final cleanNotes = (notes ?? '').trim();

  try {
    return await db.transaction<int>((txn) async {
      // (1) قراءة الدفتري والتكلفة داخل المعاملة — لقطة وقت الجرد.
      final productIds = <int>[for (final (id, _, _) in lines) id];
      final placeholders = List.filled(productIds.length, '?').join(',');
      final productRows = await txn.rawQuery(
        '''
          SELECT p.id, p.name, p.cost_price, p.track_batches,
                 COALESCE(sl.qty, 0) AS book_qty
          FROM product p
          LEFT JOIN stock_level sl
                 ON sl.product_id = p.id AND sl.warehouse_id = ?
          WHERE p.id IN ($placeholders)
          ''',
        <Object?>[warehouseId, ...productIds],
      );
      final byId = <int, Map<String, Object?>>{};
      for (final row in productRows) {
        byId[row['id'] as int] = row;
      }
      for (final (id, _, _) in lines) {
        if (!byId.containsKey(id)) {
          throw StocktakeException(
            'الصنف رقم #$id غير موجود (أو محذوف) — لا يمكن ترحيل جرده.',
          );
        }
      }

      // (2) الفروقات بالدفتري الحالي والتكلفة الحالية (لقطات المعاملة).
      final resolved = <_ResolvedLine>[];
      var totalDiff = 0.0;
      var diffsCount = 0;
      for (final (productId, _, countedRaw) in lines) {
        final row = byId[productId]!;
        final book = roundTo3((row['book_qty'] as num?)?.toDouble() ?? 0);
        final counted = roundTo3(countedRaw);
        final cost = (row['cost_price'] as num?)?.toDouble() ?? 0;
        final diff = roundTo3(counted - book);
        if (diff.abs() > kStocktakeQtyEps) {
          diffsCount++;
          totalDiff = roundMoney(totalDiff + roundMoney(diff * cost));
        }
        resolved.add(
          _ResolvedLine(
            productId: productId,
            name: row['name'] as String,
            bookQty: book,
            countedQty: counted,
            diffQty: diff,
            unitCost: cost,
            trackBatches: (row['track_batches'] as num?)?.toInt() == 1,
          ),
        );
      }

      // (3) صف الجرد — المجموع بعملة الأساس، الحالة مكتمل، الملاحظات
      //     موقَّعة باسم الجانِد.
      final stocktakeId = await txn.insert('stocktake', {
        'warehouse_id': warehouseId,
        'counted_at': countedIso,
        'total_diff': totalDiff,
        'status': 'completed',
        'notes': cleanNotes.isEmpty
            ? 'الجانِد: $counter'
            : '$cleanNotes — الجانِد: $counter',
        'created_at': nowIso,
        'created_by': userId,
      });

      // (4) سطر لكل بند (أثر تدقيق كامل) + حركة لكل فرق + قفل الرصيد.
      for (final line in resolved) {
        await txn.insert('stocktake_line', {
          'stocktake_id': stocktakeId,
          'product_id': line.productId,
          'book_qty': line.bookQty,
          'counted_qty': line.countedQty,
          'diff_qty': line.diffQty,
          'unit_cost': line.unitCost,
          'created_at': nowIso,
          'created_by': userId,
        });

        if (line.diffQty.abs() > kStocktakeQtyEps) {
          await txn.insert('stock_movement', {
            'product_id': line.productId,
            'warehouse_id': warehouseId,
            'movement_type': 'stocktake_adjust',
            'qty': line.diffQty,
            'unit_cost': line.unitCost,
            'ref_type': 'stocktake',
            'ref_id': stocktakeId,
            'moved_at': countedIso,
            'notes': 'جرد بواسطة $counter',
            'created_at': nowIso,
            'created_by': userId,
          });
        }

        // قفل الرصيد على المقيس (الصف الغائب يُنشأ أولاً بصفر).
        await txn.rawInsert(
          'INSERT OR IGNORE INTO stock_level '
          '(product_id, warehouse_id, qty) VALUES (?, ?, 0)',
          <Object?>[line.productId, warehouseId],
        );
        await txn.rawUpdate(
          'UPDATE stock_level SET qty = ? WHERE product_id = ? '
          'AND warehouse_id = ?',
          <Object?>[line.countedQty, line.productId, warehouseId],
        );

        // (5) اتساق الدفعات للصنف المتتبع (القرار 6 برأس الملف).
        if (line.trackBatches && line.diffQty.abs() > kStocktakeQtyEps) {
          await _adjustBatches(
            txn,
            productId: line.productId,
            warehouseId: warehouseId,
            diff: line.diffQty,
            nowIso: nowIso,
          );
        }
      }

      // (6) قيد التدقيق — خلاصة الجرد بأسطره وفروقاته وصافيه.
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'stocktake_post',
        'entity': 'stocktake',
        'entity_id': stocktakeId,
        'details':
            'warehouse=$warehouseId lines=${resolved.length} '
            'diffs=$diffsCount net=$totalDiff',
        'at': nowIso,
      });

      return stocktakeId;
    });
  } on StocktakeException {
    rethrow;
  } on DatabaseException catch (e) {
    throw StocktakeException(_describeDbError(e));
  }
}

// ─────────────────────────────────────────────────────────────────────
// مساعدات خاصة
// ─────────────────────────────────────────────────────────────────────

/// يوازن دفعات الصنف المتتبع مع الرصيد المقفل (القرار 6):
/// عجز → خصم FEFO (الأقرب انتهاءً أولاً، شاملة المنتهية، بلا نزول تحت
/// الصفر؛ مجموع أقل من العجز → تُصفَّر الكل)؛ زيادة → تُضاف إلى الدفعة
/// الأبعد انتهاءً؛ لا دفعات → تجاوز صامت.
Future<void> _adjustBatches(
  DatabaseExecutor txn, {
  required int productId,
  required int warehouseId,
  required double diff,
  required String nowIso,
}) async {
  final rows = await txn.rawQuery(
    '''
      SELECT id, qty FROM batch
      WHERE product_id = ? AND warehouse_id = ? AND is_archived = 0
      ORDER BY expiry_date ASC, id ASC
      ''',
    <Object?>[productId, warehouseId],
  );
  if (rows.isEmpty) return;

  if (diff < -kStocktakeQtyEps) {
    // عجز: خصم FEFO — لا دفعة تنزل تحت الصفر، والمجموع الناقص يصفّر
    // الدفعات كلها (الباقي بلا دفعة — فيزيائياً معدوم).
    var remaining = -diff;
    for (final row in rows) {
      if (remaining <= kStocktakeQtyEps) break;
      final available = (row['qty'] as num?)?.toDouble() ?? 0;
      if (available <= kStocktakeQtyEps) continue;
      final take = available < remaining ? available : remaining;
      await txn.rawUpdate(
        'UPDATE batch SET qty = qty - ?, updated_at = ? '
        'WHERE id = ? AND qty >= ?',
        <Object?>[roundTo3(take), nowIso, row['id'], roundTo3(take)],
      );
      remaining = roundTo3(remaining - take);
    }
  } else if (diff > kStocktakeQtyEps) {
    // زيادة: تُضاف إلى الدفعة الأبعد انتهاءً (آخر صف في ترتيب FEFO).
    final latestId = rows.last['id'] as int;
    await txn.rawUpdate(
      'UPDATE batch SET qty = qty + ?, updated_at = ? WHERE id = ?',
      <Object?>[roundTo3(diff), nowIso, latestId],
    );
  }
}

String _describeDbError(DatabaseException e) {
  if (e.isUniqueConstraintError()) {
    return 'قيمة مكررة تخالف قيد التفرد أثناء ترحيل الجرد';
  }
  if (e.toString().toUpperCase().contains('CHECK')) {
    return 'قيمة تخالف قيد سلامة محاسبي في القاعدة أثناء ترحيل الجرد '
        '(رصيد أو كمية غير صالحة)';
  }
  if (e.toString().toUpperCase().contains('FOREIGN KEY')) {
    return 'مرجع مفقود (صنف أو مخزن غير موجود) أثناء ترحيل الجرد';
  }
  return 'تعذر ترحيل الجرد في القاعدة: $e';
}

/// بند محلول داخل معاملة الترحيل — قيم المعاملة الحتمية.
class _ResolvedLine {
  const _ResolvedLine({
    required this.productId,
    required this.name,
    required this.bookQty,
    required this.countedQty,
    required this.diffQty,
    required this.unitCost,
    required this.trackBatches,
  });

  final int productId;
  final String name;
  final double bookQty;
  final double countedQty;
  final double diffQty;
  final double unitCost;
  final bool trackBatches;
}
