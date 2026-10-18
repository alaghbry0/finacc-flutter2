/// أنواع استيراد الأصناف النقية (صف فاشل/صف صالح/المعاينة/نتيجة التنفيذ)
/// — جزء من تقسيم R20-D3a لخدمة الاستيراد (نمط R19-D3d): منقولة حرفياً
/// من item_import_service.dart — الخدمة تُصدِّرها من هنا فكل استيراداتها
/// التاريخية تحل كما كانت.
///
/// المسار الإلزامي من مرحلتين (FR-01-13 / AC-14):
/// 1. المعاينة (parseAndValidate): قراءة الملف + تحقق كل صف (الاسم
///    إلزامي، الأرقام غير سالبة، تفرد الباركود داخل الملف ومقابل
///    القاعدة، العملات النشطة) — لا يكتب شيئاً في القاعدة إطلاقاً،
///    ويعيد المعاينة للواجهة.
/// 2. التنفيذ (commitValid): إدراج الصفوف الصالحة فقط — وإن وُجدت صفوف
///    فاشلة فالإقرار الصريح (`confirmed`) إلزامي وإلا رفضت العملية
///    (AC-14). كل صف كلِّي أو لا شيء (ذرّية createItem) ولا إدراج جزئي
///    داخل الصف.
library;

import '../../../domain/models/item.dart';

/// صف فاشل في الاستيراد — رقم الصف بالملف (شاملاً رأس الجدول) + السبب.
class ImportRowFailure {
  const ImportRowFailure({required this.rowNumber, required this.reason});

  /// رقم الصف كما يظهر للمستخدم في الملف (1 = رأس الجدول).
  final int rowNumber;

  /// سبب الفشل بالعربية (قد يجمع عدة أسباب بـ «؛»).
  final String reason;

  @override
  String toString() => 'الصف $rowNumber: $reason';
}

/// صف صالح جاهز للإدراج — المسودة + أسماء الفئة/الوحدة قبل حلّها.
class ImportedItemRow {
  const ImportedItemRow({
    required this.rowNumber,
    required this.draft,
    this.categoryName,
    this.unitName,
  });

  final int rowNumber;
  final ItemDraft draft;

  /// اسم الفئة كما ورد بالملف (تُنشأ إن لم توجد عند التنفيذ).
  final String? categoryName;

  /// اسم الوحدة كما ورد بالملف (تُنشأ إن لم توجد عند التنفيذ).
  final String? unitName;
}

/// معاينة الاستيراد — مخرجات المرحلة الأولى (تحقق بلا كتابة).
class ItemImportPreview {
  const ItemImportPreview({
    required this.totalRows,
    required this.validRows,
    required this.failedRows,
    required this.suggestedNewCategories,
    required this.suggestedNewUnits,
    required this.warehouseId,
  });

  /// عدد صفوف البيانات كلها (بلا رأس الجدول وبلا الصفوف الفارغة).
  final int totalRows;

  final List<ImportedItemRow> validRows;

  final List<ImportRowFailure> failedRows;

  /// فئات جديدة مقترحة (واردة بالملف وغير موجودة بالقاعدة).
  final List<String> suggestedNewCategories;

  /// وحدات جديدة مقترحة (واردة بالملف وغير موجودة بالقاعدة).
  final List<String> suggestedNewUnits;

  /// المخزن المرتبط بالمعاينة (الرصيد الافتتاحي يُقيَّد فيه).
  final int warehouseId;

  /// هل كل الصفوف صالحة؟ (لا حاجة للإقرار).
  bool get isClean => failedRows.isEmpty;
}

/// نتيجة تنفيذ الاستيراد — عدّادات للعرض بعد الالتزام.
class ItemImportCommitResult {
  const ItemImportCommitResult({
    required this.inserted,
    required this.failures,
    required this.createdCategories,
    required this.createdUnits,
    required this.totalRows,
  });

  /// عدد الأصناف المدرجة فعلاً.
  final int inserted;

  /// كل الفشل: صفوف المعاينة + أي فشل لحظة الإدراج (تعارض باركود طارئ).
  final List<ImportRowFailure> failures;

  /// فئات أُنشئت أثناء التنفيذ.
  final int createdCategories;

  /// وحدات أُنشئت أثناء التنفيذ.
  final int createdUnits;

  /// إجمالي صفوف البيانات في الملف الأصلي.
  final int totalRows;
}
