/// صيغة ملف النسخة الاحتياطية `.finbak` — FR-11-01/02 (وحدة 11).
///
/// الملف = أرشيف ZIP (حزمة `archive` الخالصة في Dart) بمدخلين:
/// - `manifest.json`: بيان النسخة (إصدار المخطط، إصدار التطبيق، تاريخ
///   الإنشاء، نوع النسخة، وبصمة SHA-256 لمحتوى القاعدة **غير المضغوط**).
/// - `finacc.db`: ملف قاعدة SQLite كما كان بعد `wal_checkpoint(TRUNCATE)`.
///
/// كل المنطق هنا **نقي** (بايتات ↔ بنية) بلا I/O ولا BuildContext —
/// قابل للاختبار المباشر من `test/domain/backup_format_test.dart`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// امتداد ملفات النسخة.
const String kBackupFileExtension = 'finbak';

/// اسم مدخل القاعدة داخل الأرشيف.
const String kBackupDbEntryName = 'finacc.db';

/// اسم مدخل البيان داخل الأرشيف.
const String kBackupManifestEntryName = 'manifest.json';

/// بادئة اسم الملف — `FinAcc-Backup-YYYYMMDD-HHmmss.finbak`.
const String _kBackupFilePrefix = 'FinAcc-Backup-';

/// إصدار التطبيق المكتوب في البيان — **يُزامَن يدوياً مع `version` في
/// pubspec.yaml** (لا نضيف package_info_plus هذه الجولة — قيد الحزم).
const String kFinAccAppVersion = '0.7.0';

/// بيان النسخة داخل الأرشيف — هوية الملف وفحص سلامته.
class BackupManifest {
  const BackupManifest({
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAtUtc,
    required this.dbSha256,
    required this.dbBytesLength,
    this.kind = 'manual',
  });

  /// إصدار مخطط القاعدة لحظة الإنشاء (`PRAGMA user_version`).
  final int schemaVersion;

  /// إصدار التطبيق الذي أنشأ النسخة.
  final String appVersion;

  /// لحظة إنشاء النسخة (UTC — ISO 8601).
  final DateTime createdAtUtc;

  /// بصمة SHA-256 (hex) لمحتوى `finacc.db` غير المضغوط.
  final String dbSha256;

  /// طول محتوى القاعدة بالبايت (غير المضغوط) — فحص إضافي سريع.
  final int dbBytesLength;

  /// نوع النسخة: `manual` / `auto` / `pre_restore` (مفردات جدول
  /// `backup_log` المجمّد في SRS §5.3).
  final String kind;

  /// يبني البيان فوق محتوى قاعدة معلن (يحسب البصمة داخلياً).
  factory BackupManifest.forDbBytes(
    Uint8List dbBytes, {
    required int schemaVersion,
    required DateTime createdAtUtc,
    String kind = 'manual',
  }) {
    return BackupManifest(
      schemaVersion: schemaVersion,
      appVersion: kFinAccAppVersion,
      createdAtUtc: createdAtUtc,
      dbSha256: sha256Hex(dbBytes),
      dbBytesLength: dbBytes.length,
      kind: kind,
    );
  }

  /// تحليل دفاعي من JSON — أي حقل مفقود/فاسد يرمي [FormatException].
  factory BackupManifest.fromJson(Map<String, Object?> json) {
    int readInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      throw FormatException('حقل البيان "$key" مفقود أو غير رقمي');
    }

    String readString(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) return value;
      throw FormatException('حقل البيان "$key" مفقود أو ليس نصاً');
    }

    final createdAt = DateTime.tryParse(readString('createdAtUtc'));
    if (createdAt == null) {
      throw const FormatException('حقل البيان "createdAtUtc" ليس تاريخاً');
    }
    return BackupManifest(
      schemaVersion: readInt('schemaVersion'),
      appVersion: readString('appVersion'),
      createdAtUtc: createdAt,
      dbSha256: readString('dbSha256'),
      dbBytesLength: readInt('dbBytesLength'),
      kind: json['kind'] is String && (json['kind'] as String).isNotEmpty
          ? json['kind'] as String
          : 'manual',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'format': 'finacc-finbak/1',
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'dbSha256': dbSha256,
    'dbBytesLength': dbBytesLength,
    'kind': kind,
  };
}

/// أسباب رفض فك/قبول الأرشيف — تُعرض للمستخدم بمفاتيح l10n.
enum BackupFormatError {
  /// الملف ليس أرشيف ZIP صالحاً.
  notArchive,

  /// الأرشيف لا يحوي المدخلين المطلوبين (manifest + finacc.db).
  missingEntries,

  /// البيان موجود لكنه فاسد/غير مكتمل.
  corruptManifest,

  /// البصمة أو الطول لا يطابقان المحتوى — الملف تالف أو معدَّل.
  checksumMismatch,
}

/// استثناء صيغة النسخة — يحمل السبب المفهرس للعرض.
class BackupFormatException implements Exception {
  const BackupFormatException(this.error, [this.details = '']);

