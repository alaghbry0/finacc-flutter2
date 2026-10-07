/// نماذج الدفعات وتواريخ الصلاحية — جدول `batch` (§5.3) — المرحلة 2.
///
/// الدفعات جوهر قاعدة FEFO (FR-01-10 / AC-05): الاستهلاك دائماً من
/// الدفعة الأقرب انتهاءً، والمنع القطعي للبيع من دفعة منتهية الصلاحية.
library;

/// دفعة نشطة لصنف — صف من `batch` مع أيام الصلاحية المحسوبة.
class BatchInfo {
  const BatchInfo({
    required this.id,
    required this.productId,
    required this.warehouseId,
    required this.batchNumber,
    required this.expiryDate,
    required this.costPrice,
    required this.qty,
    required this.daysToExpiry,
  });

  /// المعرّف في جدول `batch`.
  final int id;

  final int productId;

  final int warehouseId;

  /// رقم الدفعة كما ورد من المورد.
  final String batchNumber;

  /// تاريخ انتهاء الصلاحية (تاريخ فقط — `YYYY-MM-DD` كما في القاعدة).
  final DateTime expiryDate;

  /// تكلفة وحدة الدفعة (تكلفة الشراء).
  final double costPrice;

  /// الكمية المتبقية في الدفعة.
  final double qty;

  /// الأيام حتى انتهاء الصلاحية (سالب = منتهية — محسوبة يوم القراءة).
  final int daysToExpiry;

  /// هل الدفعة منتهية الصلاحية؟
  bool get isExpired => daysToExpiry < 0;

  /// ينشئ نسخة من صف قاعدة البيانات + أيام الصلاحية مقابل [asOf].
  factory BatchInfo.fromRow(
    Map<String, Object?> row, {
    required DateTime asOf,
  }) {
    final expiry = DateTime.parse(row['expiry_date'] as String);
    return BatchInfo(
      id: row['id'] as int,
      productId: row['product_id'] as int,
      warehouseId: row['warehouse_id'] as int,
      batchNumber: row['batch_number'] as String,
      expiryDate: expiry,
      costPrice: (row['cost_price'] as num?)?.toDouble() ?? 0,
      qty: (row['qty'] as num?)?.toDouble() ?? 0,
      daysToExpiry: _dateOnly(expiry).difference(_dateOnly(asOf)).inDays,
    );
  }
}

/// حصة من كمية مخصومة من دفعة محددة — ناتج تخصيص FEFO.
class BatchAllocation {
  const BatchAllocation({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.qty,
    required this.costPrice,
  });

  /// الدفعة المخصوم منها.
  final int batchId;

  final String batchNumber;

  /// تاريخ انتهاء الدفعة (للعرض والتوثيق في سطر الفاتورة).
  final DateTime expiryDate;

  /// الكمية المخصومة من هذه الدفعة (≥ 0).
  final double qty;

  /// تكلفة وحدة الدفعة (لتكلفة البند — WAC لاحقاً).
  final double costPrice;

  /// قيمة الحصة بالتكلفة (كمية × تكلفة الوحدة).
  double get costValue => qty * costPrice;
}

/// نتيجة تخصيص FEFO — الحصص + أعلام النقص (FR-01-10 / AC-05).
///
/// عند [shorted]: التخصيص جزئي والمتبقي غير المغطى [remaining] —
/// القرار (رفض الفاتورة أو السماح بالسالب) بيد المستدعي، والمستودع
/// يقدّم الحقيقة فقط.
class FefoResult {
  const FefoResult({
    required this.allocations,
    required this.shorted,
    required this.remaining,
  });

  /// الحصص مرتبة من الدفعة الأقرب انتهاءً (كمية كل دفعة ≤ المتبقي فيها).
  final List<BatchAllocation> allocations;

  /// هل الكمية المطلوبة لم تتوفر كاملة؟
  final bool shorted;

  /// الكمية التي لم يغطها أي دفعة (0 عند الاكتمال).
  final double remaining;

  /// إجمالي ما تم تخصيصه فعلاً.
  double get allocatedQty =>
      allocations.fold<double>(0, (sum, a) => sum + a.qty);
}

/// تنبيه صلاحية دفعة واحدة — لوحة تنبيهات FR-09-15.
class BatchExpiryAlert {
  const BatchExpiryAlert({
    required this.batchId,
    required this.productId,
    required this.productName,
    required this.warehouseId,
    required this.batchNumber,
    required this.expiryDate,
    required this.qty,
    required this.daysToExpiry,
  });

  final int batchId;

  final int productId;

  /// اسم الصنف (JOIN للعرض).
  final String productName;

  final int warehouseId;

  final String batchNumber;

  final DateTime expiryDate;

  /// الكمية المتبقية في الدفعة (التنبيه للكميات النشطة فقط).
  final double qty;

  /// الأيام حتى الانتهاء (سالب = منتهية — أشد إلحاحاً).
  final int daysToExpiry;

  /// هل الدفعة منتهية؟
  bool get isExpired => daysToExpiry < 0;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
