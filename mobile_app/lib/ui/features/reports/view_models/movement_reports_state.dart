/// حالات تقارير الحركة والمبيعات النقية (حركة صنف / ملخص المخزون /
/// المبيعات حسب) — مستخرجة من movement_reports_view_model (R20-D3c: نقل
/// حرفي بلا أي تغيير سلوكي؛ تُصدَّر من ملف المتحكم فبقيت استيرادات
/// المستدعين كما هي).
library;

import '../../../../data/repositories/movement_reports_repository.dart';
import '../views/widgets/period_preset_bar.dart';

// ─────────────────────────────────────────────────────────────────────
// FR-09-03 — حركة صنف
// ─────────────────────────────────────────────────────────────────────

/// حالة شاشة حركة صنف.
class ItemMovementState {
  const ItemMovementState({
    required this.loading,
    this.error,
    this.productId,
    this.period = ReportPeriod.month,
    this.from,
    this.to,
    this.report,
    this.currencyCode = '',
    this.decimals = 2,
  });

  final bool loading;
  final Object? error;

  /// الصنف المحدد (null = لم يُختر بعد — بطاقة الاختيار البطلة).
  final int? productId;

  final ReportPeriod period;
  final DateTime? from;
  final DateTime? to;

  /// التقرير المحمّل (قديم قد يبقى أثناء التحديث).
  final ItemMovementReport? report;

  final String currencyCode;
  final int decimals;

  /// لا صنف محدد — الواجهة تعرض بطاقة الاختيار (ليست حالة فراغ).
  bool get needsProduct => !loading && error == null && productId == null;

  /// صنف محدد بلا أي حركة في الفترة (احتفالية — رأس البطاقة يبقى).
  bool get isEmpty =>
      !loading &&
      error == null &&
      productId != null &&
      report != null &&
      report!.rows.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────
// FR-09-04 — ملخص حركة المخزون
// ─────────────────────────────────────────────────────────────────────

/// حالة شاشة ملخص حركة المخزون.
class StockSummaryState {
  const StockSummaryState({
    required this.loading,
    this.error,
    this.period = ReportPeriod.month,
    this.from,
    this.to,
    this.rows,
    this.currencyCode = '',
    this.decimals = 2,
  });

  final bool loading;
  final Object? error;
  final ReportPeriod period;
  final DateTime? from;
  final DateTime? to;

  /// صفوف الملخص (قديمة قد تبقى أثناء التحديث) — null قبل أول تحميل.
  final List<StockSummaryRow>? rows;

  final String currencyCode;
  final int decimals;

  /// لا حركة إطلاقاً في الفترة (الحالة الفارغة الاحتفالية).
  bool get isEmpty =>
      !loading && error == null && rows != null && rows!.isEmpty;

  /// إجمالي قيمة المخزون المتحرك بالتكلفة (رأس الشاشة).
  double get totalValueAtCost {
    var sum = 0.0;
    for (final row in rows ?? const <StockSummaryRow>[]) {
      sum += row.valueAtCost;
    }
    return sum;
  }
}

// ─────────────────────────────────────────────────────────────────────
// FR-09-06 — المبيعات حسب
// ─────────────────────────────────────────────────────────────────────

/// حالة شاشة المبيعات حسب.
class SalesByState {
  const SalesByState({
    required this.loading,
    this.error,
    this.dimension = SalesByDimension.customer,
    this.period = ReportPeriod.month,
    this.from,
    this.to,
    this.rows,
    this.currencyCode = '',
    this.decimals = 2,
  });

  final bool loading;
  final Object? error;

  /// بعد التجميع الحالي.
  final SalesByDimension dimension;

  final ReportPeriod period;
  final DateTime? from;
  final DateTime? to;

  /// صفوف التجميع (قديمة قد تبقى أثناء التحديث).
  final List<SalesByRow>? rows;

  final String currencyCode;
  final int decimals;

  /// إجمالي مبيعات الفترة بالأساس (رأس الشاشة) — مجموع الصفوف.
  double get totalSalesBase {
    var sum = 0.0;
    for (final row in rows ?? const <SalesByRow>[]) {
      sum += row.salesBase;
    }
    return sum;
  }

  /// لا مبيعات في الفترة (الحالة الفارغة الاحتفالية).
  bool get isEmpty =>
      !loading && error == null && rows != null && rows!.isEmpty;
}
