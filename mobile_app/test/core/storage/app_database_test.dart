/// اختبارات فتح القاعدة واستمراريتها — ملف واحد يعيد فتحه بنفس البيانات.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/core/storage/doc_sequence.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  test('openWith يفتح القاعدة بنجاح ويقرأ وضع اليومية والنسخة', () async {
    final app = await openUniqueFileApp();
    expect(app.db.isOpen, isTrue);
    expect(app.journalMode, isNotEmpty);
    expect(app.sqliteVersion, isNotEmpty);
    await app.close();
  });

  test('البيانات تبقى بعد إغلاق وإعادة فتح الملف (استمرارية القرص)', () async {
    final dir = await Directory.systemTemp.createTemp('finacc_persist');
    final path = '${dir.path}/persist.db';
    addTearDown(() => dir.delete(recursive: true));

    final first = await AppDatabase.openWith(databaseFactory, path);
    await first.db.insert('settings', {
      'key': 'test.persist',
      'value': '"القيمة"',
      'updated_at': '2026-10-06T00:00:00Z',
    });
    await first.close();

    final second = await AppDatabase.openWith(databaseFactory, path);
    final rows = await second.db.query(
      'settings',
      where: "key = 'test.persist'",
    );
    expect(rows, hasLength(1));
    expect(rows.first['value'], '"القيمة"');
    await second.close();
  });

  test('مصنع docSequence يرتبط بنفس القاعدة', () async {
    final app = await openUniqueFileApp();
    expect(app.docSequence, isNotNull);
    expect(
      await app.docSequence.nextNumber(DocSequenceType.invoice, 2026),
      1,
    );
    await app.close();
  });
}
