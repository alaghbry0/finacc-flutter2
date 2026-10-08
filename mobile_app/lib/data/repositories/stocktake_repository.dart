/// مستودع الجرد الفعلي (FR-01-08 + AC-04 — الشريحة 10): شاشة جرد للمخزن
/// المحدد تعرض الرصيد الدفتري وتستقبل الرصيد الفعلي، وتولّد تسوية الفرق
/// **كحركة جرد موقّعة بتاريخ المستخدم واسم الجانِد وبتكلفة لقطة
/// (unit_cost) وقت الجرد**، ثم تُقفل الأرصدة (stock_level يُضبط على
/// المقيس).
///
/// ## قرارات معمارية موثقة (هذه الشريحة):
/// 1. **تكلفة اللقطة تُلتقط داخل معاملة الترحيل** (لا وقت فتح كشف الجرد):
///    `stocktake_line.unit_cost` و`stock_movement.unit_cost` تقرآن
///    `product.cost_price` (WAC بالعملة الأساسية) لحظة الجرد داخل
///    المعاملة — نفس فلسفة إعادة قراءة `book_qty` (الرقم الدفتري
///    الحالي هو المرجع لا نسخة الواجهة). ما يعرضه الكشف أثناء العدّ
///    تكلفة لحظة الفتح للمعاينة فقط؛ المخزَّن هو لقطة وقت الاعتماد
///    الحتمية (متسقة مع الدفاتر عند الترحيل — «قيمة الفرق صحيحة»).
/// 2. **الرصيد الدفتري يُعاد قراءته داخل المعاملة** أيضاً: `bookQty`
///    المارّ في [post] استشاري فقط (نسخة الواجهة)؛ المخزَّن في
///    `stocktake_line.book_qty` هو قيمة `stock_level` لحظة الترحيل —
///    فلو جرى بيع/شراء أثناء العدّ فالفرق يُحتسب على الدفتر الحالي.
/// 3. **سطر لكل بند مُعدود** (أثر تدقيق كامل): كل الأسطر الممرَّرة لـ
///    [post] تُخزَّن في `stocktake_line` (المطابقة والفروقات معاً)،
///    والبنود **غير المعدودة لا تصل إلى المستودع أصلاً** — نموذج العرض
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
/// 8. [post] **يرمي [StocktakeException] عربية وصفية** عند فشل التحقق أو
///    القاعدة (نمط الرمي الموثق في تكليف الشريحة) — ونموذج العرض
///    يلتقطها ويعرضها؛ فشل أي خطوة داخل المعاملة يتراجع الكل (ذرّية).
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/services/purchase_pricing.dart' show roundMoney;

/// تفاوت عشري مقبول في مقارنات الكميات (NUMERIC(12,3) في القاعدة).
const double _qtyEps = 0.0005;

/// خطأ جرد موصوف بكلمات المستخدم — يرميه [StocktakeRepository.post].
class StocktakeException implements Exception {
  const StocktakeException(this.message);

  /// الرسالة العربية الوصفية (تُعرض كما هي).
  final String message;

  @override
  String toString() => message;
}

/// يقرب كمية إلى ثلاث منازل (دقة أعمدة NUMERIC(12,3)).
double _roundQty(double value) => (value * 1000).round() / 1000;

/// مستودع مرجعي صغير للمخزن (قائمة اختيار الشاشة).
class StocktakeWarehouse {
  const StocktakeWarehouse({
    required this.id,
    required this.name,
    required this.isDefault,
  });

  final int id;
  final String name;
  final bool isDefault;
}

/// بند كشف الجرد — سطر عدّ لصنف واحد في مخزن واحد.
///
/// [unitCost] لقطة عرض (تكلفة لحظة فتح الكشف) للمعاينة والمراجعة؛
/// اللقطة الملزمة المخزَّنة تُقرأ داخل معاملة الترحيل (القرار 1).
class StocktakeLineDraft {
  const StocktakeLineDraft({
    required this.productId,
    required this.name,
    this.unitName,
    required this.bookQty,
    required this.unitCost,
    this.countedQty,
  });

