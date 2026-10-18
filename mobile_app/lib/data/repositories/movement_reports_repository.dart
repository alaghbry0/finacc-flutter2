/// مستودع تقارير الحركة والمبيعات (الشريحة 10):
/// - **FR-09-03 تقرير حركة صنف**: كل حركات صنف واحد في فترة (ومخزن
///   اختياري) مع **الباقي التراكمي** — الرصيد بعد كل حركة.
/// - **FR-09-04 ملخص حركة المخزون**: تجميع لكل صنف متحرك في الفترة
///   (وارد/صادر/مرتجع/تسوية) مع الرصيد الختامي وقيمته بالتكلفة.
/// - **FR-09-06 المبيعات حسب**: العميل/الفئة/الصنف/اليوم لنفس الفترة
///   مع نسبة التغير عن **الفترة السابقة المساوية في الطول**.
///
/// وحدات التنفيذ مستخرجة إلى `movement_reports/` بجواره (R20-D3a —
/// نمط تقسيم R19-D3d): الأنواع النقية (`movement_report_models.dart`
/// — تُصدَّر من هنا فكل استيرادات المستوردين التاريخية تحل كما كانت)
/// وبطاقة حركة الصنف (`item_movement_query.dart`) وملخص المخزون
/// (`stock_summary_query.dart`) والمبيعات حسب (`sales_by_query.dart`)
/// — كل ملف يحمل قراراته المعمارية المنقولة من رأس المستودع الأصلي،
/// وهذا الصنف واجهة تفويض رقيقة بتواقيعه العامة نفسها.
library;

import 'package:sqflite/sqflite.dart';

import 'movement_reports/item_movement_query.dart';
import 'movement_reports/movement_report_models.dart';
import 'movement_reports/sales_by_query.dart';
import 'movement_reports/stock_summary_query.dart';

export 'movement_reports/movement_report_models.dart';

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
  }) async => loadItemMovementReport(
    _db,
    productId: productId,
    from: from,
    to: to,
    warehouseId: warehouseId,
  );

  // ─────────────────────────────────────────────────────────────────────
  // FR-09-04 — ملخص حركة المخزون
  // ─────────────────────────────────────────────────────────────────────

  /// ملخص الحركة لكل صنف **تحرّك** في الفترة [from]..[to] (شاملة
  /// الطرفين)، مرتّباً بقيمة المخزون تنازلياً — [warehouseId] اختياري.
  ///
  /// الأصناف الساكنة (بلا حركة في الفترة) غير مشمولة عمداً (FR: ملخص
  /// الحركة). الرصيد الختامي يقرأ كل الحركات حتى `to` (قرار 2 برأس
  /// stock_summary_query.dart).
  Future<List<StockSummaryRow>> stockSummary({
    required DateTime from,
    required DateTime to,
    int? warehouseId,
  }) async =>
      loadStockSummary(_db, from: from, to: to, warehouseId: warehouseId);

  // ─────────────────────────────────────────────────────────────────────
  // FR-09-06 — المبيعات حسب
  // ─────────────────────────────────────────────────────────────────────

  /// تجميع المبيعات حسب [dimension] للفترة [from]..[to] (شاملة الطرفين)
  /// بالعملة الأساسية، مع نسبة التغير عن الفترة السابقة المساوية في
  /// الطول (القرار 2 برأس sales_by_query.dart).
  Future<List<SalesByRow>> salesBy({
    required SalesByDimension dimension,
    required DateTime from,
    required DateTime to,
  }) async => loadSalesBy(_db, dimension: dimension, from: from, to: to);
}
