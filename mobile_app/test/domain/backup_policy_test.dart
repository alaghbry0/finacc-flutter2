/// اختبارات سياسة الجدولة والاحتفاظ — منطق نقي (FR-11-04/05).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/services/backup_policy.dart';

void main() {
  group('parseBackupSchedule (backup.schedule)', () {
    test('القيم الثلاث المعتمدة تُحل كما هي', () {
      expect(parseBackupSchedule('daily'), BackupSchedule.daily);
      expect(parseBackupSchedule('weekly'), BackupSchedule.weekly);
      expect(parseBackupSchedule('off'), BackupSchedule.off);
    });

    test('أي قيمة أخرى ترجع الافتراضي الموثق weekly', () {
      expect(parseBackupSchedule('monthly'), BackupSchedule.weekly);
      expect(parseBackupSchedule(''), BackupSchedule.weekly);
      expect(parseBackupSchedule('DAILY'), BackupSchedule.weekly);
      expect(parseBackupSchedule('قيمة تالفة'), BackupSchedule.weekly);
    });

    test('backupScheduleTag جولة كاملة مع الحل', () {
      for (final schedule in BackupSchedule.values) {
        expect(parseBackupSchedule(backupScheduleTag(schedule)), schedule);
      }
    });
  });

  group('backupScheduleInterval', () {
    test('daily = 24 ساعة، weekly = 7 أيام، off = null', () {
      expect(
        backupScheduleInterval(BackupSchedule.daily),
        const Duration(hours: 24),
      );
      expect(
        backupScheduleInterval(BackupSchedule.weekly),
        const Duration(days: 7),
      );
      expect(backupScheduleInterval(BackupSchedule.off), isNull);
    });
  });

  group('isBackupDue (FR-11-04: «عند فتح التطبيق إذا مضى المحدد»)', () {
    final now = DateTime(2026, 10, 8, 12);

    test('الجدولة موقفة: لا استحقاق أبداً ولو بلا نسخة سابقة', () {
      expect(
        isBackupDue(schedule: BackupSchedule.off, now: now, lastBackupAt: null),
        isFalse,
      );
    });

    test('لا نسخة سابقة قط: مستحق فوراً (daily وweekly)', () {
      expect(isBackupDue(schedule: BackupSchedule.daily, now: now), isTrue);
      expect(isBackupDue(schedule: BackupSchedule.weekly, now: now), isTrue);
    });

    test('قبل انقضاء الفاصل: غير مستحق', () {
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      expect(
        isBackupDue(
          schedule: BackupSchedule.weekly,
          now: now,
          lastBackupAt: twoDaysAgo,
        ),
        isFalse,
      );
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      expect(
        isBackupDue(
          schedule: BackupSchedule.daily,
          now: now,
          lastBackupAt: twoHoursAgo,
        ),
        isFalse,
      );
    });

    test('بعد انقضاء الفاصل: مستحق', () {
      final eightDaysAgo = now.subtract(const Duration(days: 8));
      expect(
        isBackupDue(
          schedule: BackupSchedule.weekly,
          now: now,
          lastBackupAt: eightDaysAgo,
        ),
        isTrue,
      );
      final yesterday = now.subtract(const Duration(hours: 25));
      expect(
        isBackupDue(
          schedule: BackupSchedule.daily,
          now: now,
          lastBackupAt: yesterday,
        ),
        isTrue,
      );
    });

    test('الحد الفاصل تماماً (== الفاصل): مستحق (مضى المحدد)', () {
      final exactlySevenDays = now.subtract(const Duration(days: 7));
      expect(
        isBackupDue(
          schedule: BackupSchedule.weekly,
          now: now,
          lastBackupAt: exactlySevenDays,
        ),
        isTrue,
      );
    });
  });

  group('isValidBackupRetentionCount (backup.retention_count)', () {
    test('النطاق الموثق 1–30', () {
      expect(isValidBackupRetentionCount(1), isTrue);
      expect(isValidBackupRetentionCount(7), isTrue);
      expect(isValidBackupRetentionCount(30), isTrue);
      expect(isValidBackupRetentionCount(0), isFalse);
      expect(isValidBackupRetentionCount(31), isFalse);
      expect(isValidBackupRetentionCount(-5), isFalse);
    });

    test('الحدان الثابتان يطابقان النطاق', () {
      expect(kBackupRetentionMin, 1);
      expect(kBackupRetentionMax, 30);
      expect(isValidBackupRetentionCount(kBackupRetentionMin), isTrue);
      expect(isValidBackupRetentionCount(kBackupRetentionMax), isTrue);
      expect(isValidBackupRetentionCount(kBackupRetentionMin - 1), isFalse);
      expect(isValidBackupRetentionCount(kBackupRetentionMax + 1), isFalse);
    });
  });
}
