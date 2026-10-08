/// اختبارات تبنّي الاستعادة في متحكم الجلسة + نموذج عرض شاشة النسخ
/// (الشريحة 8 — FR-11-02): الاستعادة حدث دورة حياة كامل (قاعدة جديدة +
/// مستودعات جديدة + إعادة تحديد الطور) والفشل يبقي الجلسة كما كانت.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/core/storage/migrations.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/services/backup/backup_service.dart';
import 'package:mobile_app/data/services/backup/backup_store_io.dart';
import 'package:mobile_app/domain/services/backup_format.dart';
import 'package:mobile_app/domain/services/backup_policy.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/settings/view_models/backup_view_model.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  /// جهاز: قاعدة مؤسَّسة بمسار معلن + متحكم فوقها بمخزن نسخ حقيقي.
  Future<(AppController, IoBackupStore, Directory, String)> bootController(
    String companyName,
  ) async {
    final dir = await Directory.systemTemp.createTemp('finacc_ctrl_test');
    final dbPath = p.join(dir.path, 'finacc.db');
    final app = await AppDatabase.openWith(databaseFactory, dbPath);
    await CompanyRepository(
      app.db,
    ).executeSetup(testDraft(name: companyName), DateTime.utc(2026, 10, 6, 12));
    final store = IoBackupStore(dbPath: dbPath);
    final controller = AppController(
      forTesting: app,
      backupStoreOverride: store,
    );
    addTearDown(controller.dispose);
    return (controller, store, dir, dbPath);
  }

  /// نسخة حقيقية من القاعدة الحالية (checkpoint ثم ضغط) — بايتات جاهزة
  /// للتغذية عبر restoreBackupFromBytes: (البايتات، اسم الملف).
  Future<(Uint8List, String)> craftBackupBytes(AppController controller) async {
    await controller.ensureBackupEngine();
    final engine = controller.backupEngine!;
    final run = await engine.createBackup(kind: BackupKind.manual);
    expect(run.ok, isTrue, reason: run.errorDetails ?? '');
    return (await engine.readStoredBytes(run.fileName!), run.fileName!);
  }

  group('AppController.restoreBackupFromBytes (FR-11-02)', () {
    test('نجاح: يتبنّى القاعدة المستعادة ويعيد تحديد الطور (قفل)', () async {
      final (controller, store, dir, _) = await bootController('متجر الأصل');
      addTearDown(() => dir.delete(recursive: true));
      final (bytes, fileName) = await craftBackupBytes(controller);

      // «فقدان بيانات» بعد النسخة: تغيير قيمة نظامية.
      await controller.settings!.setNumerals('arabic_indic');
      final oldDb = controller.database;

      final result = await controller.restoreBackupFromBytes(
        bytes,
        sourceName: fileName,
      );

      // قاعدة جديدة مُتبنّاة (ليست القديمة) بمستودعات جديدة فوقها.
      final success = result as RestoreSuccess;
      expect(identical(controller.database, oldDb), isFalse);
      expect(identical(controller.database, success.newDatabase), isTrue);
      expect(controller.settings, isNotNull);
      expect(await controller.settings!.numerals(), 'western');
      expect(
        (await CompanyRepository(controller.database!.db).findCompany())!.name,
        'متجر الأصل',
      );
      // الطور أُعيد تحديده: منشأة موجودة → جلسة مقفلة (PIN النسخة).
      expect(controller.phase, AppPhase.locked);
      // المحرك تجدد فوق القاعدة الجديدة (يشير للقاعدة المستعادة).
      expect(controller.backupEngine, isNotNull);
      expect(await controller.backupEngine!.databaseFileSize(), greaterThan(0));
    });

    test('فشل (مخطط أحدث): الجلسة كما كانت بلا أي تغيير', () async {
      final (controller, store, dir, _) = await bootController('متجر الأصل');
      addTearDown(() => dir.delete(recursive: true));
      await controller.ensureBackupEngine();
      expect(controller.backupEngine, isNotNull);

      // نسخة بمخطط أحدث من تطبيق التطبيق.
      await controller.database!.db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      final dbBytes = await store.readDatabaseFile();
      final manifest = BackupManifest.forDbBytes(
        dbBytes,
        schemaVersion: currentSchemaVersion + 2,
        createdAtUtc: DateTime.utc(2026, 1, 1),
        kind: 'manual',
      );
      final bytes = encodeBackupArchive(dbBytes: dbBytes, manifest: manifest);

      final phaseBefore = controller.phase;
      final dbBefore = controller.database;
      final result = await controller.restoreBackupFromBytes(
        bytes,
        sourceName: 'future.finbak',
      );
      final failure = result as RestoreFailure;
      expect(failure.reason, RestoreFailureReason.newerSchema);
      expect(failure.reopenedDatabase, isNull);

      // الجلسة لم تتغير: نفس القاعدة ونفس الطور.
      expect(identical(controller.database, dbBefore), isTrue);
      expect(controller.phase, phaseBefore);
      expect(
        (await CompanyRepository(controller.database!.db).findCompany())!.name,
        'متجر الأصل',
      );
      // ولا نسخة أمان على القرص.
      expect(await store.listBackupFiles(), isEmpty);
    });
  });

  group('BackupViewModel (شاشة النسخ الاحتياطي)', () {
    test(
      'load: تهيئة المحرك عبر المتحكم + الافتراضيات + قائمة فارغة',
      () async {
        final (controller, _, dir, _) = await bootController('متجر الأصل');
        addTearDown(() => dir.delete(recursive: true));

        final vm = BackupViewModel(app: controller);
        addTearDown(vm.dispose);
        await vm.load();

        expect(vm.filesSupported, isTrue);
        expect(vm.state.loading, isFalse);
        expect(vm.state.error, isNull);
        expect(vm.state.schedule, BackupSchedule.weekly);
        expect(vm.state.retentionCount, 7);
        expect(vm.state.lastBackupAt, isNull);
        expect(vm.state.entries, isEmpty);
      },
    );

    test(
      'createBackupNow: نتيجة ناجحة + إعادة تحميل السجل وآخر نسخة',
      () async {
        final (controller, _, dir, _) = await bootController('متجر الأصل');
        addTearDown(() => dir.delete(recursive: true));

        final vm = BackupViewModel(app: controller);
        addTearDown(vm.dispose);
        await vm.load();

        final result = await vm.createBackupNow();
        expect(result, isNotNull);
        expect(result!.ok, isTrue);
        expect(vm.state.creating, isFalse);
        expect(vm.state.entries, hasLength(1));
        expect(vm.state.entries.single.kind, BackupKind.manual);
        expect(vm.state.lastBackupAt, isNotNull);
      },
    );

    test(
      'الإعدادات: تثبيت الجدولة والاحتفاظ ينعكس في الحالة والمستودع',
      () async {
        final (controller, _, dir, _) = await bootController('متجر الأصل');
        addTearDown(() => dir.delete(recursive: true));

        final vm = BackupViewModel(app: controller);
        addTearDown(vm.dispose);
        await vm.load();

        expect(await vm.setSchedule(BackupSchedule.daily), isTrue);
        expect(vm.state.schedule, BackupSchedule.daily);
        expect(await controller.settings!.backupSchedule(), 'daily');

        expect(await vm.setRetentionCount(14), isTrue);
        expect(vm.state.retentionCount, 14);
        expect(await controller.settings!.backupRetentionCount(), 14);

        // خارج النطاق (ملحق هـ: 1–30) يُرفض بلا تغيير.
        expect(await vm.setRetentionCount(31), isFalse);
        expect(vm.state.retentionCount, 14);
      },
    );

    test(
      'performRestore بنسخة أحدث مخططاً: فشل مفهرس + إلغاء قفل التنفيذ',
      () async {
        final (controller, store, dir, _) = await bootController('متجر الأصل');
        addTearDown(() => dir.delete(recursive: true));
        await controller.ensureBackupEngine();

        await controller.database!.db.rawQuery(
          'PRAGMA wal_checkpoint(TRUNCATE)',
        );
        final dbBytes = await store.readDatabaseFile();
        final manifest = BackupManifest.forDbBytes(
          dbBytes,
          schemaVersion: currentSchemaVersion + 5,
          createdAtUtc: DateTime.utc(2026, 1, 1),
          kind: 'manual',
        );
        final bytes = encodeBackupArchive(dbBytes: dbBytes, manifest: manifest);

        final vm = BackupViewModel(app: controller);
        addTearDown(vm.dispose);
        await vm.load();

        final result = await vm.performRestore(
          bytes,
          sourceName: 'future.finbak',
        );
        final failure = result as RestoreFailure;
        expect(failure.reason, RestoreFailureReason.newerSchema);
        expect(vm.state.restoring, isFalse);
      },
    );
  });
}
