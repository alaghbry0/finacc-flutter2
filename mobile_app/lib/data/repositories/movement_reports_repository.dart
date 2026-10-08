/// مستودع تقارير الحركة والمبيعات (الشريحة 10):
/// - **FR-09-03 تقرير حركة صنف**: كل حركات صنف واحد في فترة (ومخزن
///   اختياري) مع **الباقي التراكمي** — الرصيد بعد كل حركة.
/// - **FR-09-04 ملخص حركة المخزون**: تجميع لكل صنف متحرك في الفترة
///   (وارد/صادر/مرتجع/تسوية) مع الرصيد الختامي وقيمته بالتكلفة.
/// - **FR-09-06 المبيعات حسب**: العميل/الفئة/الصنف/اليوم لنفس الفترة
///   مع نسبة التغير عن **الفترة السابقة المساوية في الطول**.
///
/// ## القرارات المعمارية (موثقة):
/// 1. **حدود الفترة على مستوى اليوم**: `date(moved_at)` و`date(issued_at)`
///    `BETWEEN` شاملة الطرفين — نفس اصطلاح `profit_report_repository`
///    (لا ساعات/دقائق تُقصّ من أطراف اليوم).
/// 2. **الكمية موقّعة أصلاً في المخطط** (§5.4): البيع ومرتجع الشراء
///    والتحويل الصادر سالبة، والشراء والافتتاحي ومرتجع البيع والتحويل
///    الوارد موجبة — فالرصيد التراكمي = مجموعCumul بسيط.
/// 3. **الباقي التراكمي يُحسب في Dart تصاعدياً** (moved_at ثم id) ثم
///    **تُعرض الصفوف تنازلياً** (الأحدث أولاً) — مسؤولية الشاشة.
/// 4. **رصيد ما قبل الفترة** = SUM(qty) للحركات قبل `from` حصراً (بفلتر
///    المخزن إن وجد) — نقطة انطلاق السلسلة التراكمية.
/// 5. **ملخص المخزون — أعمدة تدفق إجمالية**: «وارد» = شراء + افتتاحي +
///    **الجزء الموجب** من تسويات الجرد؛ «صادر» = |بيع + مرتجع شراء|؛
///    «مرتجع» = مرتجع بيع (وارد)؛ «تسوية» = صافي تسوية الجرد بإشارته.
///    **الرصيد الختامي مصدر الحقيقة**: SUM لكل الحركات (أي نوع، شاملة
///    التحويلات والتسويات اليدوية) حتى `to` — لا يُشتق من الأعمدة
///    (التسوية الموجبة تظهر في «وارد» و«تسوية» معاً بقرار FR).
/// 6. `manual_adjust` بلا منتج واجهة في V1 (نفس قرار 10-b) — يدخل
///    الرصيد الختامي حصراً لا أعمدة التدفق.
/// 7. **المبيعات بالعملة الأساسية**: `line_total × exchange_rate`
///    لكل سطر (لا خلط عملات — 5.4-7)، فواتير البيع **المكتملة حصراً**
///    (المسودة والإبطال مستبعدان)، والفترة السابقة = [من − N، من − 1]
///    حيث N = طول الفترة بالأيام (متلاصقة أمام البداية).
/// 8. **نسبة التغير**: null عند صفر الفترة السابقة (لا معنى رياضياً —
///    الواجهة تعرض «جديد»).
/// 9. **بعد «اليوم»**: اليوم الحالي يقارن بنفس ترتيبه في الفترة السابقة
///    (اليوم − N) — مقارنة «مثل اليوم من الفترة السابقة».
/// 10. **التصنيف الفارغ**: مبيعات بلا عميل تُجمَّع تحت سطر «عميل نقدي»
///     (label = '')؛ الأسطر الحرة/الأصناف بلا فئة تحت «غير مصنّف»
///     (label = '') — لا تختفي المبيعات من التقرير. سطر حر (بلا صنف)
///     مستبعد من بعد «الصنف» عمداً (لا صنف يُنسب إليه — نفس قرار
///     `topItems`).
/// 11. الترتيب: «اليوم» تصاعدياً بالتاريخ؛ وغيره تنازلياً بالمبيعات
///     (كسر التعادل بالاسم تصاعدياً) بحد 50 صفاً.
library;

import 'package:sqflite/sqflite.dart';

/// صف حركة واحد داخل بطاقة الصنف — الرصيد التراكمي محسوب مسبقاً.
class ItemMovementRow {
  const ItemMovementRow({
    required this.movedAt,
    required this.movementType,
    required this.qty,
    required this.unitCost,
    required this.refType,
    required this.refId,
    required this.notes,
    required this.balanceAfter,
  });

