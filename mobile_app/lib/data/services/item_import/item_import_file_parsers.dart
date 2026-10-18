/// محلّلات ملفات الاستيراد (CSV/XLSX → صفوف نصية) — جزء من تقسيم
/// R20-D3a لخدمة الاستيراد (نمط R19-D3d): منقولة حرفياً من
/// item_import_service.dart (الخاصّيان `_parseCsv`/`_parseXlsx` صارا
/// عامين بأسماء مميزة — الخدمة تفوِّض بتواقيعها نفسها).
library;

import 'dart:typed_data';

import 'package:excel/excel.dart';

/// محلّل CSV بعربون قوي: BOM، أسطر CRLF، حقول مقتبسة بفواصل داخلية،
/// اقتباس مزدوج `""`، وفواصل أسطر داخل الحقول المقتبسة.
List<List<String>> parseImportCsv(String text) {
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
List<List<String>> parseImportXlsx(Uint8List bytes) {
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
