/// أنواع تقارير الحركة والمبيعات النقية (صف الحركة/بطاقة الصنف/سطر
/// الملخص/بعد التجميع/سطر المبيعات) — جزء من تقسيم R20-D3a لمستودع
/// تقارير الحركة (نمط R19-D3d): منقولة حرفياً من
/// movement_reports_repository.dart — المستودع يُصدِّرها من هنا فكل
/// استيراداته التاريخية تحل كما كانت.
library;

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
  /// (بعد الفئة) — الواجهة تعرض الترجمة المناسبة (قرار 10 برأس ملف
  /// sales_by_query.dart).
  final String label;

  /// إجمالي المبيعات بالعملة الأساسية (line_total × سعر الصرف).
  final double salesBase;

  /// عدد فواتير البيع المكتملة المميزة المساهمة في السطر.
  final int invoiceCount;

  /// نسبة التغير عن الفترة السابقة المساوية ٪ — **null عند صفر السابقة**.
  final double? changePct;
}
