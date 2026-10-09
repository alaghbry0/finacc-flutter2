/// اختبارات هجرة v4 (موجة UX-3) — جدول `print_template` وبذور القوالب
/// الثلاثة: قاعدة فارغة (إقلاع نظيف)، ترقية قاعدة v3 قائمة (الجدول
/// جديد فوقها)، idempotency، بذور `INSERT OR IGNORE` لا تدوس تخصيص
/// المستخدم ولا تكرر، وقيد UNIQUE(doc_type, code).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/migrations.dart';
import 'package:mobile_app/core/storage/schema.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  /// يبني قاعدة بإصدار [upTo] يدوياً (نفس مسار onUpgrade الحقيقي).
  Future<Database> buildDbAtVersion(int upTo, String name) async {
    final dir = await Directory.systemTemp.createTemp('finacc_v$upTo$name');
    addTearDown(() => dir.delete(recursive: true));
    final db = await databaseFactory.openDatabase('${dir.path}/v.db');
    addTearDown(db.close);
    await db.execute(migrationsTableDdl);
    for (final migration in migrations.where((m) => m.version <= upTo)) {
      for (final statement in migration.statements) {
        await db.execute(statement);
      }
      for (final seed in migration.seeds) {
        await db.execute(seed);
      }
      await db.execute(
        "INSERT INTO _migrations(version, applied_at) VALUES(?, '2026-10-01')",
        <Object>[migration.version],
      );
    }
    return db;
  }

  test('قاعدة فارغة: الجدول مبني والقالبان مبذوران والبسيط نشط (الحراري حُذف بv6)', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);

    final rows = await app.db.query('print_template', orderBy: 'id ASC');
    expect(rows, hasLength(2), reason: 'قالبان لفواتير البيع — الحراري حُذف بهجرة v6');
    expect(rows.map((r) => r['code']).toList(), [
      'classic_a4',
      'simple_a4',
    ]);
    expect(rows.every((r) => r['doc_type'] == 'sale'), isTrue);
    // البسيط A4 هو الافتراضي — سلوك المتاجر القائمة كما هو.
    final defaults = rows.where((r) => r['is_default'] == 1).toList();
    expect(defaults, hasLength(1));
    expect(defaults.single['code'], 'simple_a4');
    // config JSON مفكوك سليماً لكل صف.
    for (final row in rows) {
      expect((row['config'] as String).contains('"templateId"'), isTrue);
    }
  });

  test('ترقية قاعدة v3 قائمة: v4 تضيف الجدول والبذر بلا فقد القديم', () async {
    final db = await buildDbAtVersion(3, '_upgrade');
    // v3: لا جدول قوالب بعد.
    expect(
      await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='print_template'",
      ),
      isEmpty,
      reason: 'قبل v4 لا يوجد جدول قوالب الطباعة',
    );

    await applyMigrations(db);

    expect(
      (await db.query('_migrations')).map((r) => r['version']).toList(),
      [1, 2, 3, 4, 5, 6],
    );
    final templates = await db.query('print_template');
    expect(templates, hasLength(2));
    // مفاتيح v3 بقت كما هي (لا فقد بالترقية).
    final byKey = {
      for (final r in await db.query('settings')) r['key'] as String: r['value'],
    };
    expect(byKey['sale.default_payment'], '"cash"');
    expect(byKey['display.font_scale'], '"normal"');
  });

  test('idempotent: إعادة applyMigrations فوق v4 لا تكرر الصفوف', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    await applyMigrations(app.db);
    expect(await app.db.query('print_template'), hasLength(2));
    await applyMigrations(app.db);
    expect(await app.db.query('print_template'), hasLength(2));
    expect(await app.db.query('_migrations'), hasLength(6));
  });

  test('بذور v4 بـ INSERT OR IGNORE لا تدوس تخصيص المستخدم ولا تكرر', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);

    // المستخدم خصّص الكلاسيكي وفعّله بعد الترقية.
    await app.db.rawUpdate(
      "UPDATE print_template SET is_default = 1, config = ? "
      "WHERE doc_type = 'sale' AND code = 'classic_a4'",
      <Object>['{"templateId":"classic_a4","tableHeadArgb":4278190080}'],
    );
    await app.db.rawUpdate(
      "UPDATE print_template SET is_default = 0 WHERE code = 'simple_a4'",
    );

    // إعادة تنفيذ بذور v4 نفسها (سطر INSERT OR IGNORE) فوق القاعدة.
    final v4 = migrations.firstWhere((m) => m.version == 4);
    for (final seed in v4.seeds) {
      await app.db.execute(seed);
    }

    final rows = await app.db.query('print_template');
    // إعادة تنفيذ بذور v4 يدوياً (سيناريو اصطناعي بالاختبار) يُحيي صف
    // الحراري المحذوف بهجرة v6 — النظام الحي لا يعيد تنفيذ بذر مطبّق،
    // والقيد الجوهري هنا: لا ازدواج لأي كود وتخصيص المستخدم لا يُداس.
    final codes = rows.map((r) => r['code']).toList();
    expect(codes.toSet().length, codes.length, reason: 'لا ازدواج لأي كود');
    final classic = rows.firstWhere((r) => r['code'] == 'classic_a4');
    expect(classic['is_default'], 1, reason: 'تفعيل المستخدم لا يُداس');
    expect(
      classic['config'],
      '{"templateId":"classic_a4","tableHeadArgb":4278190080}',
      reason: 'تخصيص المستخدم لا يُداس',
    );
  });

  test('UNIQUE(doc_type, code): تكرار الكود لنفس النوع يُرفض', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    expect(
      () => app.db.insert('print_template', {
        'doc_type': 'sale',
        'code': 'classic_a4',
      }),
      throwsA(isA<Exception>()),
      reason: 'قيد التفرد يحرس صفّاً واحداً لكل (نوع × قالب)',
    );
    // نفس الكود لنوع مختلف مقبول (أنواع مستندات لاحقة).
    final id = await app.db.insert('print_template', {
      'doc_type': 'voucher',
      'code': 'classic_a4',
    });
    expect(id, greaterThan(0));
  });
}
