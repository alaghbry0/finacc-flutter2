/// مستودع لوحة التحكم — تجميعات SQL أوفلاين لبطاقات الداشبورد (FR-09-01).
///
/// «صافي الصندوق» اليوم يعمل الآن **بخريطة الترحيل الكاملة (ملحق و)**
/// منذ الشريحة 6: الوارد (+) = receipt/capital_in/opening؛ الصادر (−) =
/// payment/expense/owner_draw؛ التحويلات والعمليات البنكية **متعادلة
/// في القيمة الأساس** (ساقان: مصدر − وهدف +) ويظهر فرقها في
/// `fx_gain_loss` فقط؛ الحركات الملغاة (`is_voided`) **والمعاكسة**
/// (`reversal_of`) مستبعدتان دائماً. كل شيء **بالقيمة الأساسية**
/// (`amount × exchange_rate`) — لا خلط عملات في رقم واحد (5.4-7).
///
/// إكمال الشريحة 9 (17-c): مبيعات الشهر مقارنة بالشهر السابق (FR-09-01
/// «مقارنة بالفترة السابقة ٪») + أعلى الأصناف مبيعاً للشهر الجاري
/// (تجميع كميات بنود فواتير البيع المكتملة).
library;

import 'package:sqflite/sqflite.dart';

/// إحصاءات اليوم الواحد.
class DashboardTodayStats {
  const DashboardTodayStats({
    required this.sales,
    required this.profit,
    required this.invoiceCount,
    required this.netCash,
  });

  /// مبيعات اليوم (بالعملة الأساسية — total_base).
  final double sales;

  /// أرباح اليوم (مبيعات − تكلفة البنود للفواتير المكتملة اليوم).
  final double profit;

  /// عدد فواتير اليوم (بيع/شراء/مرتجعات مكتملة).
  final int invoiceCount;

  /// صافي حركة الصندوق اليوم.
  final double netCash;
}

/// نقطة سلسلة 30 يوماً للمبيعات.
class DailySalesPoint {
  const DailySalesPoint({required this.date, required this.total});

  /// اليوم (YYYY-MM-DD).
  final String date;

  /// إجمالي مبيعات اليوم بالعملة الأساسية.
  final double total;
}

/// إحصاءات الشهر مقارنة بالشهر التقويمي السابق (FR-09-01).
class MonthSalesStats {
  const MonthSalesStats({
    required this.thisMonthSales,
    required this.previousMonthSales,
    required this.invoiceCountThisMonth,
  });

  /// مبيعات الشهر الجاري بالعملة الأساسية (total_base).
  final double thisMonthSales;

  /// مبيعات الشهر التقويمي السابق بالعملة الأساسية.
  final double previousMonthSales;

  /// عدد فواتير البيع المكتملة هذا الشهر.
  final int invoiceCountThisMonth;

  /// نسبة التغير عن الشهر السابق (٪) — **null عند صفر الشهر السابق**
  /// (لا معنى رياضياً للنسبة؛ الواجهة تعرض «جديد» بدلها).
  double? get changePct {
    if (previousMonthSales == 0) return null;
    return (thisMonthSales - previousMonthSales) / previousMonthSales * 100;
  }
}

/// صنف من قائمة أعلى الأصناف مبيعاً (FR-09-01).
class TopItemStat {
  const TopItemStat({
    required this.productId,
    required this.name,
    required this.qtySold,
    required this.revenueBase,
  });

  final int productId;

  /// اسم الصنف من جدول product.
  final String name;

  /// إجمالي الكمية المبيعة في الفترة (بصنف الوحدة).
  final double qtySold;

  /// إجمالي الإيراد بالعملة الأساسية (line_total × سعر الصرف).
  final double revenueBase;
}

class DashboardRepository {
  DashboardRepository(this._db);

  final Database _db;

  /// إحصاءات اليوم (وقت الجهاز المحلي — يوم العمل).
  Future<DashboardTodayStats> todayStats(DateTime now) async {
    final today = _dateOnly(now);
    final salesRows = await _db.rawQuery(
      "SELECT COALESCE(SUM(total_base), 0) AS s, "
      "COALESCE(SUM(cost_total), 0) AS c, COUNT(*) AS n "
      "FROM invoice "
      "WHERE doc_type = 'sale' AND status = 'completed' "
      "AND date(issued_at) = ?",
      [today],
    );
    final cashRows = await _db.rawQuery(
      // ملحق و — القيمة الأساسية لكل ساق؛ الساقان متعادلتان للتحويلات
      // فيبقى أثرها fx_gain_loss حصراً (انظر رأس الملف).
      "SELECT COALESCE("
      " (SELECT SUM(amount * exchange_rate) FROM cash_tx "
      "   WHERE tx_type IN ('receipt','capital_in','opening') "
      "   AND is_voided = 0 AND reversal_of IS NULL "
      "   AND date(tx_date) = ?), 0) "
      " - COALESCE("
      " (SELECT SUM(amount * exchange_rate) FROM cash_tx "
      "   WHERE tx_type IN ('payment','expense','owner_draw') "
      "   AND is_voided = 0 AND reversal_of IS NULL "
      "   AND date(tx_date) = ?), 0) "
      " + COALESCE("
      " (SELECT SUM(fx_gain_loss) FROM cash_tx "
      "   WHERE tx_type IN ('box_transfer','bank_deposit','bank_withdraw') "
      "   AND is_voided = 0 AND reversal_of IS NULL "
      "   AND date(tx_date) = ?), 0) "
      "AS net",
      [today, today, today],
    );
    final sales = (salesRows.first['s'] as num?)?.toDouble() ?? 0;
    final cost = (salesRows.first['c'] as num?)?.toDouble() ?? 0;
    return DashboardTodayStats(
      sales: sales,
      profit: sales - cost,
      invoiceCount: (salesRows.first['n'] as int? ?? 0),
      netCash: (cashRows.first['net'] as num?)?.toDouble() ?? 0,
    );
  }

