/// سياسة الجدولة والاحتفاظ بالنسخ — FR-11-04/05 (وحدة 11)، منطق نقي.
///
/// المفاتيح (ملحق هـ): `backup.schedule` (daily/weekly/off، افتراضي
/// weekly) و`backup.retention_count` (1–30، افتراضي 7) — والقرار
/// «هل حان وقت النسخة التلقائية؟» يقارن `backup.last_backup_at` بالفاصل.
library;

/// إيقاع الجدولة (`backup.schedule`).
enum BackupSchedule {
  /// نسخة تلقائية كل 24 ساعة عند فتح التطبيق.
  daily,

  /// نسخة تلقائية كل 7 أيام (الافتراضي).
  weekly,

  /// الجدولة معطلة — النسخ اليدوي فقط.
  off,
}

/// يحل قيمة المفتاح الخام (`daily`/`weekly`/`off`) — أي قيمة أخرى
/// تُرجع الافتراضي الموثق `weekly` (قيمة مفتاح تالفة لا تعطّل النسخ).
BackupSchedule parseBackupSchedule(String raw) {
  switch (raw) {
    case 'daily':
      return BackupSchedule.daily;
    case 'weekly':
      return BackupSchedule.weekly;
    case 'off':
      return BackupSchedule.off;
    default:
      return BackupSchedule.weekly;
  }
}

/// قيمة المفتاح الخام المعتمدة للحفظ.
String backupScheduleTag(BackupSchedule schedule) => switch (schedule) {
  BackupSchedule.daily => 'daily',
  BackupSchedule.weekly => 'weekly',
  BackupSchedule.off => 'off',
};

/// فاصل الجدولة — أو null عند الإيقاف.
Duration? backupScheduleInterval(BackupSchedule schedule) => switch (schedule) {
  BackupSchedule.daily => const Duration(hours: 24),
  BackupSchedule.weekly => const Duration(days: 7),
  BackupSchedule.off => null,
};

/// هل حان وقت نسخة تلقائية؟ (FR-11-04: «عند فتح التطبيق إذا مضى المحدد»)
///
/// - الجدولة موقفة → لا أبداً.
/// - لا نسخة سابقة قط (`lastBackupAt` = null) → نعم فوراً.
/// - مضى الفاصل كاملاً منذ آخر نسخة → نعم.
bool isBackupDue({
  required BackupSchedule schedule,
  required DateTime now,
  DateTime? lastBackupAt,
}) {
  final interval = backupScheduleInterval(schedule);
  if (interval == null) return false;
  final last = lastBackupAt;
  if (last == null) return true;
  return now.difference(last) >= interval;
}

/// أقصى قيمة مسموحة لـ `backup.retention_count` (ملحق هـ: النطاق 1–30).
const int kBackupRetentionMax = 30;

/// أقل قيمة مسموحة.
const int kBackupRetentionMin = 1;

/// هل قيمة الاحتفاظ داخل النطاق الموثق؟
bool isValidBackupRetentionCount(int count) =>
    count >= kBackupRetentionMin && count <= kBackupRetentionMax;