  /// لحظة الحركة (UTC — `moved_at`).
  final DateTime movedAt;

  /// نوع الحركة كما في المخطط: purchase/sale/sale_return/purchase_return/
  /// stocktake_adjust/manual_adjust/transfer_in/transfer_out/opening.
  final String movementType;

  /// الكمية **موقّعة** (موجبة وارد / سالبة صادر — المخطط §5.4).
  final double qty;

  /// تكلفة الوحدة لحظة الحركة (WAC وقت الترحيل).
  final double unitCost;

  /// نوع المرجع (invoice/stocktake/…).
  final String? refType;

  /// معرّف المرجع.
  final int? refId;

  /// ملاحظات الحركة (رقم الفاتورة/الدفعة غالباً).
  final String? notes;

  /// **الباقي التراكمي** بعد هذه الحركة (من رصيد ما قبل الفترة).
  final double balanceAfter;
}

/// بطاقة حركة صنف كاملة (FR-09-03).
class ItemMovementReport {
  const ItemMovementReport({
    required this.productId,
    required this.name,
    required this.unitCostNow,
    required this.openingBalance,
    required this.from,
    required this.to,
    required this.rows,
  });

  /// معرّف الصنف.
  final int productId;

  /// اسم الصنف (من جدول product).
  final String name;

  /// التكلفة الحالية للوحدة (WAC — `product.cost_price` الآن).
  final double unitCostNow;

  /// **رصيد ما قبل الفترة** (مجموع الكميات قبل `from` — لعرض سطر
  /// الافتتاح وبداية السلسلة التراكمية).
  final double openingBalance;

  final DateTime from;
  final DateTime to;

  /// حركات الفترة **تصاعدياً** (moved_at ثم id) — الشاشة تعرضها
  /// تنازلياً (الأحدث أولاً).
  final List<ItemMovementRow> rows;

  /// إجمالي الوارد في الفترة (مجموع الكميات الموجبة).
  double get totalIn {
    var sum = 0.0;
    for (final row in rows) {
      if (row.qty > 0) sum += row.qty;
    }
    return sum;
  }

  /// إجمالي الصادر في الفترة (مجموع الكميات السالبة بمقدارها).
  double get totalOut {
    var sum = 0.0;
    for (final row in rows) {
      if (row.qty < 0) sum -= row.qty;
    }
    return sum;
  }
}

/// سطر ملخص حركة صنف واحد في الفترة (FR-09-04).
class StockSummaryRow {
  const StockSummaryRow({
    required this.productId,
    required this.name,
    required this.qtyIn,
    required this.qtyOut,
    required this.qtyReturns,
    required this.qtyAdjustNet,
    required this.endBalance,
    required this.valueAtCost,
  });

  final int productId;

  /// اسم الصنف.
  final String name;

  /// وارد الفترة: شراء + افتتاحي + الجزء الموجب من تسويات الجرد.
  final double qtyIn;

  /// صادر الفترة: |بيع + مرتجع شراء| (مقدار موجب).
  final double qtyOut;

  /// مرتجع البيع الوارد في الفترة.
  final double qtyReturns;

  /// صافي تسويات الجرد بإشارته (زيادة − عجز).
  final double qtyAdjustNet;

  /// **الرصيد الختامي** حتى نهاية الفترة (SUM كل الحركات أي نوع).
  final double endBalance;

  /// قيمة الرصيد بالتكلفة ≈ endBalance × product.cost_price (الحالي).
  final double valueAtCost;
}

/// بعد تجميع المبيعات (FR-09-06).
enum SalesByDimension { customer, category, item, day }

/// سطر مبيعات واحد حسب البعد المختار.
class SalesByRow {
  const SalesByRow({
    required this.label,
    required this.salesBase,
    required this.invoiceCount,
    this.changePct,
  });

  /// التسمية: اسم العميل/الفئة/الصنف، أو التاريخ `YYYY-MM-DD` بعد
  /// «اليوم». **سلسلة فارغة** = عميل نقدي (بعد العميل) أو غير مصنّف
  /// (بعد الفئة) — الواجهة تعرض الترجمة المناسبة (قرار 10 برأس الملف).
  final String label;

  /// إجمالي المبيعات بالعملة الأساسية (line_total × سعر الصرف).
  final double salesBase;

  /// عدد فواتير البيع المكتملة المميزة المساهمة في السطر.
  final int invoiceCount;

