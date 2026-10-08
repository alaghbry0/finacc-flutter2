/// اختبارات خدمة استيراد الأصناف — FR-01-13 / AC-14: تحليل CSV/xlsx
/// بالعربية والاقتباسات، التحقق صفاً صفاً، الإقرار الإلزامي عند وجود
/// صفوف فاشلة، والالتزام الجزئي للصفوف الصالحة فقط.
library;

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/services/item_import_service.dart';
import 'package:mobile_app/domain/models/company.dart';
import 'package:mobile_app/domain/models/item.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase handle;
  late ItemImportService service;
  late CompanyRepository companies;
  late List<Currency> currencies;
  late int warehouseId;
  late int userId;
  late int yerId;
  final at = DateTime.utc(2026, 10, 6, 12);

  setUp(() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    companies = seeded.$2;
    service = ItemImportService(handle.db);
    currencies = await companies.listActiveCurrencies();
    warehouseId =
        (await handle.db.rawQuery('SELECT id FROM warehouse LIMIT 1'))
                .first['id']
            as int;
    userId =
        (await handle.db.rawQuery('SELECT id FROM app_user LIMIT 1'))
                .first['id']
            as int;
    yerId = currencies.firstWhere((c) => c.code == 'YER').id;
  });

  tearDown(() async {
    await handle.close();
  });

  group('parseAndValidate — التحليل بلا كتابة', () {
    test('CSV عربي: BOM وأسطر CRLF وفاصلة داخل اقتباس واقتباس مزدوج', () async {
      const csv =
          '\uFEFFالاسم,الباركود,التكلفة,سعر YER,الكمية\r\n'
          '"أرز, بسمتي ""الفاخر""",2000000000008,4500,5000,20\r\n'
          'عدس أحمر,2999999999991,3000,3500,10\r\n';
      final preview = await service.parseAndValidate(
        csv,
        warehouseId: warehouseId,
        columnMapping: const {
          'name': 'A',
          'barcode': 'B',
          'cost': 'C',
          'price_yer': 'D',
          'qty': 'E',
        },
        activeCurrencies: currencies,
      );
      expect(preview.failedRows, isEmpty);
      expect(preview.totalRows, 2);
      expect(preview.validRows.first.draft.name, 'أرز, بسمتي "الفاخر"');
      expect(preview.validRows.first.draft.barcode, '2000000000008');
      expect(preview.validRows.first.draft.costPrice, 4500);
      expect(preview.validRows.first.draft.openingQty, 20);
      expect(preview.validRows.first.draft.prices.single.currencyId, yerId);
      expect(preview.validRows.first.draft.prices.single.price, 5000);
      // لا كتابة إطلاقاً في مرحلة المعاينة.
      expect(await handle.db.query('product'), isEmpty);
      expect(
        await handle.db.query('audit_log', where: "action = 'items_import'"),
        isEmpty,
      );
    });

    test('بارامتر barcodeColumn يتقدم على التخطيط + مؤشرات رقمية', () async {
      const csv = 'الاسم,الكود\r\nشاي أخضر,2000000000008\r\n';
      final preview = await service.parseAndValidate(
        csv,
        warehouseId: warehouseId,
        columnMapping: const {'name': '0'},
        barcodeColumn: 'B',
        activeCurrencies: currencies,
      );
      expect(preview.validRows.single.draft.barcode, '2000000000008');

      const numeric = 'name,cost\r\nشاي,50\r\n';
      final numericPreview = await service.parseAndValidate(
        numeric,
        warehouseId: warehouseId,
        columnMapping: const {'name': '0', 'cost': '1'},
        activeCurrencies: currencies,
      );
      expect(numericPreview.validRows.single.draft.costPrice, 50);
    });

    test(
      'أسباب الفشل: الاسم والسالب وغير الرقمي وتكرار الباركود والعملة',
      () async {
        // باركود موجود مسبقاً في القاعدة.
        final items = ItemRepository(handle.db);
        await items.createItem(
          const ItemDraft(name: 'موجود', barcode: '2000000000008'),
          warehouseId: warehouseId,
          userId: userId,
          now: at,
        );

        const csv =
            'name,barcode,cost,qty,price_yer,price_eur\r\n'
            'صالح,2000000000015,100,5,120,\r\n' // الصف 2 — صالح.
            ',,,10,,\r\n' // الصف 3 — اسم فارغ (وبقية الحقول ليست فارغة كلياً).
            'سالب,,,,-5,\r\n' // الصف 4 — سعر سالب.
            'غير رقمي,,-5,,,\r\n' // الصف 5 — تكلفة سالبة.
            'نصي,,ABC,,,\r\n' // الصف 6 — تكلفة غير رقمية.
            'مكرر,2000000000022,,,,\r\n' // الصف 7 — أول استعمال.
            'مكرر ثانٍ,2000000000022,,,,\r\n' // الصف 8 — تكرار داخل الملف.
            'من القاعدة,2000000000008,,,,\r\n' // الصف 9 — موجود بالقاعدة.
            'عملة,2000000000039,,,,10\r\n'; // الصف 10 — EUR غير معروفة.
        final preview = await service.parseAndValidate(
          csv,
          warehouseId: warehouseId,
          columnMapping: const {
            'name': 'A',
            'barcode': 'B',
            'cost': 'C',
            'qty': 'D',
            'price_yer': 'E',
            'price_eur': 'F',
          },
          activeCurrencies: currencies,
        );

        expect(preview.totalRows, 9);
        expect(preview.validRows, hasLength(2)); // «صالح» + «مكرر» أول استعمال.
        expect(preview.validRows.first.draft.name, 'صالح');

        final failures = {
          for (final failure in preview.failedRows)
            failure.rowNumber: failure.reason,
        };
        expect(failures[3], 'اسم الصنف مطلوب');
        expect(failures[4], contains('سالباً'));
        expect(failures[5], contains('سالباً'));
        expect(failures[6], 'سعر التكلفة غير رقمي');
        expect(failures[7], isNull, reason: 'أول استعمال للباركود صالح');
        expect(failures[8], contains('مكرر داخل الملف (الصف 7)'));
        expect(failures[9], contains('مستخدم لصنف موجود'));
        expect(failures[10], 'عملة eur غير معروفة');
      },
    );

    test('فئات ووحدات مقترحة + تجاهل الصفوف الفارغة', () async {
      const csv =
          'name,category,unit\r\n'
          'صنف واحد,مواد غذائية,كرتون\r\n'
          '\r\n'
          'صنف ثانٍ,مواد غذائية,\r\n';
      final preview = await service.parseAndValidate(
        csv,
        warehouseId: warehouseId,
        columnMapping: const {'name': 'A', 'category': 'B', 'unit': 'C'},
        activeCurrencies: currencies,
      );
      expect(preview.totalRows, 2, reason: 'الصف الفارغ لا يُحسب');
      expect(preview.suggestedNewCategories, ['مواد غذائية']);
      expect(preview.suggestedNewUnits, ['كرتون']);
      expect(preview.validRows.first.categoryName, 'مواد غذائية');
      expect(preview.validRows.first.unitName, 'كرتون');
      expect(preview.validRows.last.unitName, isNull);
    });

    test('xlsx: خلايا نصية ورقمية عبر package:excel', () async {
      final excel = Excel.createExcel();
      final sheet = excel.getDefaultSheet()!;
      excel.appendRow(sheet, [
        TextCellValue('الاسم'),
        TextCellValue('التكلفة'),
        TextCellValue('سعر YER'),
      ]);
      excel.appendRow(sheet, [
        TextCellValue('شامبو'),
        IntCellValue(800),
        DoubleCellValue(1200.5),
      ]);
      final bytes = excel.encode();

      final preview = await service.parseAndValidate(
        bytes!,
        warehouseId: warehouseId,
        columnMapping: const {'name': 'A', 'cost': 'B', 'price_yer': 'C'},
        activeCurrencies: currencies,
      );
      expect(preview.totalRows, 1);
      expect(preview.validRows.single.draft.name, 'شامبو');
      expect(preview.validRows.single.draft.costPrice, 800);
      expect(preview.validRows.single.draft.prices.single.price, 1200.5);
    });

    test('مصدر غير مدعوم → ArgumentError', () async {
      expect(
        () => service.parseAndValidate(
          42,
          warehouseId: warehouseId,
          columnMapping: const {'name': 'A'},
          activeCurrencies: currencies,
        ),
        throwsArgumentError,
      );
    });
  });

  group('commitValid — الالتزام (AC-14)', () {
    test('الإقرار الإلزامي عند وجود صفوف فاشلة ثم الالتزام الجزئي', () async {
      // 100 صف بيانات — 17 فاشلة (اسم فارغ ×16 + كمية سالبة ×1).
      final broken = StringBuffer('name,barcode,cost,qty\r\n');
      for (var i = 1; i <= 100; i++) {
        if (i == 7) {
          broken.writeln('صنف $i,9000000000007,100,-5');
        } else if (i % 6 == 0) {
          broken.writeln(',90000000000$i,100,10');
        } else {
          broken.writeln('صنف $i,80000000000$i,100,10');
        }
      }
      final preview = await service.parseAndValidate(
        broken.toString(),
        warehouseId: warehouseId,
        columnMapping: const {
          'name': 'A',
          'barcode': 'B',
          'cost': 'C',
          'qty': 'D',
        },
        activeCurrencies: currencies,
      );
      expect(preview.totalRows, 100);
      expect(preview.failedRows, hasLength(17));
      expect(preview.validRows, hasLength(83));
      // أسباب الفشل كلها مذكورة.
      for (final failure in preview.failedRows) {
        expect(failure.reason, isNotEmpty);
      }
      expect(
        preview.failedRows.every(
          (f) => f.reason == 'اسم الصنف مطلوب' || f.reason.contains('سالباً'),
        ),
        isTrue,
      );

      // رفض دون إقرار — ولا صف واحد يُدرج (AC-14).
      final refused = await service.commitValid(
        preview,
        warehouseId: warehouseId,
        userId: userId,
        confirmed: false,
        now: at,
      );
      expect(refused.errorOrNull, 'يوجد صفوف فاشلة — الإقرار مطلوب');
      expect(await handle.db.query('product'), isEmpty);
      expect(
        await handle.db.query('audit_log', where: "action = 'items_import'"),
        isEmpty,
      );

      // الإقرار → إدراج الصالحة فقط.
      final committed = await service.commitValid(
        preview,
        warehouseId: warehouseId,
        userId: userId,
        confirmed: true,
        now: at,
      );
      expect(committed.isOk, isTrue);
      final result = committed.valueOrNull!;
      expect(result.inserted, 83);
      expect(result.failures, hasLength(17));
      expect(result.totalRows, 100);

      expect(await handle.db.query('product'), hasLength(83));
      // مخزون افتتاحي للأصناف المدرجة.
      expect(await handle.db.query('stock_level'), hasLength(83));
      // قيد تدقيق واحد بالعدادين.
      final audit = await handle.db.query(
        'audit_log',
        where: "action = 'items_import'",
      );
      expect(audit, hasLength(1));
      expect(audit.first['details'], 'ok=83 failed=17');
      expect(audit.first['user_id'], userId);

      // إعادة الاستيراد بعد إصلاح الملف: نجاح كامل.
      final fixed = StringBuffer('name,barcode,cost,qty\r\n');
      for (var i = 1; i <= 100; i++) {
        fixed.writeln('صنف مصلح $i,70000000000$i,100,10');
      }
      final fixedPreview = await service.parseAndValidate(
        fixed.toString(),
        warehouseId: warehouseId,
        columnMapping: const {
          'name': 'A',
          'barcode': 'B',
          'cost': 'C',
          'qty': 'D',
        },
        activeCurrencies: currencies,
      );
      expect(fixedPreview.failedRows, isEmpty);
      expect(fixedPreview.isClean, isTrue);

      final recommitted = await service.commitValid(
        fixedPreview,
        warehouseId: warehouseId,
        userId: userId,
        confirmed: true,
        now: at,
      );
      expect(recommitted.valueOrNull!.inserted, 100);
      expect(await handle.db.query('product'), hasLength(183));
    });

    test('إنشاء الفئات والوحدات الناقصة وربطها بالأصناف', () async {
      const csv =
          'name,category,unit\r\n'
          'أرز,مواد غذائية,كرتون\r\n'
          'شاي,مشروبات,كرتون\r\n';
      final preview = await service.parseAndValidate(
        csv,
        warehouseId: warehouseId,
        columnMapping: const {'name': 'A', 'category': 'B', 'unit': 'C'},
        activeCurrencies: currencies,
      );
      final committed = await service.commitValid(
        preview,
        warehouseId: warehouseId,
        userId: userId,
        confirmed: true,
        now: at,
      );
      final result = committed.valueOrNull!;
      expect(result.inserted, 2);
      expect(result.createdCategories, 2);
      expect(result.createdUnits, 1);

      // الربط الفعلي: كل صنف يشير لفئته ووحدته.
      final linked = await handle.db.rawQuery('''
        SELECT p.name AS p_name, c.name AS c_name, u.name AS u_name
        FROM product p
        LEFT JOIN category c ON c.id = p.category_id
        LEFT JOIN unit u ON u.id = p.unit_id
        ORDER BY p.name
      ''');
      expect(linked, hasLength(2));
      expect(linked.first['c_name'], 'مواد غذائية');
      expect(linked.first['u_name'], 'كرتون');
      expect(linked.last['c_name'], 'مشروبات');
    });

    test('ملف نظيف بلا صفوف فاشلة يلتزم دون إقرار', () async {
      const csv = 'name\r\nصنف وحيد\r\n';
      final preview = await service.parseAndValidate(
        csv,
        warehouseId: warehouseId,
        columnMapping: const {'name': 'A'},
        activeCurrencies: currencies,
      );
      final committed = await service.commitValid(
        preview,
        warehouseId: warehouseId,
        userId: userId,
        confirmed: false, // لا فشل → لا حاجة للإقرار.
        now: at,
      );
      expect(committed.valueOrNull!.inserted, 1);
      // باركود تلقائي EAN-13 صالح.
      final barcode =
          (await handle.db.query(
                'product',
                columns: ['barcode'],
              )).first['barcode']
              as String;
      expect(
        RegExp(r'^2\d{12}$').hasMatch(barcode),
        isTrue,
        reason: 'توليد تلقائي عند فراغ عمود الباركود',
      );
    });
  });
}