  /// معرّف الصنف في جدول `product`.
  final int productId;

  /// اسم الصنف.
  final String name;

  /// اسم وحدة القياس (إن عُرِّفت للصنف).
  final String? unitName;

  /// الرصيد الدفتري الحالي (stock_level — 0 عند غياب الصف).
  final double bookQty;

  /// لقطة تكلفة الوحدة للعرض (WAC بالعملة الأساسية لحظة الفتح).
  final double unitCost;

  /// الرصيد الفعلي المُعدود — `null` حتى يُدخله المستخدم.
  final double? countedQty;

  /// نسخة بعدّ جديد للسطر (نمط الحالة الثابتة).
  StocktakeLineDraft withCounted(double? qty) => StocktakeLineDraft(
    productId: productId,
    name: name,
    unitName: unitName,
    bookQty: bookQty,
    unitCost: unitCost,
    countedQty: qty,
  );

  /// الفرق = المقيس − الدفتري (`null` ما لم يُعدّ).
  double? get diff {
    final counted = countedQty;
    if (counted == null) return null;
    return _roundQty(counted - bookQty);
  }
}

/// ملخص الجرد الجاري — القيم بالعملة الأساسية (فرق × تكلفة اللقطة).
class StocktakeSummary {
  const StocktakeSummary({
    required this.linesCount,
    required this.countedCount,
    required this.diffsCount,
    required this.surplusValue,
    required this.shortageValue,
  });

  /// عدد أسطر الكشف (كل الأصناف غير الخدمية غير المؤرشفة).
  final int linesCount;

  /// عدد الأسطر المعدودة.
  final int countedCount;

  /// عدد أسطر الفروقات (المعدودة ذات فرق ≠ 0).
  final int diffsCount;

  /// قيمة الزيادات (موجبة دائماً).
  final double surplusValue;

  /// قيمة العجوزات (سالبة دائماً).
  final double shortageValue;

  /// صافي أثر الجرد المالي = زيادات + عجوزات (محسوباً — لا حقل ثابت
  /// حتى يبقى المنشئ const).
  double get netDiffValue => roundMoney(surplusValue + shortageValue);

  /// ملخص فارغ — لا أسطر.
  static const StocktakeSummary empty = StocktakeSummary(
    linesCount: 0,
    countedCount: 0,
    diffsCount: 0,
    surplusValue: 0,
    shortageValue: 0,
  );

  /// يبني الملخص فوق أسطر الكشف (بعدّها الاختياري).
  static StocktakeSummary of(List<StocktakeLineDraft> lines) {
    var counted = 0;
    var diffs = 0;
    var surplus = 0.0;
    var shortage = 0.0;
    for (final line in lines) {
      final diff = line.diff;
      if (diff == null) continue;
      counted++;
      if (diff.abs() <= _qtyEps) continue;
      diffs++;
      final value = roundMoney(diff * line.unitCost);
      if (value > 0) {
        surplus = roundMoney(surplus + value);
      } else {
        shortage = roundMoney(shortage + value);
      }
    }
    return StocktakeSummary(
      linesCount: lines.length,
      countedCount: counted,
      diffsCount: diffs,
      surplusValue: surplus,
      shortageValue: shortage,
    );
  }
}

/// صف جرد في السجل — جرد واحد مكتمل.
class StocktakeHistoryRow {
  const StocktakeHistoryRow({
    required this.id,
    required this.countedAt,
    required this.totalDiff,
    required this.notes,
    required this.linesCount,
  });

