/// مستودع الأصناف — جداول `product` / `product_price` / `stock_level` /
/// `stock_movement` / `category` / `unit` (§5.3) — المرحلة 2 (FR-01).
///
/// القواعد الملزمة هنا:
/// - **الذرّية**: الإنشاء/التعديل/الأرشفة كل منها معاملة واحدة — فشل أي
///   خطوة يرجع الكل ولا يُكتب شيء.
/// - **لا حذف أبداً** (FR-01-15): الأرشفة `is_archived = 1` بديل الحذف.
/// - **الأصناف الخدمية** بلا أي صفوف مخزون (`stock_level`/`stock_movement`).
/// - **توليد الباركود** EAN-13 بنطاق المتجر 200–299 عند فراغ الباركود،
///   مع حتى 5 محاولات عند تصادم التفرد (FR-01-02).
/// - **كل قيم SQL عبر معاملات `?`** — لا دمج نصي لمدخلات المستخدم.
///
/// وحدات التنفيذ الداخلية مستخرجة إلى `item/` بجواره (R19-D3d —
/// نمط تقسيم R18-D3a): الكتابات (`item_write_ops.dart`) والقراءات
/// (`item_queries.dart`) واستعلامات المخزون (`item_stock_queries.dart`)
/// والفئات والوحدات (`item_category_unit_ops.dart`) — هذا الصنف واجهة
/// تفويض رقيقة بتواقيعه العامة نفسها.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/item.dart';
import '../../domain/services/barcode_ean13.dart';
import 'item/item_category_unit_ops.dart';
import 'item/item_queries.dart';
import 'item/item_stock_queries.dart';
import 'item/item_write_ops.dart';

/// مستودع الأصناف والمخزون والفئات والوحدات.
class ItemRepository {
  /// [barcodeGenerator] قابل للحقن للاختبارات (مولّد متحكم به لتجربة
  /// إعادة المحاولة عند تصادم الباركود).
  ItemRepository(this._db, {Ean13Generator? barcodeGenerator})
    : _generator = barcodeGenerator ?? const Ean13Generator();

  final Database _db;
  final Ean13Generator _generator;

  // ─────────────────────────────────────────────────────────────────────
  // الإنشاء / التعديل / الأرشفة
  // ─────────────────────────────────────────────────────────────────────

  /// **إنشاء صنف ذرّياً**: صف `product` + أسعار `product_price` +
  /// (لغير الخدمي مع كمية افتتاحية) `stock_level` وحركة `opening`
  /// + (للمتتبع للدفعات) صف `batch` افتتاحي بصلاحية بعيدة
  /// + قيد تدقيق `item_create` — كلها في معاملة واحدة.
  ///
  /// - الباركود الفارغ يولّد EAN-13 داخلياً (حتى 5 محاولات عند التصادم).
  /// - الصنف الخدمي لا يُنشئ أي صفوف مخزون مهما كانت [ItemDraft.openingQty].
  /// - **المتتبع للدفعات**: الرصيد الافتتاحي يُدفَّع أيضاً دفعةً
  ///   (`expiry_date = 9999-12-31`) — بدونها يبقى الكتاب (stock_level)
  ///   حاملاً كمية تعجز FEFO عن تخصيصها فيُرفض البيع بمتاح = 0
  ///   رغم رصيد كتابي كبير (خلل الموجة 4 — مُصلح هنا وهجرةً v2).
  Future<Result<int, String>> createItem(
    ItemDraft draft, {
    required int warehouseId,
    required int userId,
    DateTime? now,
  }) async => createItemFlow(
    _db,
    _generator,
    draft,
    warehouseId: warehouseId,
    userId: userId,
    now: now,
  );

  /// **تعديل صنف ذرّياً**: استبدال كامل لحقول الصنف + الأسعار (حذف ثم
  /// إدراج داخل المعاملة) + قيد تدقيق `item_update`.
  ///
  /// - [ItemDraft.openingQty] **يُتجاهل** هنا — المخزون يُعدَّل بحركات
  ///   (شراء/بيع/جرد) لا بتعديل مباشر.
  /// - الباركود الفارغ في المسودة **يمسح** باركود الصنف (استبدال كامل؛
  ///   لا توليد تلقائي عند التعديل).
  Future<Result<Item, String>> updateItem(
    int id,
    ItemDraft draft, {
    required int userId,
    DateTime? now,
  }) async => updateItemFlow(_db, id, draft, userId: userId, now: now);

  /// **أرشفة صنف** (FR-01-15: لا حذف — الأرشفة تُخفي الصنف من البحث
  /// والبيع مع بقاء التاريخ الكامل) + قيد تدقيق `item_archive`.
  Future<Result<void, String>> archiveItem(
    int id, {
    required int userId,
    DateTime? now,
  }) async => archiveItemFlow(_db, id, userId: userId, now: now);

