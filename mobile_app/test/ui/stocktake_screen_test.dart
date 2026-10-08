/// اختبارات شاشة الجرد الفعلي (FR-01-08):
///
/// عرض الكشف بالبيانات عبر **seam** — نموذج محمّل مسبقاً داخل
/// `tester.runAsync` (استعلامات FFI لا تتقدم في منطقة الاختبار الزائفة —
/// نمط aging/inventory) ثم: إدخال العدّ يحدّث شارة الفرق والملخص السفلي
/// ويفعّل زر الاعتماد، ورقاقة «＝ الدفتري» تملأ المطابق، ونافذة المراجعة
/// تعرض أسطر الفروقات وقيمها بتكلفة اللقطة وتحذير قفل الأرصدة، والحالة
/// الفارغة الاحتفالية عند مخزن بلا أصناف.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/stocktake_repository.dart';
import 'package:mobile_app/data/repositories/user_repository.dart';
import 'package:mobile_app/ui/features/inventory/view_models/stocktake_view_model.dart';
import 'package:mobile_app/ui/features/inventory/views/stocktake_screen.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  /// يهيّئ قاعدة مؤسَّسة + منتجين برصيديهما + نموذجاً محمّلاً (الـseam).
  Future<StocktakeViewModel> bootWithProducts(
    WidgetTester tester, {
    bool withProducts = true,
  }) async {
    final seeded = await openSeededApp();
    addTearDown(seeded.$1.close);
    final db = seeded.$1.db;
    final warehouseId =
        (await db.query('warehouse', limit: 1)).first['id'] as int;

    if (withProducts) {
      for (final (name, cost, qty) in <(String, double, double)>[
        ('صنف ألف', 150, 10),
        ('صنف باء', 200, 5),
      ]) {
        final id = await db.insert('product', {
          'name': name,
          'cost_price': cost,
          'is_service': 0,
        });
        await db.insert('stock_level', {
          'product_id': id,
          'warehouse_id': warehouseId,
          'qty': qty,
        });
      }
    }

    final vm = StocktakeViewModel(
      stocktakeRepo: StocktakeRepository(db),
      userRepo: UserRepository(db),
      companyRepo: CompanyRepository(db),
    );
    await vm.load();
    addTearDown(vm.dispose);
    return vm;
  }

  testWidgets('الكشف: الأصناف بدفتريها وتكلفتها والتوقيع مُعبَّأ', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final vm = await bootWithProducts(tester);
      await tester.pumpWidget(wrapWithL10n(StocktakeScreen(viewModel: vm)));
      await pumpQuietly(tester, 12);

      expect(find.text('الجرد الفعلي'), findsOneWidget);
      expect(find.text('صنف ألف'), findsOneWidget);
      expect(find.text('صنف باء'), findsOneWidget);
      // الدفتري والتكلفة (YER بلا كسور).
      expect(find.text('10'), findsOneWidget, reason: 'دفتري ألف');
      expect(find.text('5'), findsOneWidget, reason: 'دفتري باء');
      expect(find.text('150'), findsOneWidget, reason: 'تكلفة ألف');
      expect(find.text('200'), findsOneWidget, reason: 'تكلفة باء');
      // اسم الجانِد مُعبَّء باسم المدير + المخزن الافتراضي في البطاقة.
      expect(find.text('أبو نور'), findsOneWidget);
      expect(find.text('المخزن الرئيسي'), findsOneWidget);
      // عنوان السجل يظهر مرتين عند الفراغ: ترويسة القسم + عنوان الحالة
      // الفارغة تحتها (نفس نمط سجل الورديات في شاشة الوردية).
      expect(find.text('سجل عمليات الجرد'), findsNWidgets(2));

      // لا عدّ بعد → زر الاعتماد معطّل.
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('stocktake_post_button')),
      );
      expect(button.onPressed, isNull);
    });
  });

  testWidgets('إدخال العدّ: شارة الفرق والملخص السفلي وزر الاعتماد', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final vm = await bootWithProducts(tester);
      final a = vm.state.lines
          .firstWhere((line) => line.name == 'صنف ألف')
          .productId;
      final b = vm.state.lines
          .firstWhere((line) => line.name == 'صنف باء')
          .productId;

      await tester.pumpWidget(wrapWithL10n(StocktakeScreen(viewModel: vm)));
      await pumpQuietly(tester, 12);

      await tester.enterText(
        find.byKey(Key('stocktake_counted_field_$a')),
        '8',
      );
      await pumpQuietly(tester, 6);

      expect(find.text('−2'), findsOneWidget, reason: 'شارة عجز ملوّنة');
      expect(find.text('المعدود 1 من 2'), findsOneWidget);
      final enabled = tester.widget<FilledButton>(
        find.byKey(const Key('stocktake_post_button')),
      );
      expect(enabled.onPressed, isNotNull, reason: 'بند واحد يكفي');

      // رقاقة «＝ الدفتري» تملأ المطابق لصف باء.
      await tester.tap(find.byTooltip('نسخ الدفتري').at(1));
      await pumpQuietly(tester, 6);
      expect(find.text('مطابق'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(Key('stocktake_counted_field_$b')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '5',
        reason: 'نسخ الدفتري ملأ الحقل',
      );
    });
  });

  testWidgets('نافذة المراجعة: أسطر الفروقات وقيمها وتحذير القفل', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final vm = await bootWithProducts(tester);
      final a = vm.state.lines
          .firstWhere((line) => line.name == 'صنف ألف')
          .productId;
      final b = vm.state.lines
          .firstWhere((line) => line.name == 'صنف باء')
          .productId;

      await tester.pumpWidget(wrapWithL10n(StocktakeScreen(viewModel: vm)));
      await pumpQuietly(tester, 12);

      await tester.enterText(
        find.byKey(Key('stocktake_counted_field_$a')),
        '8',
      );
      await pumpQuietly(tester, 6);
      await tester.enterText(
        find.byKey(Key('stocktake_counted_field_$b')),
        '6',
      );
      await pumpQuietly(tester, 6);

      await tester.tap(find.byKey(const Key('stocktake_post_button')));
      await pumpQuietly(tester, 10);

      // النافذة: العنوان + الفروقات بقيمها بتكلفة اللقطة + التحذير.
      expect(find.text('مراجعة فروقات الجرد'), findsOneWidget);
      expect(find.text('صنف ألف'), findsNWidgets(2), reason: 'الصف + النافذة');
      expect(find.text('−2.000'), findsOneWidget, reason: 'فرق كمية ألف');
      expect(find.text('+1.000'), findsOneWidget, reason: 'فرق كمية باء');
      expect(find.textContaining('−300'), findsAtLeastNWidgets(1));
      expect(find.textContaining('+200'), findsAtLeastNWidgets(1));
      expect(find.textContaining('لا يمكن التراجع'), findsOneWidget);
      // كل الأصناف معدودة → لا ملاحظة تجاوز.
      expect(find.textContaining('غير معدود'), findsNothing);
      expect(find.byKey(const Key('stocktake_confirm_button')), findsOneWidget);

      // إغلاق النافذة بلا ترحيل (FFI لا يتقدم في منطقة الاختبار الزائفة).
      await tester.tap(find.text('إلغاء'));
      await pumpQuietly(tester, 8);
      expect(find.text('مراجعة فروقات الجرد'), findsNothing);
    });
  });

  testWidgets('مخزن بلا أصناف: الحالة الفارغة الاحتفالية', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final vm = await bootWithProducts(tester, withProducts: false);

      await tester.pumpWidget(wrapWithL10n(StocktakeScreen(viewModel: vm)));
      await pumpQuietly(tester, 12);

      expect(find.text('المخزن فارغ'), findsOneWidget);
      expect(
        find.byKey(const Key('stocktake_post_button')),
        findsNothing,
        reason: 'لا شريط اعتماد بلا أصناف',
      );
    });
  });
}
