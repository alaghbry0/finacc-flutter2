/// مستودع لوحة التحكم — تجميعات SQL أوفلاين لبطاقات الداشبورد (FR-09-01).
///
/// المرحلة 1 تؤسس السباكة الكاملة بالقاعدة الحقيقية؛ الأرقام صفرية حتى
/// تشغيل شرائح البيع/الشراء، وتتحقق لحظياً بعدها دون تعديل هنا.
///
/// ملاحظة تجميع «صافي الصندوق» (مبدئية — تُكمل بجدول الترحيل الكامل في
/// شريحة النقدية 6): الوارد (+) = receipt, capital_in؛ الصادر (−) =
/// payment, expense, owner_draw؛ التحويلات والعمليات البنكية والتزامات
/// V1.1/V2 مستثناة حتى اكتمال خريطة الترحيل (ملحق و).
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
      "SELECT COALESCE("
      " (SELECT SUM(amount) FROM cash_tx "
      "   WHERE tx_type IN ('receipt','capital_in') "
      "   AND is_voided = 0 AND date(tx_date) = ?), 0) "
      " - COALESCE("
      " (SELECT SUM(amount) FROM cash_tx "
      "   WHERE tx_type IN ('payment','expense','owner_draw') "
      "   AND is_voided = 0 AND date(tx_date) = ?), 0) "
      "AS net",
      [today, today],
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

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