  /// السبب (يُترجم في العرض).
  final BackupFormatError error;

  /// تفاصيل تقنية للسجل فقط.
  final String details;

  @override
  String toString() => 'BackupFormatException($error)$details';
}

/// محتوى أرشيف نسخة بعد فكّه والتحقق من سلامته.
class BackupArchiveContent {
  const BackupArchiveContent({required this.manifest, required this.dbBytes});

  final BackupManifest manifest;
  final Uint8List dbBytes;
}

/// بصمة SHA-256 لبايتات (hex صغير).
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// اسم ملف النسخة: `FinAcc-Backup-YYYYMMDD-HHmmss.finbak`
/// (بتوقيت الجهاز المحلي — مقروء للمستخدم).
String formatBackupFileName(DateTime localTime) {
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${localTime.year}${two(localTime.month)}${two(localTime.day)}'
      '-${two(localTime.hour)}${two(localTime.minute)}${two(localTime.second)}';
  return '$_kBackupFilePrefix$stamp.$kBackupFileExtension';
}

/// يستخرج لحظة إنشاء النسخة من اسم الملف (محلي) — أو null لاسم غير مطابق.
DateTime? parseBackupFileNameTime(String fileName) {
  final match = RegExp(
    r'^FinAcc-Backup-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})\.finbak$',
  ).firstMatch(fileName);
  if (match == null) return null;
  final dateTime = DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
  return dateTime;
}

/// يضغط نسخة كاملة إلى بايتات `.finbak` (ZIP + DEFLATE).
Uint8List encodeBackupArchive({
  required Uint8List dbBytes,
  required BackupManifest manifest,
}) {
  final manifestJson = jsonEncode(manifest.toJson());
  final archive = Archive()
    ..addFile(
      ArchiveFile(kBackupManifestEntryName, manifestJson.length, manifestJson),
    )
    ..addFile(ArchiveFile(kBackupDbEntryName, dbBytes.length, dbBytes));
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw const BackupFormatException(BackupFormatError.notArchive);
  }
  return Uint8List.fromList(encoded);
}

/// يفك أرشيف نسخة ويتحقق من سلامته بالكامل (FR-11-02 — فحص Checksum):
/// ZIP صالح + المدخلان موجودان + بيان مفهوم + بصمة وطول متطابقان.
///
/// يرمي [BackupFormatException] مفهرسة السبب — لا يعيد أبداً محتوى غير
/// متحقق منه.
BackupArchiveContent decodeBackupArchive(Uint8List bytes) {
  // فحص سريع للبنية قبل أي فك: كل ZIP يبدأ بتوقيع PK — وإلا فالملف ليس
  // أرشيفاً أصلاً (رسالة أدق من رمي المفكك الداخلي).
  if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
    throw const BackupFormatException(BackupFormatError.notArchive);
  }
  Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes, verify: true);
  } on ArchiveException catch (error) {
    // ArchiveException تمتد FormatException — تُمسك أولاً: بنية/تحقق فاسد
    // بعد توقيع PK (CRC أو دليل مركزي معطوب) = ملف تالف أو معدّل.
    throw BackupFormatException(BackupFormatError.checksumMismatch, '$error');
  } on FormatException catch (error) {
    throw BackupFormatException(BackupFormatError.notArchive, '$error');
  } on RangeError catch (error) {
    // فواصل خارج النطاء حسبها المفكك من دليل معطوب — ملف مقطوع/تالف.
    throw BackupFormatException(BackupFormatError.checksumMismatch, '$error');
  }

  Uint8List? dbBytes;
  String? manifestJson;
  for (final file in archive) {
    if (!file.isFile) continue;
    if (file.name == kBackupDbEntryName) {
      dbBytes = Uint8List.fromList((file.content as List<int>).toList());
    } else if (file.name == kBackupManifestEntryName) {
      manifestJson = utf8.decode(
        (file.content as List<int>).toList(),
        allowMalformed: false,
      );
    }
  }
  if (dbBytes == null || manifestJson == null) {
    throw const BackupFormatException(BackupFormatError.missingEntries);
  }

  BackupManifest manifest;
  try {
    manifest = BackupManifest.fromJson(
      jsonDecode(manifestJson) as Map<String, Object?>,
    );
  } on FormatException catch (error) {
    throw BackupFormatException(BackupFormatError.corruptManifest, '$error');
  } on TypeError catch (error) {
    throw BackupFormatException(BackupFormatError.corruptManifest, '$error');
  }

  if (dbBytes.length != manifest.dbBytesLength) {
    throw const BackupFormatException(BackupFormatError.checksumMismatch);
  }
  if (sha256Hex(dbBytes) != manifest.dbSha256) {
    throw const BackupFormatException(BackupFormatError.checksumMismatch);
  }
  return BackupArchiveContent(manifest: manifest, dbBytes: dbBytes);
}
