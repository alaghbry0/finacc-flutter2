/// اختبارات شاشة «ملخص حركة المخزون» (FR-09-04 — الشريحة 10):
///
/// 1. العرض الكامل عبر **seam** بمستودع معلَّب: بطاقة الإجماليات (عدد
///    الأصناف المتحركة + قيمة المخزون بالتكلفة) + صفوف مرتّبة بالقيمة
///    تنازلياً بأعمدة التدفق وشارة القيمة الذهبية.
/// 2. رقائق الفترات المشتركة تعمل (التبديل إلى «اليوم»).
/// 3. الحالة الفارغة الاحتفالية عند لا حركة.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/movement_reports_repository.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/reports/view_models/movement_reports_view_model.dart';
import 'package:mobile_app/ui/features/reports/views/stock_summary_screen.dart';
import 'package:mobile_app/ui/features/reports/views/widgets/period_preset_bar.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

/// لحظة «الآن» المحقونة للنموذج — ثابتة.
final DateTime _now = DateTime(2026, 10, 8, 15);

void main() {
  setUpAll(initFfiForTests);

  /// صفوف ملخص معلَّبة حتمية: ثلاجة (القيمة الأعلى) ثم مروحة —
  /// الترتيب بالقيمة تنازلياً مسؤولية المستودع فتُقدَّم مرتّبة جاهزة.
  List<StockSummaryRow> cannedRows() => [
    StockSummaryRow(
      productId: 1,
      name: 'ثلاجة',
      qtyIn: 3,
      qtyOut: 0,
      qtyReturns: 0,
      qtyAdjustNet: 0,
      endBalance: 3,
      valueAtCost: 3000,
    ),
    StockSummaryRow(
      productId: 2,
      name: 'مروحة',
      qtyIn: 4,
      qtyOut: 1,
      qtyReturns: 1,
      qtyAdjustNet: -1,
      endBalance: 3,
      valueAtCost: 750,
    ),
  ];

  /// يبذر حالة جاهزة: قاعدة مؤسَّسة + متحكم جلسة + نموذج فوق مستودع
  /// معلَّب يعيد [rows] أياً كانت النافذة (اختبار واجهة صرف).
  Future<(AppDatabase, AppController, StockSummaryViewModel)> pumpReady(
    WidgetTester tester,
    List<StockSummaryRow> rows, {
    Size surface = const Size(390, 2400),
  }) async {
    final seeded = await openSeededApp();
    final db = seeded.$1.db;
    final controller = AppController(forTesting: seeded.$1);
    await controller.decidePhaseForTest();
    controller.unlockSession();

    final vm = StockSummaryViewModel(
      movementRepo: _CannedMovementRepo(db, rows),
      companyRepo: CompanyRepository(db),
      reference: _now,
    );
    await vm.load();

    await tester.binding.setSurfaceSize(surface);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: wrapWithL10n(StockSummaryScreen(viewModel: vm)),
      ),
    );
    await pumpQuietly(tester, 12);
    return (seeded.$1, controller, vm);
  }

  testWidgets('الرأس والإجماليات وصفوف التدفق بالترتيب بالقيمة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (app, controller, vm) = await pumpReady(tester, cannedRows());

      expect(find.text('ملخص حركة المخزون'), findsOneWidget);
      expect(find.byKey(const Key('stockSummary_totals_card')), findsOneWidget);
      // عدد الأصناف المتحركة (plural two) + إجمالي القيمة بالتكلفة.
      expect(
        find.text('صنفان متحركان'),
        findsNWidgets(2),
        reason: 'الترويسة + بطاقة الرأس',
      );
      expect(find.text('إجمالي قيمة المخزون بالتكلفة'), findsOneWidget);
      // 3,000 + 750 = 3,750 (YER منازل 0 بفواصل آلاف).
      expect(find.text('3,750'), findsOneWidget);

      // الصف الأول في الشجرة = الأعلى قيمة (ثلاجة 3,000).
      expect(find.byKey(const Key('stockSummary_row_0')), findsOneWidget);
      expect(find.byKey(const Key('stockSummary_row_1')), findsOneWidget);
      final firstRowTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('stockSummary_row_0')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(firstRowTexts, contains('ثلاجة'));
      expect(firstRowTexts, contains('3,000'), reason: 'شارة القيمة الذهبية');

      // الصف الثاني (مروحة): رصيد 3 + أعمدة التدفق الأربعة موقّعة.
      expect(find.text('مروحة'), findsOneWidget);
      expect(find.text('750'), findsOneWidget, reason: 'شارة قيمة المروحة');
      // رصيدا الصفين 3 و3 (بلا إشارة — أرصدة لا تدفقات).
      expect(find.text('3'), findsNWidgets(2));
      // رقاقات تدفق المروحة: وارد +4 / صادر −1 / مرتجع +1 / تسوية −1.
      // (تسمات الرقائق الأربع معروضة في الصفين معاً — الصفري منها محايد.)
      expect(find.text('وارد'), findsNWidgets(2));
      expect(find.text('+4'), findsOneWidget);
      expect(find.text('صادر'), findsNWidgets(2));
      expect(find.text('\u22121'), findsNWidgets(2), reason: 'صادر وتسوية');
      expect(find.text('مرتجع'), findsNWidgets(2));
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('تسوية'), findsNWidgets(2));
      // شارات التدفق الصفرية للثلاجة محايدة خافتة لكنها معروضة.
      expect(vm.state.totalValueAtCost, 3750);

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('رقائق الفترات: التبديل إلى «اليوم» يحدّث النموذج', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // عرض أوسع حتى تتسع الرقائق الست كلها أفقياً (عنصر مشترك).
      final (app, controller, vm) = await pumpReady(
        tester,
        cannedRows(),
        surface: const Size(900, 2000),
      );

      expect(find.byKey(const Key('periodToday')), findsOneWidget);
      expect(find.byKey(const Key('periodMonth')), findsOneWidget);
      expect(vm.state.period, ReportPeriod.month);

      await tester.tap(find.byKey(const Key('periodToday')));
      await pumpQuietly(tester, 10);
      expect(vm.state.period, ReportPeriod.today);
      expect(vm.state.loading, isFalse);
      expect(vm.state.from, DateTime(2026, 10, 8));
      expect(vm.state.to, DateTime(2026, 10, 8));
      // المستودع المعلَّب يعيد الصفوف نفسها أياً كانت النافذة.
      expect(vm.state.rows, hasLength(2));

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('الحالة الفارغة الاحتفالية عند لا حركة في الفترة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (app, controller, vm) = await pumpReady(
        tester,
        const <StockSummaryRow>[],
      );

      expect(find.text('لا حركة مخزون في هذه الفترة'), findsOneWidget);
      // لا بطاقة إجماليات ولا صفوف في الفراغ.
      expect(find.byKey(const Key('stockSummary_totals_card')), findsNothing);
      expect(find.byKey(const Key('stockSummary_row_0')), findsNothing);
      expect(vm.state.isEmpty, isTrue);

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });
}

/// مستودع معلَّب لاختبار الواجهة — يعيد الصفوف نفسها أياً كانت النافذة.
class _CannedMovementRepo extends MovementReportsRepository {
  _CannedMovementRepo(super.db, this.rows);

  final List<StockSummaryRow> rows;

  @override
  Future<List<StockSummaryRow>> stockSummary({
    required DateTime from,
    required DateTime to,
    int? warehouseId,
  }) async {
    return rows;
  }
}