  // ─────────────────────────────────────────────────────────────────────
  // البحث والاستعلام
  // ─────────────────────────────────────────────────────────────────────

  /// **البحث السريع** (FR-01-04): الاسم أو الباركود `LIKE %q%` مع إجمالي
  /// المخزون وسعر تجزئة اختياري — المؤرشف مستثنى إلا بطلب صريح.
  ///
  /// [currencyIdForPrice] يضمّن سعر التجزئة بعملة محددة (null = بلا سعر).
  /// خيارات التصنيف/الحد/الإزاحة تدعم التمرير المتدرج في قائمة الأصناف.
  Future<List<ItemStockInfo>> searchItems(
    String query, {
    int? categoryId,
    bool includeArchived = false,
    int limit = 50,
    int offset = 0,
    int? currencyIdForPrice,
  }) async => searchItemsPage(
    _db,
    query,
    categoryId: categoryId,
    includeArchived: includeArchived,
    limit: limit,
    offset: offset,
    currencyIdForPrice: currencyIdForPrice,
  );

  /// **بحث الباركود الدقيق** (FR-01-03: شاشة نتيجة المسح / POS):
  /// مطابقة تامة، المؤرشف مستثنى دائماً. [currencyId] يضمّن سعر التجزئة.
  Future<ItemStockInfo?> findByBarcode(String code, {int? currencyId}) async =>
      itemByBarcode(_db, code, currencyId: currencyId);

  /// **تفاصيل صنف كاملة** (FR-01-03): الصنف + كل الأسعار بكل العملات +
  /// المخزون لكل مستودع + آخر 20 حركة (بطاقة الصنف).
  ///
  /// يعمل حتى للأصناف المؤرشفة (الوصول بالمعرّف مباشرة).
  Future<ItemFullDetail?> detail(int id) async => itemDetail(_db, id);

  /// **أصناف تحت حد الطلب** (FR-01-12): غير الخدمي وغير المؤرشف حيث
  /// إجمالي المخزون ≤ `min_stock` (أو ≤ [minThresholdOverride] لكل الأصناف).
  /// الأصناف بلا أي صف مخزون تعتبر كميتها صفراً فتُدرج (نفاد تام).
  Future<List<ItemStockInfo>> lowStockItems({
    double? minThresholdOverride,
  }) async =>
      listLowStockItems(_db, minThresholdOverride: minThresholdOverride);

  /// **بطاقة الصنف** (FR-09-03): كل حركات الصنف مع الرصيد التتابعي بعد
  /// كل حركة، مرتبة الأحدث أولاً.
  ///
  /// [from]/[to]/[warehouseId] تصفي النافذة المعروضة، بينما يُحسب
  /// `remainingAfter` على التاريخ الكامل غير المصفّى (رصيد محاسبي صحيح).
  Future<List<ItemMovementEntry>> itemMovements(
    int productId, {
    DateTime? from,
    DateTime? to,
    int? warehouseId,
    int limit = 200,
  }) async => loadItemMovements(
    _db,
    productId,
    from: from,
    to: to,
    warehouseId: warehouseId,
    limit: limit,
  );

  /// هل للصنف حركات مخزون؟ (يحرس قرار الأرشفة مقابل أي تنظيف مستقبلي).
  Future<bool> hasMovements(int productId) async =>
      itemHasMovements(_db, productId);

  // ─────────────────────────────────────────────────────────────────────
  // الفئات والوحدات (FR-01-05 / FR-13-06)
  // ─────────────────────────────────────────────────────────────────────

  /// فئات الأصناف (المستوى الأول والثاني معاً — الترتيب بالاسم).
  Future<List<ItemCategory>> listCategories() async => listItemCategories(_db);

  /// ينشئ فئة — شجرة بمستويين حصراً (FR-01-05): الجذر ثم الأبناء،
  /// ولا يُقبل ابن لابن. الاسم فريد (فحص مسبق — المخطط لا يفرضه).
  Future<Result<int, String>> createCategory(
    String name, {
    int? parentId,
    DateTime? now,
  }) async => createItemCategory(_db, name, parentId: parentId, now: now);

  /// وحدات القياس (قطعة/كرتون/… — مرتبة بالاسم).
  Future<List<ItemUnit>> listUnits() async => listItemUnits(_db);

  /// ينشئ وحدة قياس — [factor] معامل التحويل إلى الوحدة الأساسية
  /// (1 كرتون = 24 قطعة → factor = 24 — FR-13-06).
  Future<Result<int, String>> createUnit(
    String name, {
    double factor = 1,
    DateTime? now,
  }) async => createItemUnit(_db, name, factor: factor, now: now);
}
