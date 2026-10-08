/// اختبارات مستودع أعمار الديون (FR-09-05): تصنيف مستحقات العملاء
/// على دلاء (٠–٣٠ / ٣١–٦٠ / ٦١–٩٠ / +٩٠) بأساس FIFO — أي فواتير البيع
/// المكتملة ذات `due_amount > 0` (المتبقي بعد تخصيص الدفعات الأقدم
/// أولاً — راجع رأس `DebtAgingRepository`).
///
/// تُحقن صفوف فواتير خامّة بتواريخ استحقاق مضبوطة نسبة إلى لحظة
/// احتساب ثابتة (2026-11-15) للتحقق من:
/// حدود الدلاء باليوم، مرجع الاستحقاق عند غيابه (issued_at)، الدمج
/// السالب (غير المستحق بعد) في دلو ٠–٣٠ مع تتبّعه، التجميع لكل عميل
/// والترتيب بالأكبر ديناً، تفاصيل الفواتير، فلترة العملة، واستبعاد
/// المسودات/الإبطالات/المسددة/المرتجعات/المشتريات.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/debt_aging_repository.dart';
import 'package:sqflite/sqflite.dart';

import '../helpers/app_for_tests.dart';

/// لحظة الاحتساب الثابتة لكل الاختبارات — منتصف ليل UTC.
final DateTime _asOf = DateTime.utc(2026, 11, 15);

var _docCounter = 0;

/// يحقن صف عميل خاماً بهاتف/واتساب اختياريين (بيانات التذكير).
Future<int> seedCustomer(
  Database db, {
  required String name,
  String? phone,
  String? whatsapp,
}) {
  return db.insert('customer', {
    'name': name,
    'phone': phone,
    'whatsapp': whatsapp,
    'is_archived': 0,
  });
}

