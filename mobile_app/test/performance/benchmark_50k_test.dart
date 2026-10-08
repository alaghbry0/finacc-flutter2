/// اختبار أداء AC-22 (الشريحة 10-d) — قاعدة ضخمة: **50,000 فاتورة بيع /
/// 20,000 صنف / 100,000 حركة مخزون / 100,000 بند فاتورة**.
///
/// ## تصميم «الاشتراك الصريح» (إلزامي — لا يجوز إبطاء الجناح الكامل):
/// - الملف موسوم `@Tags(['performance'])` وكل اختبار ينسحب فوراً ما لم
///   يكن متغير البيئة `FINACC_BENCH=1` مضبوطاً — فعبء `flutter test`
///   العادي على هذا الملف أجزاء ثانية بلا أي بذر.
/// - التشغيل الصريح وحده يقيس:
///   `FINACC_BENCH=1 flutter test test/performance/benchmark_50k_test.dart`
///
/// ## البذر (setUpAll واحد):
/// قاعدة مؤقتة عبر محرك FFI نفسه (`AppDatabase.openWith` فوق
/// `databaseFactoryFfi`) مع هجرات التطبيق الحقيقية وبذورها المرجعية
/// (عملات YER أساسية…)، ثم إدراج دفعي بمعاملات معدّة (`db.batch()`)
/// يُرسَل كل 5,000 عبارة: 20,000 صنف (أسماء عربية/إنجليزية متنوعة +
/// باركود فريد + تكلفة/سعر + فئات) و50,000 فاتورة بيع **مكتملة** موزّعة
/// على آخر 12 شهراً (بندان لكل فاتورة → 100,000 بند، و`total_base`/
/// `cost_total` متسقان حسابياً) و100,000 حركة مخزون موزّعة كذلك.
///
/// ## القياس:
/// `Stopwatch` حول استدعاء **المستودع الحقيقي نفسه** (لا SQL مخصص):
/// بطاقات الداشبورد الأربع (كلٌّ < 3000ms)، بحث الأصناف بالاسم العربي
/// وبالباركود (3 تشغيلات لكلٍّ، كل تشغيل < 100ms)، تقرير أرباح الشهر
/// (< 3000ms)، ملخص حركة المخزون (بونص بلا حد)، وقائمة فواتير البيع
/// الأخيرة (بونص < 3000ms). **الصحة متحققة أيضاً**: القيم المتوقعة
/// تُحتسب أثناء البذر نفسه وتُقارن بأرقام الاستعلامات — لا يُكتفى
/// بالسرعة. جدول ملخص ختامي في `tearDownAll`.
@Tags(['performance'])
@Timeout(Duration(minutes: 15))
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/dashboard_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/movement_reports_repository.dart';
import 'package:mobile_app/data/repositories/profit_report_repository.dart';
import 'package:mobile_app/data/repositories/sale_repository.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ─────────────────────────────────────────────────────────────────────
// أحجام البذر (AC-22) والاشتراك الصريح
// ─────────────────────────────────────────────────────────────────────

const int kProductCount = 20000;
const int kSaleInvoiceCount = 50000;
const int kMovementCount = 100000;

/// بندان لكل فاتورة → 100,000 بند فاتورة.
const int kItemsPerInvoice = 2;

/// حجم الدفعة المرسلة للقاعدة (عبارات لكل commit).
const int kCommitEveryStatements = 5000;

const String kBenchEnvVar = 'FINACC_BENCH';

/// هل وضع قياس الأداء مفعّل؟ (`FINACC_BENCH=1`)
bool _benchEnabled() => Platform.environment[kBenchEnvVar] == '1';

/// ينسحب الاختبار فوراً عندما لا يكون وضع الأداء مفعّلاً — الجناح
/// العادي يمرّ سريعاً ولا يبذر شيئاً.
bool _skipUnlessBench() {
  if (_benchEnabled()) return false;
  _log(
    'تخطٍّ — اختبار أداء اختياري (وسم performance): شغّله صراحة بـ '
    'FINACC_BENCH=1 flutter test test/performance/benchmark_50k_test.dart',
  );
  return true;
}

