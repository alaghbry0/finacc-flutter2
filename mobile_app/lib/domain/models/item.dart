/// نماذج الأصناف والمخزون — جداول `product` / `product_price` /
/// `stock_level` / `stock_movement` (§5.3) — المرحلة 2 (وحدة الأصناف FR-01).
///
/// القاعدة النقدية (§0.3): كل الأرقام المالية والكميات `double`، وتُقرأ
/// من الصفوف عبر `(row['x'] as num?)?.toDouble() ?? 0`.
library;

/// صنف واحد — صف من جدول `product`.
class Item {
  const Item({
    required this.id,
    required this.name,
    this.barcode,
    this.categoryId,
    this.unitId,
    this.costPrice = 0,
    this.minStock = 0,
    this.isService = false,
    this.trackBatches = false,
    this.trackSerials = false,
    this.imagePath,
    this.notes,
    this.isArchived = false,
    this.updatedAt,
  });

  /// المعرّف في جدول `product`.
  final int id;

  /// اسم الصنف (إلزامي — فريد دلالياً لا بنائياً).
  final String name;

  /// الباركود (EAN-13 داخلي يبدأ بـ 2 أو باركود المورد) — فريد بنائياً.
  final String? barcode;

  /// الفئة (شجرة بمستويين — FR-01-05).
  final int? categoryId;

  /// وحدة القياس (مع معامل تحويل — FR-13-06).
  final int? unitId;

  /// تكلفة الوحدة (متوسط مرجّح WAC لاحقاً — §5.4).
  final double costPrice;

  /// حد إعادة الطلب — تنبيه نفاد المخزون (FR-01-12).
  final double minStock;

  /// صنف خدمي بلا مخزون (لا stock_level ولا stock_movement إطلاقاً).
  final bool isService;

  /// يتتبع الدفعات وتواريخ الصلاحية (FEFO — FR-01-10).
  final bool trackBatches;

  /// يتتبع الأرقام التسلسلية (مؤجل — V1 يخزّن العلم فقط).
  final bool trackSerials;

  /// مسار صورة الصنف المحلية (اختياري).
  final String? imagePath;

  /// ملاحظات حرة (اختياري).
  final String? notes;

  /// مؤرشف؟ (الحذف ممنوع — FR-01-15: الأرشفة بديل الحذف).
  final bool isArchived;

  /// آخر تعديل (UTC — ISO 8601 كما في القاعدة).
  final DateTime? updatedAt;

  /// ينشئ نسخة من صف قاعدة البيانات.
  factory Item.fromRow(Map<String, Object?> row) => Item(
    id: row['id'] as int,
    name: row['name'] as String,
    barcode: row['barcode'] as String?,
    categoryId: row['category_id'] as int?,
    unitId: row['unit_id'] as int?,
    costPrice: (row['cost_price'] as num?)?.toDouble() ?? 0,
    minStock: (row['min_stock'] as num?)?.toDouble() ?? 0,
    isService: (row['is_service'] as int? ?? 0) == 1,
    trackBatches: (row['track_batches'] as int? ?? 0) == 1,
    trackSerials: (row['track_serials'] as int? ?? 0) == 1,
    imagePath: row['image_path'] as String?,
    notes: row['notes'] as String?,
    isArchived: (row['is_archived'] as int? ?? 0) == 1,
    updatedAt: row['updated_at'] == null
        ? null
        : DateTime.tryParse(row['updated_at'] as String),
  );
}

/// سعر بيع لصنف بعملة ومستوى — صف من `product_price`.
class ItemPrice {
  const ItemPrice({
    this.productId,
    required this.currencyId,
    required this.price,
    this.priceLevel = 'retail',
    this.marginPercent = 0,
    this.updatedAt,
  });

  /// الصنف (null في مسودات الإدخال قبل الإنشاء).
  final int? productId;

  /// العملة (YER الأساسية + SAR/USD/AED — §0.1).
  final int currencyId;

  /// السعر (≥ 0 — قيد CHECK في المخطط).
  final double price;

  /// مستوى السعر: `retail` / `wholesale` / `credit`.
  final String priceLevel;

  /// هامش الربح ٪ (عرض فقط — لا يدخل أي حساب محاسبي).
  final double marginPercent;

  /// آخر تحديث للسعر (UTC).
  final DateTime? updatedAt;

