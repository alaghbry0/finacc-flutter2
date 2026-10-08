/// مستودع تقرير الأرباح والخسائر — FR-09-02 (الشريحة 10) عبر **خريطة
/// الترحيل (ملحق و)** حصراً: كل سطر في التقرير مشتق من صف واحد من
/// صفوف الخريطة عبر استعلام SQL موثَّق أدناه — لا تجميع مخصص خارج
/// الخريطة إطلاقاً (قيد SRS الملزم).
///
/// ## الصيغة الملزمة (حرفياً من SRS — FR-09-02):
/// `الربح = (المبيعات − مرتجع المبيعات) − (COGS − تكلفة المرتجع)
/// + زيادات الجرد − عجز الجرد − المصاريف ± فروق الصرف المحققة`
/// - **مسحوبات المالك = بند مستقل خارج المصاريف** (لا تدخل في الربح).
/// - سطر الإغلاق: «صافي ما بقي للمالك = الربح − المسحوبات».
///
/// ## مصدر كل سطر (خريطة الترحيل — ملحق و):
/// 1. **المبيعات (+)** — صف «فاتورة بيع مكتملة»:
///    `SELECT SUM(total_base) FROM invoice WHERE doc_type='sale'
///    AND status='completed' AND date(issued_at) BETWEEN ? AND ?`
///    (المسودة والمُبطلة مستبعدتان — آلة الحالات 5.4-2).
/// 2. **مرتجع المبيعات (−)** — نفس الاستعلام بـ `doc_type='sale_return'`.
/// 3. **COGS (+)** — `SUM(cost_total)` لفواتير البيع المكتملة:
///    `cost_total` بالعملة الأساسية أصلاً (line_cost = qty ×
///    product.cost_price بـ WAC لحظة البيع — sale_repository 8-ج/8-د).
/// 4. **تكلفة المرتجع (تُخصم من COGS)** — `SUM(cost_total)`
///    لـ `doc_type='sale_return'` المكتملة.
/// 5. **زيادات الجرد (+)** — صف «تسوية جرد» الموجبة:
///    `SELECT SUM(qty * unit_cost) FROM stock_movement WHERE
///    movement_type='stocktake_adjust' AND qty > 0 AND
///    date(moved_at) BETWEEN ? AND ?` (unit_cost بالعملة الأساسية).
/// 6. **عجز الجرد (−)** — نفسه بـ `qty < 0` ويُعرض بمقداره الموجب.
/// 7. **المصاريف (−)** — صف «مصروف نقدي»:
///    `SELECT SUM(amount * exchange_rate) FROM cash_tx WHERE
///    tx_type='expense' AND is_voided = 0 AND reversal_of IS NULL AND
///    date(tx_date) BETWEEN ? AND ?` (يشمل مصاريف فئة الرواتب — بديل
///    وحدة الموظفين المؤجلة V1). القيمة دائماً بالأساس (5.4-7).
/// 8. **فروق الصرف (±)** — `SELECT SUM(fx_gain_loss) FROM cash_tx WHERE
///    is_voided = 0 AND reversal_of IS NULL AND fx_gain_loss IS NOT NULL
///    AND date(tx_date) BETWEEN ? AND ?` (تسويات الديون بعملة مخالفة +
///    تحويلات الصناديق — ساقاها متعادلتان فيبقى أثرها هنا حصراً).
/// 9. **مسحوبات المالك (بند مستقل)** — نفس استبعادات المصاريف بـ
///    `tx_type='owner_draw'`: `SUM(amount * exchange_rate)`.
///
/// ## قرارات موثقة:
/// - كل المبالغ **بالعملة الأساسية** (`total_base` / `cost_total` /
///   `amount × exchange_rate`) — لا خلط عملات في رقم واحد (5.4-7).
/// - الفترة `[from, to]` **شاملة الطرفين بالتاريخ** (`date(x) BETWEEN`).
/// - حركات `manual_adjust` **لا منتج لها في V1** (لا مسار واجهة يكتبها)
///   وخريطة الترحيل لا ترحّل سوى `stocktake_adjust` للجرد → مستبعدة من
///   سطري الزيادة/العجز عمداً.
/// - الإبطال والمعاكسة في cash_tx (`is_voided=1` / `reversal_of` غير
///   فارغ) مستبعدان دائماً — إشارات ملحق و نفسها.
library;

