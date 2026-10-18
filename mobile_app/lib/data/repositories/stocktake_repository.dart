/// مستودع الجرد الفعلي (FR-01-08 + AC-04 — الشريحة 10): شاشة جرد للمخزن
/// المحدد تعرض الرصيد الدفتري وتستقبل الرصيد الفعلي، وتولّد تسوية الفرق
/// **كحركة جرد موقّعة بتاريخ المستخدم واسم الجانِد وبتكلفة لقطة
/// (unit_cost) وقت الجرد**، ثم تُقفل الأرصدة (stock_level يُضبط على
/// المقيس).
///
/// وحدات التنفيذ مستخرجة إلى `stocktake/` بجواره (R20-D3a — نمط
/// تقسيم R19-D3d): الأنواع النقية والاستثناء (`stocktake_models.dart`
/// — تُصدَّر من هنا فكل استيرادات المستوردين التاريخية تحل كما كانت)
/// وقراءات الكشف (`stocktake_queries.dart`) والترحيل الذرّي بقراراته
/// المعمارية الثمانية (`stocktake_post_flow.dart` — **المعاملة كاملة
/// داخل ملف واحد غير مشطورة**) — هذا الصنف واجهة تفويض رقيقة بتواقيعه
/// العامة نفسها.
library;

import 'package:sqflite/sqflite.dart';

import 'stocktake/stocktake_models.dart';
import 'stocktake/stocktake_post_flow.dart';
import 'stocktake/stocktake_queries.dart';

export 'stocktake/stocktake_models.dart';

/// مستودع الجرد الفعلي — قراءة الكشف + ترحيل ذرّي + سجل.
class StocktakeRepository {
  StocktakeRepository(this._db);

  final Database _db;

  // ─────────────────────────────────────────────────────────────────────
  // قراءات الكشف (FR-01-08)
  // ─────────────────────────────────────────────────────────────────────

  /// المخازن غير المؤرشفة (الافتراضي أولاً) — لاختيار «المخزن المحدد».
  Future<List<StocktakeWarehouse>> warehouses() async =>
      stocktakeWarehouses(_db);

  /// كشف الجرد للمخزن: كل الأصناف غير الخدمية غير المؤرشفة — الرصيد
  /// الدفتري من `stock_level` (0 عند الغياب) ولقطة تكلفة العرض من
  /// `product.cost_price` (WAC أساس)، مرتّبة بالاسم.
  Future<List<StocktakeLineDraft>> loadDraft(int warehouseId) async =>
      loadStocktakeDraft(_db, warehouseId);

  /// سجل عمليات الجرد الأخيرة للمخزن (الأحدث أولاً) مع عدد الأسطر.
  Future<List<StocktakeHistoryRow>> history({
    required int warehouseId,
    int limit = 20,
  }) async => stocktakeHistory(_db, warehouseId: warehouseId, limit: limit);

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
  ///   (القراران 1/2 برأس stocktake_post_flow.dart).
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
  }) async => postStocktake(
    _db,
    warehouseId: warehouseId,
    countedAt: countedAt,
    countedBy: countedBy,
    notes: notes,
    lines: lines,
    userId: userId,
  );
}
