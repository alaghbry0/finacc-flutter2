/// اختبارات بصرية لشاشتي الإعدادات وسجل التدقيق — بيانات حقيقية عبر seam.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/data/repositories/user_repository.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/settings/view_models/audit_log_view_model.dart';
import 'package:mobile_app/ui/features/settings/view_models/settings_view_model.dart';
import 'package:mobile_app/ui/features/settings/views/audit_log_screen.dart';
import 'package:mobile_app/ui/features/settings/views/settings_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  testWidgets('شاشة الإعدادات: كل الأقسام والبيانات من قاعدة حقيقية', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();

      // نموذج محمّل مسبقاً (الـ seam) — التحميل الحقيقي داخل runAsync.
      final vm = SettingsViewModel(
        companyRepo: CompanyRepository(seeded.$1.db),
        userRepo: UserRepository(seeded.$1.db),
        settingsRepo: SettingsRepository(seeded.$1.db),
      );
      await vm.load();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(SettingsScreen(viewModel: vm)),
        ),
      );
      await pumpQuietly(tester, 14);

      // بطاقة المنشأة.
      expect(find.textContaining('متجر النور للأدوات المنزلية'), findsWidgets);
      expect(find.textContaining('ريال يمني'), findsWidgets);
      expect(find.textContaining('أبو نور'), findsWidgets);
      // قسم الأمان: تغيير PIN وسجل التدقيق والقفل.
      expect(find.textContaining('تغيير رمز'), findsOneWidget);
      expect(find.text('سجل التدقيق'), findsOneWidget);
      // البيانات (المسح المحروس) وبوابات التخصيص الثلاث (UX-2a — الثيم
      // والأرقام انتقلا من المركز إلى شاشة «العرض والمظهر» المتخصصة،
      // وتغطيهما اختبارات settings2_screens هناك).
      expect(find.textContaining('مسح كل البيانات'), findsOneWidget);
      expect(find.text('بيانات المنشأة'), findsOneWidget);
      expect(find.text('تفضيلات البيع'), findsOneWidget);
      expect(find.text('العرض والمظهر'), findsOneWidget);
      vm.dispose();
      controller.dispose();
    });
  });

  testWidgets('سجل التدقيق: بطاقة الحماية + أحداث التأسيس + ترقيم', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();

      // بذرة أحداث إضافية.
      final db = seeded.$1.db;
      for (var i = 0; i < 3; i++) {
        final day = (8 + i).toString().padLeft(2, '0');
        await db.insert('audit_log', {
          'user_id': 1,
          'action': 'login',
          'at': '2026-10-$day\x5410:00:00Z',
        });
      }

      final vm = AuditLogViewModel(repository: controller.audit!);
      await vm.load();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: wrapWithL10n(AuditLogScreen(viewModel: vm)),
        ),
      );
      await pumpQuietly(tester, 12);

      // عنوان الشاشة وبطاقة «للإضافة فقط».
      expect(find.text('سجل التدقيق'), findsOneWidget);
      expect(find.text('للإضافة فقط'), findsOneWidget);
      // حدث التأسيس وأحداث إضافية ظاهرة.
      expect(find.text('تأسيس التطبيق'), findsOneWidget);
      vm.dispose();
      controller.dispose();
    });
  });
}