import 'package:sqflite/sqflite.dart';

/// تقرير الأرباح والخسائر لفترة `[from, to]` — كل المبالغ بالعملة
/// الأساسية (انظر رأس الملف لمصدر كل سطر من خريطة الترحيل).
class ProfitReport {
  const ProfitReport({
    required this.from,
    required this.to,
    required this.sales,
    required this.salesReturns,
    required this.cogs,
    required this.returnCost,
    required this.stockSurplus,
    required this.stockShortage,
    required this.expenses,
    required this.fxGainLoss,
    required this.ownerDrawings,
    required this.salesInvoiceCount,
    required this.returnInvoiceCount,
  });

  /// بداية الفترة (شاملة).
  final DateTime from;

  /// نهاية الفترة (شاملة).
  final DateTime to;

  /// Σ total_base لفواتير البيع المكتملة (سطر 1 من الخريطة).
  final double sales;

  /// Σ total_base لمرتجعات البيع المكتملة (سطر 2).
  final double salesReturns;

  /// Σ cost_total لفواتير البيع المكتملة (سطر 3 — بالأساس).
  final double cogs;

  /// Σ cost_total لمرتجعات البيع المكتملة (سطر 4).
  final double returnCost;

  /// Σ (qty × unit_cost) لتسويات الجرد الموجبة (سطر 5).
  final double stockSurplus;

  /// مقدار عجز الجرد — موجب دائماً (سطر 6).
  final double stockShortage;

  /// Σ (amount × exchange_rate) للمصاريف الحية (سطر 7 — موجب).
  final double expenses;

  /// Σ fx_gain_loss المحققة (سطر 8 — موجب ربح/سالب خسارة).
  final double fxGainLoss;

  /// Σ (amount × exchange_rate) لمسحوبات المالك الحية (سطر 9 — موجب).
  final double ownerDrawings;

  /// عدد فواتير البيع المكتملة في الفترة (للعرض).
  final int salesInvoiceCount;

  /// عدد مرتجعات البيع المكتملة في الفترة (للعرض).
  final int returnInvoiceCount;

  /// إجمالي فواتير الفترة (بيع + مرتجع) — واجهة العرض الموحّدة.
  int get invoiceCount => salesInvoiceCount + returnInvoiceCount;

  /// تقرير صفري لفترة — لا أي حركة (الحالة الفارغة الاحتفالية).
  factory ProfitReport.zero({required DateTime from, required DateTime to}) {
    return ProfitReport(
      from: from,
      to: to,
      sales: 0,
      salesReturns: 0,
      cogs: 0,
      returnCost: 0,
      stockSurplus: 0,
      stockShortage: 0,
      expenses: 0,
      fxGainLoss: 0,
      ownerDrawings: 0,
      salesInvoiceCount: 0,
      returnInvoiceCount: 0,
    );
  }

  /// صافي المبيعات = المبيعات − مرتجع المبيعات.
  double get netSales => sales - salesReturns;

  /// صافي التكلفة = COGS − تكلفة المرتجع.
  double get netCogs => cogs - returnCost;

  /// **الصيغة الملزمة** (FR-09-02 — انظر رأس الملف):
  /// (المبيعات − المرتجع) − (COGS − تكلفة المرتجع) + زيادات الجرد −
  /// عجز الجرد − المصاريف ± فروق الصرف.
  double get profit =>
      netSales - netCogs + stockSurplus - stockShortage - expenses + fxGainLoss;

  /// سطر الإغلاق: صافي ما بقي للمالك = الربح − المسحوبات.
  double get netForOwner => profit - ownerDrawings;

  /// هل في الفترة أي حركة تُذكر؟ (false → الحالة الفارغة الاحتفالية).
  bool get hasAnyActivity =>
      sales != 0 ||
      salesReturns != 0 ||
      cogs != 0 ||
      returnCost != 0 ||
      stockSurplus != 0 ||
      stockShortage != 0 ||
      expenses != 0 ||
      fxGainLoss != 0 ||
      ownerDrawings != 0 ||
      salesInvoiceCount != 0 ||
      returnInvoiceCount != 0;
}

/// مستودع تقرير الأرباح والخسائر — قراءة صرفة فوق خريطة الترحيل.
class ProfitReportRepository {
  ProfitReportRepository(this._db);

