/// اختبارات جلسة مسودة الجرد الفعلي (P0-1a — فقدان بيانات صامت):
///
/// 1) `load()` لنفس المخزن يُرحّل الأعداد المُدخلة والتوقيع والملاحظات
///    (تحديث مرجعي فقط — لا تصفير)، بينما تبديل المخزن يفتح كشفاً نظيفاً.
/// 2) الجلسة التطبيقية (نمط SellCartSession) تعيد نفس النموذج فوق نفس
///    القاعدة — وإعادة بناء الشاشة تحافظ على العدّ المُدخل.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/stocktake_repository.dart';
import 'package:mobile_app/data/repositories/user_repository.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/inventory/view_models/stocktake_session.dart';
import 'package:mobile_app/ui/features/inventory/view_models/stocktake_view_model.dart';
import 'package:mobile_app/ui/features/inventory/views/stocktake_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  setUp(() {
    // الجلسة مفردة تطبيقية — نظّفها قبل كل اختبار (بداية نظيفة).
    stocktakeSession.reset();
  });

  /// يبذر صنفاً مخزنياً برصيده ويرجع معرّفه.
  Future<int> seedProduct(AppDatabase app, String name, double qty) async {
    final warehouseId =
        (await app.db.query('warehouse', limit: 1)).first['id'] as int;
    final id = await app.db.insert('product', {
      'name': name,
      'cost_price': 150,
      'is_service': 0,
    });
    await app.db.insert('stock_level', {
      'product_id': id,
      'warehouse_id': warehouseId,
      'qty': qty,
    });
    return id;
  }

  /// قاعدة مؤسَّسة + منتجان مبذوران + نموذج جرد محمّل.
  Future<(AppDatabase, StocktakeViewModel)> bootWithProducts() async {
    final seeded = await openSeededApp();
    addTearDown(seeded.$1.close);
    final app = seeded.$1;
    await seedProduct(app, 'صنف ألف', 10);
    await seedProduct(app, 'صنف باء', 5);
    final vm = StocktakeViewModel(
      stocktakeRepo: StocktakeRepository(app.db),
      userRepo: UserRepository(app.db),
      companyRepo: CompanyRepository(app.db),
    );
    await vm.load();
    addTearDown(vm.dispose);
    return (app, vm);
  }

  test(
    'إعادة التحميل لنفس المخزن: العدّ والتوقيع والملاحظات تُرحَّل',
    () async {
      final (_, vm) = await bootWithProducts();
      final a = vm.state.lines
          .firstWhere((line) => line.name == 'صنف ألف')
          .productId;

      vm.setCounted(a, 8);
      vm.setCountedBy('الجانِد سالم');
      vm.setNotes('جرد نهاية الأسبوع');

      // تنشيط المسار/عودة من قفل = load() لنفس المخزن.
      await vm.load();

      final line = vm.state.lines.firstWhere((line) => line.productId == a);
      expect(
        line.countedQty,
        8,
        reason: 'العدّ المُدخل باقٍ بعد إعادة التحميل',
      );
      expect(vm.state.countedBy, 'الجانِد سالم');
      expect(vm.state.notes, 'جرد نهاية الأسبوع');
      expect(vm.state.summary.countedCount, 1);
      expect(vm.state.loading, isFalse);
    },
  );

  test('تبديل المخزن: كشف نظيف — العدّ لا ينتقل بين المخازن', () async {
    final seeded = await openSeededApp();
    addTearDown(seeded.$1.close);
    final app = seeded.$1;
    final otherWarehouseId = await app.db.insert('warehouse', {
      'name': 'مخزن الفرع',
      'is_default': 0,
      'is_archived': 0,
    });
    final a = await seedProduct(app, 'صنف ألف', 10);
    final vm = StocktakeViewModel(
      stocktakeRepo: StocktakeRepository(app.db),
      userRepo: UserRepository(app.db),
      companyRepo: CompanyRepository(app.db),
    );
    await vm.load();
    addTearDown(vm.dispose);

    vm.setCounted(a, 8);
    expect(vm.state.summary.countedCount, 1);

    await vm.setWarehouse(otherWarehouseId);

    expect(vm.state.warehouseId, otherWarehouseId);
    // كشف المخزن الجديد يعرض كل الأصناف (دفتري صفر) لكن **بلا عدّ** —
    // عدّ المخزن القديم لا ينتقل.
    expect(vm.state.lines, isNotEmpty);
    expect(
      vm.state.lines.every((line) => line.countedQty == null),
      isTrue,
      reason: 'عدّ المخزن القديم لا ينتقل',
    );
    expect(vm.state.summary.countedCount, 0);
  });

  test(
    'الجلسة: نفس النموذج فوق نفس القاعدة وقاعدة جديدة = مسودة جديدة',
    () async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      addTearDown(controller.dispose);

      final first = stocktakeSession.attach(
        database: seeded.$1,
        stocktakeRepo: StocktakeRepository(seeded.$1.db),
        userRepo: controller.users!,
        companyRepo: controller.companies!,
      );
      final same = stocktakeSession.attach(
        database: seeded.$1,
        stocktakeRepo: StocktakeRepository(seeded.$1.db),
        userRepo: controller.users!,
        companyRepo: controller.companies!,
      );
      expect(
        identical(first, same),
        isTrue,
        reason: 'نفس القاعدة = نفس النموذج',
      );

      // قاعدة جديدة (استعادة/مسح) → نموذج جديد فوقها.
      final other = await openSeededApp();
      addTearDown(other.$1.close);
      final second = stocktakeSession.attach(
        database: other.$1,
        stocktakeRepo: StocktakeRepository(other.$1.db),
        userRepo: UserRepository(other.$1.db),
        companyRepo: CompanyRepository(other.$1.db),
      );
      expect(
        identical(first, second),
        isFalse,
        reason: 'قاعدة جديدة = مسودة جديدة',
      );
    },
  );

  testWidgets('الشاشة عبر الجلسة: مغادرة وعودة = العدّ موجود', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();
      addTearDown(controller.dispose);

      final productId = await seedProduct(seeded.$1, 'صنف ألف', 10);

      // جلسة مبنية ومحمّلة مسبقاً (الشاشة تتصل بها — بلا seam):
      // التحميل الكامل يُنتظر داخل runAsync (نمط FFI في الاختبارات).
      final preAttached = stocktakeSession.attach(
        database: seeded.$1,
        stocktakeRepo: StocktakeRepository(seeded.$1.db),
        userRepo: controller.users!,
        companyRepo: controller.companies!,
      );
      await preAttached.load();

      Future<void> pumpScreen() async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppController>.value(
            value: controller,
            child: wrapWithL10n(const StocktakeScreen()),
          ),
        );
        await pumpQuietly(tester, 14);
      }

      // الدخول الأول: الشاشة تتصل بالجلسة (بلا seam).
      await pumpScreen();
      expect(
        identical(stocktakeSession.current, preAttached),
        isTrue,
        reason: 'الشاشة استعملت نموذج الجلسة نفسه',
      );

      await tester.enterText(
        find.byKey(Key('stocktake_counted_field_$productId')),
        '8',
      );
      await pumpQuietly(tester, 6);
      expect(find.text('المعدود 1 من 1'), findsOneWidget);

      // «مغادرة الشاشة»: بناء شاشة جديدة (route builder جديد) — نفس الجلسة.
      await pumpScreen();
      expect(
        identical(stocktakeSession.current, preAttached),
        isTrue,
        reason: 'نفس النموذج عبر الجلسة (نمط SellCartSession)',
      );
      expect(
        find.text('المعدود 1 من 1'),
        findsOneWidget,
        reason: 'العدّ باقٍ بعد إعادة بناء الشاشة',
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(Key('stocktake_counted_field_$productId')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '8',
        reason: 'حقل العدّ ما زال معبَّأً',
      );
    });
  });
}
