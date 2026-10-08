/// اختبارات شاشة أعمار الديون (FR-09-05):
///
/// 1. التوجيه `/reports` → `/reports/aging` عبر الراوتر الحقيقي.
/// 2. عرض التقرير بالبيانات عبر **seam** — نموذج محمّل مسبقاً داخل
///    `tester.runAsync` (الاستعلامات FFI لا تتقدم في منطقة الاختبار
///    الزائفة — نمط `inventory_screens_test`/`settings_and_audit_test`)
///    مع لحظة احتساب محقونة ثابتة، ثم: الدلاء الأربعة، توسيع تفاصيل
///    الفواتير، بناء رسالة التذكير، وزر واتساب بلا رقم (تنبيه ودود).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/debt_aging_repository.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/router/app_router.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/reports/view_models/aging_view_model.dart';
import 'package:mobile_app/ui/features/reports/views/aging_report_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

/// لحظة الاحتساب المحقونة — ثابتة فيبقى التصنيف حتمياً.
final DateTime _asOf = DateTime.utc(2026, 10, 8);

void main() {
  setUpAll(initFfiForTests);

  testWidgets('جذر /reports يفتح مركز التقارير وبطاقة أعمار الديون تعمل', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();

      final router = buildAppRouter(controller);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await pumpQuietly(tester, 6);

      router.go('/reports');
      await pumpQuietly(tester, 8);
      // الشريحة 10: الجذر صار مركز التقارير (بدل التحويل القديم).
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/reports',
        reason: 'جذر التقارير يفتح مركز التقارير',
      );
      expect(find.text('التقارير'), findsWidgets);
      // بطاقة أعمار الديون داخل قسم الديون والتحصيل.
      expect(find.text('أعمار الديون'), findsOneWidget);

      // الضغط على البطاقة يفتح التقرير نفسه (هيكله العظمي أثناء التحميل).
      await tester.tap(find.text('أعمار الديون'));
      await pumpQuietly(tester, 8);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/reports/aging',
        reason: 'بطاقة الأعمار تفتح /reports/aging',
      );

      router.dispose();
      controller.dispose();
    });
  });

  testWidgets('التقرير: دلاء وملخص وتوسيع وتذكير واتساب', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final db = seeded.$1.db;
      final warehouseId =
          (await db.query('warehouse', limit: 1)).first['id'] as int;
      final yer =
          (await db.rawQuery(
                "SELECT id FROM currency WHERE code = 'YER' LIMIT 1",
              )).first['id']
              as int;

      // عميل بووتساب: متأخرة ٣٣ يوماً (٣١–٦٠) + مستقبلية غير مستحقة بعد
      // (٠–٣٠ مع currentNotDue) — الإجمالي ٤٠٠.
      final tabrirId = await db.insert('customer', {
        'name': 'عميل التعمير',
        'phone': '777000111',
        'whatsapp': '777000111',
        'is_archived': 0,
        'created_at': '2026-09-01T00:00:00.000Z',
      });
      await db.insert('invoice', {
        'invoice_no': 'AG-SMOKE-1',
        'doc_type': 'sale',
        'pay_status': 'credit',
        'status': 'completed',
        'issued_at': '2026-09-05T10:00:00.000Z',
        'due_date': '2026-09-05',
        'warehouse_id': warehouseId,
        'customer_id': tabrirId,
        'currency_id': yer,
        'exchange_rate': 1,
        'total': 250,
        'paid_amount': 0,
        'due_amount': 250,
      });
      await db.insert('invoice', {
        'invoice_no': 'AG-SMOKE-2',
        'doc_type': 'sale',
        'pay_status': 'credit',
        'status': 'completed',
        'issued_at': '2026-10-01T10:00:00.000Z',
        'due_date': '2026-11-30',
        'warehouse_id': warehouseId,
        'customer_id': tabrirId,
        'currency_id': yer,
        'exchange_rate': 1,
        'total': 150,
        'paid_amount': 0,
        'due_amount': 150,
      });

      // عميل بلا أي رقم: دين عميق (+٩٠) — زر واتسابه ينبه بغياب الرقم.
      final noNumberId = await db.insert('customer', {
        'name': 'عميل بلا أرقام',
        'is_archived': 0,
        'created_at': '2026-09-01T00:00:00.000Z',
      });
      await db.insert('invoice', {
        'invoice_no': 'AG-SMOKE-3',
        'doc_type': 'sale',
        'pay_status': 'credit',
        'status': 'completed',
        'issued_at': '2026-06-20T10:00:00.000Z',
        'due_date': '2026-07-01',
        'warehouse_id': warehouseId,
        'customer_id': noNumberId,
        'currency_id': yer,
        'exchange_rate': 1,
        'total': 90,
        'paid_amount': 0,
        'due_amount': 90,
      });

      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();

      // النموذج محمّل مسبقاً (seam) — التحميل الحقيقي داخل runAsync مع
      // لحظة احتساب محقونة.
      final vm = AgingViewModel(
        debtRepo: DebtAgingRepository(db),
        companyRepo: CompanyRepository(db),
        company: controller.company,
        reference: _asOf,
      );
      await vm.load();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(AgingReportScreen(viewModel: vm)),
        ),
      );
      await pumpQuietly(tester, 12);

      // العنوان والعملاء المدينون وشرائح الدلاء الأربعة في الملخص.
      expect(find.text('أعمار الديون'), findsOneWidget);
      expect(find.text('عميل التعمير'), findsOneWidget);
      expect(find.text('عميل بلا أرقام'), findsOneWidget);
      expect(find.text('٠–٣٠ يوماً'), findsOneWidget);
      expect(find.text('٣١–٦٠ يوماً'), findsOneWidget);
      expect(find.text('٦١–٩٠ يوماً'), findsOneWidget);
      expect(find.text('أكثر من ٩٠ يوماً'), findsOneWidget);

      // نموذج العرض: العملة الأساسية ودلاء السطر الأول وأرقام التذكير.
      expect(vm.state.currencyId, yer);
      expect(vm.state.report!.currencyCode, 'YER');
      final first = vm.state.report!.rows.first;
      expect(first.name, 'عميل التعمير');
      expect(first.bucket31to60, 250);
      expect(first.bucket0to30, 150);
      expect(first.currentNotDue, 150);
      expect(vm.whatsappDigits(first), '777000111');
      expect(
        vm.whatsappDigits(vm.state.report!.rows.last),
        isNull,
        reason: 'عميل بلا أرقام لا وجهة تذكير له',
      );

      // رسالة التذكير: الاسم + المنشأة + الإجمالي بعملته.
      final l10n = AppLocalizations.of(
        tester.element(find.text('أعمار الديون')),
      )!;
      final message = vm.reminderMessage(l10n, first);
      expect(message, contains('عميل التعمير'));
      expect(message, contains('متجر النور للأدوات المنزلية'));
      expect(message, contains('400 YER'));

      // التوسيع يكشف تفاصيل الفواتير المفتوحة — المؤشّر يدور نصف دورة
      // (AnimatedCrossFade يبقي الطرف المخفي في الشجرة بشفافية صفر فيُتحقَّق
      // بالحالة لا بالوجود).
      final tabrirCard = find.byKey(Key('aging_row_${yer}_$tabrirId'));
      final chevron = find.descendant(
        of: tabrirCard,
        matching: find.byType(AnimatedRotation),
      );
      expect(tester.widget<AnimatedRotation>(chevron).turns, 0.0);
      await tester.tap(find.text('عميل التعمير'));
      await pumpQuietly(tester, 8);
      expect(tester.widget<AnimatedRotation>(chevron).turns, 0.5);
      expect(find.text('AG-SMOKE-1'), findsOneWidget);
      expect(find.text('AG-SMOKE-2'), findsOneWidget);

      // زر تذكير واتساب حاضر لكل مدين؛ وبلا رقم يظهر التنبيه الودود.
      expect(find.byTooltip('إرسال تذكير واتساب'), findsNWidgets(2));
      final noNumberCard = find.byKey(Key('aging_row_${yer}_$noNumberId'));
      expect(noNumberCard, findsOneWidget);
      await tester.tap(
        find.descendant(
          of: noNumberCard,
          matching: find.byTooltip('إرسال تذكير واتساب'),
        ),
      );
      await pumpQuietly(tester, 8);
      expect(
        find.textContaining('لا يوجد رقم واتساب أو هاتف'),
        findsOneWidget,
        reason: 'تنبيه SnackBar عند غياب أي رقم',
      );

      vm.dispose();
      controller.dispose();
    });
  });
}
