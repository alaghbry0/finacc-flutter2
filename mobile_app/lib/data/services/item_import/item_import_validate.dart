/// المرحلة 1 من الاستيراد — التحليل والتحقق (بلا أي كتابة) — جزء من
/// تقسيم R20-D3a لخدمة الاستيراد (نمط R19-D3d): منقول حرفياً من
/// item_import_service.dart (الواجهة العامة والسلوك ثابتان — الخدمة
/// تفوِّض بتواقيعها نفسها) مع مساعدات التخطيط والتحقق الخاصة بها.
library;

import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/company.dart';
import '../../../domain/models/item.dart';
import 'item_import_file_parsers.dart';
import 'item_import_models.dart';

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
Future<ItemImportPreview> parseAndValidateImport(
  Database db,
  Object source, {
  required int warehouseId,
  required Map<String, String> columnMapping,
  required List<Currency> activeCurrencies,
  String? barcodeColumn,
}) async {
  final rows = switch (source) {
    final String text => parseImportCsv(text),
    final Uint8List bytes => parseImportXlsx(bytes),
    final List<int> bytes => parseImportXlsx(Uint8List.fromList(bytes)),
    _ => throw ArgumentError(
      'مصدر الاستيراد يجب أن يكون نص CSV أو بايتات xlsx',
    ),
  };

  // فك الأعمدة من التخطيط (حرف أو رقم — أول صف بيانات بعد الرأس).
  final mapping = _resolveMapping(columnMapping, barcodeColumn);
  final existingBarcodes = await _existingBarcodes(db);
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

  final suggestedCategories = await _filterExisting(db, 'category', categories);
  final suggestedUnits = await _filterExisting(db, 'unit', units);
  return ItemImportPreview(
    totalRows: validRows.length + failures.length,
    validRows: validRows,
    failedRows: failures,
    suggestedNewCategories: suggestedCategories,
    suggestedNewUnits: suggestedUnits,
    warehouseId: warehouseId,
  );
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
Future<Set<String>> _existingBarcodes(Database db) async {
  final rows = await db.rawQuery(
    'SELECT barcode FROM product WHERE barcode IS NOT NULL',
  );
  return {for (final row in rows) row['barcode'] as String};
}

/// أسماء غير الموجودة في جدول مرجعي (فئة/وحدة) — المقترحات الجديدة.
Future<List<String>> _filterExisting(
  Database db,
  String table,
  Set<String> values,
) async {
  if (values.isEmpty) return const [];
  final rows = await db.rawQuery('SELECT name FROM $table');
  final existing = {for (final row in rows) row['name'] as String};
  return values.difference(existing).toList()..sort();
}