// ─────────────────────────────────────────────────────────────────────
// الحالة المشتركة بين الاختبارات (تُملأ في setUpAll عند التفعيل)
// ─────────────────────────────────────────────────────────────────────

/// سطر نتيجة واحد في جدول الملخص الختامي.
class _BenchEntry {
  const _BenchEntry({
    required this.name,
    required this.rows,
    required this.ms,
    required this.thresholdMs,
  });

  /// اسم الاستعلام (عربي).
  final String name;

  /// حجم البيانات المسؤول عنه (وصف نصي).
  final String rows;

  /// الزمن المقيس بالميلي ثانية.
  final int ms;

  /// الحد الأقصى بالميلي ثانية — null يعني بونصاً بلا حد صارم.
  final int? thresholdMs;

  bool get passed => thresholdMs == null || ms < thresholdMs!;
}

final List<_BenchEntry> _entries = <_BenchEntry>[];

Directory? _tempDir;
AppDatabase? _app;
bool _seeded = false;
late DateTime _benchNow;

// القيم المتوقعة المحسوبة أثناء البذر (تدقيق صحة الاستعلامات).
int _expectedTodayCount = 0;
double _expectedTodaySales = 0;
double _expectedTodayCost = 0;
int _expectedMonthCount = 0;
double _expectedMonthSales = 0;
double _expectedMonthCost = 0;
late String _probeBarcode;

// ─────────────────────────────────────────────────────────────────────
// مساعدات القياس والطباعة
// ─────────────────────────────────────────────────────────────────────

/// طباعة خرج اختبار الأداء — الطباعة هنا هي المنتج المقصود.
// ignore: avoid_print
void _log(Object? message) => print(message);

/// يقيس زمن تنفيذ [body] ويعيد (الميلي ثانية، القيمة).
Future<(int, T)> _timed<T>(Future<T> Function() body) async {
  final sw = Stopwatch()..start();
  final T value = await body();
  sw.stop();
  return (sw.elapsedMilliseconds, value);
}

/// يسجّل النتيجة في جدول الملخص ويطبعها فوراً.
void _record(String name, String rows, int ms, int? thresholdMs) {
  _entries.add(
    _BenchEntry(name: name, rows: rows, ms: ms, thresholdMs: thresholdMs),
  );
  final limit = thresholdMs?.toString() ?? '—';
  _log('  $name | صفوف: $rows | زمن: $ms ms | الحد: $limit ms');
}

/// يفرض الحد الزمني برسالة فشل عربية واضحة تتضمن الزمن الفعلي (AC-22).
void _expectUnderThreshold(String name, int ms, int thresholdMs) {
  expect(
    ms,
    lessThan(thresholdMs),
    reason:
        'فشل AC-22 — «$name» استغرق $ms ميلي ثانية '
        'بينما الحد المسموح $thresholdMs ميلي ثانية.',
  );
}

// ─────────────────────────────────────────────────────────────────────
// مولّدات بيانات البذر (حتمية — بلا عشوائية قابلة للتذبذب)
// ─────────────────────────────────────────────────────────────────────

const List<String> _kArabicNouns = <String>[
  'زيت',
  'سكر',
  'أرز',
  'شاي',
  'حليب',
  'مكينة',
  'سماعة',
  'شاحن',
  'كابل',
  'ساعة',
  'مروحة',
  'ثلاجة',
  'صابون',
  'منظفة',
  'بطارية',
  'لمبة',
  'مفتاح',
  'أنبوب',
  'دهان',
  'فرشاة',
  'زيتون',
  'عسل',
  'تمر',
  'قهوة',
  'حلاوة',
  'معلبة',
  'كيس',
  'دلو',
  'مطرقة',
  'مفك',
  'حامل',
  'رف',
  'طاولة',
  'كرسي',
  'ستارة',
  'سجادة',
  'مرتبة',
  'مخدة',
  'بطانية',
  'منشفة',
];

