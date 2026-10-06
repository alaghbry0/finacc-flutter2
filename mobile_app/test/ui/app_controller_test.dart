/// اختبارات متحكم الجلسة — الأطوار والإعدادات الحية والقفل التلقائي.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;

  setUp(() async {
    app = await openUniqueFileApp();
  });

  tearDown(() async {
    await app.close();
  });

  test('التهيئة فوق قاعدة فارغة: needsOnboarding والافتراضيات سليمة', () async {
    final controller = AppController(forTesting: app);
    await controller.decidePhaseForTest();
    expect(controller.phase, AppPhase.needsOnboarding);
    expect(controller.company, isNull);
    expect(controller.themeMode, 'system');
    expect(controller.numerals, 'western');
    expect(controller.autolockMinutes, 5);
    expect(controller.audit, isNotNull);
    expect(controller.companies, isNotNull);
    expect(controller.settings, isNotNull);
    expect(controller.dashboard, isNotNull);
    expect(controller.users, isNotNull);
  });

  test('بعد التأسيس: الجلسة الجديدة مقفلة دائماً (FR-12-01)', () async {
    final companies = CompanyRepository(app.db);
    final controller = AppController(forTesting: app);
    await companies.executeSetup(testDraft(), DateTime.utc(2026, 10, 6, 12));
    await controller.decidePhaseForTest();
    expect(controller.phase, AppPhase.locked);
    expect(controller.company!.name, 'متجر النور للأدوات المنزلية');
  });

  test('unlockSession يدخل الجلسة، وlock يقفل — ولا قفل خارج ready', () async {
    final controller = AppController(forTesting: app);
    await controller.decidePhaseForTest();

    // lock من needsOnboarding يتجاهل.
    controller.lock();
    expect(controller.phase, AppPhase.needsOnboarding);

    // دخول الجلسة.
    controller.unlockSession();
    expect(controller.phase, AppPhase.ready);
    controller.lock();
    expect(controller.phase, AppPhase.locked);
    // lock مرة ثانية يبقى مقفلاً (لا دوران).
    controller.lock();
    expect(controller.phase, AppPhase.locked);
  });

  group('نظام الأرقام الحي', () {
    test('setNumerals يثبّت محلياً وفي القاعدة ويرفض المجهول', () async {
      final controller = AppController(forTesting: app);
      await controller.decidePhaseForTest();

      await controller.setNumerals('arabic_indic');
      expect(controller.numerals, 'arabic_indic');
      expect(controller.arabicIndicNumerals, isTrue);
      final stored = await app.db.query(
        'settings',
        where: "key = 'display.numerals'",
      );
      expect(stored.first['value'], '"arabic_indic"');

      // قيمة غير معروفة ترفض.
      await controller.setNumerals('roman');
      expect(controller.numerals, 'arabic_indic');
    });

    test('القراءة عند التهيئة تعكس المحفوظ (استمرارية)', () async {
      final settings = SettingsRepository(app.db);
      await settings.setNumerals('arabic_indic');
      final controller = AppController(forTesting: app);
      await controller.decidePhaseForTest();
      expect(controller.numerals, 'arabic_indic');
      expect(controller.arabicIndicNumerals, isTrue);
    });
  });

  group('وضع الثيم الحي', () {
    test('setThemeMode ينعكس فوراً ويحفظ', () async {
      final controller = AppController(forTesting: app);
      await controller.decidePhaseForTest();
      await controller.setThemeMode('dark');
      expect(controller.themeMode, 'dark');
      final stored = await app.db.query(
        'settings',
        where: "key = 'ui.theme_mode'",
      );
      expect(stored.first['value'], '"dark"');
    });

    test('القيمة المحفوظة تُقرأ عند التهيئة', () async {
      final settings = SettingsRepository(app.db);
      await settings.setThemeMode('light');
      final controller = AppController(forTesting: app);
      await controller.decidePhaseForTest();
      expect(controller.themeMode, 'light');
    });
  });

  group('مدة القفل التلقائي (FR-12-05)', () {
    test('النطاق الملزم 1-60 مع قيد تدقيق للتغيير', () async {
      final controller = AppController(forTesting: app);
      await controller.decidePhaseForTest();

      await controller.setAutolockMinutes(15);
      expect(controller.autolockMinutes, 15);
      expect(() => controller.setAutolockMinutes(0), throwsArgumentError);
      expect(() => controller.setAutolockMinutes(61), throwsArgumentError);

      // قيد تدقيق للتغيير الأمني.
      final auditRows = await app.db.query(
        'audit_log',
        where: "action = 'settings_change'",
      );
      expect(auditRows, hasLength(1));
      expect(auditRows.first['details'], 'security.autolock_minutes=15');
    });

    test('القيمة المحفوظة تُقرأ عند التهيئة', () async {
      final settings = SettingsRepository(app.db);
      await settings.setAutolockMinutes(30);
      final controller = AppController(forTesting: app);
      await controller.decidePhaseForTest();
      expect(controller.autolockMinutes, 30);
    });
  });

  test('العودة السريعة من الخلفية تجدد النشاط ولا تقفل', () async {
    final controller = AppController(forTesting: app);
    await controller.decidePhaseForTest();
    controller.unlockSession();
    expect(controller.phase, AppPhase.ready);

    // غياب قصير جداً — لا قفل.
    controller.appHidden();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    controller.appResumed();
    expect(controller.phase, AppPhase.ready);
  });

  test('completeOnboarding يعيد قراءة المنشأة ويدخل الجلسة', () async {
    final controller = AppController(forTesting: app);
    await controller.decidePhaseForTest();
    await controller.companies!.executeSetup(
      testDraft(),
      DateTime.utc(2026, 10, 6, 12),
    );
    await controller.completeOnboarding();
    expect(controller.phase, AppPhase.ready);
    expect(controller.company!.name, 'متجر النور للأدوات المنزلية');
  });

  test('touch يجدد آخر نشاط (خمول القفل التلقائي)', () async {
    final controller = AppController(forTesting: app);
    await controller.decidePhaseForTest();
    controller.unlockSession();
    final before = controller.lastActivityForTest;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    controller.touch();
    expect(
      controller.lastActivityForTest.isAfter(before),
      isTrue,
      reason: 'touch يجب أن يجدد لحظة النشاط',
    );
  });
}