  factory StocktakeHistoryRow.fromMap(Map<String, Object?> map) =>
      StocktakeHistoryRow(
        id: map['id'] as int,
        countedAt: map['counted_at'] as String?,
        totalDiff: (map['total_diff'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String?,
        linesCount: (map['lines_count'] as num?)?.toInt() ?? 0,
      );

  /// معرّف الجرد.
  final int id;

  /// لحظة العدّ (ISO-UTC — بتاريخ المستخدم).
  final String? countedAt;

  /// صافي أثر الجرد المالي (بالعملة الأساسية).
  final double totalDiff;

  /// ملاحظات الجرد (تشمل اسم الجانِد — القرار 4 في post).
  final String? notes;

  /// عدد أسطر الجرد المخزَّنة.
  final int linesCount;
}

/// مستودع الجرد الفعلي — قراءة الكشف + ترحيل ذرّي + سجل.
class StocktakeRepository {
  StocktakeRepository(this._db);

  final Database _db;

  // ─────────────────────────────────────────────────────────────────────
  // قراءات الكشف (FR-01-08)
  // ─────────────────────────────────────────────────────────────────────

  /// المخازن غير المؤرشفة (الافتراضي أولاً) — لاختيار «المخزن المحدد».
  Future<List<StocktakeWarehouse>> warehouses() async {
    final rows = await _db.query(
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
  Future<List<StocktakeLineDraft>> loadDraft(int warehouseId) async {
    final rows = await _db.rawQuery(
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
          bookQty: _roundQty((row['book_qty'] as num?)?.toDouble() ?? 0),
          unitCost: (row['unit_cost'] as num?)?.toDouble() ?? 0,
        ),
    ];
  }

  /// سجل عمليات الجرد الأخيرة للمخزن (الأحدث أولاً) مع عدد الأسطر.
  Future<List<StocktakeHistoryRow>> history({
    required int warehouseId,
    int limit = 20,
  }) async {
    final rows = await _db.rawQuery(
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

  // ─────────────────────────────────────────────────────────────────────
  // الترحيل الذرّي (AC-04)
  // ─────────────────────────────────────────────────────────────────────

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
  Future<int> post({
    required int warehouseId,
    required DateTime countedAt,
    required String countedBy,
    String? notes,
    required List<(int productId, double bookQty, double countedQty)> lines,
    required int userId,
  }) async {
    final counter = countedBy.trim();
    if (counter.isEmpty) {
      throw const StocktakeException(
        'اسم الجانِد مطلوب — الجرد يُوقَّع باسمه.',
      );
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
      return await _db.transaction<int>((txn) async {
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
          final book = _roundQty((row['book_qty'] as num?)?.toDouble() ?? 0);
          final counted = _roundQty(countedRaw);
          final cost = (row['cost_price'] as num?)?.toDouble() ?? 0;
          final diff = _roundQty(counted - book);
          if (diff.abs() > _qtyEps) {
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

          if (line.diffQty.abs() > _qtyEps) {
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
          if (line.trackBatches && line.diffQty.abs() > _qtyEps) {
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
  // السباكة الداخلية
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

    if (diff < -_qtyEps) {
      // عجز: خصم FEFO — لا دفعة تنزل تحت الصفر، والمجموع الناقص يصفّر
      // الدفعات كلها (الباقي بلا دفعة — فيزيائياً معدوم).
      var remaining = -diff;
      for (final row in rows) {
        if (remaining <= _qtyEps) break;
        final available = (row['qty'] as num?)?.toDouble() ?? 0;
        if (available <= _qtyEps) continue;
        final take = available < remaining ? available : remaining;
        await txn.rawUpdate(
          'UPDATE batch SET qty = qty - ?, updated_at = ? '
          'WHERE id = ? AND qty >= ?',
          <Object?>[_roundQty(take), nowIso, row['id'], _roundQty(take)],
        );
        remaining = _roundQty(remaining - take);
      }
    } else if (diff > _qtyEps) {
      // زيادة: تُضاف إلى الدفعة الأبعد انتهاءً (آخر صف في ترتيب FEFO).
      final latestId = rows.last['id'] as int;
      await txn.rawUpdate(
        'UPDATE batch SET qty = qty + ?, updated_at = ? WHERE id = ?',
        <Object?>[_roundQty(diff), nowIso, latestId],
      );
    }
  }

  static String _describeDbError(DatabaseException e) {
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