  final Database _db;

  /// يبني تقرير الفترة `[from, to]` (شاملة الطرفين بالتاريخ) — سطراً
  /// سطراً من خريطة الترحيل (مصدر كل استعلام موثَّق برأس الملف).
  Future<ProfitReport> report({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromDay = _dateOnly(from);
    final toDay = _dateOnly(to);

    // ── سطرا 1+3: فواتير البيع المكتملة (المبيعات + COGS + العدد) ──
    final saleRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(total_base), 0) AS total, '
      'COALESCE(SUM(cost_total), 0) AS cost, COUNT(*) AS n '
      'FROM invoice '
      "WHERE doc_type = 'sale' AND status = 'completed' "
      'AND date(issued_at) BETWEEN ? AND ?',
      [fromDay, toDay],
    );

    // ── سطرا 2+4: مرتجعات البيع المكتملة (المرتجع + تكلفته + العدد) ──
    final returnRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(total_base), 0) AS total, '
      'COALESCE(SUM(cost_total), 0) AS cost, COUNT(*) AS n '
      'FROM invoice '
      "WHERE doc_type = 'sale_return' AND status = 'completed' "
      'AND date(issued_at) BETWEEN ? AND ?',
      [fromDay, toDay],
    );

    // ── سطر 5: زيادات الجرد (تسويات الجرد الموجبة) ──
    final surplusRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(qty * unit_cost), 0) AS v FROM stock_movement '
      "WHERE movement_type = 'stocktake_adjust' AND qty > 0 "
      'AND date(moved_at) BETWEEN ? AND ?',
      [fromDay, toDay],
    );

    // ── سطر 6: عجز الجرد (تسويات الجرد السالبة — بمقدارها الموجب) ──
    final shortageRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(qty * unit_cost), 0) AS v FROM stock_movement '
      "WHERE movement_type = 'stocktake_adjust' AND qty < 0 "
      'AND date(moved_at) BETWEEN ? AND ?',
      [fromDay, toDay],
    );

    // ── سطر 7: المصاريف (شاملة فئة الرواتب — بديل V1) ──
    final expenseRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount * exchange_rate), 0) AS v FROM cash_tx '
      "WHERE tx_type = 'expense' AND is_voided = 0 AND reversal_of IS NULL "
      'AND date(tx_date) BETWEEN ? AND ?',
      [fromDay, toDay],
    );

    // ── سطر 8: فروق الصرف المحققة (تسويات + تحويلات) ──
    final fxRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(fx_gain_loss), 0) AS v FROM cash_tx '
      'WHERE is_voided = 0 AND reversal_of IS NULL '
      'AND fx_gain_loss IS NOT NULL '
      'AND date(tx_date) BETWEEN ? AND ?',
      [fromDay, toDay],
    );

    // ── سطر 9: مسحوبات المالك (بند مستقل خارج المصاريف) ──
    final drawRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount * exchange_rate), 0) AS v FROM cash_tx '
      "WHERE tx_type = 'owner_draw' AND is_voided = 0 AND reversal_of IS NULL "
      'AND date(tx_date) BETWEEN ? AND ?',
      [fromDay, toDay],
    );

    return ProfitReport(
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      sales: (saleRows.first['total'] as num?)?.toDouble() ?? 0,
      salesReturns: (returnRows.first['total'] as num?)?.toDouble() ?? 0,
      cogs: (saleRows.first['cost'] as num?)?.toDouble() ?? 0,
      returnCost: (returnRows.first['cost'] as num?)?.toDouble() ?? 0,
      stockSurplus: (surplusRows.first['v'] as num?)?.toDouble() ?? 0,
      // qty سالب × تكلفة = سالب → نعرض مقدار العجز موجباً.
      stockShortage: ((shortageRows.first['v'] as num?)?.toDouble() ?? 0).abs(),
      expenses: (expenseRows.first['v'] as num?)?.toDouble() ?? 0,
      fxGainLoss: (fxRows.first['v'] as num?)?.toDouble() ?? 0,
      ownerDrawings: (drawRows.first['v'] as num?)?.toDouble() ?? 0,
      salesInvoiceCount: saleRows.first['n'] as int? ?? 0,
      returnInvoiceCount: returnRows.first['n'] as int? ?? 0,
    );
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
