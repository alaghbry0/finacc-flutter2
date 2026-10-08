/// اختبارات تذكير النسخ في لوحة التحكم (FR-11-04 — الشريحة 8): نسخة
/// تلقائية صامتة عند دخول اللوحة إن حان وقتها وبانر بنتيجتها + حالة الويب.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/dashboard_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/data/services/backup/backup_service.dart';
import 'package:mobile_app/data/services/backup/backup_store_io.dart';
import 'package:mobile_app/data/services/backup/backup_store_web.dart';
import 'package:mobile_app/ui/features/home/view_models/home_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  /// جهاز حقيقي كامل: قاعدة مؤسَّسة + محرك نسخ فوق مخزن IO بمسارها.
  Future<(DashboardViewModel, BackupService, AppDatabase)> bootReal() async {
    final dir = await Directory.systemTemp.createTemp('finacc_dash_test');
    addTearDown(() => dir.delete(recursive: true));
    final dbPath = '${dir.path}/finacc.db';
    final app = await AppDatabase.openWith(databaseFactory, dbPath);
    addTearDown(app.close);
    await CompanyRepository(app.db)
        .executeSetup(testDraft(), DateTime.utc(2026, 10, 6, 12));
    final service = BackupService(
      database: app,
      settings: SettingsRepository(app.db),
      store: IoBackupStore(dbPath: dbPath),
    );
    final vm = DashboardViewModel(
      repository: DashboardRepository(app.db),
      backupEngine: service,
    );
    addTearDown(vm.dispose);
    return (vm, service, app);
  }

  test(
    'استحقاق أسبوعي بلا نسخة سابقة: نسخة صامتة + بانر نجاح قابل للإخفاء',
    () async {
      final (vm, service, _) = await bootReal();
      await vm.load(companyName: 'متجر النور للأدوات المنزلية');

      expect(vm.state.loading, isFalse);
      expect(vm.state.error, isNull);
      final reminder = vm.backupReminder;
      expect(reminder, isNotNull);
      expect(reminder!.kind, BackupReminderKind.autoDone);
      expect(reminder.at, isNotNull);
      expect(reminder.sizeBytes, greaterThan(0));

      // نسخة تلقائية فعلًا على القرص + لا استحقاق بعدها.
      final info = await service.dueInfo();
      expect(info.isDue, isFalse);
      expect(await service.listEntries(), isNotEmpty);

      // الإخفاء لبقية الجلسة.
      vm.dismissBackupReminder();
      expect(vm.backupReminder, isNull);
    },
  );

  test('الجدولة off: لا نسخة ولا بانر', () async {
    final (vm, _, app) = await bootReal();
    // الجدولة off قبل دخول اللوحة.
    await SettingsRepository(app.db).setBackupSchedule('off');

    await vm.load(companyName: 'متجر النور');
    expect(vm.backupReminder, isNull);
  });

  test('نسخة حديثة (قبل الفاصل): دخول اللوحة بلا نسخة وبلا بانر', () async {
    final (vm, service, _) = await bootReal();
    await service.createBackup(kind: BackupKind.manual);
    await vm.load(companyName: 'متجر النور');
    expect(vm.backupReminder, isNull);
  });

  test('الويب + استحقاق: بانر «الميزة على أندرويد» بلا إنشاء', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final service = BackupService(
      database: app,
      settings: SettingsRepository(app.db),
      store: const WebBackupStore(),
    );
    final vm = DashboardViewModel(
      repository: DashboardRepository(app.db),
      backupEngine: service,
    );
    addTearDown(vm.dispose);
    await vm.load(companyName: 'متجر النور');

    expect(vm.state.loading, isFalse);
    final reminder = vm.backupReminder;
    expect(reminder, isNotNull);
    expect(reminder!.kind, BackupReminderKind.webDue);
    // لم تُنشأ أي نسخة (المخزن الويبي لا يكتب أصلاً).
    expect(await service.listEntries(), isEmpty);
  });
}
