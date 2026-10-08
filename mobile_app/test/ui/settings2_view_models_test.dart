/// اختبارات نماذج عرض موجة UX-2a — محرر بيانات المنشأة (تحميل/حفظ/
/// حراسة/رافع الشعار seam) + تفضيلات البيع (تحميل/تبديل يحدّث المستودع)
/// + متحكم الجلسة لحجم الخط والتباين العالي (تثبيت محلي وقاعدي).
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/settings/view_models/company_profile_view_model.dart';
import 'package:mobile_app/ui/features/settings/view_models/sale_preferences_view_model.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  group('CompanyProfileViewModel — محرر بيانات المنشأة', () {
    test('التحميل: كل حقول المنشأة المؤسَّسة + العملة الأساسية', () async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final vm = CompanyProfileViewModel(companyRepo: seeded.$2);
      await vm.load();

      expect(vm.state.loading, isFalse);
      expect(vm.state.error, isNull);
      expect(vm.name, 'متجر النور للأدوات المنزلية');
      expect(vm.phone, '777123456');
      expect(vm.whatsapp, '');
      expect(vm.address, '');
      expect(vm.taxRateText, '0');
      expect(vm.footerText, '');
      expect(vm.logoPng, isNull);
      expect(vm.state.currency!.code, 'YER');
      vm.dispose();
    });

    test('الحفظ الكامل: يحدّث المستودع بكل الحقول + الشعار BLOB', () async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final logo = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 9, 9]);
      final vm = CompanyProfileViewModel(
        companyRepo: seeded.$2,
        logoPicker: () async => logo,
      );
      await vm.load();

      vm.setName('مؤسسة النور التجارية');
      vm.setPhone('712345678');
      vm.setWhatsapp('712345678');
      vm.setAddress('عدن - كريتر');
      vm.setTaxNumber('TAX-999');
      vm.setTaxRateText('5');
      vm.setFooterText('الأسعار شاملة الضريبة');
      expect(await vm.pickLogo(), isNull, reason: 'الشعار ضمن الحجم');
      expect(vm.logoPng, logo);

      expect(await vm.save(), isTrue);
      expect(vm.state.saved, isTrue);
      expect(vm.state.saveError, isNull);

      final reread = (await seeded.$2.findCompany())!;
      expect(reread.name, 'مؤسسة النور التجارية');
      expect(reread.phone, '712345678');
      expect(reread.whatsapp, '712345678');
      expect(reread.address, 'عدن - كريتر');
      expect(reread.taxNumber, 'TAX-999');
      expect(reread.taxRate, 5);
      expect(reread.footerText, 'الأسعار شاملة الضريبة');
      expect(reread.logoPng, logo);
      vm.dispose();
    });

    test('الحراسة: اسم فارغ ونسبة ضريبية شاذة ترفضان بلا كتابة', () async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final vm = CompanyProfileViewModel(companyRepo: seeded.$2);
      await vm.load();
      final before = await seeded.$2.findCompany();

      vm.setName('   ');
      expect(await vm.save(), isFalse);
      expect(vm.state.saveError, 'NAME_REQUIRED');

      vm.setName('اسم سليم');
      vm.setTaxRateText('250');
      expect(await vm.save(), isFalse);
      expect(vm.state.saveError, 'TAX_RATE_INVALID');

      vm.setTaxRateText('abc');
      expect(vm.validate(), 'TAX_RATE_INVALID');

      // لم يُكتب شيء قط.
      final after = await seeded.$2.findCompany();
      expect(after!.name, before!.name);
      expect(after.taxRate, before.taxRate);
      vm.dispose();
    });

    test('رافع الشعار seam: صورة ضخمة ترفض برسالة ولا تدخل الحالة', () async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final huge = Uint8List.fromList(
        List<int>.filled(kCompanyLogoMaxBytes + 1, 7),
      );
      final vm = CompanyProfileViewModel(
        companyRepo: seeded.$2,
        logoPicker: () async => huge,
      );
      await vm.load();
      expect(await vm.pickLogo(), 'LOGO_TOO_LARGE');
      expect(vm.logoPng, isNull);
      vm.dispose();
    });
  });

  group('SalePreferencesViewModel — تفضيلات البيع', () {
    test('التحميل: الافتراضيات الخمس من بذور الملحق', () async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final vm = SalePreferencesViewModel(
        settingsRepo: SettingsRepository(seeded.$1.db),
      );
      await vm.load();

      expect(vm.state.loading, isFalse);
      expect(vm.state.defaultPayment, 'cash');
      expect(vm.state.showDiscounts, isTrue);
      expect(vm.state.creditLimitAction, 'warn');
      expect(vm.state.overAvailPolicy, 'warn');
      expect(vm.state.warnBelowMargin, isFalse);
      vm.dispose();
    });

    test('تبديل كل خيار يحدّث المستودع فوراً (قراءة مستقلة تؤكد)', () async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final repo = SettingsRepository(seeded.$1.db);
      final vm = SalePreferencesViewModel(settingsRepo: repo);
      await vm.load();

      await vm.setDefaultPayment('mixed');
      await vm.setShowDiscounts(false);
      await vm.setCreditLimitAction('block');
      await vm.setOverAvailPolicy('block');
      await vm.setWarnBelowMargin(true);

      expect(vm.state.defaultPayment, 'mixed');
      expect(vm.state.showDiscounts, isFalse);
      expect(vm.state.creditLimitAction, 'block');
      expect(vm.state.overAvailPolicy, 'block');
      expect(vm.state.warnBelowMargin, isTrue);

      // المستودع (قراءة مستقلة عبر موصّلاته) — لا مجرد الحالة الحية.
      expect(await repo.defaultPayment(), 'mixed');
      expect(await repo.showDiscounts(), isFalse);
      expect(await repo.creditLimitAction(), 'block');
      expect(await repo.overAvailPolicy(), 'block');
      expect(await repo.discountBelowMargin(), isTrue);
      vm.dispose();
    });
  });

  group('AppController — حجم الخط والتباين العالي (display.font_scale / ui.high_contrast)', () {
    test(
      'القراءة عند التهيئة + المعاملات (1.0/1.15/1.3) + رفض المجهول',
      () async {
        final app = await openUniqueFileApp();
        addTearDown(app.close);
        final controller = AppController(forTesting: app);
        await controller.decidePhaseForTest();

        expect(controller.fontScale, 'normal');
        expect(controller.fontScaleFactor, 1.0);
        expect(controller.highContrast, isFalse);

        await controller.setFontScale('large');
        expect(controller.fontScale, 'large');
        expect(controller.fontScaleFactor, closeTo(1.15, 0.001));

        await controller.setFontScale('xlarge');
        expect(controller.fontScaleFactor, closeTo(1.3, 0.001));

        // المجهول يُتجاهل بصمت (نمط setNumerals).
        await controller.setFontScale('huge');
        expect(controller.fontScale, 'xlarge');

        // الثبات القاعدي.
        final stored = await app.db.query(
          'settings',
          where: "key = 'display.font_scale'",
        );
        expect(stored.first['value'], '"xlarge"');
        controller.dispose();
      },
    );

    test('setHighContrast يثبّت محلياً وفي القاعدة', () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final controller = AppController(forTesting: app);
      await controller.decidePhaseForTest();

      await controller.setHighContrast(true);
      expect(controller.highContrast, isTrue);
      final stored = await app.db.query(
        'settings',
        where: "key = 'ui.high_contrast'",
      );
      expect(stored.first['value'], '"on"');

      await controller.setHighContrast(false);
      expect(controller.highContrast, isFalse);
      final after = await app.db.query(
        'settings',
        where: "key = 'ui.high_contrast'",
      );
      expect(after.first['value'], '"off"');
      controller.dispose();
    });

    test('القيم تُقرأ من القاعدة عند التهيئة (بقاء عبر الإقلاع)', () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final repo = SettingsRepository(app.db);
      await repo.setFontScale('large');
      await repo.setHighContrast(true);

      final controller = AppController(forTesting: app);
      await controller.decidePhaseForTest();
      expect(controller.fontScale, 'large');
      expect(controller.highContrast, isTrue);
      controller.dispose();
    });
  });
}
