/// أنواع خدمة النسخ الاحتياطي النقية (نتيجة المحاولة/الاستحقاق/الفحص/
/// سطر السجل/أسباب فشل الاستعادة/نتائجها) — جزء من تقسيم R20-D3a
/// لخدمة النسخ (نمط R19-D3d): منقولة حرفياً من backup_service.dart —
/// الخدمة تُصدِّرها من هنا فكل استيراداتها التاريخية تحل كما كانت.
library;

import '../../../core/storage/app_database.dart';
import '../../../domain/services/backup_format.dart';
import '../../../domain/services/backup_policy.dart';
import '../../repositories/backup_log_repository.dart';

/// نتيجة محاولة إنشاء نسخة (نجحت أو فشلت — كلتاهما تُسجَّل).
class BackupRunResult {
  const BackupRunResult({
    required this.ok,
    required this.kind,
    required this.atUtc,
    this.fileName,
    this.sizeBytes,
    this.checksum,
    this.errorDetails,
  });

  /// هل نجحت وكُتب الملف؟
  final bool ok;

  /// نوع المحاولة.
  final BackupKind kind;

  /// لحظة المحاولة (UTC).
  final DateTime atUtc;

  /// اسم الملف المكتوب (null عند الفشل).
  final String? fileName;

  /// حجم الأرشيف المضغوط بالبايت.
  final int? sizeBytes;

  /// بصمة SHA-256 للملف المضغوط (hex).
  final String? checksum;

  /// تفاصيل الفشل التقنية (للعرض التقني فقط).
  final String? errorDetails;
}

/// حالة استحقاق النسخة التلقائية (للعرض والتذكير).
class BackupDueInfo {
  const BackupDueInfo({
    required this.schedule,
    required this.lastBackupAt,
    required this.isDue,
    required this.isSupported,
  });

  final BackupSchedule schedule;
  final DateTime? lastBackupAt;
  final bool isDue;
  final bool isSupported;
}

/// فحص ملف نسخة قبل التأكيد (نافذة «عرض فحص الملف» — FR-11-02).
class BackupInspection {
  const BackupInspection({
    required this.fileName,
    required this.fileSizeBytes,
    required this.manifest,
  });

  /// الاسم كما اختاره المستخدم أو المحفوظ.
  final String fileName;

  /// حجم الملف المضغوط بالبايت.
  final int fileSizeBytes;

  /// بيان النسخة (تاريخ/مخطط/بصمة/نوع).
  final BackupManifest manifest;
}

/// سطر في قائمة سجل النسخ (FR-11-06): دمج قيود الجدول مع ملفات القرص —
/// الملف المصدر الحقيقي للحقيقة (زر استعادة/مشاركة لما له ملف فقط).
class BackupListEntry {
  const BackupListEntry({
    required this.atUtc,
    required this.fileExists,
    required this.statusOk,
    required this.sizeBytes,
    this.fileName,
    this.kind,
    this.checksum,
  });

  /// لحظة المحاولة/الإنشاء (UTC).
  final DateTime atUtc;

  final String? fileName;

  /// النوع من الجدول (null = ملف بلا قيد — نجا من استعادة قديمة).
  final BackupKind? kind;

  final String? checksum;

  /// هل الملف موجود الآن في مجلد النسخ؟
  final bool fileExists;

  /// الحالة المعروضة (فشل الجدول أو فقد الملف = غير ناجحة).
  final bool statusOk;

  final int sizeBytes;
}

/// أسباب فشل الاستعادة — مفهرسة لتُترجم بمفاتيح l10n بلا نص حرفي.
enum RestoreFailureReason {
  /// المنصة لا تدعم ملفات النسخ (ويب — معاينة).
  unsupportedPlatform,

  /// الملف ليس نسخة `.finbak` صالحة.
  notBackupFile,

  /// فحص السلامة فشل (بصمة/طول لا يطابقان).
  checksumMismatch,

  /// نسخة بمخطط أحدث من تطبيق التطبيق — تُرفض (FR-11-02).
  newerSchema,

  /// فشلت نسخة الأمان التلقائية قبل الاستبدال — أُلغيت العملية.
  safetyBackupFailed,

  /// فشل فتح القاعدة المستعادة — أُرجعت القاعدة القديمة وسليمة.
  openFailed,
}

/// نتيجة الاستعادة — نجاح (قاعدة جديدة مفتوحة) أو فشل مفهرس السبب.
sealed class RestoreResult {
  const RestoreResult();
}

class RestoreSuccess extends RestoreResult {
  const RestoreSuccess({required this.newDatabase, required this.safety});

  /// القاعدة المستعادة **المفتوحة** — يتبنّاها AppController.
  final AppDatabase newDatabase;

  /// نتيجة نسخة الأمان التي سبقت الاستبدال.
  final BackupRunResult safety;
}

class RestoreFailure extends RestoreResult {
  const RestoreFailure(
    this.reason, {
    this.details,
    this.fileSchemaVersion,
    this.appSchemaVersion,
    this.reopenedDatabase,
  });

  final RestoreFailureReason reason;

  /// تفاصيل تقنية (العرض التقني فقط).
  final String? details;

  /// إصدار مخطط النسخة (عند newerSchema فقط).
  final int? fileSchemaVersion;

  /// إصدار مخطط التطبيق الحالي (عند newerSchema فقط).
  final int? appSchemaVersion;

  /// القاعدة القديمة **المعاد فتحها** بعد rollback — على المتصل تبنّيها
  /// (null حين لم تُغلق أصلاً: أخطاء التحقق قبل أي لمسة للقاعدة).
  final AppDatabase? reopenedDatabase;
}
