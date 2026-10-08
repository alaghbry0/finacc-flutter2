/// اختبارات شاشات موجة UX-2a بالـseam الموثق (نمط aging/stocktake):
/// نموذج محمّل مسبقاً داخل runAsync ثم تفاعل حقيقي:
/// شاشة بيانات المنشأة (حقول مُعبأة + حفظ + رافع شعار) وشاشة تفضيلات
/// البيع (خيارات افتراضية + تبديل يحدّث المستودع).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/settings/views/appearance_screen.dart';
import 'package:mobile_app/ui/features/settings/views/company_profile_screen.dart';
import 'package:mobile_app/ui/features/settings/views/sale_preferences_screen.dart';
import 'package:mobile_app/ui/features/settings/view_models/company_profile_view_model.dart';
import 'package:mobile_app/ui/features/settings/view_models/sale_preferences_view_model.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

/// شعار PNG صالح 1×1 بكسل (70 بايت، IHDR+IDAT+IEND بصياغة zlib صحيحة) —
/// رافع الشعار الحقيقي (image_picker) يعيد بايتات قابلة للفك دائماً؛
/// بايتات مبتورة كانت تفشل فك الترميز (Invalid image data) وتُفشل
/// الاختبار قبل أي فحص.
final Uint8List validLogoPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0xF0,
  0x1F,
  0x00,
  0x05,
  0x00,
  0x01,
  0xFF,
  0x89,
  0x99,
  0x3D,
  0x1D,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  setUpAll(initFfiForTests);

  group('CompanyProfileScreen — seam', () {
    testWidgets('الحقول مُعبأة ببيانات المنشأة والعملة معروضة', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        final seeded = await openSeededApp();
        addTearDown(seeded.$1.close);
        final vm = CompanyProfileViewModel(
          companyRepo: CompanyRepository(seeded.$1.db),
          logoPicker: () async => null,
        );
        await vm.load();
        addTearDown(vm.dispose);

        await tester.pumpWidget(
          wrapWithL10n(CompanyProfileScreen(viewModel: vm)),
        );
        await pumpQuietly(tester, 10);

        expect(find.byType(CompanyProfileScreen), findsOneWidget);
        // الاسم والهاتف من التأسيس معبّئين في الحقلين.
        expect(
          tester
              .widget<TextField>(
                find
                    .descendant(
                      of: find.byType(CompanyProfileScreen),
                      matching: find.byType(TextField),
                    )
                    .at(0),
              )
              .controller!
              .text,
          'متجر النور للأدوات المنزلية',
        );
        expect(
          tester
              .widget<TextField>(
                find
                    .descendant(
                      of: find.byType(CompanyProfileScreen),
                      matching: find.byType(TextField),
                    )
                    .at(1),
              )
              .controller!
              .text,
          '777123456',
        );
        // زر الرفع ظاهر (رافع الشعار متوفر) وبلا شعار بعد.
        expect(find.text('اختيار شعار'), findsOneWidget);
        expect(find.byType(Image), findsNothing);
      });
    });

    testWidgets(
      'تعديل الاسم + رفع شعار + حفظ → المستودع تغيّر والمعاينة ظهرت',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.runAsync(() async {
          final seeded = await openSeededApp();
          addTearDown(seeded.$1.close);
          final companies = CompanyRepository(seeded.$1.db);
          final logo = validLogoPng;
          final vm = CompanyProfileViewModel(
            companyRepo: companies,
            logoPicker: () async => logo,
          );
          await vm.load();
          addTearDown(vm.dispose);

          await tester.pumpWidget(
            wrapWithL10n(CompanyProfileScreen(viewModel: vm)),
          );
          await pumpQuietly(tester, 10);

          // رفع الشعار عبر زر الرفع (seam يرجع البايتات).
          await tester.tap(find.text('اختيار شعار'));
          await pumpQuietly(tester, 6);
          expect(find.byType(Image), findsOneWidget, reason: 'معاينة الشعار');

          // تعديل الاسم.
          await tester.enterText(
            find
                .descendant(
                  of: find.byType(CompanyProfileScreen),
                  matching: find.byType(TextField),
                )
                .at(0),
            'مؤسسة النور للتجارة',
          );
          await pumpQuietly(tester, 4);

          // الحفظ.
          await tester.tap(find.text('حفظ التعديلات'));
          await pumpQuietly(tester, 8);
          // مهلة حقيقية بعد الحفظ قبل أي فحص/إغلاق — الحفظ عبر FFI حقيقي
          // والإغلاق قبله يفجر database_closed (نمط منتقي العميل الموثق).
          await Future<void>.delayed(const Duration(milliseconds: 300));

          final reread = await companies.findCompany();
          expect(reread!.name, 'مؤسسة النور للتجارة');
          expect(reread.logoPng, logo);
        });
      },
    );
  });

  group('SalePreferencesScreen — seam', () {
    testWidgets('الخيارات الافتراضية معروضة (نقدي محدد، تحذيرات مفعّلة)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        final seeded = await openSeededApp();
        addTearDown(seeded.$1.close);
        final vm = SalePreferencesViewModel(
          settingsRepo: SettingsRepository(seeded.$1.db),
        );
        await vm.load();
        addTearDown(vm.dispose);

        await tester.pumpWidget(
          wrapWithL10n(SalePreferencesScreen(viewModel: vm)),
        );
        await pumpQuietly(tester, 10);

        expect(find.text('تفضيلات البيع'), findsWidgets);
        expect(find.text('طريقة الدفع الافتراضية'), findsOneWidget);
        expect(find.text('نقدي كامل'), findsOneWidget);
        // المفاتيح الافتراضية on.
        final switches = tester
            .widgetList<Switch>(find.byType(Switch))
            .toList();
        expect(switches, hasLength(2));
        expect(switches.first.value, isTrue, reason: 'إظهار الخصومات on');
        expect(switches.last.value, isFalse, reason: 'تحذير التكلفة off');
      });
    });

    testWidgets('تبديل سياسة حد الائتمان إلى «منع» يكتب في المستودع', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        final seeded = await openSeededApp();
        addTearDown(seeded.$1.close);
        final repo = SettingsRepository(seeded.$1.db);
        final vm = SalePreferencesViewModel(settingsRepo: repo);
        await vm.load();
        addTearDown(vm.dispose);

        await tester.pumpWidget(
          wrapWithL10n(SalePreferencesScreen(viewModel: vm)),
        );
        await pumpQuietly(tester, 10);

        // خيار «منع» لسياسة حد الائتمان (أول ظهور).
        await tester.tap(find.text('منع').first);
        await pumpQuietly(tester, 6);

        expect(await repo.creditLimitAction(), 'block');
      });
    });
  });

  group('AppearanceScreen — seam', () {
    testWidgets('الثيم والأرقام وحجم الخط والتباين معروضة حية', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        final seeded = await openSeededApp();
        addTearDown(seeded.$1.close);
        final controller = AppController(forTesting: seeded.$1);
        await controller.decidePhaseForTest();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppController>.value(
            value: controller,
            child: wrapWithL10n(const AppearanceScreen()),
          ),
        );
        await pumpQuietly(tester, 10);

        expect(find.text('العرض والمظهر'), findsOneWidget);
        // الثيم ونظام الأرقام (انتقلا هنا من مركز الإعدادات — UX-2a).
        expect(find.text('تلقائي (حسب النظام)'), findsOneWidget);
        expect(find.text('فاتح'), findsOneWidget);
        expect(find.text('داكن'), findsOneWidget);
        expect(find.text('نظام الأرقام'), findsOneWidget);
        expect(find.text('غربي'), findsOneWidget);
        expect(find.text('عربي شرقي'), findsOneWidget);
        // حجم الخط: المستويات الثلاثة (العادي محدد افتراضياً).
        expect(find.text('عادي'), findsOneWidget);
        expect(find.text('كبير'), findsOneWidget);
        expect(find.text('أكبر'), findsOneWidget);
        // التباين العالي: مفتاح مغلق افتراضياً.
        final sw = tester.widget<Switch>(find.byType(Switch));
        expect(sw.value, isFalse);
      });
    });

    testWidgets('تبديل التباين العالي من الشاشة يكتب في المستودع', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        final seeded = await openSeededApp();
        addTearDown(seeded.$1.close);
        final controller = AppController(forTesting: seeded.$1);
        await controller.decidePhaseForTest();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppController>.value(
            value: controller,
            child: wrapWithL10n(const AppearanceScreen()),
          ),
        );
        await pumpQuietly(tester, 10);

        await tester.tap(find.byType(Switch));
        await pumpQuietly(tester, 6);
        // مهلة حقيقية بعد الكتابة (FFI) قبل أي فحص/إغلاق — النمط الموثق.
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(await controller.settings!.highContrast(), isTrue);
        expect(controller.highContrast, isTrue);
      });
    });
  });
}
