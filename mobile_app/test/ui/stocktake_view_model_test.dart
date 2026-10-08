/// اختبارات نموذج عرض الجرد (FR-01-08): التحميل (المخزن الافتراضي +
/// تعبئة اسم الجانِد + العملة الأساسية) + العدّ والملخص الحي + قواعد
/// الاعتماد (العدّ الجزئي جائز والتوقيع إلزامي) + نجاح الترحيل (تفريغ
/// وإعادة تحميل + السجل) + فشل الترحيل (العدّ محفوظ والخطأ عربي) +
/// تجاوز غير المعدود + البحث وتغيير المخزن.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/stocktake_repository.dart';
import 'package:mobile_app/data/repositories/user_repository.dart';
import 'package:mobile_app/ui/features/inventory/view_models/stocktake_view_model.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late StocktakeViewModel vm;
  late int warehouseId;

  final countedAt = DateTime.utc(2026, 10, 8, 9, 30);

  setUp(() async {
    final seeded = await openSeededApp();
    app = seeded.$1;
    warehouseId =
        (await app.db.query('warehouse', limit: 1)).first['id'] as int;
    vm = StocktakeViewModel(
      stocktakeRepo: StocktakeRepository(app.db),
      userRepo: UserRepository(app.db),
      companyRepo: CompanyRepository(app.db),
    );
    addTearDown(vm.dispose);
    addTearDown(app.close);
  });

  /// يبذر صنفاً مخزنياً برصيد ويرجع معرّفه.
  Future<int> seedProduct(String name, double cost, double qty) async {
    final id = await app.db.insert('product', {
      'name': name,
      'cost_price': cost,
      'is_service': 0,
    });
    await app.db.insert('stock_level', {
      'product_id': id,
      'warehouse_id': warehouseId,
      'qty': qty,
    });
    return id;
  }

  test(
    'load: المخزن الافتراضي + تعبئة اسم الجانِد + العملة الأساسية',
    () async {
      await seedProduct('صنف ألف', 150, 10);
      await vm.load();

      expect(vm.state.loading, isFalse);
      expect(vm.state.error, isNull);
      expect(vm.state.warehouseId, warehouseId);
      expect(vm.state.warehouseName, 'المخزن الرئيسي');
      expect(vm.state.lines, hasLength(1));
      expect(vm.state.lines.first.bookQty, 10);
      expect(vm.state.lines.first.countedQty, isNull);
      expect(vm.state.countedBy, 'أبو نور', reason: 'اسم المدير من التأسيس');
      expect(vm.state.countedAt, isNotNull);
      expect(vm.state.baseCurrencyCode, 'YER');
      expect(vm.state.baseCurrencyDecimals, 0, reason: 'YER بلا كسور');
      expect(vm.state.history, isEmpty);
      expect(vm.userId, isNotNull);
    },
  );

  test('setCounted: ملخص حي بالقيم — والعدّ المحو ممسوح', () async {
    final a = await seedProduct('صنف ألف', 150, 10);
    await seedProduct('صنف باء', 200, 5);
    await vm.load();
    expect(vm.state.summary.countedCount, 0);
    expect(vm.canPost, isFalse, reason: 'لا عدّ بعد');

    vm.setCounted(a, 8);
    var summary = vm.state.summary;
    expect(summary.countedCount, 1);
    expect(summary.diffsCount, 1);
    expect(summary.shortageValue, -300);
    expect(summary.netDiffValue, -300);

    vm.setCounted(a, 12);
    summary = vm.state.summary;
    expect(summary.surplusValue, 300, reason: 'زيادة 2 × 150');
    expect(summary.netDiffValue, 300);

    // محو العدّ يعيده غير معدود.
    vm.setCounted(a, null);
    expect(vm.state.summary.countedCount, 0);
    expect(vm.state.summary.diffsCount, 0);

    // القيم غير الصالحة تُتجاهل.
    vm.setCounted(a, -5);
    expect(vm.state.lines.first.countedQty, isNull);
  });

  test('canPost: بند معدود + اسم جانِد — العدّ الجزئي جائز', () async {
    final a = await seedProduct('صنف ألف', 150, 10);
    await seedProduct('صنف باء', 200, 5);
    await vm.load();

    expect(vm.canPost, isFalse, reason: 'بلا عدّ');
    vm.setCounted(a, 8);
    expect(vm.canPost, isTrue, reason: 'بند واحد يكفي — الجزئي جائز');

    vm.setCountedBy('');
    expect(vm.canPost, isFalse, reason: 'التوقيع إلزامي');
    vm.setCountedBy('أحمد');
    expect(vm.canPost, isTrue);
  });

  test(
    'post: نجاح → قفل الأرصدة + تفريغ العدّ + السجل + إيصال النجاح',
    () async {
      final a = await seedProduct('صنف ألف', 150, 10);
      await seedProduct('صنف باء', 200, 5);
      await vm.load();
      vm.setCounted(a, 8);
      vm
        ..setCountedBy('أحمد الجانِد')
        ..setCountedAt(countedAt)
        ..setNotes('جرد أسبوعي');

      final result = await vm.post();
      expect(result.isOk, isTrue);
      final posted = result.valueOrNull!;
      expect(posted.diffsCount, 1);
      expect(posted.netDiffValue, -300);
      expect(posted.countedAt, countedAt);

      // القاعدة: جرد واحد بسطر واحد (غير المعدود مُتجاوز) والرصيد مقفل.
      final stocktakes = await app.db.query('stocktake');
      expect(stocktakes, hasLength(1));
      expect(stocktakes.first['id'], posted.id);
      expect(
        await app.db.query('stocktake_line'),
        hasLength(1),
        reason: 'باء غير المعدود لم يُخزَّن',
      );
      final level = (await app.db.query(
        'stock_level',
        where: 'product_id = ?',
        whereArgs: [a],
      )).first;
      expect((level['qty'] as num).toDouble(), 8);

      // النموذج أُعيد تحميله: عدّ نظيف + سجل.
      expect(vm.state.summary.countedCount, 0);
      expect(vm.state.lines.first.countedQty, isNull);
      expect(vm.state.lines.first.bookQty, 8, reason: 'الدفتري صار المقيس');
      expect(vm.state.history, hasLength(1));
      expect(vm.state.posting, isFalse);
      expect(vm.state.notes, '', reason: 'الملاحظات لا تعبر الجرد');
    },
  );

  test('post: فشل → خطأ عربي والعدّ محفوظ والكشف سليم', () async {
    final a = await seedProduct('صنف ألف', 150, 10);
    await vm.load();
    vm.setCounted(a, 8);
    vm.setCountedBy('أحمد');

    // صنف مهلك بعد فتح الكشف — المستودع يرفض داخل المعاملة (نحذف
    // رصيده أولاً ليفل قيد المفتاح الأجنبي عند حذف الصنف).
    await app.db.delete('stock_level', where: 'product_id = ?', whereArgs: [a]);
    await app.db.delete('product', where: 'id = ?', whereArgs: [a]);

    final result = await vm.post();
    expect(result.isErr, isTrue);
    expect(result.errorOrNull, contains('الصنف'));
    expect(vm.state.posting, isFalse);
    expect(vm.state.summary.countedCount, 1, reason: 'العدّ لم يضِع');
    expect(vm.state.lines.first.countedQty, 8);
    expect(await app.db.query('stocktake'), isEmpty);
  });

  test('الضوابط: setCountedBy/At/Notes توقّع الحالة وتُخطر', () async {
    await seedProduct('صنف ألف', 150, 10);
    await vm.load();

    var notifications = 0;
    vm.addListener(() => notifications++);

    vm.setCountedBy('سالم');
    expect(vm.state.countedBy, 'سالم');
    vm.setCountedAt(countedAt);
    expect(vm.state.countedAt, countedAt);
    vm.setNotes('ملاحظة');
    expect(vm.state.notes, 'ملاحظة');
    expect(notifications, 3, reason: 'إشعار لكل تغيير');

    // القيمة نفسها لا تُخطر.
    vm.setNotes('ملاحظة');
    expect(notifications, 3);
  });

  test('البحث: تصفية عرضية بالاسم لا تمس الملخص', () async {
    await seedProduct('صنف ألف', 150, 10);
    await seedProduct('صنف باء', 200, 5);
    await vm.load();

    vm.setQuery('ألف');
    expect(vm.state.visibleLines, hasLength(1));
    expect(vm.state.visibleLines.first.name, 'صنف ألف');
    expect(vm.state.lines, hasLength(2), reason: 'التصفية عرضية فقط');
    expect(vm.state.summary.linesCount, 2);

    vm.setQuery('لا يوجد');
    expect(vm.state.visibleLines, isEmpty);
  });

  test('تغيير المخزن: كشف جديد للمخزن الآخر (العدّ لا ينتقل)', () async {
    await seedProduct('صنف ألف', 150, 10);
    await vm.load();
    vm.setCounted(vm.state.lines.first.productId, 3);

    final other = await app.db.insert('warehouse', {
      'name': 'مخزن الفرع',
      'is_default': 0,
    });
    final otherProduct = await app.db.insert('product', {
      'name': 'صنف الفرع',
      'cost_price': 90,
    });
    await app.db.insert('stock_level', {
      'product_id': otherProduct,
      'warehouse_id': other,
      'qty': 7,
    });

    await vm.setWarehouse(other);

    expect(vm.state.warehouseId, other);
    expect(vm.state.warehouseName, 'مخزن الفرع');
    // كل الأصناف تظهر لكن بدفتري هذا المخزن (غائب = 0).
    expect(vm.state.lines, hasLength(2));
    expect(
      vm.state.lines.map((l) => l.productId).toSet(),
      contains(otherProduct),
    );
    final otherLine = vm.state.lines.firstWhere(
      (l) => l.productId == otherProduct,
    );
    expect(otherLine.bookQty, 7);
    expect(
      vm.state.lines.firstWhere((l) => l.productId != otherProduct).bookQty,
      0,
      reason: 'لا صف stock_level للمخزن الآخر',
    );
    expect(otherLine.countedQty, isNull, reason: 'عدّ المخزن السابق لا ينتقل');
  });
}