  /// نسبة التغير عن الفترة السابقة المساوية ٪ — **null عند صفر السابقة**.
  final double? changePct;
}

/// مستودع تقارير الحركة والمبيعات — قراءة صرفة فوق
/// `stock_movement` × `product` و`invoice` × `invoice_item`.
class MovementReportsRepository {
  MovementReportsRepository(this._db);

  final Database _db;

  // ─────────────────────────────────────────────────────────────────────
  // FR-09-03 — بطاقة حركة صنف
  // ─────────────────────────────────────────────────────────────────────

  /// بطاقة حركة صنف [productId] في الفترة [from]..[to] (شاملة الطرفين
  /// على مستوى اليوم) — [warehouseId] اختياري (null = كل المخازن).
  ///
  /// يرمي [StateError] إن كان الصنف غير موجود (محذوف/معرّف غريب).
  Future<ItemMovementReport> itemMovement({
    required int productId,
    required DateTime from,
    required DateTime to,
    int? warehouseId,
  }) async {
    final fromDay = _dateOnly(from);
    final toDay = _dateOnly(to);

    // (أ) الصنف: الاسم والتكلفة الحالية (WAC) — أو خطأ إن غاب.
    final productRows = await _db.rawQuery(
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
    final openingRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(qty), 0) AS opening FROM stock_movement '
      'WHERE product_id = ? AND date(moved_at) < ?'
      '${warehouseId != null ? ' AND warehouse_id = ?' : ''}',
      <Object?>[productId, fromDay, ?warehouseId],
    );
    final opening = (openingRows.first['opening'] as num?)?.toDouble() ?? 0;

