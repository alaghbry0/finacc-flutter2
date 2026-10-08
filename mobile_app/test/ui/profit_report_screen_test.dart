/// اختبارات شاشة تقرير الأرباح والخسائر (FR-09-02 — الشريحة 10):
///
/// 1. عرض البنود والعناوين والإجماليات عبر **seam** — نموذج محمّل مسبقاً
///    داخل `tester.runAsync` (استعلام FFI واحد فقط: عملة الأساس) مع
///    مستودع معلَّب يعيد تقريراً حتمياً.
/// 2. رقائق الفترات تعمل (تبديل إلى «اليوم» يحدّث النموذج).
/// 3. الحالة الفارغة الاحتفالية عند لا حركة.
/// 4. بطاقة الربح بشريط ذهبي (FinCard.accent = FinColors.gold).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/profit_report_repository.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/core/theme/app_colors.dart';
import 'package:mobile_app/ui/core/widgets/fin_card.dart';
import 'package:mobile_app/ui/features/reports/view_models/profit_report_view_model.dart';
import 'package:mobile_app/ui/features/reports/views/profit_report_screen.dart';
import 'package:mobile_app/ui/features/reports/views/widgets/period_preset_bar.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

/// لحظة «الآن» المحقونة للنموذج — ثابتة.
final DateTime _now = DateTime(2026, 10, 8, 15);