  /// سلسلة آخر 30 يوماً (أيام بلا مبيعات = 0 — لرسم الداشبورد).
  Future<List<DailySalesPoint>> last30DaysSales(DateTime now) async {
    final rows = await _db.rawQuery(
      "SELECT date(issued_at) AS d, SUM(total_base) AS t "
      "FROM invoice "
      "WHERE doc_type = 'sale' AND status = 'completed' "
      "AND date(issued_at) >= date(?, '-29 days') "
      "GROUP BY date(issued_at)",
      [_dateOnly(now)],
    );
    final byDate = <String, double>{
      for (final row in rows)
        row['d'] as String: (row['t'] as num?)?.toDouble() ?? 0,
    };
    return List<DailySalesPoint>.generate(30, (index) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 29 - index));
      final key = _dateOnly(day);
      return DailySalesPoint(date: key, total: byDate[key] ?? 0);
    });
  }

  /// عدد تنبيهات المخزون (أصناف تحت الحد الأدنى — FR-09-12 مبسطة للعداد).
  Future<int> lowStockCount() async {
    final rows = await _db.rawQuery(
      "SELECT COUNT(*) AS n FROM stock_level sl "
      "JOIN product p ON p.id = sl.product_id "
      "WHERE p.is_archived = 0 AND p.is_service = 0 "
      "AND p.min_stock > 0 AND sl.qty <= p.min_stock",
    );
    return rows.first['n'] as int? ?? 0;
  }

  /// مبيعات الشهر الجاري مقابل الشهر التقويمي السابق (FR-09-01)
  /// — فواتير البيع **المكتملة حصراً** (المسودة والإبطال مستبعدان)،
  /// الشهر على `issued_at` بصيغة YYYY-MM التقويمية.
  Future<MonthSalesStats> monthStats(DateTime now) async {
    final thisMonth = _monthOnly(now);
    final previous = DateTime(now.year, now.month - 1);
    final previousMonth = _monthOnly(previous);
    final rows = await _db.rawQuery(
      "SELECT strftime('%Y-%m', issued_at) AS m, "
      "COALESCE(SUM(total_base), 0) AS s, COUNT(*) AS n "
      "FROM invoice "
      "WHERE doc_type = 'sale' AND status = 'completed' "
      "AND strftime('%Y-%m', issued_at) IN (?, ?) "
      "GROUP BY strftime('%Y-%m', issued_at)",
      [thisMonth, previousMonth],
    );
    var thisSales = 0.0;
    var previousSales = 0.0;
    var invoiceCount = 0;
    for (final row in rows) {
      final total = (row['s'] as num?)?.toDouble() ?? 0;
      if (row['m'] == thisMonth) {
        thisSales = total;
        invoiceCount = row['n'] as int? ?? 0;
      } else if (row['m'] == previousMonth) {
        previousSales = total;
      }
    }
    return MonthSalesStats(
      thisMonthSales: thisSales,
      previousMonthSales: previousSales,
      invoiceCountThisMonth: invoiceCount,
    );
  }

  /// أعلى الأصناف مبيعاً بالكمية في فترة (FR-09-01) — فواتير البيع
  /// **المكتملة حصراً**؛ الافتراضي الشهر الجاري. الأسطر الحرة/الخدمية
  /// (`product_id IS NULL`) **مستبعدة عمداً** — لا صنف تُنسب إليه.
  /// الإيراد بالقيمة الأساسية (`line_total × exchange_rate`).
  Future<List<TopItemStat>> topItems({
    DateTime? from,
    DateTime? to,
    int limit = 5,
  }) async {
    final now = DateTime.now();
    final effectiveFrom = from ?? DateTime(now.year, now.month);
    final effectiveTo = to ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final rows = await _db.rawQuery(
      "SELECT ii.product_id AS productId, p.name AS name, "
      "SUM(ii.qty) AS qtySold, "
      "SUM(ii.line_total * i.exchange_rate) AS revenueBase "
      "FROM invoice_item ii "
      "JOIN invoice i ON i.id = ii.invoice_id "
      "JOIN product p ON p.id = ii.product_id "
      "WHERE i.doc_type = 'sale' AND i.status = 'completed' "
      "AND ii.product_id IS NOT NULL "
      "AND date(i.issued_at) >= ? AND date(i.issued_at) <= ? "
      "GROUP BY ii.product_id "
      "ORDER BY qtySold DESC, revenueBase DESC "
      "LIMIT ?",
      [_dateOnly(effectiveFrom), _dateOnly(effectiveTo), limit],
    );
    return [
      for (final row in rows)
        TopItemStat(
          productId: row['productId'] as int,
          name: (row['name'] as String?) ?? '',
          qtySold: (row['qtySold'] as num?)?.toDouble() ?? 0,
          revenueBase: (row['revenueBase'] as num?)?.toDouble() ?? 0,
        ),
    ];
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _monthOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}';
}
