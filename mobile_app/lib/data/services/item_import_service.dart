/// خدمة استيراد الأصناف من CSV/Excel — FR-01-13 / AC-14.
///
/// المسار الإلزامي من مرحلتين:
/// 1. [parseAndValidate]: قراءة الملف + تحقق كل صف (الاسم إلزامي، الأرقام
///    غير سالبة، تفرد الباركود داخل الملف ومقابل القاعدة، العملات النشطة)
///    — لا يكتب شيئاً في القاعدة إطلاقاً، ويعيد المعاينة للواجهة.
/// 2. [commitValid]: إدراج الصفوف الصالحة فقط — وإن وُجدت صفوف فاشلة
///    فالإقرار الصريح (`confirmed`) إلزامي وإلا رفضت العملية (AC-14).
///    كل صف كلِّي أو لا شيء (ذرّية createItem) ولا إدراج جزئي داخل الصف.
library;

import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/company.dart';
import '../../domain/models/item.dart';
import '../repositories/item_repository.dart';

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
  }) async {
    final rows = switch (source) {
      final String text => _parseCsv(text),
      final Uint8List bytes => _parseXlsx(bytes),
      final List<int> bytes => _parseXlsx(Uint8List.fromList(bytes)),
      _ => throw ArgumentError(
        'مصدر الاستيراد يجب أن يكون نص CSV أو بايتات xlsx',
      ),
    };

    // فك الأعمدة من التخطيط (حرف أو رقم — أول صف بيانات بعد الرأس).
    final mapping = _resolveMapping(columnMapping, barcodeColumn);
    final existingBarcodes = await _existingBarcodes();
    // مطابقة العملات غير حساسة لحالة الأحرف (yer == YER).
    final currencyByCode = {
      for (final currency in activeCurrencies)
        currency.code.toUpperCase(): currency,
    };

    final validRows = <ImportedItemRow>[];
    final failures = <ImportRowFailure>[];
    final seenBarcodes = <String, int>{};
    final categories = <String>{};
    final units = <String>{};

    // رأس الجدول هو الصف الأول — البيانات تبدأ من الصف 2.
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i];
      if (_isEmptyRow(cells)) continue;

      final rowNumber = i + 1;
      final reasons = <String>[];
      final name = _cell(cells, mapping['name'] ?? -1).trim();
      if (name.isEmpty) reasons.add('اسم الصنف مطلوب');

      final barcode = _cell(cells, mapping['barcode'] ?? -1).trim();
      if (barcode.isNotEmpty) {
        final firstSeen = seenBarcodes[barcode];
        if (firstSeen != null) {
          reasons.add('الباركود مكرر داخل الملف (الصف $firstSeen)');
        } else {
          seenBarcodes[barcode] = rowNumber;
          if (existingBarcodes.contains(barcode)) {
            reasons.add('الباركود مستخدم لصنف موجود');
          }
        }
      }

      final cost = _parseAmount(
        _cell(cells, mapping['cost'] ?? -1),
        'سعر التكلفة',
        reasons,
      );
      final qty = _parseAmount(
        _cell(cells, mapping['qty'] ?? -1),
        'الكمية الافتتاحية',
        reasons,
      );
      final minStock = _parseAmount(
        _cell(cells, mapping['min_stock'] ?? -1),
        'حد إعادة الطلب',
        reasons,
      );

      final prices = <ItemPrice>[];
      for (final entry in mapping.entries) {
        if (!entry.key.startsWith('price_')) continue;
        final code = entry.key.substring('price_'.length);
        final currency = currencyByCode[code.toUpperCase()];
        final value = _cell(cells, entry.value);
        if (value.trim().isEmpty) continue;
        if (currency == null) {
          reasons.add('عملة $code غير معروفة');
          continue;
        }
        final price = _parseAmount(value, 'سعر ${currency.code}', reasons);
        if (price != null && price < 0) continue; // السبب أُضيف داخل التحليل.
        if (price != null) {
          prices.add(ItemPrice(currencyId: currency.id, price: price));
        }
      }

      if (reasons.isEmpty) {
        final categoryName = _cell(cells, mapping['category'] ?? -1).trim();
        final unitName = _cell(cells, mapping['unit'] ?? -1).trim();
        if (categoryName.isNotEmpty) categories.add(categoryName);
        if (unitName.isNotEmpty) units.add(unitName);
        validRows.add(
          ImportedItemRow(
            rowNumber: rowNumber,
            draft: ItemDraft(
              name: name,
              barcode: barcode.isEmpty ? null : barcode,
              costPrice: cost ?? 0,
              minStock: minStock ?? 0,
              notes: _cell(cells, mapping['notes'] ?? -1).trim(),
              openingQty: qty ?? 0,
              prices: prices,
            ),
            categoryName: categoryName.isEmpty ? null : categoryName,
            unitName: unitName.isEmpty ? null : unitName,
          ),
        );
      } else {
        failures.add(
          ImportRowFailure(rowNumber: rowNumber, reason: reasons.join('؛ ')),
        );
      }
    }

    final suggestedCategories = await _filterExisting('category', categories);
    final suggestedUnits = await _filterExisting('unit', units);
    return ItemImportPreview(
      totalRows: validRows.length + failures.length,
      validRows: validRows,
      failedRows: failures,
      suggestedNewCategories: suggestedCategories,
      suggestedNewUnits: suggestedUnits,
      warehouseId: warehouseId,
    );
  }

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
  }) async {
    if (!confirmed && preview.failedRows.isNotEmpty) {
      return const Err('يوجد صفوف فاشلة — الإقرار مطلوب');
    }

    final items = ItemRepository(_db);
    final at = now ?? DateTime.now();

    // 1) إنشاء الفئات والوحدات الناقصة أولاً (مع تحمّل سباق غير محتمل
    //    باستبعاد الفشل — القيمة الموجودة تُعاد استخدامها).
    final categoryIdByName = <String, int>{};
    var createdCategories = 0;
    for (final name in preview.suggestedNewCategories) {
      final result = await items.createCategory(name, now: at);
      final id = switch (result) {
        final Ok<int, String> ok => ok.value,
        final Err<int, String> _ => await _existingId('category', name),
      };
      if (id != null) {
        categoryIdByName[name] = id;
        createdCategories++;
      }
    }

    final unitIdByName = <String, int>{};
    var createdUnits = 0;
    for (final name in preview.suggestedNewUnits) {
      final result = await items.createUnit(name, now: at);
      final id = switch (result) {
        final Ok<int, String> ok => ok.value,
        final Err<int, String> _ => await _existingId('unit', name),
      };
      if (id != null) {
        unitIdByName[name] = id;
        createdUnits++;
      }
    }

    // 2) إدراج كل صف صالح (كل صف عبر createItem الذرّية — لا إدراج جزئي).
    final commitFailures = <ImportRowFailure>[];
    var inserted = 0;
    for (final row in preview.validRows) {
      final categoryId = row.categoryName == null
          ? null
          : categoryIdByName[row.categoryName] ??
                await _existingId('category', row.categoryName!);
      final unitId = row.unitName == null
          ? null
          : unitIdByName[row.unitName] ??
                await _existingId('unit', row.unitName!);
      final result = await items.createItem(
        row.draft,
        warehouseId: warehouseId,
        userId: userId,
        now: at,
      );
      switch (result) {
        case final Ok<int, String> ok:
          // إرفاق الفئة/الوحدة بالصنف بعد إنشائه (تحديث مباشر بلا مسودة
          // كاملة — الحقول الاختيارية فقط).
          if (categoryId != null || unitId != null) {
            await _db.update(
              'product',
              {
                'category_id': ?categoryId,
                'unit_id': ?unitId,
                'updated_at': at.toUtc().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [ok.value],
            );
          }
          inserted++;
        case final Err<int, String> err:
          commitFailures.add(
            ImportRowFailure(rowNumber: row.rowNumber, reason: err.error),
          );
      }
    }

    // 3) قيد تدقيق واحد لعملية الاستيراد (نمط user_repository).
    final failedTotal = preview.failedRows.length + commitFailures.length;
    await _db.insert('audit_log', {
      'user_id': userId,
      'action': 'items_import',
      'entity': 'product',
      'entity_id': null,
      'details': 'ok=$inserted failed=$failedTotal',
      'at': at.toUtc().toIso8601String(),
    });

    return Ok(
      ItemImportCommitResult(
        inserted: inserted,
        failures: [...preview.failedRows, ...commitFailures],
        createdCategories: createdCategories,
        createdUnits: createdUnits,
        totalRows: preview.totalRows,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // تحليل الملفات
  // ─────────────────────────────────────────────────────────────────────

  /// محلّل CSV بعربون قوي: BOM، أسطر CRLF، حقول مقتبسة بفواصل داخلية،
  /// اقتباس مزدوج `""`، وفواصل أسطر داخل الحقول المقتبسة.
  List<List<String>> _parseCsv(String text) {
    final clean = text.startsWith('\uFEFF') ? text.substring(1) : text;
    final rows = <List<String>>[];
    var field = StringBuffer();
    var row = <String>[];
    var inQuotes = false;

    void endField() {
      row.add(field.toString());
      field = StringBuffer();
    }

    void endRow() {
      endField();
      rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < clean.length; i++) {
      final ch = clean[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < clean.length && clean[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        endField();
      } else if (ch == '\r') {
        // جزء من CRLF — يُتجاهل (إنتهاء السطر عند \n).
        continue;
      } else if (ch == '\n') {
        endRow();
      } else {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  /// يقرأ الورقة الأولى من ملف xlsx عبر `package:excel`.
  List<List<String>> _parseXlsx(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final name =
        excel.getDefaultSheet() ??
        (excel.tables.keys.isEmpty ? null : excel.tables.keys.first);
    if (name == null) return const [];
    final sheet = excel.tables[name];
    if (sheet == null) return const [];
    return [
      for (final row in sheet.rows) [for (final cell in row) _dataText(cell)],
    ];
  }

  /// نص الخلية من خلية Excel (نص/رقم/تاريخ — القيم الخالية فارغة).
  String _dataText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    return switch (value) {
      final TextCellValue text => text.toString(),
      final IntCellValue number => number.value.toString(),
      final DoubleCellValue number => number.value.toString(),
      _ => value.toString(),
    };
  }

  // ─────────────────────────────────────────────────────────────────────
  // مساعدات التخطيط والتحقق
  // ─────────────────────────────────────────────────────────────────────

  /// يحوّل التخطيط إلى مؤشرات أعمدة (حرف A..Z / AA.. أو رقم 0..n).
  Map<String, int> _resolveMapping(
    Map<String, String> columnMapping,
    String? barcodeColumn,
  ) {
    final resolved = <String, int>{};
    for (final entry in columnMapping.entries) {
      final index = _columnIndex(entry.value);
      if (index != null) resolved[entry.key] = index;
    }
    final barcodeIndex = barcodeColumn == null
        ? null
        : _columnIndex(barcodeColumn);
    if (barcodeIndex != null) resolved['barcode'] = barcodeIndex;
    return resolved;
  }

  /// حرف العمود (A = 0، AA = 26…) أو رقمه النصي مباشرة — وإلا null.
  int? _columnIndex(String spec) {
    final trimmed = spec.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return int.parse(trimmed);
    if (!RegExp(r'^[A-Z]+$').hasMatch(trimmed)) return null;
    var index = 0;
    for (final code in trimmed.codeUnits) {
      index = index * 26 + (code - 0x40);
    }
    return index - 1;
  }

  /// قيمة خلية بمؤشر عمود (خارج النطاق أو غير معيّن = سلسلة فارغة).
  String _cell(List<String> cells, int index) =>
      index >= 0 && index < cells.length ? cells[index] : '';

  /// هل الصف فارغ كلياً (يُتجاهل ولا يُحسب من الإجمالي)؟
  bool _isEmptyRow(List<String> cells) =>
      cells.every((cell) => cell.trim().isEmpty);

  /// يحلّل رقماً عشرياً غير سالب — يضيف سبباً عربياً عند الفشل أو السالب.
  double? _parseAmount(String raw, String label, List<String> reasons) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null; // عمود فارغ = قيمة افتراضية (0/إسقاط).
    final value = double.tryParse(trimmed);
    if (value == null) {
      reasons.add('$label غير رقمي');
      return null;
    }
    if (value < 0) {
      reasons.add('$label لا يمكن أن يكون سالباً');
      return null;
    }
    return value;
  }

  /// كل الباركودات الموجودة (الأرشيف مشمول — التفرد بنائي على الجدول).
  Future<Set<String>> _existingBarcodes() async {
    final rows = await _db.rawQuery(
      'SELECT barcode FROM product WHERE barcode IS NOT NULL',
    );
    return {for (final row in rows) row['barcode'] as String};
  }

  /// أسماء غير الموجودة في جدول مرجعي (فئة/وحدة) — المقترحات الجديدة.
  Future<List<String>> _filterExisting(String table, Set<String> values) async {
    if (values.isEmpty) return const [];
    final rows = await _db.rawQuery('SELECT name FROM $table');
    final existing = {for (final row in rows) row['name'] as String};
    return values.difference(existing).toList()..sort();
  }

  /// معرّف اسم موجود في جدول مرجعي (أو null).
  Future<int?> _existingId(String table, String name) async {
    final rows = await _db.rawQuery(
      'SELECT id FROM $table WHERE name = ? LIMIT 1',
      [name],
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }
}
