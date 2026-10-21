/// اختبار تصدير التقرير إلى Excel (V7-B): البايتات تبدأ ببصمة ZIP
/// (PK) ثم تُعاد فتحها بحزمة excel نفسها ويتحقق من: اسم الورقة
/// العربي المقصوص لحد 31 محرفًا، قيم الخلايا والعناوين العربية،
/// والقيمة الرقمية الخالصة مكتوبة **رقمًا خامًا** (Int/DoubleCellValue)
/// لا نصًا، والرؤوس عريضة.
library;

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/ui/features/reports/services/report_excel_export.dart';

void main() {
  test('يبني مصنف xlsx سليمًا بقيم عربية وأرقام خام', () {
    final bytes = buildReportExcelBytes(
      sheetTitle: 'تقرير المبيعات حسب الصنف',
      headers: const ['اسم الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي'],
      rows: const [
        ['شامبو كلير 400 مل', '3', '1,500', '4500'],
        ['زيت زيتون عائلي', '2', '12.5', '25'],
        ['صابون', '10', 'NaN', '0.25'],
      ],
    );

    // بصمة حاوية xlsx: ZIP يبدأ بـPK.
    expect(String.fromCharCodes(bytes.sublist(0, 2)), 'PK');
    expect(bytes.length, greaterThan(500));

    // إعادة الفتح والتحقق.
    final excel = Excel.decodeBytes(bytes);
    final sheetName = excel.getDefaultSheet() ?? excel.tables.keys.first;
    final sheet = excel[sheetName];

    // صف الرؤوس عربي حرفيًا.
    final headerRow = sheet.rows[0];
    expect(
      [for (final cell in headerRow) cell?.value.toString()],
      ['اسم الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي'],
    );

    // الصف الأول: الكمية 3 رقم صحيح خام، والإجمالي 4500 رقمًا لا نصًا،
    // والسعر «1,500» بفاصلة الآلاف ليس رقميًا خالصًا فيبقى نصًا.
    final row1 = sheet.rows[1];
    expect(row1[0]?.value, isA<TextCellValue>());
    expect((row1[0]?.value as TextCellValue).toString(), 'شامبو كلير 400 مل');
    expect(row1[1]?.value, isA<IntCellValue>());
    expect((row1[1]?.value as IntCellValue).value, 3);
    expect(row1[2]?.value, isA<TextCellValue>());
    expect(row1[3]?.value, isA<IntCellValue>());
    expect((row1[3]?.value as IntCellValue).value, 4500);

    // الصف الثاني: 12.5 و25 أرقام عشرية خامّة.
    final row2 = sheet.rows[2];
    expect(row2[2]?.value, isA<DoubleCellValue>());
    expect((row2[2]?.value as DoubleCellValue).value, 12.5);
    expect(row2[3]?.value, isA<IntCellValue>());

    // الصف الثالث: «NaN» نص (ليست قيمة رقمية سليمة) و0.25 عشري.
    final row3 = sheet.rows[3];
    expect(row3[2]?.value, isA<TextCellValue>());
    expect(row3[3]?.value, isA<DoubleCellValue>());
    expect((row3[3]?.value as DoubleCellValue).value, 0.25);
  });

  test('اسم الورقة يقص عند حد Excel 31 محرفًا وينظف المحارف المحظورة', () {
    const longTitle =
        'تقرير أعمار الديون حسب العميل: حركة/المبيعات? * تفصيلي[ جداً ]طويل';
    final bytes = buildReportExcelBytes(
      sheetTitle: longTitle,
      headers: const ['العميل'],
      rows: const [
        ['أحمد'],
      ],
    );
    final excel = Excel.decodeBytes(bytes);
    final sheetName = excel.tables.keys.single;
    expect(sheetName.length, lessThanOrEqualTo(31));
    for (final banned in [':', '/', '?', '*', '[', ']']) {
      expect(
        sheetName,
        isNot(contains(banned)),
        reason: 'المحرف «$banned» محظور في أسماء أوراق Excel',
      );
    }
    expect(sheetName, startsWith('تقرير أعمار الديون حسب العميل'));
  });

  test('صف ناقص الخلايا يُحشى ولا يكسر البناء، والفراغ يبقى نصًا', () {
    final bytes = buildReportExcelBytes(
      sheetTitle: 'تقرير',
      headers: const ['أ', 'ب', 'ج'],
      rows: const [
        ['قيمة واحدة'],
        [],
      ],
    );
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel[excel.tables.keys.single];
    expect(
      sheet.rows[1].length,
      3,
      reason: 'حشو بقيمة فارغة للعمودين الباقيين',
    );
    expect(sheet.rows[2].length, 3);
    expect(sheet.rows[1][0]?.value.toString(), 'قيمة واحدة');
  });

  test('sanitizeReportFileName يستبدل محارف المسارات بنمط المعاينة', () {
    expect(sanitizeReportFileName('المبيعات حسب الصنف'), 'المبيعات حسب الصنف');
    expect(
      sanitizeReportFileName('تقرير/أعمار: الديون? "العملاء" | 2026'),
      'تقرير-أعمار- الديون- -العملاء- - 2026',
    );
    expect(sanitizeReportFileName('  xxx\\y*z  '), 'xxx-y-z');
  });

  test('اسم ورقة فارغ يسقط لاسم Excel الافتراضي', () {
    final bytes = buildReportExcelBytes(
      sheetTitle: '   ',
      headers: const ['أ'],
      rows: const [
        ['ب'],
      ],
    );
    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.keys.single, 'Sheet1');
  });

  test('الرؤوس عريضة (CellStyle bold) بعد إعادة الفتح', () {
    final bytes = buildReportExcelBytes(
      sheetTitle: 'تقرير',
      headers: const ['الصنف', 'الكمية'],
      rows: const [
        ['شامبو', '3'],
      ],
    );
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel[excel.tables.keys.single];
    final headerCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    expect(headerCell.value.toString(), 'الصنف');
    // نمط الخلية يُقرأ من مصنف مبني ذاتيًا: العلم العريض محفوظ.
    expect(headerCell.cellStyle?.isBold, isTrue);
    final bodyCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
    );
    expect(bodyCell.cellStyle?.isBold ?? false, isFalse);
  });
}