  /// ينشئ نسخة من صف قاعدة البيانات.
  factory ItemPrice.fromRow(Map<String, Object?> row) => ItemPrice(
    productId: row['product_id'] as int?,
    currencyId: row['currency_id'] as int,
    price: (row['price'] as num?)?.toDouble() ?? 0,
    priceLevel: (row['price_level'] as String?) ?? 'retail',
    marginPercent: (row['margin_percent'] as num?)?.toDouble() ?? 0,
    updatedAt: row['updated_at'] == null
        ? null
        : DateTime.tryParse(row['updated_at'] as String),
  );
}

/// صنف مع معلومات المخزون المجمّعة — نتيجة البحث السريع (FR-01-04).
class ItemStockInfo {
  const ItemStockInfo({
    required this.item,
    this.totalQty = 0,
    this.warehouseQty = const {},
    this.retailPrice,
  });

  /// الصنف نفسه.
  final Item item;

  /// إجمالي الكمية عبر كل المخازن (SUM لـ `stock_level`).
  final double totalQty;

  /// الكمية لكل مخزن (معرّف المخزن → كمية) — تُملأ في التفاصيل والبحث.
  final Map<int, double> warehouseQty;

  /// سعر التجزئة بعملة محددة (null إن لم يُطلب أو لم يوجد سعر).
  final double? retailPrice;

  /// هل المخزون منتهٍ (صفر أو سالب نظرياً)؟
  bool get isOutOfStock => totalQty <= 0;
}

/// حركة مخزون واحدة — صف من `stock_movement` (بطاقة الصنف FR-09-03).
class ItemMovementEntry {
  const ItemMovementEntry({
    this.id,
    this.productId,
    required this.movementType,
    required this.qty,
    required this.unitCost,
    required this.movedAt,
    this.refType,
    this.refId,
    this.notes,
    this.remainingAfter,
  });

  /// المعرّف في جدول `stock_movement`.
  final int? id;

  /// الصنف المتحرك.
  final int? productId;

  /// نوع الحركة: `purchase` / `sale` / `sale_return` / `purchase_return` /
  /// `stocktake_adjust` / `manual_adjust` / `transfer_in` / `transfer_out` /
  /// `opening`.
  final String movementType;

  /// الكمية بإشارة (+ دخول / − خروج).
  final double qty;

  /// تكلفة الوحدة لحظة الحركة (WAC — §5.4).
  final double unitCost;

  /// لحظة الحركة (UTC — ISO 8601 كما في القاعدة).
  final DateTime movedAt;

  /// نوع المستند المرجعي (`opening` / `invoice` / `purchase` / …).
  final String? refType;

  /// معرّف المستند المرجعي.
  final int? refId;

  /// ملاحظات الحركة.
  final String? notes;

  /// الرصيد المتبقي بعد هذه الحركة (محسوب تتابعياً — بطاقة الصنف).
  final double? remainingAfter;

  /// ينشئ نسخة من صف قاعدة البيانات.
  factory ItemMovementEntry.fromRow(Map<String, Object?> row) =>
      ItemMovementEntry(
        id: row['id'] as int?,
        productId: row['product_id'] as int?,
        movementType: row['movement_type'] as String,
        qty: (row['qty'] as num?)?.toDouble() ?? 0,
        unitCost: (row['unit_cost'] as num?)?.toDouble() ?? 0,
        movedAt: DateTime.parse(row['moved_at'] as String),
        refType: row['ref_type'] as String?,
        refId: row['ref_id'] as int?,
        notes: row['notes'] as String?,
        remainingAfter: (row['remaining_after'] as num?)?.toDouble(),
      );
}

/// مسودة إدخال صنف (إنشاء/تعديل) — مدخلات الواجهة إلى المستودع.
///
/// عند [updateItem]: تُستبدل كل الحقول، ويُتجاهل [openingQty] (الرصيد
/// الافتتاحي يُدخل عند الإنشاء فقط) — تعديل المخزون يتم بحركات لا بتعديل.
class ItemDraft {
  const ItemDraft({
    required this.name,
    this.barcode,
    this.categoryId,
    this.unitId,
    this.costPrice = 0,
    this.minStock = 0,
    this.isService = false,
    this.trackBatches = false,
    this.notes,
    this.openingQty = 0,
    this.prices = const [],
  });

  /// الاسم (إلزامي — «اسم الصنف مطلوب» عند الفراغ).
  final String name;

  /// الباركود — فارغ/null عند الإنشاء يولّد EAN-13 داخلي تلقائياً.
  final String? barcode;

