/// مستودع سجل النسخ الاحتياطي — جدول `backup_log` (FR-11-06، وحدة 11).
///
/// **قرار تصميمي موثّق**: الجدول موجود أصلاً في المخطط المجمّد (SRS §5.3
/// منذ إصدار 1) بأعمدته `kind`/`file_name`/`file_size`/`checksum`/
/// `status`/`at`/`user_id` — فلا حاجة لهجرة جديدة ولا لملف JSON موازٍ.
/// نوع «نسخة الأمان قبل الاستعادة» = `pre_restore` حرفياً كما صمّمه SRS.
///
/// ملاحظة سلوكية: السجل يعيش داخل القاعدة نفسها، لذا تُستعاد نسخته مع
/// أي استعادة — خدمة النسخ (backup_service) تعيد إدراج قيد نسخة الأمان
/// في القاعدة المستعادة بعد نجاح الاستبدال كي يبقى السجل صادقاً.
library;

import 'package:sqflite/sqflite.dart';

/// نوع النسخة — مفردات عمود `kind` المجمّدة في DDL.
enum BackupKind {
  /// نسخة يدوية (زر «إنشاء نسخة الآن» — FR-11-01).
  manual('manual'),

  /// نسخة تلقائية مجدولة (FR-11-04).
  auto('auto'),

  /// نسخة أمان تُنشأ تلقائياً قبل أي استعادة (FR-11-02).
  preRestore('pre_restore');

  const BackupKind(this.tag);

  /// القيمة المخزنة في العمود.
  final String tag;

  /// يحل نوع النسخة من قيمة العمود — أو null لمفردات غير معروفة.
  static BackupKind? fromTag(String? tag) => switch (tag) {
    'manual' => BackupKind.manual,
    'auto' => BackupKind.auto,
    'pre_restore' => BackupKind.preRestore,
    _ => null,
  };
}

/// قيد سجل نسخة واحدة (للعرض في قائمة السجل — FR-11-06).
class BackupLogEntry {
  const BackupLogEntry({
    required this.id,
    required this.kindTag,
    required this.status,
    required this.atUtc,
    this.fileName,
    this.fileSize,
    this.checksum,
  });

  final int id;

  /// قيمة `kind` الخام (`manual`/`auto`/`pre_restore`/`cloud`/…).
  final String kindTag;

  /// `ok` أو `failed`.
  final String status;

  /// لحظة المحاولة (UTC).
  final DateTime atUtc;

  final String? fileName;
  final int? fileSize;
  final String? checksum;

  /// النوع المحلول (null = مفردات غير معروفة مثل `cloud` المؤجل V1.1).
  BackupKind? get kind => BackupKind.fromTag(kindTag);

  /// هل القيد ناجح؟
  bool get ok => status == 'ok';
}

/// كتابة/قراءة سجل النسخ داخل جدول `backup_log`.
class BackupLogRepository {
  BackupLogRepository(this._db);

  final Database _db;

  /// يسجل محاولة نسخة (نجاحاً أو فشلاً).
  ///
  /// المحاولات الفاشلة بلا `fileName` (لم يُكتب ملف) وبحالة `failed` —
  /// يعرضها السجل كسجل تاريخي بلا أزرار استعادة/مشاركة.
  Future<void> insert({
    required BackupKind kind,
    required bool ok,
    required DateTime atUtc,
    String? fileName,
    int? fileSize,
    String? checksum,
    int? userId,
  }) async {
    await _db.insert('backup_log', <String, Object?>{
      'kind': kind.tag,
      'file_name': fileName,
      'file_size': fileSize,
      'checksum': checksum,
      'cloud_path': null,
      'status': ok ? 'ok' : 'failed',
      'at': atUtc.toUtc().toIso8601String(),
      'user_id': userId,
      'created_at': atUtc.toUtc().toIso8601String(),
    });
  }

  /// أحدث القيود أولاً (للعرض) — بحد معقول للشاشة.
  Future<List<BackupLogEntry>> list({int limit = 200}) async {
    final rows = await _db.rawQuery(
      'SELECT id, kind, file_name, file_size, checksum, status, at '
      'FROM backup_log ORDER BY at DESC, id DESC LIMIT ?',
      <Object>[limit],
    );
    return [
      for (final row in rows)
        BackupLogEntry(
          id: row['id'] as int,
          kindTag: row['kind'] as String,
          status: (row['status'] as String?) ?? 'ok',
          atUtc: DateTime.parse(row['at'] as String),
          fileName: row['file_name'] as String?,
          fileSize: row['file_size'] as int?,
          checksum: row['checksum'] as String?,
        ),
    ];
  }
}
