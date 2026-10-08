/// اختبارات خدمة النسخ الاحتياطي فوق مخزن ملفات حقيقي (IoBackupStore) وقاعدة
/// SQLite حقيقية عبر FFI — دورة FR-11 كاملة: إنشاء/سجل/احتفاظ/فحص/
/// استعادة بنجاحها وإخفاقها المنتصف وشبكة أمان الإقلاع.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/core/storage/migrations.dart';
import 'package:mobile_app/data/repositories/backup_log_repository.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/data/services/backup/backup_service.dart';
import 'package:mobile_app/data/services/backup/backup_store_io.dart';
import 'package:mobile_app/data/services/backup/backup_store_web.dart';
import 'package:mobile_app/domain/services/backup_format.dart';
import 'package:mobile_app/domain/services/backup_policy.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  /// جهاز اختبار: مجلد مؤقت + قاعدة حقيقية مؤسَّسة + خدمة فوق مخزن IO.
  Future<(AppDatabase, BackupService, IoBackupStore, Directory)> boot({
    String companyName = 'متجر النور للأدوات المنزلية',
  }) async {
    final dir = await Directory.systemTemp.createTemp('finacc_backup_test');
    final dbPath = p.join(dir.path, 'finacc.db');
    final app = await AppDatabase.openWith(databaseFactory, dbPath);
    final settings = SettingsRepository(app.db);
    await CompanyRepository(
      app.db,
    ).executeSetup(testDraft(name: companyName), DateTime.utc(2026, 10, 6, 12));
    final store = IoBackupStore(dbPath: dbPath);
    final service = BackupService(
      database: app,
      settings: settings,
      store: store,
    );
    return (app, service, store, dir);
  }

  /// إغلاق آمن (القاعدة قد تكون أُغلقت أصلاً من الخدمة أثناء الاستعادة).
  Future<void> closeQuietly(AppDatabase? db) async {
    try {
      await db?.close();
    } catch (_) {
      // مغلقة سابقاً — تمام.
    }
  }

  /// `PRAGMA user_version` لقاعدة مفتوحة.
  Future<int> userVersionOf(AppDatabase app) async {
    final rows = await app.db.rawQuery('PRAGMA user_version');
    final value = rows.first.values.first;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  /// يبني ملف نسخة حقيقياً بالمحتوى الحالي للقاعدة باسم مؤرَّخ ثابت
  /// (حتمي — بعيداً عن تصادم اسم الثانية الواحدة مع نسخة الأمان).
  Future<String> craftBackupOfCurrent(
    AppDatabase app,
    IoBackupStore store, {
    String name = 'FinAcc-Backup-20260101-090000.finbak',
    int? schemaVersionOverride,
    Uint8List? dbBytesOverride,
  }) async {
    // checkpoint أولاً (نفس ما تفعله الخدمة قبل القراءة) كي يمثل الملف
    // القاعدة كاملة — بدونه تعيش آخر معاملات WAL في الملف الجانبي.
    try {
      await app.db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {
      // محرك بلا WAL — الملف الرئيسي أصلاً كامل.
    }
    final dbBytes = dbBytesOverride ?? await store.readDatabaseFile();
    final manifest = BackupManifest.forDbBytes(
      dbBytes,
      schemaVersion: schemaVersionOverride ?? await userVersionOf(app),
      createdAtUtc: DateTime.utc(2026, 1, 1, 9),
      kind: 'manual',
    );
    final bytes = encodeBackupArchive(dbBytes: dbBytes, manifest: manifest);
    await store.writeBackupFile(name, bytes);
    return name;
  }

  group('الإنشاء (FR-11-01)', () {
    test('نسخة يدوية: ملف finbak + سجل ok + آخر نسخة + قائمة واحدة', () async {
      final (app, service, store, dir) = await boot();
      addTearDown(() async {
        await closeQuietly(app);
        await dir.delete(recursive: true);
      });

      final result = await service.createBackup(kind: BackupKind.manual);

      expect(result.ok, isTrue, reason: result.errorDetails ?? '');
      expect(result.kind, BackupKind.manual);
      expect(
        result.fileName,
        matches(RegExp(r'^FinAcc-Backup-\d{8}-\d{6}\.finbak$')),
      );
      expect(result.sizeBytes, greaterThan(0));
      expect(result.checksum, matches(RegExp(r'^[0-9a-f]{64}$')));

      // الملف على القرص في مجلد backups بجوار القاعدة.
      final files = await store.listBackupFiles();
      expect(files.map((f) => f.fileName), [result.fileName]);
      expect(files.single.sizeBytes, result.sizeBytes);

      // السجل (FR-11-06): قيد واحد ناجح بنفس الملف.
      final rows = await BackupLogRepository(app.db).list();
      expect(rows, hasLength(1));
      expect(rows.first.kind, BackupKind.manual);
      expect(rows.first.ok, isTrue);
      expect(rows.first.fileName, result.fileName);
      expect(rows.first.fileSize, result.sizeBytes);
      expect(rows.first.checksum, result.checksum);

      // لحظة آخر نسخة ناجحة (حالة نظامية).
      final last = await SettingsRepository(app.db).backupLastBackupAt();
      expect(last, isNotNull);
      expect(
        last!.difference(DateTime.now().toUtc()).abs(),
        lessThan(const Duration(minutes: 1)),
      );

      // القائمة المدمجة (FR-11-06).
      final entries = await service.listEntries();
      expect(entries, hasLength(1));
      expect(entries.single.fileExists, isTrue);
      expect(entries.single.statusOk, isTrue);
      expect(entries.single.kind, BackupKind.manual);
      expect(entries.single.sizeBytes, result.sizeBytes);
    });

    test(
      'الفحص يقرأ البيان الفعلي: إصدار المخطط الحالي + إصدار التطبيق',
      () async {
        final (app, service, store, dir) = await boot();
        addTearDown(() async {
          await closeQuietly(app);
          await dir.delete(recursive: true);
        });

        final result = await service.createBackup(kind: BackupKind.manual);
        final inspection = await service.inspectStoredBackup(result.fileName!);

        expect(inspection.fileName, result.fileName);
        expect(inspection.fileSizeBytes, result.sizeBytes);
        expect(inspection.manifest.schemaVersion, currentSchemaVersion);
        expect(inspection.manifest.appVersion, kFinAccAppVersion);
        expect(inspection.manifest.kind, 'manual');
        // الطول المعلن = حجم ملف القاعدة الفعلي بعد checkpoint.
        expect(
          inspection.manifest.dbBytesLength,
          File(p.join(dir.path, 'finacc.db')).lengthSync(),
        );
        expect(
          inspection.manifest.dbSha256,
          matches(RegExp(r'^[0-9a-f]{64}$')),
        );
      },
    );
  });

  group('الاحتفاظ (FR-11-05)', () {
    test(
      'فوق N نسخة: الأقدم تُحذف تلقائياً (حسب بطاقة الزمن بالاسم)',
      () async {
        final (app, service, store, dir) = await boot();
        addTearDown(() async {
          await closeQuietly(app);
          await dir.delete(recursive: true);
        });

        // 4 ملفات قديمة بأسماء مؤرَّخة (مصنوعة يدوياً — المحتوى هنا غير مهم).
        for (final day in ['01', '02', '03', '04']) {
          await store.writeBackupFile(
            'FinAcc-Backup-202610$day-090000.finbak',
            Uint8List.fromList([1, 2, 3]),
          );
        }
        await SettingsRepository(app.db).setBackupRetentionCount(2);

        final result = await service.createBackup(kind: BackupKind.manual);
        expect(result.ok, isTrue);

        // المجموع 5 → يُحتفظ بأحدث اثنين: نسخة الآن + 20261004.
        final remaining = (await store.listBackupFiles())
            .map((f) => f.fileName)
            .toSet();
        expect(remaining, {
          result.fileName,
          'FinAcc-Backup-20261004-090000.finbak',
        });
      },
    );

    test('دون N: لا حذف', () async {
      final (app, service, store, dir) = await boot();
      addTearDown(() async {
        await closeQuietly(app);
        await dir.delete(recursive: true);
      });

      await store.writeBackupFile(
        'FinAcc-Backup-20261001-090000.finbak',
        Uint8List.fromList([1]),
      );
      final result = await service.createBackup(kind: BackupKind.manual);
      expect(result.ok, isTrue);
      expect((await store.listBackupFiles()).length, 2);
    });
  });

  group('الجدولة (FR-11-04)', () {
    test('لا نسخة سابقة + weekly → نسخة تلقائية فوراً ثم لا استحقاق', () async {
      final (app, service, store, dir) = await boot();
      addTearDown(() async {
        await closeQuietly(app);
        await dir.delete(recursive: true);
      });

      final before = await service.dueInfo();
      expect(before.schedule, BackupSchedule.weekly);
      expect(before.isDue, isTrue);

      final run = await service.runScheduledBackupIfDue();
      expect(run, isNotNull);
      expect(run!.ok, isTrue);
      expect(run.kind, BackupKind.auto);

      final after = await service.dueInfo();
      expect(after.isDue, isFalse);
      expect(after.lastBackupAt, isNotNull);
      expect(await store.listBackupFiles(), hasLength(1));
    });

    test('قبل انقضاء الفاصل → لا نسخة تلقائية (null)', () async {
      final (app, service, _, dir) = await boot();
      addTearDown(() async {
        await closeQuietly(app);
        await dir.delete(recursive: true);
      });

      await SettingsRepository(app.db).setBackupLastBackupAt(
        DateTime.now().toUtc().subtract(const Duration(days: 2)),
      );
      expect(await service.runScheduledBackupIfDue(), isNull);
    });

    test('الجدولة off → لا استحقاق ولا نسخة أبداً', () async {
      final (app, service, _, dir) = await boot();
      addTearDown(() async {
        await closeQuietly(app);
        await dir.delete(recursive: true);
      });

      await SettingsRepository(app.db).setBackupSchedule('off');
      expect((await service.dueInfo()).isDue, isFalse);
      expect(await service.runScheduledBackupIfDue(), isNull);
    });
  });

  group('الاستعادة (FR-11-02)', () {
    test(
      'نجاح كامل: بيانات النسخة تعود + نسخة أمان + قيود ما بعد الاستعادة',
      () async {
        final (app, service, store, dir) = await boot();
        addTearDown(() => dir.delete(recursive: true));
        final backupName = await craftBackupOfCurrent(app, store);

        // «فقدان بيانات»: مفتاح إعداد كُتب بعد النسخة — لا يجب أن يعود.
        await SettingsRepository(app.db).setNumerals('arabic_indic');

        final result = await service.restoreFromStoredBackup(backupName);
        expect(result, isA<RestoreSuccess>());
        final success = result as RestoreSuccess;
        addTearDown(() => closeQuietly(success.newDatabase));

        // بيانات النسخة (قبل الكتابة اللاحقة) هي الحية الآن — القاعدة
        // القديمة أُغلقت داخل الخدمة والجديدة مفتوحة محلها.
        final settings = SettingsRepository(success.newDatabase.db);
        expect(await settings.numerals(), 'western');
        final company = await CompanyRepository(success.newDatabase.db)
            .findCompany();
        expect(company!.name, 'متجر النور للأدوات المنزلية');

        // نسخة الأمان (pre_restore) على القرص + مسجلة في القاعدة المستعادة
        // (أُعيد إدراجها كي يبقى السجل صادقاً — راجع وثائق المستودع).
        final files = await store.listBackupFiles();
        expect(files.map((f) => f.fileName), contains(backupName));
        expect(files.where((f) => f.fileName != backupName), isNotEmpty);
        final log = await BackupLogRepository(success.newDatabase.db).list();
        expect(log, hasLength(1));
        expect(log.first.kind, BackupKind.preRestore);
        expect(log.first.ok, isTrue);

        // قيد تدقيق الاستعادة (FR-12-04 حدث موسّع).
        final audits = await success.newDatabase.db.query(
          'audit_log',
          where: "action = 'backup_restore'",
        );
        expect(audits, hasLength(1));
        expect(audits.first['details'] as String, contains(backupName));

        // لحظة آخر نسخة = لحظة نسخة الأمان (الآن — ليست 2026/01/01).
        final last = await settings.backupLastBackupAt();
        expect(last, isNotNull);
        expect(
          last!.difference(DateTime.now().toUtc()).abs(),
          lessThan(const Duration(minutes: 1)),
        );
      },
    );

    test('رفض مخطط أحدث من تطبيق التطبيق: القاعدة لم تُلمس أصلاً', () async {
      final (app, service, store, dir) = await boot();
      addTearDown(() async {
        await closeQuietly(app);
        await dir.delete(recursive: true);
      });

      final newerName = await craftBackupOfCurrent(
        app,
        store,
        schemaVersionOverride: currentSchemaVersion + 3,
      );

      final result = await service.restoreFromStoredBackup(newerName);
      final failure = result as RestoreFailure;
      expect(failure.reason, RestoreFailureReason.newerSchema);
      expect(failure.fileSchemaVersion, currentSchemaVersion + 3);
      expect(failure.appSchemaVersion, currentSchemaVersion);
      expect(failure.reopenedDatabase, isNull); // لم تُغلق القاعدة أصلاً.

      // القاعدة الحالية ما زالت حية وسليمة وقابلة للاستعلام.
      expect(
        (await CompanyRepository(app.db).findCompany())!.name,
        'متجر النور للأدوات المنزلية',
      );
      // ولا نسخة أمان ولا سجل — العملية أُلغيت قبل أي أثر (الملف الوحيد
      // على القرص هو النسخة المصنوعة نفسها).
      expect((await store.listBackupFiles()).map((f) => f.fileName), [
        newerName,
      ]);
      expect(await BackupLogRepository(app.db).list(), isEmpty);
    });

    test(
      'ملف تالف (بصمة لا تطابق) = checksumMismatch بلا لمس القاعدة',
      () async {
        final (app, service, store, dir) = await boot();
        addTearDown(() async {
          await closeQuietly(app);
          await dir.delete(recursive: true);
        });

        final name = await craftBackupOfCurrent(app, store);
        // تخريب المحتوى المضغوط داخل الملف.
        final path = await store.backupFilePath(name);
        final bytes = Uint8List.fromList(File(path).readAsBytesSync());
        bytes[bytes.length ~/ 2] ^= 0xFF;
        File(path).writeAsBytesSync(bytes);

        final failure =
            await service.restoreFromStoredBackup(name) as RestoreFailure;
        expect(failure.reason, RestoreFailureReason.checksumMismatch);
        expect(failure.reopenedDatabase, isNull);
        expect(
          (await CompanyRepository(app.db).findCompany())!.name,
          'متجر النور للأدوات المنزلية',
        );
        // لا نسخة أمان (الملف الوحيد = النسخة المصنوعة المخرّبة نفسها).
        expect(await store.listBackupFiles(), hasLength(1));
      },
    );

    test(
      'فشل المنتصف: إرجاع القاعدة القديمة وإبلاغ المستخدم (حرفياً)',
      () async {
        final (app, service, store, dir) = await boot();
        addTearDown(() => dir.delete(recursive: true));

        // محتوى «قاعدة» قمامة لكن ببيان صادق فوقه (بصمة تطابق القمامة) —
        // يجتاز فحص السلامة ثم يفشل فتحها كقاعدة بعد الاستبدال الذرّي.
        final garbage = Uint8List.fromList(
          List.generate(4096, (i) => (i * 31 + 7) & 0xFF),
        );
        final backupName = await craftBackupOfCurrent(
          app,
          store,
          dbBytesOverride: garbage,
        );

        final failure =
            await service.restoreFromStoredBackup(backupName) as RestoreFailure;
        expect(failure.reason, RestoreFailureReason.openFailed);
        addTearDown(() => closeQuietly(failure.reopenedDatabase));

        // القاعدة القديمة رجعت لمكانها وبياناتها سليمة.
        final reopened = failure.reopenedDatabase;
        expect(reopened, isNotNull);
        expect(
          (await CompanyRepository(reopened!.db).findCompany())!.name,
          'متجر النور للأدوات المنزلية',
        );

        // آثار المحاولة نُظفت: لا علامة ولا مؤقت ولا جانبية pre-restore.
        expect(
          File(p.join(dir.path, 'finacc.db.restore-ok')).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(dir.path, 'finacc.db.restore-tmp')).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(dir.path, 'finacc.db.pre-restore')).existsSync(),
          isFalse,
        );
        // نسخة الأمان مع ذلك كُتبت قبل المحاولة (تاريخ صادق) — موجودة.
        expect(await store.listBackupFiles(), isNotEmpty);
      },
    );
  });

  group('شبكة أمان الإقلاع (FR-11-02 — علامة متروكة)', () {
    test('علامة restore-ok بلا اعتماد = إرجاع القديمة عند الإقلاع', () async {
      final (app, service, store, dir) = await boot();
      addTearDown(() => dir.delete(recursive: true));
      final backupName = await craftBackupOfCurrent(app, store);

      // «تحديث بعد النسخة» — كي تتمايز القديمة عن محتوى النسخة.
      await SettingsRepository(app.db).setNumerals('arabic_indic');

      // محاكاة استعادة قُطعت بعد الاستبدال قبل الاعتماد.
      final bytes = await store.readBackupFile(backupName);
      final content = decodeBackupArchive(bytes);
      await app.close(); // الخدمة أغلقتها قبل الاستبدال.
      await store.swapDatabaseFile(content.dbBytes);
      // ⟵ انقطعت الجلسة هنا: لا commit ولا rollback — العلامة متروكة.

      await store.recoverInterruptedRestore();

      final recovered = await store.openDatabase();
      addTearDown(() => closeQuietly(recovered));
      // القاعدة القديمة (بالتحديث اللاحق) رجعت — لا بيانات النسخة.
      expect(await SettingsRepository(recovered.db).numerals(), 'arabic_indic');
      expect(
        (await CompanyRepository(recovered.db).findCompany())!.name,
        'متجر النور للأدوات المنزلية',
      );
      // العلامة والمؤقت نُظفا.
      expect(
        File(p.join(dir.path, 'finacc.db.restore-ok')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(dir.path, 'finacc.db.restore-tmp')).existsSync(),
        isFalse,
      );
    });
  });

  group('الويب دفاعي (معاينة)', () {
    test('مخزن الويب: إنشاء/استعادة غير مدعومين والقوائم فارغة', () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final service = BackupService(
        database: app,
        settings: SettingsRepository(app.db),
        store: const WebBackupStore(),
      );

      expect(service.isSupported, isFalse);
      final run = await service.createBackup(kind: BackupKind.manual);
      expect(run.ok, isFalse);
      expect(run.errorDetails, contains('unsupported'));

      final failure = await service.restoreFromBytes(
        Uint8List.fromList([1, 2, 3]),
      ) as RestoreFailure;
      expect(failure.reason, RestoreFailureReason.unsupportedPlatform);

      expect(await service.listEntries(), isEmpty);
      // الجدولة نفسها تُقرأ (الاستحقاق يعمل — بانر الويب يعتمده).
      final info = await service.dueInfo();
      expect(info.isDue, isTrue);
      expect(info.isSupported, isFalse);
      expect(await service.runScheduledBackupIfDue(), isNull);
    });
  });
}
