/// اختبارات شاشة «المبيعات حسب» (FR-09-06 — الشريحة 10):
///
/// 1. العرض الكامل عبر **seam** بمستودع معلَّب: رقائق الأبعاد الأربعة +
///    بطاقة الإجمالي + الصفوف (التسمية/المبلغ/عدد الفواتير) مع رقاقة
///    النسبة الثلاثية (ارتفاع أخضر / انخفاض أحمر / محجوبة عند null —
///    العميل النقدي بلا فترة سابقة).
/// 2. تبديل البعد إلى «الصنف» يعيد التحميل ويحدّث الترويسة.
/// 3. الحالة الفارغة الاحتفالية عند لا مبيعات.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/movement_reports_repository.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/reports/view_models/movement_reports_view_model.dart';
import 'package:mobile_app/ui/features/reports/views/sales_by_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

/// لحظة «الآن» المحقونة للنموذج — ثابتة.
final DateTime _now = DateTime(2026, 10, 8, 15);

void main() {
  setUpAll(initFfiForTests);

  /// صفوف «العميل» المعلَّبة: نمو + تراجع + نقدي بلا فترة سابقة
  /// (مرتّبة بالمبيعات تنازلياً — مسؤولية المستودع فتُقدَّم جاهزة).
  List<SalesByRow> customerRows() => [
    SalesByRow(
      label: 'أحمد سعيد',
      salesBase: 500,
      invoiceCount: 2,
      changePct: 25.0,
    ),
    SalesByRow(
      label: 'سارة',
      salesBase: 100,
      invoiceCount: 1,
      changePct: -50.0,
    ),
    SalesByRow(label: '', salesBase: 50, invoiceCount: 1),
  ];

  /// صفوف «الصنف» بعد التبديل.
  List<SalesByRow> itemRows() => [
    SalesByRow(label: 'أرز بسمتي', salesBase: 200, invoiceCount: 3),
  ];

  /// يبذر حالة جاهزة: قاعدة مؤسَّسة + متحكم جلسة + نموذج فوق مستودع
  /// معلَّب يبدّل صفوفه حسب البعد (اختبار واجهة صرف).
  Future<(AppDatabase, AppController, SalesByViewModel)> pumpReady(
    WidgetTester tester, {
    List<SalesByRow> customer = const [],
    List<SalesByRow> item = const [],
    Size surface = const Size(390, 2400),
  }) async {
    final seeded = await openSeededApp();
    final db = seeded.$1.db;
    final controller = AppController(forTesting: seeded.$1);
    await controller.decidePhaseForTest();
    controller.unlockSession();

    final vm = SalesByViewModel(
      movementRepo: _CannedSalesRepo(db, customer, item),
      companyRepo: CompanyRepository(db),
      reference: _now,
    );
    await vm.load();

    await tester.binding.setSurfaceSize(surface);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: wrapWithL10n(SalesByScreen(viewModel: vm)),
      ),
    );
    await pumpQuietly(tester, 12);
    return (seeded.$1, controller, vm);
  }

  testWidgets('الأبعاد والإجمالي والصفوف مع رقاقة النسبة الثلاثية', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // عرض أوسع حتى تتسع رقائق الأبعاد الأربعة أفقياً (شريط قابل
      // للتمرير داخل 390 — التمرير غير مطلوب لصحة الاختبار).
      final (app, controller, vm) = await pumpReady(
        tester,
        customer: customerRows(),
        item: itemRows(),
        surface: const Size(900, 2000),
      );

      expect(find.text('المبيعات حسب'), findsOneWidget);
      // رقائق الأبعاد الأربعة بمفاتيحها الثابتة + تسمية الترويسة الفرعية.
      expect(find.byKey(const Key('salesByTabCustomer')), findsOneWidget);
      expect(find.byKey(const Key('salesByTabCategory')), findsOneWidget);
      expect(find.byKey(const Key('salesByTabItem')), findsOneWidget);
      expect(find.byKey(const Key('salesByTabDay')), findsOneWidget);
      // «العميل» مرتين: رقاقة البعد + الترويسة الفرعية للبعد الجاري.
      expect(find.text('العميل'), findsNWidgets(2));
      expect(find.text('الفئة'), findsOneWidget);
      expect(find.text('الصنف'), findsOneWidget);
      // «اليوم» مرتين: رقاقة البعد + رقاقة «فترة اليوم» في الشريط المشترك.
      expect(find.text('اليوم'), findsNWidgets(2));

      // بطاقة الإجمالي: 500 + 100 + 50 = 650 (YER منازل 0).
      expect(find.byKey(const Key('salesBy_total_card')), findsOneWidget);
      expect(find.text('إجمالي المبيعات'), findsOneWidget);
      expect(find.text('650'), findsOneWidget);
      expect(vm.state.totalSalesBase, 650);

      // الصفوف الثلاثة: التسمية (النقدي مُترجَم) + المبلغ + عدد الفواتير.
      expect(find.text('أحمد سعيد'), findsOneWidget);
      expect(find.text('سارة'), findsOneWidget);
      expect(find.text('عميل نقدي (بلا عميل)'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('فاتورتان'), findsOneWidget);
      expect(
        find.text('فاتورة واحدة'),
        findsNWidgets(2),
        reason: 'سارة والنقدي',
      );

      // رقاقة النسبة: نمو أخضر وتراجع أحمر والنقدي بلا رقاقة (null).
      expect(find.byKey(const Key('salesBy_change_chip')), findsNWidgets(2));
      expect(find.text('ارتفاع 25٪'), findsOneWidget);
      expect(find.text('انخفاض 50٪'), findsOneWidget);
      // ملاحظة النسبة أسفل القائمة.
      expect(find.textContaining('فترة سابقة مساوية'), findsOneWidget);

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('تبديل البعد إلى «الصنف» يعيد التحميل ويحدّث الترويسة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (app, controller, vm) = await pumpReady(
        tester,
        customer: customerRows(),
        item: itemRows(),
        surface: const Size(900, 2000),
      );
      expect(vm.state.dimension, SalesByDimension.customer);

      await tester.tap(find.byKey(const Key('salesByTabItem')));
      await pumpQuietly(tester, 10);

      expect(vm.state.dimension, SalesByDimension.item);
      expect(vm.state.loading, isFalse);
      expect(vm.state.rows, hasLength(1));
      expect(vm.state.rows!.first.label, 'أرز بسمتي');
      expect(vm.state.rows!.first.salesBase, 200);
      // الصف الجديد ظاهر والإجمالي تحدّث (200 في البطاقة وفي الصف معاً).
      expect(find.text('أرز بسمتي'), findsOneWidget);
      expect(
        find.text('200'),
        findsNWidgets(2),
        reason: 'بطاقة الإجمالي وصف الأرز',
      );
      expect(
        find.text('650'),
        findsNothing,
        reason: 'إجمالي العملاء القديم اختفى',
      );
      // «الصنف» مرتين الآن: الرقاقة + الترويسة الفرعية للبعد الجديد.
      expect(find.text('الصنف'), findsNWidgets(2));

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('الحالة الفارغة الاحتفالية عند لا مبيعات في الفترة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (app, controller, vm) = await pumpReady(tester);

      expect(find.text('لا مبيعات في هذه الفترة'), findsOneWidget);
      // لا بطاقة إجمالي ولا صفوف ولا رقاقات نسبة في الفراغ.
      expect(find.byKey(const Key('salesBy_total_card')), findsNothing);
      expect(find.byKey(const Key('salesBy_row_0')), findsNothing);
      expect(find.byKey(const Key('salesBy_change_chip')), findsNothing);
      expect(vm.state.isEmpty, isTrue);

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });
}

/// مستودع معلَّب لاختبار الواجهة — يبدّل صفوفه حسب البعد المطلوب
/// أياً كانت النافذة (لا SQL للمبيعات؛ عملة الأساس عبر المستودع الحقيقي).
class _CannedSalesRepo extends MovementReportsRepository {
  _CannedSalesRepo(super.db, this.customerRows, this.itemRows);

  final List<SalesByRow> customerRows;
  final List<SalesByRow> itemRows;

  @override
  Future<List<SalesByRow>> salesBy({
    required SalesByDimension dimension,
    required DateTime from,
    required DateTime to,
  }) async {
    return dimension == SalesByDimension.item ? itemRows : customerRows;
  }
}