    // (ج) حركات الفترة تصاعدياً (moved_at ثم id) — الترتيب الذي يُحسب
    // عليه الرصيد التراكمي (العرض التنازلي مسؤولية الشاشة).
    final movementRows = await _db.rawQuery(
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

  // ─────────────────────────────────────────────────────────────────────
  // FR-09-04 — ملخص حركة المخزون
  // ─────────────────────────────────────────────────────────────────────

  /// ملخص الحركة لكل صنف **تحرّك** في الفترة [from]..[to] (شاملة
  /// الطرفين)، مرتّباً بقيمة المخزون تنازلياً — [warehouseId] اختياري.
  ///
  /// الأصناف الساكنة (بلا حركة في الفترة) غير مشمولة عمداً (FR: ملخص
  /// الحركة). الرصيد الختامي يقرأ كل الحركات حتى `to` (قرار 5).
  Future<List<StockSummaryRow>> stockSummary({
    required DateTime from,
    required DateTime to,
    int? warehouseId,
  }) async {
    final fromDay = _dateOnly(from);
    final toDay = _dateOnly(to);
    final warehouseClause = warehouseId != null
        ? ' AND sm.warehouse_id = ?'
        : '';

    // (أ) أعمدة التدفق لكل صنف متحرك في الفترة (GROUP BY واحد).
    final flowRows = await _db.rawQuery(
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
    final balanceRows = await _db.rawQuery(
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

  // ─────────────────────────────────────────────────────────────────────
  // FR-09-06 — المبيعات حسب
  // ─────────────────────────────────────────────────────────────────────

  /// تجميع المبيعات حسب [dimension] للفترة [from]..[to] (شاملة الطرفين)
  /// بالعملة الأساسية، مع نسبة التغير عن الفترة السابقة المساوية في
  /// الطول (قرار 7 برأس الملف).
  Future<List<SalesByRow>> salesBy({
    required SalesByDimension dimension,
    required DateTime from,
    required DateTime to,
  }) async {
    final fromDay = _dateOnly(from);
    final toDay = _dateOnly(to);

    // الفترة السابقة: [من − N، من − 1] — متلاصقة أمام البداية (قرار 7).
    final lengthDays =
        DateTime(
          to.year,
          to.month,
          to.day,
        ).difference(DateTime(from.year, from.month, from.day)).inDays +
        1;
    final prevFrom = DateTime(
      from.year,
      from.month,
      from.day,
    ).subtract(Duration(days: lengthDays));
    final prevTo = DateTime(
      from.year,
      from.month,
      from.day,
    ).subtract(const Duration(days: 1));
    final prevFromDay = _dateOnly(prevFrom);
    final prevToDay = _dateOnly(prevTo);

    // (أ) تجميع الفترة الحالية.
    final currentRows = await _salesAggregate(dimension, fromDay, toDay);
    // (ب) تجميع الفترة السابقة (لا ترتيب/حد — خريطة بحث فقط).
    final previousRows = await _salesAggregate(
      dimension,
      prevFromDay,
      prevToDay,
    );

    // بعد «اليوم» يقارن كل يوم بنظيره بالإزاحة نفسها (قرار 9):
    // اليوم d ↔ اليوم d − N — فخريطة السابقة بمفاتيحها الخام، والبحث
    // بمفتاح اليوم الحالي بعد إزاحته للخلف N يوماً (identity للأبعاد
    // الأخرى: الكيان نفسه).
    String previousKeyOf(String label) {
      if (dimension != SalesByDimension.day) return label;
      final day = DateTime.tryParse(label);
      if (day == null) return label;
      return _dateOnly(day.subtract(Duration(days: lengthDays)));
    }

    final previousByLabel = <String, double>{
      for (final row in previousRows)
        (row['label'] as String? ?? ''):
            (row['salesBase'] as num?)?.toDouble() ?? 0,
    };

    final rows = <SalesByRow>[];
    for (final row in currentRows) {
      final label = (row['label'] as String?) ?? '';
      final salesBase = (row['salesBase'] as num?)?.toDouble() ?? 0;
      final previous = previousByLabel[previousKeyOf(label)] ?? 0;
      rows.add(
        SalesByRow(
          label: label,
          salesBase: salesBase,
          invoiceCount: row['invoiceCount'] as int? ?? 0,
          changePct: previous == 0
              ? null
              : (salesBase - previous) / previous * 100,
        ),
      );
    }

    // (ج) الترتيب (قرار 11): «اليوم» تصاعدياً؛ وغيره بالمبيعات
    // تنازلياً (كسر التعادل بالاسم) بحد 50.
    if (dimension == SalesByDimension.day) {
      rows.sort((a, b) => a.label.compareTo(b.label));
    } else {
      rows.sort((a, b) {
        if (a.salesBase != b.salesBase) {
          return b.salesBase.compareTo(a.salesBase);
        }
        return a.label.compareTo(b.label);
      });
      if (rows.length > 50) rows.removeRange(50, rows.length);
    }

    return rows;
  }

  /// تجميع واحد لمبيعات الفترة حسب البعد — فواتير البيع المكتملة حصراً،
  /// المبالغ بالأساس (`line_total × exchange_rate`)، وعدد الفواتير
  /// **المميزة** (COUNT DISTINCT — السطور المتعددة لفاتورة واحدة لا
  /// تضاعف العدد).
  Future<List<Map<String, Object?>>> _salesAggregate(
    SalesByDimension dimension,
    String fromDay,
    String toDay,
  ) async {
    // التجميع والتسمية حسب البعد (قرار 10): LEFT JOIN للعميل/الفئة —
    // الفارغ يُجمَّع في سطر واحد (label = '').
    final (groupExpr, joins) = switch (dimension) {
      SalesByDimension.customer => (
        'c.id',
        'LEFT JOIN customer c ON c.id = i.customer_id',
      ),
      SalesByDimension.category => (
        'cat.id',
        'LEFT JOIN product p ON p.id = ii.product_id '
            'LEFT JOIN category cat ON cat.id = p.category_id',
      ),
      SalesByDimension.item => (
        'p.id',
        'JOIN product p ON p.id = ii.product_id',
      ),
      SalesByDimension.day => ('date(i.issued_at)', ''),
    };
    final labelExpr = switch (dimension) {
      // العميل/الفئة قد يكونان NULL → COALESCE إلى '' (القرار 10).
      SalesByDimension.customer => "COALESCE(c.name, '')",
      SalesByDimension.category => "COALESCE(cat.name, '')",
      SalesByDimension.item => "COALESCE(p.name, '')",
      SalesByDimension.day => 'date(i.issued_at)',
    };

    return _db.rawQuery(
      '''
      SELECT $labelExpr AS label,
             COALESCE(SUM(ii.line_total * i.exchange_rate), 0) AS salesBase,
             COUNT(DISTINCT i.id) AS invoiceCount
      FROM invoice_item ii
      JOIN invoice i ON i.id = ii.invoice_id
      $joins
      WHERE i.doc_type = 'sale' AND i.status = 'completed'
        AND date(i.issued_at) >= ? AND date(i.issued_at) <= ?
      GROUP BY $groupExpr
      ''',
      <Object?>[fromDay, toDay],
    );
  }

  /// `YYYY-MM-DD` ليوم التقويم (نفس مساعد `dashboard_repository`).
  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
