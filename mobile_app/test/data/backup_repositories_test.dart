/// اختبارات مستودعات وحدة النسخ: سجل `backup_log` (FR-11-06) + مفاتيح
/// إعدادات النسخ في سجل الإعدادات (FR-11-04/05 — ملحق هـ).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/repositories/backup_log_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  group('BackupLogRepository (جدول backup_log)', () {
    test('insert ناجح → list يعيده كاملاً بأحدثه أولاً', () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final log = BackupLogRepository(app.db);

      await log.insert(
        kind: BackupKind.manual,
        ok: true,
        atUtc: DateTime.utc(2026, 10, 6, 9),
        fileName: 'FinAcc-Backup-20261006-090000.finbak',
        fileSize: 2048,
        checksum: 'a' * 64,
      );
      await log.insert(
        kind: BackupKind.auto,
        ok: true,
        atUtc: DateTime.utc(2026, 10, 7, 10),
        fileName: 'FinAcc-Backup-20261007-100000.finbak',
        fileSize: 4096,
        checksum: 'b' * 64,
      );

      final rows = await log.list();
      expect(rows, hasLength(2));
      // الأحدث أولاً (ORDER BY at DESC).
      expect(rows.first.kind, BackupKind.auto);
      expect(rows.first.ok, isTrue);
      expect(rows.first.fileName, 'FinAcc-Backup-20261007-100000.finbak');
      expect(rows.first.fileSize, 4096);
      expect(rows.first.checksum, 'b' * 64);
      expect(rows.first.atUtc, DateTime.utc(2026, 10, 7, 10));
      expect(rows.last.kind, BackupKind.manual);
    });

    test('insert فاشل → status=failed بلا ملف (سجل تاريخي صادق)', () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final log = BackupLogRepository(app.db);

      await log.insert(
        kind: BackupKind.auto,
        ok: false,
        atUtc: DateTime.utc(2026, 10, 8, 8),
      );
      final rows = await log.list();
      expect(rows, hasLength(1));
      expect(rows.first.ok, isFalse);
      expect(rows.first.status, 'failed');
      expect(rows.first.fileName, isNull);
      expect(rows.first.kind, BackupKind.auto);
    });

    test(
      'مفردات غير معروفة (cloud المؤجل V1.1) تُعرض بنوع محلول null',
      () async {
        final app = await openUniqueFileApp();
        addTearDown(app.close);
        final db = app.db;
        await db.insert('backup_log', <String, Object?>{
          'kind': 'cloud',
          'status': 'ok',
          'at': DateTime.utc(2026, 10, 8, 8).toIso8601String(),
          'created_at': DateTime.utc(2026, 10, 8, 8).toIso8601String(),
        });
        final rows = await BackupLogRepository(db).list();
        expect(rows, hasLength(1));
        expect(rows.first.kind, isNull); // مفردات مؤجلة — لكن السطر يُعرض.
        expect(rows.first.kindTag, 'cloud');
      },
    );

    test('حد القائمة limit يعمل', () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final log = BackupLogRepository(app.db);
      for (var i = 0; i < 5; i++) {
        await log.insert(
          kind: BackupKind.manual,
          ok: true,
          atUtc: DateTime.utc(2026, 10, 1 + i),
        );
      }
      expect((await log.list()).length, 5);
      expect((await log.list(limit: 3)).length, 3);
      // أول 3 = الأحدث (الثالث والرابع والخامس).
      expect((await log.list(limit: 3)).map((e) => e.atUtc.day).toList(), [
        5,
        4,
        3,
      ]);
    });

    test('BackupKind.fromTag: القيم الثلاث + null لغيرها', () {
      expect(BackupKind.fromTag('manual'), BackupKind.manual);
      expect(BackupKind.fromTag('auto'), BackupKind.auto);
      expect(BackupKind.fromTag('pre_restore'), BackupKind.preRestore);
      expect(BackupKind.fromTag('cloud'), isNull);
      expect(BackupKind.fromTag(null), isNull);
      expect(BackupKind.fromTag(''), isNull);
    });

    test('وسوم الأعمدة المجمّدة في DDL: manual/auto/pre_restore', () {
      expect(BackupKind.manual.tag, 'manual');
      expect(BackupKind.auto.tag, 'auto');
      expect(BackupKind.preRestore.tag, 'pre_restore');
    });
  });

  group('مفاتيح إعدادات النسخ (SettingsRepository — ملحق هـ)', () {
    test('الافتراضيات: schedule=weekly وretention=7 وlast=null', () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final settings = SettingsRepository(app.db);

      expect(await settings.backupSchedule(), 'weekly');
      expect(await settings.backupRetentionCount(), 7);
      expect(await settings.backupLastBackupAt(), isNull);
    });

    test('كتابة/قراءة جولة كاملة للجدولة والاحتفاظ', () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final settings = SettingsRepository(app.db);

      await settings.setBackupSchedule('daily');
      await settings.setBackupRetentionCount(14);
      expect(await settings.backupSchedule(), 'daily');
      expect(await settings.backupRetentionCount(), 14);

      await settings.setBackupSchedule('off');
      expect(await settings.backupSchedule(), 'off');
    });

    test('حراسة القيم: جدولة/احتفاظ خارج النطاق يرفض', () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final settings = SettingsRepository(app.db);

      expect(() => settings.setBackupSchedule('monthly'), throwsArgumentError);
      expect(() => settings.setBackupSchedule(''), throwsArgumentError);
      expect(() => settings.setBackupRetentionCount(0), throwsArgumentError);
      expect(() => settings.setBackupRetentionCount(31), throwsArgumentError);
      expect(() => settings.setBackupRetentionCount(-3), throwsArgumentError);
    });

    test('backup.last_backup_at حالة نظامية: تُكتب وتُقرأ لحظة UTC', () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      final settings = SettingsRepository(app.db);

      final at = DateTime.utc(2026, 10, 8, 11, 30);
      await settings.setBackupLastBackupAt(at);
      expect(await settings.backupLastBackupAt(), at);

      // آخر كتابة تغلب السابقة.
      final later = DateTime.utc(2026, 10, 9, 9);
      await settings.setBackupLastBackupAt(later);
      expect(await settings.backupLastBackupAt(), later);
    });

    test(
      'قيمة تالفة لـ last_backup_at تُهمل بهدوء (null لا يفجر الجدولة)',
      () async {
        final app = await openUniqueFileApp();
        addTearDown(app.close);
        final settings = SettingsRepository(app.db);

        // كتابة قيمة غير تاريخ مباشرة (محاكاة تلف خارجي).
        await settings.set('backup.last_backup_at', 'ليس تاريخاً');
        expect(await settings.backupLastBackupAt(), isNull);
      },
    );

    test('المفاتيح الثلاثة داخل السجل المعتمد (FR-13-09)', () {
      expect(
        SettingsRepository.knownKeys,
        containsAll(<String>[
          'backup.schedule',
          'backup.retention_count',
          'backup.last_backup_at',
        ]),
      );
    });
  });
}
