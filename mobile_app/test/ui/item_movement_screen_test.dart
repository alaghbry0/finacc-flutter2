/// اختبارات شاشة «حركة صنف» (FR-09-03 — الشريحة 10):
///
/// 1. بطاقة الاختيار البطلة حين لا صنف محدداً.
/// 2. العرض الكامل عبر **seam** بمستودع معلَّب: رأس الإحصاءات + الصفوف
///    **تنازلياً** (الأحدث أولاً) مع رقاقات الأنواع وشارات الباقي.
/// 3. الحالة الفارغة مع بقاء رأس البطاقة.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/movement_reports_repository.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/reports/view_models/movement_reports_view_model.dart';
import 'package:mobile_app/ui/features/reports/views/item_movement_screen.dart';
import 'package:mobile_app/ui/features/reports/views/widgets/period_preset_bar.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

/// لحظة «الآن» المحقونة للنموذج — ثابتة.
final DateTime _now = DateTime(2026, 10, 8, 15);

void main() {
  setUpAll(initFfiForTests);

  /// بطاقة حركة معلَّبة حتمية: افتتاحي 10 قبل الفترة ثم أربع حركات.
  ItemMovementReport cannedReport() => ItemMovementReport(
    productId: 1,
    name: 'أرز بسمتي',
    unitCostNow: 150,
    openingBalance: 10,
    from: DateTime(2026, 10, 1),
    to: DateTime(2026, 10, 8),
    rows: [
      ItemMovementRow(
        movedAt: DateTime.utc(2026, 11, 3, 10),
        movementType: 'sale',
        qty: -3,
        unitCost: 150,
        refType: 'invoice',
        refId: 101,
        notes: 'INV-2026-000101',
        balanceAfter: 7,
      ),
      ItemMovementRow(
        movedAt: DateTime.utc(2026, 11, 8, 11, 30),
        movementType: 'purchase',
        qty: 5,
        unitCost: 150,
        refType: 'invoice',
        refId: 102,
        notes: 'PUR-2026-000102',
        balanceAfter: 12,
      ),
      ItemMovementRow(
        movedAt: DateTime.utc(2026, 11, 12, 8),
        movementType: 'sale_return',
        qty: 2,
        unitCost: 150,
        refType: 'invoice',
        refId: 103,
        notes: 'SRN-2026-000103',
        balanceAfter: 14,
      ),
      ItemMovementRow(
        movedAt: DateTime.utc(2026, 11, 20, 16, 45),
        movementType: 'stocktake_adjust',
        qty: -1,
        unitCost: 150,
        refType: 'stocktake',
        refId: 9,
        notes: '— الجانِد: أبو نور',
        balanceAfter: 13,
      ),
    ],
  );

  /// يبذر حالة جاهزة: قاعدة مؤسَّسة + متحكم جلسة + نموذج فوق مستودع
  /// معلَّب يعيد [canned] أياً كانت النافذة (اختبار واجهة صرف).
  Future<(AppDatabase, AppController, ItemMovementViewModel)> pumpReady(
    WidgetTester tester,
    ItemMovementReport canned, {
    int? productId,
    Size surface = const Size(390, 2400),
  }) async {
    final seeded = await openSeededApp();
    final db = seeded.$1.db;
    final controller = AppController(forTesting: seeded.$1);
    await controller.decidePhaseForTest();
    controller.unlockSession();

    final vm = ItemMovementViewModel(
      movementRepo: _CannedMovementRepo(db, canned),
      companyRepo: CompanyRepository(db),
      productId: productId,
      reference: _now,
    );
    await vm.load();

    await tester.binding.setSurfaceSize(surface);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: wrapWithL10n(ItemMovementScreen(viewModel: vm)),
      ),
    );
    await pumpQuietly(tester, 12);
    return (seeded.$1, controller, vm);
  }

  testWidgets('لا صنف محدد — بطاقة الاختيار البطلة مع زر الاختيار', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (app, controller, vm) = await pumpReady(tester, cannedReport());

      expect(find.text('حركة صنف'), findsOneWidget);
      expect(find.text('اختر صنفاً أولاً'), findsOneWidget);
      expect(find.byKey(const Key('itemMovement_pick_card')), findsOneWidget);
      expect(find.byKey(const Key('itemMovement_pick_button')), findsOneWidget);
      expect(find.text('اختيار الصنف'), findsOneWidget);
      // شريط الفترات المشترك حاضر.
      expect(find.byKey(const Key('periodMonth')), findsOneWidget);
      // لا تقرير بعد.
      expect(find.byKey(const Key('itemMovement_summary_card')), findsNothing);
      expect(vm.state.needsProduct, isTrue);

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('التقرير الكامل: الإحصاءات + الصفوف تنازلياً بشارات الباقي', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (app, controller, vm) = await pumpReady(
        tester,
        cannedReport(),
        productId: 1,
      );

      // رأس البطاقة: الاسم (الترويسة + البطاقة) + الرصيد الافتتاحي + الإجماليان + WAC.
      expect(
        find.byKey(const Key('itemMovement_summary_card')),
        findsOneWidget,
      );
      expect(
        find.text('أرز بسمتي'),
        findsNWidgets(2),
        reason: 'العنوان الفرعي + بطاقة الرأس',
      );
      expect(find.text('رصيد ما قبل الفترة'), findsOneWidget);
      // الرصيد الافتتاحي **بلا إشارة** (رصيد لا تدفق — _qtyPlain).
      expect(find.text('10'), findsOneWidget);
      expect(find.text('إجمالي الوارد'), findsOneWidget);
      expect(find.text('+7'), findsOneWidget);
      expect(find.text('إجمالي الصادر'), findsOneWidget);
      expect(find.text('\u22124'), findsOneWidget);
      expect(find.text('التكلفة الحالية للوحدة'), findsOneWidget);
      // WAC داخل رأس البطاقة حصراً (تكاليف الوحدات في الصفوف مستقلة).
      expect(
        find.descendant(
          of: find.byKey(const Key('itemMovement_summary_card')),
          matching: find.text('150'),
        ),
        findsOneWidget,
      );
      expect(find.text('4 حركات'), findsOneWidget);

      // العرض تنازلي: الأحدث (تسوية 20-11) أولاً والبيع (03-11) أخيراً.
      // (اليوم/الشهر بلا حشو صفري في المنسِّق — 8 و3 كما هي.)
      expect(find.text('20/11/2026 16:45'), findsOneWidget);
      expect(find.text('12/11/2026 08:00'), findsOneWidget);
      expect(find.text('8/11/2026 11:30'), findsOneWidget);
      expect(find.text('3/11/2026 10:00'), findsOneWidget);
      // رقاقات الأنواع الأربع.
      expect(find.text('تسوية جرد'), findsOneWidget);
      expect(find.text('مرتجع بيع'), findsOneWidget);
      expect(find.text('شراء'), findsOneWidget);
      expect(find.text('بيع'), findsOneWidget);
      // الكميات الموقّعة (− U+2212).
      expect(find.text('\u22121'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('\u22123'), findsOneWidget);
      // شارة الباقي: القيمة النهائية 13 (آخر تراكم).
      expect(find.text('13'), findsOneWidget);

      // ترتيب فعلي: الصف الأول في الشجرة هو الأحدث (تسوية الجرد).
      final firstRow = tester.widget<Padding>(
        find.byKey(const Key('itemMovement_row_0')),
      );
      expect(firstRow, isNotNull);
      final tileTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('itemMovement_row_0')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(tileTexts, contains('تسوية جرد'));
      expect(tileTexts, contains('20/11/2026 16:45'));
      expect(tileTexts, isNot(contains('بيع')), reason: 'البيع أقدم حركة');

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('حركة صنف: فترة اليوم تحدّث النموذج (رقائق الفترات)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (app, controller, vm) = await pumpReady(
        tester,
        cannedReport(),
        productId: 1,
        surface: const Size(900, 2000),
      );

      await tester.tap(find.byKey(const Key('periodToday')));
      await pumpQuietly(tester, 10);
      expect(vm.state.period, ReportPeriod.today);
      expect(vm.state.from, DateTime(2026, 10, 8));
      expect(vm.state.to, DateTime(2026, 10, 8));
      expect(vm.state.loading, isFalse);

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('الفراغ: لا حركات في الفترة مع بقاء رأس البطاقة', (tester) async {
    await tester.runAsync(() async {
      final empty = ItemMovementReport(
        productId: 1,
        name: 'صنف صامت',
        unitCostNow: 75,
        openingBalance: 0,
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 8),
        rows: const <ItemMovementRow>[],
      );
      final (app, controller, vm) = await pumpReady(
        tester,
        empty,
        productId: 1,
      );

      expect(find.text('لا حركة في هذه الفترة'), findsOneWidget);
      expect(
        find.byKey(const Key('itemMovement_summary_card')),
        findsOneWidget,
      );
      expect(
        find.text('صنف صامت'),
        findsNWidgets(2),
        reason: 'العنوان الفرعي + بطاقة الرأس',
      );
      expect(find.byKey(const Key('itemMovement_row_0')), findsNothing);

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });
}

/// مستودع معلَّب لاختبار الواجهة — يعيد البطاقة نفسها أياً كانت النافذة.
class _CannedMovementRepo extends MovementReportsRepository {
  _CannedMovementRepo(super.db, this.canned);

  final ItemMovementReport canned;

  @override
  Future<ItemMovementReport> itemMovement({
    required int productId,
    required DateTime from,
    required DateTime to,
    int? warehouseId,
  }) async {
    return ItemMovementReport(
      productId: productId,
      name: canned.name,
      unitCostNow: canned.unitCostNow,
      openingBalance: canned.openingBalance,
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      rows: canned.rows,
    );
  }
}
