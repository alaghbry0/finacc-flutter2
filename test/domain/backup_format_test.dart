/// اختبارات صيغة ملف النسخة `.finbak` — منطق نقي بلا I/O (FR-11-01/02).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/domain/services/backup_format.dart';

/// قاعدة SQLite مصغّرة (رأس «SQLite format 3» + حشوة) — تمثل محتوى حقيقياً
/// بصمةً وطولاً دون فتح قاعدة فعلية.
Uint8List fakeDbBytes([int length = 512]) {
  final bytes = Uint8List(length);
  final header = ascii.encode('SQLite format 3');
  bytes.setRange(0, header.length, header);
  for (var i = 16; i < length; i++) {
    bytes[i] = (i * 7) & 0xFF;
  }
  return bytes;
}

BackupManifest buildManifest(
  Uint8List dbBytes, {
  int schemaVersion = 1,
  String kind = 'manual',
  DateTime? createdAtUtc,
}) {
  return BackupManifest.forDbBytes(
    dbBytes,
    schemaVersion: schemaVersion,
    createdAtUtc: createdAtUtc ?? DateTime.utc(2026, 3, 14, 9, 30, 5),
    kind: kind,
  );
}

void main() {
  group('اسم ملف النسخة (FR-11-01)', () {
    test('النمط المعتمد FinAcc-Backup-YYYYMMDD-HHmmss.finbak', () {
      final name = formatBackupFileName(DateTime(2026, 3, 7, 8, 5, 9));
      expect(name, 'FinAcc-Backup-20260307-080509.finbak');
    });

    test('parseBackupFileNameTime يستخرج اللحظة من الاسم المطابق', () {
      final time = parseBackupFileNameTime(
        'FinAcc-Backup-20251231-235959.finbak',
      );
      expect(time, DateTime(2025, 12, 31, 23, 59, 59));
    });

    test('parseBackupFileNameTime يرفض الأسماء غير المطابقة', () {
      expect(parseBackupFileNameTime('backup.zip'), isNull);
      expect(parseBackupFileNameTime('FinAcc-Backup-2026.finbak'), isNull);
      expect(
        parseBackupFileNameTime('FinAcc-Backup-20260307-080509.zip'),
        isNull,
      );
      expect(parseBackupFileNameTime(''), isNull);
    });
  });

  group('البيان BackupManifest', () {
    test('forDbBytes يحسب البصمة والطول تلقائياً', () {
      final bytes = fakeDbBytes(300);
      final manifest = buildManifest(bytes, schemaVersion: 4, kind: 'auto');
      expect(manifest.dbBytesLength, 300);
      expect(manifest.dbSha256, sha256Hex(bytes));
      expect(manifest.appVersion, kFinAccAppVersion);
      expect(manifest.kind, 'auto');
    });

    test('sha256Hex متجه معروف: الفراغ', () {
      expect(sha256Hex(<int>[]), startsWith('e3b0c44298fc1c14'));
      expect(sha256Hex(<int>[]).length, 64);
    });

    test('fromJson ↔ toJson جولة كاملة بلا فقد', () {
      final bytes = fakeDbBytes(128);
      final manifest = buildManifest(bytes, schemaVersion: 2);
      final restored = BackupManifest.fromJson(
        jsonDecode(jsonEncode(manifest.toJson())) as Map<String, Object?>,
      );
      expect(restored.schemaVersion, manifest.schemaVersion);
      expect(restored.appVersion, manifest.appVersion);
      expect(restored.createdAtUtc, manifest.createdAtUtc);
      expect(restored.dbSha256, manifest.dbSha256);
      expect(restored.dbBytesLength, manifest.dbBytesLength);
      expect(restored.kind, manifest.kind);
    });

    test('fromJson دفاعي: حقل مفقود/فاسد يرمي FormatException', () {
      const base = <String, Object?>{
        'schemaVersion': 1,
        'appVersion': '0.7.0',
        'createdAtUtc': '2026-03-14T09:30:05Z',
        'dbSha256': 'abc',
        'dbBytesLength': 10,
      };
      expect(
        () => BackupManifest.fromJson({...base}..remove('dbSha256')),
        throwsFormatException,
      );
      expect(
        () => BackupManifest.fromJson({...base, 'dbBytesLength': 'كبير'}),
        throwsFormatException,
      );
      expect(
        () => BackupManifest.fromJson({...base, 'createdAtUtc': 'غداً'}),
        throwsFormatException,
      );
      expect(
        () => BackupManifest.fromJson({...base, 'appVersion': ''}),
        throwsFormatException,
      );
    });

    test('fromJson: kind مفقود يرجع manual والأرقام تُحوَّل من num', () {
      const json = <String, Object?>{
        'schemaVersion': 3.0,
        'appVersion': '0.7.0',
        'createdAtUtc': '2026-03-14T09:30:05.000Z',
        'dbSha256': 'abc',
        'dbBytesLength': 12.0,
      };
      final manifest = BackupManifest.fromJson(json);
      expect(manifest.schemaVersion, 3);
      expect(manifest.dbBytesLength, 12);
      expect(manifest.kind, 'manual');
    });
  });

  group('ترميز/فك الأرشيف (FR-11-01/02)', () {
    test('جولة كاملة: المحتوى والبيان يخرجان سليمين', () {
      final bytes = fakeDbBytes(1024);
      final manifest = buildManifest(bytes, schemaVersion: 6, kind: 'auto');
      final archive = encodeBackupArchive(dbBytes: bytes, manifest: manifest);

      final content = decodeBackupArchive(archive);
      expect(content.dbBytes, bytes);
      expect(content.manifest.schemaVersion, 6);
      expect(content.manifest.kind, 'auto');
      expect(content.manifest.dbSha256, sha256Hex(bytes));
    });

    test('الأرشيف ZIP حقيقي بمدخلين فقط بالأسماء المعتمدة', () {
      final bytes = fakeDbBytes(64);
      final archive = encodeBackupArchive(
        dbBytes: bytes,
        manifest: buildManifest(bytes),
      );
      final decoded = ZipDecoder().decodeBytes(archive);
      expect(decoded.map((f) => f.name).toSet(), {
        kBackupManifestEntryName,
        kBackupDbEntryName,
      });
    });

    test('بايتات عشوائية (بلا توقيع PK) = notArchive', () {
      final junk = Uint8List.fromList(List.generate(256, (i) => i * 13 & 0xFF));
      expect(
        () => decodeBackupArchive(junk),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.notArchive,
          ),
        ),
      );
    });

    test('ملف يبدأ بتوقيع PK لكنه معطوب = checksumMismatch (تالف)', () {
      final junk = Uint8List.fromList(List.generate(128, (i) => i));
      junk[0] = 0x50; // P
      junk[1] = 0x4B; // K
      expect(
        () => decodeBackupArchive(junk),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.checksumMismatch,
          ),
        ),
      );
    });

    test('أرشيف ZIP بلا المدخلين = missingEntries', () {
      final alien = ZipEncoder().encode(
        Archive()..addFile(ArchiveFile('other.txt', 3, 'abc')),
      )!;
      expect(
        () => decodeBackupArchive(Uint8List.fromList(alien)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.missingEntries,
          ),
        ),
      );
    });

    test('بيان فاسد داخل أرشيف سليم البنية = corruptManifest', () {
      final broken = ZipEncoder().encode(
        Archive()
          ..addFile(ArchiveFile(kBackupManifestEntryName, 5, 'ليس JSON'))
          ..addFile(ArchiveFile(kBackupDbEntryName, 4, [1, 2, 3, 4])),
      )!;
      expect(
        () => decodeBackupArchive(Uint8List.fromList(broken)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.corruptManifest,
          ),
        ),
      );
    });

    test('بيان JSON بمصفوفة (ليس خريطة) = corruptManifest', () {
      final broken = ZipEncoder().encode(
        Archive()
          ..addFile(ArchiveFile(kBackupManifestEntryName, 2, '[]'))
          ..addFile(ArchiveFile(kBackupDbEntryName, 4, [1, 2, 3, 4])),
      )!;
      expect(
        () => decodeBackupArchive(Uint8List.fromList(broken)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.corruptManifest,
          ),
        ),
      );
    });

    test('تلاعب بمحتوى القاعدة بعد الإنشاء = checksumMismatch', () {
      final bytes = fakeDbBytes(256);
      final archive = encodeBackupArchive(
        dbBytes: bytes,
        manifest: buildManifest(bytes),
      );
      // قلب بايت داخل بيانات finacc.db المضغوطة (مدخل القاعدة هو الأكبر —
      // نستهدف منتصف الأرشيف حيث يقع حتماً).
      final tampered = Uint8List.fromList(archive);
      final target = tampered.length ~/ 2 + 24;
      tampered[target] ^= 0xFF;
      expect(
        () => decodeBackupArchive(tampered),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.checksumMismatch,
          ),
        ),
      );
    });

    test('طول معلن لا يطابق المحتوى = checksumMismatch', () {
      final bytes = fakeDbBytes(100);
      final manifest = BackupManifest(
        schemaVersion: 1,
        appVersion: kFinAccAppVersion,
        createdAtUtc: DateTime.utc(2026, 1, 1),
        dbSha256: sha256Hex(bytes),
        dbBytesLength: 999, // طول كاذب.
      );
      final archive = encodeBackupArchive(dbBytes: bytes, manifest: manifest);
      expect(
        () => decodeBackupArchive(archive),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.checksumMismatch,
          ),
        ),
      );
    });

    test('بصمة معلنة كاذبة (طول صحيح) = checksumMismatch', () {
      final bytes = fakeDbBytes(100);
      final manifest = BackupManifest(
        schemaVersion: 1,
        appVersion: kFinAccAppVersion,
        createdAtUtc: DateTime.utc(2026, 1, 1),
        dbSha256: '0' * 64, // بصمة كاذبة.
        dbBytesLength: bytes.length,
      );
      final archive = encodeBackupArchive(dbBytes: bytes, manifest: manifest);
      expect(
        () => decodeBackupArchive(archive),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.checksumMismatch,
          ),
        ),
      );
    });
  });
}
