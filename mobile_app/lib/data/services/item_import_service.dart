/// خدمة استيراد الأصناف من CSV/Excel — FR-01-13 / AC-14.
///
/// وحدات التنفيذ مستخرجة إلى `item_import/` بجوارها (R20-D3a — نمط
/// تقسيم R19-D3d): الأنواع النقية (`item_import_models.dart` — تُصدَّر
/// من هنا فكل استيرادات الخدمة التاريخية تحل كما كانت) ومحلّلات
/// الملفات CSV/XLSX (`item_import_file_parsers.dart`) والتحقق بمرحلته
/// الأولى (`item_import_validate.dart`) والتنفيذ بمرحلته الثانية
/// (`item_import_commit.dart`) — هذا الصنف واجهة تفويض رقيقة بتواقيعه
/// العامة نفسها.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/company.dart';
import 'item_import/item_import_commit.dart';
import 'item_import/item_import_models.dart';
import 'item_import/item_import_validate.dart';

export 'item_import/item_import_models.dart';

/// خدمة استيراد الأصناف (FR-01-13) — CSV نصي أو ملف xlsx ثنائي.
class ItemImportService {
  ItemImportService(this._db);

  final Database _db;

  /// **المرحلة 1 — التحليل والتحقق** (بلا أي كتابة):
  ///
  /// [source] نص CSV (مع رأس جدول، BOM، فواصل مقتبسة، أسطر CRLF، عربي)
  /// أو بايتات xlsx (الورقة الأولى).
  ///
  /// [columnMapping] يربط الأسماء الدلالية بأحرف/أرقام الأعمدة:
  /// `{'name': 'A', 'barcode': 'B', 'cost': 'C', 'price_yer': 'D',
  /// 'price_sar': 'E', 'qty': 'F', 'min_stock': 'G', 'category': 'H',
  /// 'unit': 'I', 'notes': 'J'}` — مفاتيح `price_<رمز العملة>` مرنة
  /// بأي عملة من [activeCurrencies].
  ///
  /// [barcodeColumn] إن أُعطي يتقدم على `columnMapping['barcode']`.
  Future<ItemImportPreview> parseAndValidate(
    Object source, {
    required int warehouseId,
    required Map<String, String> columnMapping,
    required List<Currency> activeCurrencies,
    String? barcodeColumn,
  }) async => parseAndValidateImport(
    _db,
    source,
    warehouseId: warehouseId,
    columnMapping: columnMapping,
    activeCurrencies: activeCurrencies,
    barcodeColumn: barcodeColumn,
  );

  /// **المرحلة 2 — التنفيذ** (AC-14): إدراج الصفوف الصالحة فقط.
  ///
  /// - إن وُجدت صفوف فاشلة ولم يُقرّ المستخدم ([confirmed] = false)
  ///   فالعملية مرفوضة برسالة الإقرار — **لا يُدرج أي صف**.
  /// - الفئات/الوحدات الجديدة تُنشأ أولاً، ثم كل صف عبر [ItemRepository]
  ///   .createItem (ذرّي لكل صف) — الصف كلِّي أو لا شيء دائماً.
  /// - قيد تدقيق `items_import` واحد بتفاصيل `ok=N failed=M`.
  Future<Result<ItemImportCommitResult, String>> commitValid(
    ItemImportPreview preview, {
    required int warehouseId,
    required int userId,
    required bool confirmed,
    DateTime? now,
  }) async => commitValidImport(
    _db,
    preview,
    warehouseId: warehouseId,
    userId: userId,
    confirmed: confirmed,
    now: now,
  );
}