const List<String> _kEnglishNouns = <String>[
  'Cable',
  'Charger',
  'Lamp',
  'Fan',
  'Oil Filter',
  'Rice Bag',
  'Sugar Pack',
  'Battery',
  'Switch',
  'Pipe',
  'Paint',
  'Brush',
  'Clock',
  'Speaker',
  'Phone Case',
  'Glass',
  'Holder',
  'Cutter',
  'Tape',
  'Drill',
  'Screw',
  'Wrench',
  'Pliers',
  'Hammer',
  'Saw',
  'Drill Bit',
  'Socket',
  'Extension',
  'Adapter',
  'Converter',
];

const List<String> _kAdjectives = <String>[
  'أصلي',
  'اقتصادي',
  'فاخر',
  'ممتاز',
  'جديد',
  'مقاوم',
  'سريع',
  'خفيف',
  'ثقيل',
  'صغير',
  'كبير',
  'ملكي',
  'ذهبي',
  'فضي',
  'أسود',
  'أبيض',
];

const List<String> _kCategories = <String>[
  'مواد غذائية',
  'مشروبات',
  'إلكترونيات',
  'أدوات منزلية',
  'خردوات',
  'عناية شخصية',
  'ملابس',
  'أثاث',
  'ألعاب',
  'قرطاسية',
  'مخبوزات',
  'أخرى',
];

/// اسم صنف متنوع (عربي/إنجليزي/مختلط) — اللاحقة الرقمية تضمن التفرد.
String _productName(int index) {
  final n = index + 1;
  final arabic = _kArabicNouns[index % _kArabicNouns.length];
  final english = _kEnglishNouns[(index * 7) % _kEnglishNouns.length];
  final adjective = _kAdjectives[(index * 13) % _kAdjectives.length];
  return switch (index % 4) {
    0 => '$arabic $adjective رقم $n',
    1 => '$english $adjective No. $n',
    2 => '$arabic $english $n',
    _ => '$arabic $n',
  };
}

/// باركود EAN-13 الشكلي فريد لكل صنف (رقم 2 + 12 خانة).
String _barcodeOf(int index) =>
    '2${(100000000000 + index).toString().padLeft(12, '0')}';

/// تكلفة الصنف (حتمية 20..999).
double _costOf(int index) => 20.0 + ((index * 37) % 980);

/// سعر التجزئة = التكلفة × 1.25 (مقرب).
double _retailOf(int index) => (_costOf(index) * 1.25).roundToDouble();

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// صيغة ISO UTC من مكونات **التاريخ المحلي** — يضمن أن `date()` في SQL
/// يطابق اليوم التقويمي المحلي المقصود أياً كان منطق الجهاز الزمني.
String _isoFrom(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-${_twoDigits(local.month)}-'
    '${_twoDigits(local.day)}T${_twoDigits(local.hour)}:'
    '${_twoDigits(local.minute)}:${_twoDigits(local.second)}Z';

/// `YYYY-MM-DD` ليوم تقويمي محلي.
String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_twoDigits(d.month)}-'
    '${_twoDigits(d.day)}';

/// `YYYY-MM` لشهر تقويمي محلي.
String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_twoDigits(d.month)}';

// ─────────────────────────────────────────────────────────────────────
// البذر
// ─────────────────────────────────────────────────────────────────────