  /// الفئة (اختياري).
  final int? categoryId;

  /// وحدة القياس (اختياري).
  final int? unitId;

  /// تكلفة الوحدة (≥ 0).
  final double costPrice;

  /// حد إعادة الطلب (≥ 0).
  final double minStock;

  /// صنف خدمي (بلا مخزون).
  final bool isService;

  /// يتتبع الدفعات (FEFO).
  final bool trackBatches;

  /// ملاحظات (اختياري).
  final String? notes;

  /// الكمية الافتتاحية — تُسجَّل كحركة `opening` عند الإنشاء فقط،
  /// وتُتجاهل للأصناف الخدمية.
  final double openingQty;

  /// أسعار البيع (مستوى `retail` افتراضياً — عملة لكل صف).
  final List<ItemPrice> prices;
}

/// سطر سعر في تفاصيل الصنف — `product_price` مع رمز العملة (JOIN).
class ItemPriceLine {
  const ItemPriceLine({
    required this.currencyId,
    required this.currencyCode,
    required this.currencyName,
    required this.price,
    required this.priceLevel,
    this.marginPercent = 0,
  });

  final int currencyId;

  /// رمز العملة الدولي (YER / SAR / …) — للعرض.
  final String currencyCode;

  /// اسم العملة العربي — للعرض.
  final String currencyName;

  final double price;

  /// `retail` / `wholesale` / `credit`.
  final String priceLevel;

  final double marginPercent;
}

/// كمية صنف في مخزن واحد — سطر من تفاصيل الصنف.
class WarehouseStock {
  const WarehouseStock({
    required this.warehouseId,
    required this.warehouseName,
    required this.qty,
  });

  final int warehouseId;

  /// اسم المخزن — للعرض.
  final String warehouseName;

  final double qty;
}

/// التفاصيل الكاملة لصنف — شاشة بطاقة الصنف (FR-01-03 / FR-09-03):
/// الصنف + كل أسعاره بكل العملات + مخزونه لكل مستودع + آخر الحركات.
class ItemFullDetail {
  const ItemFullDetail({
    required this.item,
    required this.prices,
    required this.stockByWarehouse,
    required this.recentMovements,
  });

  final Item item;

  /// كل أسعار الصنف (كل العملات والمستويات).
  final List<ItemPriceLine> prices;

  /// المخزون لكل مستودع.
  final List<WarehouseStock> stockByWarehouse;

  /// آخر الحركات (20 افتراضياً — الأحدث أولاً).
  final List<ItemMovementEntry> recentMovements;

  /// إجمالي المخزون عبر المستودعات.
  double get totalQty =>
      stockByWarehouse.fold<double>(0, (sum, w) => sum + w.qty);
}

/// فئة صنف — جدول `category` (شجرة بمستويين — FR-01-05).
class ItemCategory {
  const ItemCategory({required this.id, required this.name, this.parentId});

  final int id;

  /// اسم الفئة (فريد — قيد UNIQUE).
  final String name;

  /// الفئة الأصل (null = جذر — والمستوى الثاني لا يأتيه أبناء).
  final int? parentId;

  /// هل فئة جذر؟
  bool get isRoot => parentId == null;

  /// ينشئ نسخة من صف قاعدة البيانات.
  factory ItemCategory.fromRow(Map<String, Object?> row) => ItemCategory(
    id: row['id'] as int,
    name: row['name'] as String,
    parentId: row['parent_id'] as int?,
  );
}

/// وحدة قياس — جدول `unit` (FR-13-06: 1 كرتون = 24 قطعة → factor = 24).
class ItemUnit {
  const ItemUnit({
    required this.id,
    required this.name,
    this.factor = 1,
    this.baseUnitId,
  });

  final int id;

  /// اسم الوحدة (فريد — قيد UNIQUE).
  final String name;

  /// معامل التحويل إلى الوحدة الأساسية (قطعة) — ≥ 1 منطقياً.
  final double factor;

  /// الوحدة الأساسية (null = وحدة أساسية بذاتها).
  final int? baseUnitId;

  /// ينشئ نسخة من صف قاعدة البيانات.
  factory ItemUnit.fromRow(Map<String, Object?> row) => ItemUnit(
    id: row['id'] as int,
    name: row['name'] as String,
    factor: (row['factor'] as num?)?.toDouble() ?? 1,
    baseUnitId: row['base_unit_id'] as int?,
  );
}
