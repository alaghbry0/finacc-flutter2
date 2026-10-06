/// اختبارات نموذج عرض الإعدادات — التجميع الموحد والخطأ.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/data/repositories/user_repository.dart';
import 'package:mobile_app/ui/features/settings/view_models/settings_view_model.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  test('التجميع الموحد: منشأة/عملة/مدير/قفل/ثيم من قاعدة مؤسسة', () async {
    final seeded = await openSeededApp();
    addTearDown(seeded.$1.close);

    final settingsRepo = SettingsRepository(seeded.$1.db);
    await settingsRepo.setAutolockMinutes(20);
    await settingsRepo.setThemeMode('dark');

    final vm = SettingsViewModel(
      companyRepo: CompanyRepository(seeded.$1.db),
      userRepo: UserRepository(seeded.$1.db),
      settingsRepo: settingsRepo,
    );
    await vm.load();

    expect(vm.state.loading, isFalse);
    expect(vm.state.error, isNull);
    expect(vm.state.company!.name, 'متجر النور للأدوات المنزلية');
    expect(vm.state.baseCurrency!.code, 'YER');
    expect(vm.state.adminName, 'أبو نور');
    expect(vm.state.autolockMinutes, 20);
    expect(vm.state.themeMode, 'dark');
    vm.dispose();
  });

  test('قاعدة فارغة: بلا منشأة لكن بلا خطأ (قبل Onboarding)', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final vm = SettingsViewModel(
      companyRepo: CompanyRepository(app.db),
      userRepo: UserRepository(app.db),
      settingsRepo: SettingsRepository(app.db),
    );
    await vm.load();
    expect(vm.state.loading, isFalse);
    expect(vm.state.company, isNull);
    // العملة الأساسية مبذورة (YER) حتى قبل تأسيس المنشأة.
    expect(vm.state.baseCurrency!.code, 'YER');
    expect(vm.state.adminName, isNull);
    expect(vm.state.autolockMinutes, 5);
    expect(vm.state.themeMode, 'system');
    vm.dispose();
  });

  test('خطأ التجميع: حالة error مع بقاء القيم السابقة', () async {
    final app = await openUniqueFileApp();
    final vm = SettingsViewModel(
      companyRepo: CompanyRepository(app.db),
      userRepo: UserRepository(app.db),
      settingsRepo: SettingsRepository(app.db),
    );
    await vm.load();
    expect(vm.state.loading, isFalse);
    await app.close(); // القراءة التالية تفشل.
    await vm.load();
    expect(vm.state.error, isNotNull);
    expect(vm.state.loading, isFalse);
    vm.dispose();
  });
}