void main() {
  setUpAll(initFfiForTests);

  /// يبذر حالة جاهزة: قاعدة مؤسَّسة + متحكم جلسة + نموذج محمّل فوق
  /// مستودع معلَّب يعيد [canned] أياً كانت النافذة (اختبار واجهة صرف).
  Future<(AppDatabase, AppController, ProfitReportViewModel)> pumpReady(
    WidgetTester tester,
    ProfitReport canned, {
    Size surface = const Size(390, 2400),
  }) async {
    final seeded = await openSeededApp();
    final db = seeded.$1.db;
    final controller = AppController(forTesting: seeded.$1);
    await controller.decidePhaseForTest();
    controller.unlockSession();

    final vm = ProfitReportViewModel(
      profitRepo: _CannedProfitRepo(db, canned),
      companyRepo: CompanyRepository(db),
      reference: _now,
    );
    await vm.load();

    await tester.binding.setSurfaceSize(surface);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: wrapWithL10n(ProfitReportScreen(viewModel: vm)),
      ),
    );
    await pumpQuietly(tester, 12);
    return (seeded.$1, controller, vm);
  }

  /// تقرير معلَّب حتمي: كل السطور بأرقام مميزة.
  ProfitReport cannedReport() => ProfitReport(
    from: DateTime(2026, 10, 1),
    to: DateTime(2026, 10, 8),
    sales: 1250,
    salesReturns: 250,
    cogs: 700,
    returnCost: 150,
    stockSurplus: 300,
    stockShortage: 120,
    expenses: 180,
    fxGainLoss: 40,
    ownerDrawings: 90,
    salesInvoiceCount: 5,
    returnInvoiceCount: 2,
  );

  testWidgets('يعرض كل البنود والإجماليات الملزمة', (tester) async {
    await tester.runAsync(() async {
      final report = cannedReport();
      // الربح = (1250−250) − (700−150) + 300 − 120 − 180 + 40 = 490.
      final (app, controller, vm) = await pumpReady(tester, report);

      expect(find.text('الأرباح والخسائر'), findsOneWidget);
      // سطور الأقسام الأربعة.
      expect(find.text('المبيعات'), findsOneWidget);
      expect(find.text('مرتجع المبيعات'), findsOneWidget);
      expect(find.text('صافي المبيعات'), findsOneWidget);
      expect(find.text('تكلفة المبيعات (COGS)'), findsOneWidget);
      expect(find.text('تكلفة المرتجع'), findsOneWidget);
      expect(find.text('صافي التكلفة'), findsOneWidget);
      expect(find.text('زيادات الجرد'), findsOneWidget);
      expect(find.text('عجز الجرد'), findsOneWidget);
      expect(find.text('فروق الصرف المحققة'), findsOneWidget);
      // «المصاريف» مرتين: عنوان القسم وسطر البند.
      expect(find.text('المصاريف'), findsNWidgets(2));
      // المبالغ (YER منازل 0 — غربية بفواصل آلاف وإشارة).
      expect(find.text('+1,250'), findsOneWidget);
      expect(find.text('−250'), findsOneWidget);
      // بطاقتا الربح والإغلاق.
      expect(find.text('الربح'), findsOneWidget);
      expect(find.text('+490'), findsOneWidget);
      expect(find.text('صافي ما بقي للمالك'), findsOneWidget);
      expect(find.text('+400'), findsOneWidget, reason: '490 − 90 مسحوبات');
      expect(find.text('مسحوبات المالك (خارج المصاريف)'), findsOneWidget);
      expect(find.text('تقرير PDF'), findsOneWidget);
      // تفصيل عدد الفواتير الرخيص من المستودع.
      expect(find.textContaining('فواتير'), findsWidgets);

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('رقائق الفترات: التبديل إلى «اليوم» يحدّث النموذج', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // عرض أوسع حتى تتسع الرقائق الست كلها أفقياً (شريط أفقي قابل
      // للتمرير داخل 390 — التمرير غير مطلوب لصحة الاختبار).
      final (app, controller, vm) = await pumpReady(
        tester,
        cannedReport(),
        surface: const Size(900, 2000),
      );

      // الرقائق الست ظاهرة بمفاتيحها الثابتة (periodToday/… — عنصر مشترك).
      expect(find.byKey(const Key('periodToday')), findsOneWidget);
      expect(find.byKey(const Key('periodWeek')), findsOneWidget);
      expect(find.byKey(const Key('periodMonth')), findsOneWidget);
      expect(find.byKey(const Key('periodQuarter')), findsOneWidget);
      expect(find.byKey(const Key('periodYear')), findsOneWidget);
      expect(find.byKey(const Key('periodCustom')), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('هذا الشهر'), findsOneWidget);
      expect(find.text('هذه السنة'), findsOneWidget);
      expect(find.text('فترة مخصصة'), findsOneWidget);
      expect(vm.state.period, ReportPeriod.month);

      await tester.tap(find.byKey(const Key('periodToday')));
      await pumpQuietly(tester, 10);
      expect(vm.state.period, ReportPeriod.today);
      expect(vm.state.loading, isFalse);
      expect(vm.state.from, DateTime(2026, 10, 8));
      expect(vm.state.to, DateTime(2026, 10, 8));

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('الحالة الفارغة الاحتفالية عند لا حركة في الفترة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final empty = ProfitReport.zero(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 8),
      );
      final (app, controller, vm) = await pumpReady(tester, empty);

      expect(find.text('لا حركة في هذه الفترة'), findsOneWidget);
      // لا بطاقات تقرير في الفراغ.
      expect(find.byKey(const Key('profit_total_card')), findsNothing);
      expect(find.byKey(const Key('profit_lines_card')), findsNothing);

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });

  testWidgets('بطاقة الربح بشريط ذهبي مميز (FinCard.accent)', (tester) async {
    await tester.runAsync(() async {
      final (app, controller, vm) = await pumpReady(tester, cannedReport());

      final card = tester.widget<FinCard>(
        find.byKey(const Key('profit_total_card')),
      );
      expect(card.accent, FinColors.light.gold);

      // بطاقة الإغلاق حاضرة بلمسة أساسية متباينة.
      expect(find.byKey(const Key('profit_owner_card')), findsOneWidget);
      final owner = tester.widget<FinCard>(
        find.byKey(const Key('profit_owner_card')),
      );
      expect(owner.accent, isNot(FinColors.light.gold));

      await app.close();
      controller.dispose();
      vm.dispose();
    });
  });
}

/// مستودع معلَّب لاختبار الواجهة — يعيد التقرير المعلَّب نفسه أياً كانت
/// النافذة (لا SQL للأرباح؛ عملة الأساس فقط عبر CompanyRepository الحقيقي).
class _CannedProfitRepo extends ProfitReportRepository {
  _CannedProfitRepo(super.db, this.canned);

  final ProfitReport canned;

  @override
  Future<ProfitReport> report({
    required DateTime from,
    required DateTime to,
  }) async {
    return ProfitReport(
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      sales: canned.sales,
      salesReturns: canned.salesReturns,
      cogs: canned.cogs,
      returnCost: canned.returnCost,
      stockSurplus: canned.stockSurplus,
      stockShortage: canned.stockShortage,
      expenses: canned.expenses,
      fxGainLoss: canned.fxGainLoss,
      ownerDrawings: canned.ownerDrawings,
      salesInvoiceCount: canned.salesInvoiceCount,
      returnInvoiceCount: canned.returnInvoiceCount,
    );
  }
}