/// يبذر القاعدة كاملة ويعيد عدد العبارات المدرجة.
Future<int> _seedAll() async {
  final db = _app!.db;
  _benchNow = DateTime.now();
  final today = DateTime(_benchNow.year, _benchNow.month, _benchNow.day);
  final thisMonth = _monthKey(today);
  final stamp = _isoFrom(DateTime(today.year, today.month, today.day, 8));
  var statements = 0;

  // ── (1) البيانات المرجعية: مخزن + صندوق + 12 فئة + 3 وحدات + 200 عميل.
  await db.transaction((txn) async {
    await txn.insert('warehouse', <String, Object?>{
      'id': 1,
      'name': 'المخزن الرئيسي',
      'is_default': 1,
      'created_at': stamp,
      'updated_at': stamp,
    });
    await txn.insert('cashbox', <String, Object?>{
      'id': 1,
      'name': 'الصندوق الرئيسي',
      'currency_id': 1,
      'is_default': 1,
      'created_at': stamp,
      'updated_at': stamp,
    });
    for (var c = 0; c < _kCategories.length; c++) {
      await txn.insert('category', <String, Object?>{
        'id': c + 1,
        'name': _kCategories[c],
        'created_at': stamp,
        'updated_at': stamp,
      });
      statements++;
    }
    const units = <String>['قطعة', 'كرتون', 'كيس'];
    for (var u = 0; u < units.length; u++) {
      await txn.insert('unit', <String, Object?>{
        'id': u + 1,
        'name': units[u],
        'factor': 1.0,
        'created_at': stamp,
        'updated_at': stamp,
      });
      statements++;
    }
    for (var p = 0; p < 200; p++) {
      await txn.insert('customer', <String, Object?>{
        'id': p + 1,
        'name': p % 2 == 0 ? 'عميل رقم ${p + 1}' : 'Customer ${p + 1}',
        'phone': '77${(1000000 + p).toString()}',
        'created_at': stamp,
        'updated_at': stamp,
      });
      statements++;
    }
  });

  // ── (2) الأصناف: 20,000 صنف + سعر تجزئة + رصيد مخزني لكل صنف.
  final productsSw = Stopwatch()..start();
  var batch = db.batch();
  var pending = 0;
  for (var i = 0; i < kProductCount; i++) {
    final id = i + 1;
    batch.insert('product', <String, Object?>{
      'id': id,
      'name': _productName(i),
      'barcode': _barcodeOf(i),
      'category_id': 1 + (i % _kCategories.length),
      'unit_id': 1 + (i % 3),
      'cost_price': _costOf(i),
      'min_stock': 5,
      'is_service': 0,
      'track_batches': 0,
      'track_serials': 0,
      'is_archived': 0,
      'created_at': stamp,
      'updated_at': stamp,
      'created_by': 1,
    });
    batch.insert('product_price', <String, Object?>{
      'product_id': id,
      'currency_id': 1,
      'price': _retailOf(i),
      'price_level': 'retail',
      'margin_percent': 25.0,
      'updated_at': stamp,
    });
    batch.insert('stock_level', <String, Object?>{
      'product_id': id,
      'warehouse_id': 1,
      'qty': 100.0 + (i % 200),
    });
    pending += 3;
    if (pending >= kCommitEveryStatements) {
      await batch.commit(noResult: true);
      statements += pending;
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) {
    await batch.commit(noResult: true);
    statements += pending;
  }
  productsSw.stop();

  // ── (3) فواتير البيع: 50,000 مكتملة على آخر 12 شهراً (بندان لكلٍّ).
  final invoicesSw = Stopwatch()..start();
  batch = db.batch();
  pending = 0;
  for (var i = 0; i < kSaleInvoiceCount; i++) {
    final invoiceId = i + 1;
    final dayOffset = i % 365;
    final when = DateTime(
      today.year,
      today.month,
      today.day - dayOffset,
      9 + (i % 9),
      (i * 7) % 60,
      (i * 11) % 60,
    );
    final issuedAt = _isoFrom(when);

    // بندان حتميان — الجمع يطابق total/cost_total تماماً.
    var total = 0.0;
    var costTotal = 0.0;
    final itemRows = <Map<String, Object?>>[];
    for (var k = 0; k < kItemsPerInvoice; k++) {
      final productIndex = (i * 137 + 11 + k * 7001) % kProductCount;
      final qty = 1 + ((i + k) % 5);
      final unitPrice = _retailOf(productIndex);
      final lineTotal = qty * unitPrice;
      final lineCost = qty * _costOf(productIndex);
      total += lineTotal;
      costTotal += lineCost;
      itemRows.add(<String, Object?>{
        'invoice_id': invoiceId,
        'product_id': productIndex + 1,
        'qty': qty.toDouble(),
        'unit_id': 1 + (productIndex % 3),
        'unit_factor': 1.0,
        'unit_price': unitPrice,
        'discount_percent': 0.0,
        'discount_amount': 0.0,
        'tax_percent': 0.0,
        'line_total': lineTotal,
        'line_cost': lineCost,
        'batch_id': null,
        'created_at': issuedAt,
      });
    }

    final isCredit = i % 5 == 0;
    final paid = isCredit ? (total * 0.4).roundToDouble() : total;
    batch.insert('invoice', <String, Object?>{
      'id': invoiceId,
      'invoice_no': 'INV-${when.year}-${invoiceId.toString().padLeft(6, '0')}',
      'doc_type': 'sale',
      'pay_status': isCredit ? 'credit' : 'cash',
      'status': 'completed',
      'issued_at': issuedAt,
      'due_date': isCredit ? issuedAt : null,
      'customer_id': i % 5 == 3 ? null : 1 + (i % 200),
      'cashbox_id': 1,
      'warehouse_id': 1,
      'currency_id': 1,
      'exchange_rate': 1.0,
      'rate_is_fallback': 0,
      'subtotal': total,
      'discount_amount': 0.0,
      'tax_rate': 0.0,
      'tax_amount': 0.0,
      'total': total,
      'total_base': total,
      'paid_amount': paid,
      'due_amount': total - paid,
      'cost_total': costTotal,
      'created_at': issuedAt,
      'updated_at': issuedAt,
      'created_by': 1,
    });
    for (final row in itemRows) {
      batch.insert('invoice_item', row);
    }
    pending += 3;

    // تراكم القيم المتوقعة (تدقيق صحة الاستعلامات لاحقاً).
    if (dayOffset == 0) {
      _expectedTodayCount++;
      _expectedTodaySales += total;
      _expectedTodayCost += costTotal;
    }
    if (_monthKey(when) == thisMonth) {
      _expectedMonthCount++;
      _expectedMonthSales += total;
      _expectedMonthCost += costTotal;
    }

    if (pending >= kCommitEveryStatements) {
      await batch.commit(noResult: true);
      statements += pending;
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) {
    await batch.commit(noResult: true);
    statements += pending;
  }
  invoicesSw.stop();

  // ── (4) حركات المخزون: 100,000 حركة على آخر 12 شهراً بأنواع متنوعة.
  final movementsSw = Stopwatch()..start();
  batch = db.batch();
  pending = 0;
  for (var j = 0; j < kMovementCount; j++) {
    final productIndex = (j * 421 + 17) % kProductCount;
    final dayOffset = j % 365;
    final when = DateTime(
      today.year,
      today.month,
      today.day - dayOffset,
      8 + (j % 10),
      (j * 3) % 60,
      (j * 17) % 60,
    );
    final movedAt = _isoFrom(when);
    final type = switch (j % 10) {
      0 || 1 || 2 || 3 || 4 => 'sale',
      5 || 6 || 7 => 'purchase',
      8 => 'sale_return',
      _ => 'opening',
    };
    final qty = switch (type) {
      'sale' => -(1.0 + (j % 5)),
      'purchase' => 5.0 + (j % 20),
      'sale_return' => 1.0 + (j % 3),
      _ => 10.0 + (j % 40),
    };
    batch.insert('stock_movement', <String, Object?>{
      'id': j + 1,
      'product_id': productIndex + 1,
      'warehouse_id': 1,
      'movement_type': type,
      'qty': qty,
      'unit_cost': _costOf(productIndex),
      'ref_type': type == 'opening' ? 'opening' : 'invoice',
      'ref_id': type == 'opening' ? null : (j % kSaleInvoiceCount) + 1,
      'moved_at': movedAt,
      'notes': 'بذر اختبار الأداء 50K',
      'created_at': movedAt,
      'created_by': 1,
    });
    pending++;
    if (pending >= kCommitEveryStatements) {
      await batch.commit(noResult: true);
      statements += pending;
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) {
    await batch.commit(noResult: true);
    statements += pending;
  }
  movementsSw.stop();

  _probeBarcode = _barcodeOf(12345);
  return statements;
}

// ─────────────────────────────────────────────────────────────────────
// الملخص الختامي
// ─────────────────────────────────────────────────────────────────────

void _printSummary() {
  if (_entries.isEmpty) return;
  _log('');
  _log('═══ ملخص أداء AC-22 — 50,000 فاتورة / 20,000 صنف / 100,000 حركة ═══');
  _log('الاستعلام | الصفوف | الزمن (ms) | الحد (ms) | الحكم');
  for (final entry in _entries) {
    final limit = entry.thresholdMs?.toString() ?? '—';
    final verdict = entry.thresholdMs == null
        ? 'بونص'
        : (entry.passed ? 'ناجح' : 'فاشل');
    _log('${entry.name} | ${entry.rows} | ${entry.ms} | $limit | $verdict');
  }
  final failed = _entries
      .where((e) => e.thresholdMs != null && !e.passed)
      .length;
  _log(
    failed == 0
        ? 'النتيجة النهائية: كل الاستعلامات المقيسة تحت حدودها ✓'
        : 'النتيجة النهائية: $failed استعلام تجاوز حده ✗',
  );
}

// ─────────────────────────────────────────────────────────────────────
// الاختبارات
// ─────────────────────────────────────────────────────────────────────

void main() {
  group('AC-22 — اختبار أداء 50K (اشتراك صريح: FINACC_BENCH=1)', () {
    late DashboardRepository dashboard;
    late ItemRepository items;
    late ProfitReportRepository profit;
    late MovementReportsRepository movements;
    late SaleRepository sales;

    setUpAll(() async {
      if (!_benchEnabled()) {
        _log('FINACC_BENCH غير مضبوط — لن تُبذر بيانات 50K (تخطٍّ سريع).');
        return;
      }
      sqfliteFfiInit();
      _tempDir = await Directory.systemTemp.createTemp('finacc_bench_50k');
      _app = await AppDatabase.openWith(
        databaseFactoryFfi,
        '${_tempDir!.path}/bench_50k.db',
      );
      final seedSw = Stopwatch()..start();
      final statements = await _seedAll();
      seedSw.stop();
      _seeded = true;

      dashboard = DashboardRepository(_app!.db);
      items = ItemRepository(_app!.db);
      profit = ProfitReportRepository(_app!.db);
      movements = MovementReportsRepository(_app!.db);
      sales = SaleRepository(_app!.db);

      final db = _app!.db;
      final pageCount =
          (await db.rawQuery('PRAGMA page_count')).first.values.first as int?;
      final pageSize =
          (await db.rawQuery('PRAGMA page_size')).first.values.first as int?;
      final dbSizeKb = ((pageCount ?? 0) * (pageSize ?? 0)) ~/ 1024;
      _log('');
      _log('── البذر اكتمل ──');
      _log(
        '  إجمالي العبارات: $statements | الزمن الكلي: '
        '${seedSw.elapsed}',
      );
      _log(
        '  SQLite ${_app!.sqliteVersion} | وضع التدوين '
        '${_app!.journalMode} | حجم القاعدة ~$dbSizeKb KB',
      );
      _log(
        '  المتوقع لليوم: $_expectedTodayCount فاتورة بقيمة '
        '$_expectedTodaySales | لهذا الشهر: $_expectedMonthCount فاتورة '
        'بقيمة $_expectedMonthSales',
      );
      _log('');
      _record(
        'بذر البيانات (setup)',
        '170K جوهري / ${statements ~/ 1000}K إدراج',
        seedSw.elapsedMilliseconds,
        null,
      );
    });

    tearDownAll(() async {
      if (!_benchEnabled()) return;
      _printSummary();
      if (_seeded) {
        await _app!.close();
      }
      final dir = _tempDir;
      if (dir != null) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {
          // قد يبقى الملف مفتوحاً على بعض الأنظمة — تجاهل بأمان.
        }
      }
    });

    test('الداشبورد: todayStats + monthStats + last30DaysSales + topItems — كلٌّ < 3000ms', () async {
      if (_skipUnlessBench()) return;
      final now = _benchNow;
      final todayKey = _dateKey(now);

      final (todayMs, todayStats) = await _timed(
        () => dashboard.todayStats(now),
      );
      _record(
        'داشبورد: إحصاءات اليوم (todayStats)',
        '50,000 فاتورة',
        todayMs,
        3000,
      );
      _expectUnderThreshold('داشبورد todayStats', todayMs, 3000);
      expect(
        todayStats.invoiceCount,
        _expectedTodayCount,
        reason: 'عدد فواتير اليوم من الاستعلام لا يطابق المحسوب أثناء البذر',
      );
      expect(todayStats.sales, closeTo(_expectedTodaySales, 0.01));
      expect(
        todayStats.profit,
        closeTo(_expectedTodaySales - _expectedTodayCost, 0.01),
      );
      expect(todayStats.netCash, 0, reason: 'البذرة بلا حركات صندوق');

      final (monthMs, monthStats) = await _timed(
        () => dashboard.monthStats(now),
      );
      _record(
        'داشبورد: مبيعات الشهر (monthStats)',
        '50,000 فاتورة',
        monthMs,
        3000,
      );
      _expectUnderThreshold('داشبورد monthStats', monthMs, 3000);
      expect(
        monthStats.invoiceCountThisMonth,
        _expectedMonthCount,
        reason: 'عدد فواتير الشهر لا يطابق المحسوب أثناء البذر',
      );
      expect(monthStats.thisMonthSales, closeTo(_expectedMonthSales, 0.01));
      expect(monthStats.previousMonthSales, greaterThan(0));

      final (seriesMs, series) = await _timed(
        () => dashboard.last30DaysSales(now),
      );
      _record('داشبورد: سلسلة 30 يوماً', '50,000 فاتورة', seriesMs, 3000);
      _expectUnderThreshold('داشبورد last30DaysSales', seriesMs, 3000);
      expect(series, hasLength(30));
      expect(series.last.date, todayKey);
      expect(
        series.every((p) => p.total > 0),
        isTrue,
        reason: 'كل يوم من آخر 30 فيه مبيعات في بذرة 50K',
      );

      final (topMs, top) = await _timed(() => dashboard.topItems(limit: 5));
      _record(
        'داشبورد: أعلى الأصناف مبيعاً (topItems)',
        '100,000 بند فاتورة',
        topMs,
        3000,
      );
      _expectUnderThreshold('داشبورد topItems', topMs, 3000);
      expect(top, isNotEmpty);
      expect(top.length, lessThanOrEqualTo(5));
      expect(top.every((t) => t.qtySold > 0 && t.revenueBase > 0), isTrue);
    });

    test(
      'بحث الأصناف: اسم عربي + باركود — كل تشغيل < 100ms (3 تشغيلات لكلٍّ)',
      () async {
        if (_skipUnlessBench()) return;

        // (أ) البحث باسم عربي — «زيتون» موجود في أسماء البذر المتنوعة.
        final arabicRuns = <int>[];
        var arabicResults = const <ItemStockInfo>[];
        for (var run = 1; run <= 3; run++) {
          final (ms, results) = await _timed(() => items.searchItems('زيتون'));
          arabicRuns.add(ms);
          if (run == 1) arabicResults = results;
        }
        expect(
          arabicResults,
          isNotEmpty,
          reason: 'بحث «زيتون» يجب أن يجد أصنافاً مبذورة بالاسم',
        );
        expect(arabicResults.length, lessThanOrEqualTo(50));
        expect(
          arabicResults.every((r) => r.item.name.contains('زيتون')),
          isTrue,
          reason: 'نتائج بحث الاسم يجب أن تحوي الكلمة المبحوثة',
        );
        for (var i = 0; i < arabicRuns.length; i++) {
          _expectUnderThreshold(
            'بحث الأصناف بالاسم العربي — التشغيل ${i + 1}',
            arabicRuns[i],
            100,
          );
        }
        _record(
          'بحث: اسم عربي «زيتون» (أسوأ 3 تشغيلات)',
          '20,000 صنف',
          arabicRuns.reduce(max),
          100,
        );
        _log('  أزمنة تشغيلات بحث الاسم: ${arabicRuns.join(' / ')} ms');

        // (ب) البحث بالباركود — مطابقة تامة لصنف مبذور معروف.
        final barcodeRuns = <int>[];
        var barcodeResults = const <ItemStockInfo>[];
        for (var run = 1; run <= 3; run++) {
          final (ms, results) = await _timed(
            () => items.searchItems(_probeBarcode),
          );
          barcodeRuns.add(ms);
          if (run == 1) barcodeResults = results;
        }
        expect(
          barcodeResults,
          isNotEmpty,
          reason: 'بحث الباركود يجب أن يجد الصنف المباشر',
        );
        expect(barcodeResults.first.item.barcode, _probeBarcode);
        for (var i = 0; i < barcodeRuns.length; i++) {
          _expectUnderThreshold(
            'بحث الأصناف بالباركود — التشغيل ${i + 1}',
            barcodeRuns[i],
            100,
          );
        }
        _record(
          'بحث: باركود (أسوأ 3 تشغيلات)',
          '20,000 صنف',
          barcodeRuns.reduce(max),
          100,
        );
        _log('  أزمنة تشغيلات الباركود: ${barcodeRuns.join(' / ')} ms');
      },
    );

    test('تقرير أرباح الشهر < 3000ms + ملخص حركة المخزون (بونص)', () async {
      if (_skipUnlessBench()) return;
      final now = _benchNow;
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final (reportMs, report) = await _timed(
        () => profit.report(from: monthStart, to: monthEnd),
      );
      _record(
        'تقرير أرباح الشهر (report)',
        '50,000 فاتورة + 100,000 حركة',
        reportMs,
        3000,
      );
      _expectUnderThreshold('تقرير الأرباح الشهري', reportMs, 3000);
      expect(
        report.salesInvoiceCount,
        _expectedMonthCount,
        reason: 'عدد فواتير الشهر في تقرير الأرباح لا يطابق البذر',
      );
      expect(report.sales, closeTo(_expectedMonthSales, 0.01));
      expect(report.cogs, closeTo(_expectedMonthCost, 0.01));
      expect(report.salesReturns, 0);
      expect(report.returnInvoiceCount, 0);
      expect(report.stockSurplus, 0, reason: 'البذرة بلا تسويات جرد');
      expect(report.stockShortage, 0);
      expect(report.expenses, 0);
      expect(report.fxGainLoss, 0);
      expect(report.ownerDrawings, 0);
      expect(
        report.profit,
        closeTo(_expectedMonthSales - _expectedMonthCost, 0.01),
        reason: 'الربح = المبيعات − التكلفة في بذرة بلا مصاريف/تسويات',
      );
      expect(report.netForOwner, closeTo(report.profit, 0.01));

      // بونص (بلا حد صارم): ملخص حركة المخزون للشهر نفسه.
      final (summaryMs, summary) = await _timed(
        () => movements.stockSummary(from: monthStart, to: monthEnd),
      );
      _record(
        'ملخص حركة المخزون (stockSummary) — بونص',
        '100,000 حركة',
        summaryMs,
        null,
      );
      expect(summary, isNotEmpty);
      _log(
        '  بونص — ملخص حركة المخزون: ${summary.length} صنفاً متحركاً خلال '
        '$summaryMs ms (بلا حد)',
      );
    });

    test('قائمة فواتير البيع الأخيرة (recentSales) < 3000ms — بونص', () async {
      if (_skipUnlessBench()) return;

      final (listMs, invoices) = await _timed(
        () => sales.recentSales(limit: 50),
      );
      _record(
        'قائمة فواتير البيع (recentSales) — بونص',
        '50,000 فاتورة',
        listMs,
        3000,
      );
      _expectUnderThreshold('قائمة فواتير البيع الأخيرة', listMs, 3000);
      expect(invoices, hasLength(50));
      expect(invoices.every((i) => i.total > 0), isTrue);
      expect(
        !invoices.last.issuedAt.isAfter(invoices.first.issuedAt),
        isTrue,
        reason: 'الترتيب يجب أن يكون الأحدث أولاً',
      );
    });
  });
}
