/// حسابات استيراد الأصناف النقية (تخمين الربط من الرأس + قراءة مصادر
/// CSV/Excel) — مستخرجة من import_view_model (R20-D3c: نقل حرفي بلا أي
/// تغيير سلوكي؛ دوال الفئة الخاصة صارت علوية بادئة import).
library;

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../../../../domain/models/company.dart';

/// يخمّن الربط من رأس الجدول (عربي/إنجليزي — تام ثم جزئي للأسعار).
Map<String, String> importGuessMapping(
  List<String> headers,
  List<Currency> currencies,
) {
  final normalized = [
    for (final header in headers) header.trim().toLowerCase(),
  ];
  final taken = <int>{};
  final mapping = <String, String>{};

  String? claimExact(Set<String> candidates) {
    for (var i = 0; i < normalized.length; i++) {
      if (taken.contains(i)) continue;
      if (candidates.contains(normalized[i])) {
        taken.add(i);
        return _columnLetter(i);
      }
    }
    return null;
  }

  final name = claimExact(const {
    'name',
    'الاسم',
    'اسم',
    'اسم الصنف',
    'اسم المنتج',
    'الصنف',
    'المنتج',
    'item',
    'product',
    'item name',
    'product name',
  });
  if (name != null) mapping['name'] = name;
  final barcode = claimExact(const {
    'barcode',
    'bar code',
    'bar-code',
    'الباركود',
    'باركود',
    'الرمز',
    'الشفرة',
    'code',
    'ean',
    'sku',
  });
  if (barcode != null) mapping['barcode'] = barcode;
  final cost = claimExact(const {
    'cost',
    'costprice',
    'cost price',
    'cost_price',
    'التكلفة',
    'تكلفة',
    'سعر التكلفة',
    'سعر الشراء',
  });
  if (cost != null) mapping['cost'] = cost;
  final qty = claimExact(const {
    'qty',
    'quantity',
    'openingqty',
    'opening qty',
    'opening_qty',
    'الكمية',
    'كمية',
    'الكمية الافتتاحية',
    'المتوفر',
    'الرصيد',
    'المخزون',
  });
  if (qty != null) mapping['qty'] = qty;
  final minStock = claimExact(const {
    'minstock',
    'min stock',
    'min_stock',
    'min',
    'الحد',
    'الحد الأدنى',
    'حد الطلب',
    'حد إعادة الطلب',
    'حد الطلب الأدنى',
  });
  if (minStock != null) mapping['min_stock'] = minStock;
  final category = claimExact(const {
    'category',
    'cat',
    'الفئة',
    'فئة',
    'التصنيف',
    'تصنيف',
  });
  if (category != null) mapping['category'] = category;
  final unit = claimExact(const {
    'unit',
    'units',
    'الوحدة',
    'وحدة',
    'وحدة القياس',
    'وحدة الصنف',
  });
  if (unit != null) mapping['unit'] = unit;
  final notes = claimExact(const {
    'notes',
    'note',
    'ملاحظات',
    'الملاحظات',
    'وصف',
    'الوصف',
    'description',
  });
  if (notes != null) mapping['notes'] = notes;

  // الأسعار: عام (سعر/price) للأساسية أولاً، ثم الخاص بكل عملة
  // (price_yer / سعر yer / اسم العملة أو ميزتها الجزئي).
  final base = currencies.isEmpty ? null : currencies.first;
  if (base != null) {
    final generic = claimExact(const {
      'price',
      'سعر',
      'سعر البيع',
      'السعر',
      'سعر بيع',
      'سعر البيع ',
      'sale price',
      'saleprice',
      'retail',
      'retail price',
    });
    if (generic != null) mapping['price_${base.code}'] = generic;
  }
  for (final currency in currencies) {
    final code = currency.code.toLowerCase();
    final token = currency.name.trim().split(' ').last; // يمني/سعودي/…
    var letter = claimExact({
      'price_$code',
      'سعر $code',
      'سعر_$code',
      'سعر ${currency.name}',
      currency.name,
      code,
    });
    if (letter == null) {
      // تمريرة جزئية: عمود يحمل اسم العملة أو رمزها ولم يُحجز بعد.
      for (var i = 0; i < normalized.length; i++) {
        if (taken.contains(i)) continue;
        final header = normalized[i];
        final isPriceish = header.contains('price') || header.contains('سعر');
        final matchesCurrency =
            header.contains(code) ||
            header.contains(currency.name) ||
            (token.length > 2 && header.contains(token));
        if (isPriceish && matchesCurrency) {
          taken.add(i);
          letter = _columnLetter(i);
          break;
        }
      }
    }
    if (letter != null) mapping['price_${currency.code}'] = letter;
  }
  return mapping;
}

/// حرف العمود (A = 0، AA = 26…) — صيغة خدمة الاستيراد.
String _columnLetter(int index) {
  var letter = '';
  var i = index;
  while (i >= 0) {
    letter = String.fromCharCode(0x41 + (i % 26)) + letter;
    i = (i ~/ 26) - 1;
  }
  return letter;
}

/// محلّل CSV بعربون قوي (BOM / CRLF / اقتباسات / فواصل داخلية) —
/// نفس خوارزمية خدمة الاستيراد (خاصة هناك — نسخة عرضية هنا للرأس).
List<List<String>> importParseCsvRows(String text) {
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

/// يقرأ صفوف الورقة الأولى من xlsx (للرأس وعدد الأسطر).
List<List<String>> importReadXlsxRows(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final name =
      excel.getDefaultSheet() ??
      (excel.tables.keys.isEmpty ? null : excel.tables.keys.first);
  if (name == null) return const [];
  final sheet = excel.tables[name];
  if (sheet == null) return const [];
  return [
    for (final row in sheet.rows) [for (final cell in row) _cellText(cell)],
  ];
}

/// نص خلية Excel (نص/رقم — الفارغ '').
String _cellText(Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  return switch (value) {
    final TextCellValue text => text.toString(),
    final IntCellValue number => number.value.toString(),
    final DoubleCellValue number => number.value.toString(),
    final other => other.toString(),
  };
}