/// يحقن صف فاتورة خاماً بقيم صالحة للقيود الرقمية (CHECK).
///
/// [dueDate] هو مرجع العمر عند وجوده وإلا [issuedAt] (شروط الائتمان)؛
/// [paidAmount] يُشتق تلقائياً من total − dueAmount عند غيابه.
Future<int> seedInvoice(
  Database db, {
  required int warehouseId,
  required int customerId,
  required int currencyId,
  required double dueAmount,
  double? total,
  double? paidAmount,
  DateTime? issuedAt,
  DateTime? dueDate,
  String docType = 'sale',
  String status = 'completed',
}) {
  final effectiveTotal = total ?? dueAmount;
  return db.insert('invoice', {
    'invoice_no': 'AG-${_docCounter++}',
    'doc_type': docType,
    'pay_status': dueAmount > 0 ? 'credit' : 'cash',
    'status': status,
    'issued_at': (issuedAt ?? DateTime.utc(2026, 11, 1, 9)).toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'warehouse_id': warehouseId,
    'customer_id': customerId,
    'currency_id': currencyId,
    'exchange_rate': 1,
    'total': effectiveTotal,
    'paid_amount': paidAmount ?? effectiveTotal - dueAmount,
    'due_amount': dueAmount,
  });
}

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late Database db;
  late DebtAgingRepository repo;
  late int warehouseId;
  late int yer;
  late int sar;
  late int usd;

  setUp(() async {
    app = (await openSeededApp()).$1;
    db = app.db;
    repo = DebtAgingRepository(db);
    warehouseId = (await db.query('warehouse', limit: 1)).first['id'] as int;
    final currencies = {
      for (final row in await db.query('currency'))
        row['code'] as String: row['id'] as int,
    };
    yer = currencies['YER']!;
    sar = currencies['SAR']!;
    usd = currencies['USD']!;
  });

  tearDown(() async {
    await app.close();
  });

  // ── حدود الدلاء باليوم (حرفياً أصناف SRS الأربعة) ─────────────────

  test(
    'حدود الدلاء: ٠/٣٠ في ٠–٣٠، ٣١/٦٠ في ٣١–٦٠، ٦١/٩٠ في ٦١–٩٠، ٩١+ في +٩٠',
    () async {
      final customer = await seedCustomer(db, name: 'حدود الدلاء');

      // كل فاتورة صادرة قبل استحقاقها بـ٣٠ يوماً — المرجع هو due_date.
      Future<void> atDue(DateTime due, double amount) => seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: customer,
        currencyId: yer,
        dueAmount: amount,
        issuedAt: due.subtract(const Duration(days: 30)),
        dueDate: due,
      );

      // ٠ يوماً (يستحق اليوم) و٣٠ → دلو ٠–٣٠.
      await atDue(DateTime.utc(2026, 11, 15), 15); // 0
      await atDue(DateTime.utc(2026, 10, 16), 30); // 30
      // ٣١ و٦٠ → دلو ٣١–٦٠.
      await atDue(DateTime.utc(2026, 10, 15), 31); // 31
      await atDue(DateTime.utc(2026, 9, 16), 60); // 60
      // ٦١ و٩٠ → دلو ٦١–٩٠.
      await atDue(DateTime.utc(2026, 9, 15), 61); // 61
      await atDue(DateTime.utc(2026, 8, 17), 90); // 90
      // ٩١ → دلو +٩٠.
      await atDue(DateTime.utc(2026, 8, 16), 91); // 91

      final report = await repo.agingReport(currencyId: yer, asOf: _asOf);
      expect(report.rows, hasLength(1));
      final row = report.rows.single;
      expect(row.bucket0to30, closeTo(45, 0.001));
      expect(row.bucket31to60, closeTo(91, 0.001));
      expect(row.bucket61to90, closeTo(151, 0.001));
      expect(row.bucket90Plus, closeTo(91, 0.001));
      expect(row.total, closeTo(378, 0.001));
      expect(row.currentNotDue, 0, reason: 'لا شيء غير مستحق في هذا السيناريو');
      // المجاميع العامة مطابقة للسطر الوحيد.
      expect(report.total0to30, closeTo(45, 0.001));
      expect(report.total31to60, closeTo(91, 0.001));
      expect(report.total61to90, closeTo(151, 0.001));
      expect(report.total90Plus, closeTo(91, 0.001));
      expect(report.grandTotal, closeTo(378, 0.001));
      expect(report.customersCount, 1);
      // تفاصيل الأيام نفسها مرتبة بالإصدار (الأقدم أولاً) — كل فاتورة
      // صودرت قبل استحقاقها بـ٣٠ يوماً فيعكس الترتيب أعماراً معكوسة.
      expect(
        row.details.map((detail) => detail.daysPastDue).toList(),
        orderedEquals(const [91, 90, 61, 60, 31, 30, 0]),
        reason: 'الترتيب بـ issued_at التصاعدي لا بالأعمار',
      );
    },
  );

  test(
    'الأعمار السالبة (غير مستحق بعد) تُدمج في ٠–٣٠ وتُتتبَّع في currentNotDue',
    () async {
      final customer = await seedCustomer(db, name: 'آجل فقط');

      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: customer,
        currencyId: yer,
        dueAmount: 425,
        issuedAt: DateTime.utc(2026, 11, 1),
        dueDate: DateTime.utc(2026, 12, 10), // −٢٥ يوماً
      );
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: customer,
        currencyId: yer,
        dueAmount: 130,
        issuedAt: DateTime.utc(2026, 11, 1),
        dueDate: DateTime.utc(2026, 12, 15), // −٣٠ يوماً
      );

      final report = await repo.agingReport(currencyId: yer, asOf: _asOf);
      final row = report.rows.single;
      expect(row.bucket0to30, closeTo(555, 0.001));
      expect(row.currentNotDue, closeTo(555, 0.001));
      expect(row.bucket31to60, 0);
      expect(row.bucket61to90, 0);
      expect(row.bucket90Plus, 0);
      expect(row.total, closeTo(555, 0.001));
      expect(report.currentNotDue, closeTo(555, 0.001));
      expect(
        row.details.first.daysPastDue,
        -25,
        reason: 'أقدم إصدار أولاً (نفس يوم الإصدار — بترتيب الصف بالمعرّف)',
      );
    },
  );

  // ── التجميع والترتيب والتفاصيل والاستبعادات ───────────────────────

  test(
    'تجميع العملاء وترتيبهم بالأكبر ديناً وتفاصيلهم وأرقام تذكيرهم',
    () async {
      // عميل بواتساب — أربعة دلاء كاملة (١٢٣/٧٥/٤٥/١٠ يوماً).
      final ahmed = await seedCustomer(
        db,
        name: 'أحمد الذهب',
        whatsapp: '777123456',
      );
      // عميل بهاتف فقط — آجل غير مستحق + سقوط على issued_at (بلا due_date).
      final bayt = await seedCustomer(
        db,
        name: 'بيت التجارة',
        phone: '733445566',
      );
      // عميل بلا أي رقم — دين عميق (+٩٠).
      final saeed = await seedCustomer(db, name: 'سعيد بلا رقم');

      // أحمد: ١٢٣ يوماً (+٩٠) ١٢٠.
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: ahmed,
        currencyId: yer,
        dueAmount: 120,
        issuedAt: DateTime.utc(2026, 7, 1),
        dueDate: DateTime.utc(2026, 7, 15),
      );
      // أحمد: ٧٥ يوماً (٦١–٩٠) ٢٥٠.
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: ahmed,
        currencyId: yer,
        dueAmount: 250,
        issuedAt: DateTime.utc(2026, 8, 20),
        dueDate: DateTime.utc(2026, 9, 1),
      );
      // أحمد: ٤٥ يوماً (٣١–٦٠) ٥٠٠ — مسددة جزئياً (total=800/paid=300).
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: ahmed,
        currencyId: yer,
        dueAmount: 500,
        total: 800,
        issuedAt: DateTime.utc(2026, 9, 1),
        dueDate: DateTime.utc(2026, 10, 1),
      );
      // أحمد: ١٠ أيام (٠–٣٠) ١٠٠٠.
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: ahmed,
        currencyId: yer,
        dueAmount: 1000,
        issuedAt: DateTime.utc(2026, 9, 15),
        dueDate: DateTime.utc(2026, 11, 5),
      );

      // بيت التجارة: −٢٥ (٠–٣٠ + غير مستحق) ٤٠٠.
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: bayt,
        currencyId: yer,
        dueAmount: 400,
        issuedAt: DateTime.utc(2026, 11, 10),
        dueDate: DateTime.utc(2026, 12, 10),
      );
      // بيت التجارة: بلا due_date → المرجع issued_at (١٤ يوماً → ٠–٣٠) ٢٠٠.
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: bayt,
        currencyId: yer,
        dueAmount: 200,
        issuedAt: DateTime.utc(2026, 11, 1),
      );

      // سعيد: ١٨٩ يوماً (+٩٠) ٧٠٠.
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: saeed,
        currencyId: yer,
        dueAmount: 700,
        issuedAt: DateTime.utc(2026, 5, 1),
        dueDate: DateTime.utc(2026, 5, 10),
      );

      // ── المستبعدات كلها على حساب أحمد (لو دخل أي منها لفسدت الأرقام) ──
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: ahmed,
        currencyId: yer,
        dueAmount: 999,
        status: 'draft',
        issuedAt: DateTime.utc(2026, 9, 10),
        dueDate: DateTime.utc(2026, 10, 10),
      );
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: ahmed,
        currencyId: yer,
        dueAmount: 888,
        status: 'void',
        issuedAt: DateTime.utc(2026, 9, 10),
        dueDate: DateTime.utc(2026, 6, 10),
      );
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: ahmed,
        currencyId: yer,
        dueAmount: 0,
        total: 500,
        issuedAt: DateTime.utc(2026, 9, 10),
        dueDate: DateTime.utc(2026, 10, 10),
      );
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: ahmed,
        currencyId: yer,
        dueAmount: 300,
        docType: 'sale_return',
        issuedAt: DateTime.utc(2026, 9, 10),
        dueDate: DateTime.utc(2026, 10, 10),
      );
      await seedInvoice(
        db,
        warehouseId: warehouseId,
        customerId: ahmed,
        currencyId: yer,
        dueAmount: 777,
        docType: 'purchase',
        issuedAt: DateTime.utc(2026, 9, 10),
        dueDate: DateTime.utc(2026, 10, 10),
      );

      final report = await repo.agingReport(currencyId: yer, asOf: _asOf);

      // الترتيب بالأكبر ديناً: أحمد ١٨٧٠ > سعيد ٧٠٠ > بيت التجارة ٦٠٠.
      expect(report.rows.map((row) => row.name).toList(), [
        'أحمد الذهب',
        'سعيد بلا رقم',
        'بيت التجارة',
      ]);

      // سطر أحمد — أرقام التذكير (واتساب) والدلاء الأربعة كاملة.
      final ahmedRow = report.rows[0];
      expect(ahmedRow.whatsapp, '777123456');
      expect(ahmedRow.bucket0to30, closeTo(1000, 0.001));
      expect(ahmedRow.bucket31to60, closeTo(500, 0.001));
      expect(ahmedRow.bucket61to90, closeTo(250, 0.001));
      expect(ahmedRow.bucket90Plus, closeTo(120, 0.001));
      expect(ahmedRow.total, closeTo(1870, 0.001));
      // التفاصيل: الأقدم إصداراً أولاً (١٢٣ → ٧٥ → ٤٥ → ١٠) والمسددة
      // جزئياً يظهر متبقيها فقط (FIFO).
      expect(ahmedRow.details, hasLength(4));
      expect(
        ahmedRow.details.map((detail) => detail.daysPastDue).toList(),
        orderedEquals(const [123, 75, 45, 10]),
      );
      expect(
        ahmedRow.details.map((detail) => detail.dueAmount).toList(),
        orderedEquals(const [120, 250, 500, 1000]),
      );
      final partiallyPaid = ahmedRow.details[2];
      expect(partiallyPaid.dueAmount, closeTo(500, 0.001));
      expect(partiallyPaid.invoiceNo, startsWith('AG-'));
      expect(partiallyPaid.dueDate, DateTime.utc(2026, 10, 1));

      // سطر سعيد — بلا أي رقم للواتساب، دلو +٩٠ فقط.
      final saeedRow = report.rows[1];
      expect(saeedRow.phone, isNull);
      expect(saeedRow.whatsapp, isNull);
      expect(saeedRow.bucket90Plus, closeTo(700, 0.001));
      expect(saeedRow.bucket0to30, 0);
      expect(saeedRow.total, closeTo(700, 0.001));

      // سطر بيت التجارة — هاتف فقط، الجاري غير المستحق داخل ٠–٣٠،
      // والفاتورة بلا due_date سقطت على issued_at (١٤ يوماً).
      final baytRow = report.rows[2];
      expect(baytRow.phone, '733445566');
      expect(baytRow.whatsapp, isNull);
      expect(baytRow.bucket0to30, closeTo(600, 0.001));
      expect(baytRow.currentNotDue, closeTo(400, 0.001));
      expect(baytRow.bucket31to60, 0);
      expect(baytRow.total, closeTo(600, 0.001));
      expect(baytRow.details, hasLength(2));
      final noDueDate = baytRow.details[0];
      expect(noDueDate.dueDate, isNull, reason: 'بُذرت بلا due_date');
      expect(
        noDueDate.daysPastDue,
        14,
        reason: 'المرجع issued_at = 2026-11-01',
      );
      final future = baytRow.details[1];
      expect(future.daysPastDue, -25);

      // المجاميع العامة — تُثبت استبعاد المسودة/الإبطال/المسددة/المرتجع/
      // الشراء ضمنياً (لو دخل أي منها لاختلت).
      expect(report.currencyId, yer);
      expect(report.currencyCode, 'YER');
      expect(report.asOf, DateTime.utc(2026, 11, 15));
      expect(report.total0to30, closeTo(1600, 0.001));
      expect(report.total31to60, closeTo(500, 0.001));
      expect(report.total61to90, closeTo(250, 0.001));
      expect(report.total90Plus, closeTo(820, 0.001));
      expect(report.grandTotal, closeTo(3170, 0.001));
      expect(report.customersCount, 3);
      expect(report.currentNotDue, closeTo(400, 0.001));
    },
  );

  // ── فلترة العملة ──────────────────────────────────────────────────

  test('فلترة العملة: كل عملة تقرير مستقل برصيدها ورمزها', () async {
    final customer = await seedCustomer(db, name: 'متعدد العملات');

    // ريال يمني: ١٠ أيام (٠–٣٠).
    await seedInvoice(
      db,
      warehouseId: warehouseId,
      customerId: customer,
      currencyId: yer,
      dueAmount: 100,
      issuedAt: DateTime.utc(2026, 10, 25),
      dueDate: DateTime.utc(2026, 11, 5),
    );
    // ريال سعودي: ١٢٣ يوماً (+٩٠).
    await seedInvoice(
      db,
      warehouseId: warehouseId,
      customerId: customer,
      currencyId: sar,
      dueAmount: 999,
      issuedAt: DateTime.utc(2026, 7, 1),
      dueDate: DateTime.utc(2026, 7, 15),
    );
    // دولار: ٤٥ يوماً (٣١–٦٠).
    await seedInvoice(
      db,
      warehouseId: warehouseId,
      customerId: customer,
      currencyId: usd,
      dueAmount: 50,
      issuedAt: DateTime.utc(2026, 9, 1),
      dueDate: DateTime.utc(2026, 10, 1),
    );

    final byYer = await repo.agingReport(currencyId: yer, asOf: _asOf);
    expect(byYer.currencyCode, 'YER');
    expect(byYer.rows, hasLength(1));
    expect(byYer.rows.single.bucket0to30, closeTo(100, 0.001));
    expect(byYer.rows.single.total, closeTo(100, 0.001));
    expect(byYer.rows.single.details, hasLength(1));

    final bySar = await repo.agingReport(currencyId: sar, asOf: _asOf);
    expect(bySar.currencyCode, 'SAR');
    expect(bySar.rows, hasLength(1));
    expect(bySar.rows.single.bucket90Plus, closeTo(999, 0.001));
    expect(bySar.rows.single.bucket0to30, 0);
    expect(bySar.grandTotal, closeTo(999, 0.001));

    final byUsd = await repo.agingReport(currencyId: usd, asOf: _asOf);
    expect(byUsd.currencyCode, 'USD');
    expect(byUsd.rows.single.bucket31to60, closeTo(50, 0.001));
    expect(byUsd.grandTotal, closeTo(50, 0.001));
  });

  // ── لا ديون ───────────────────────────────────────────────────────

  test('لا ديون مستحقة — تقرير فارغ احتفالي', () async {
    await seedCustomer(db, name: 'عميل نظيف بلا فواتير');

    final report = await repo.agingReport(currencyId: yer, asOf: _asOf);
    expect(report.rows, isEmpty);
    expect(report.customersCount, 0);
    expect(report.grandTotal, 0);
    expect(report.rows, isNotNull);
  });
}
