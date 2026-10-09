/// اختبارات هجرة v3 (موجة UX-2a) — الشعار BLOB + مفاتيح التخصيص الجديدة:
/// قاعدة فارغة (إقلاع نظيف)، ترقية قاعدة v2 قائمة، idempotency، بذور لا
/// تدوس قيماً موجودة، وعمود BLOB يقبل البايتات ويعيدها.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/migrations.dart';
import 'package:mobile_app/core/storage/schema.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  test('إصدار المخطط الحالي 6، والهجرات الست مسجّلة بقاعدة فارغة', () async {
    expect(currentSchemaVersion, 6);
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final rows = await app.db.query('_migrations');
    expect(rows, hasLength(6));
    expect(rows.map((r) => r['version']).toList(), [1, 2, 3, 4, 5, 6]);
  });

  test('قاعدة فارغة: عمود logo_png موجود ويستقبل BLOB ويُقرأ كاملاً', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final logo = Uint8List.fromList(List<int>.generate(64, (i) => i % 251));
    final id = await app.db.insert('company', {
      'name': 'متجر الاختبار',
      'currency_id': 1,
      'logo_png': logo,
    });
    final row = (await app.db.query(
      'company',
      columns: ['logo_png'],
      where: 'id = ?',
      whereArgs: [id],
    )).first;
    expect(row['logo_png'] as Uint8List, logo);
  });

  test('قاعدة فارغة: مفاتيح UX-2a الثلاثة مزروعة بقيمها المعتمدة', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    final byKey = {
      for (final r in await app.db.query('settings'))
        r['key'] as String: r['value'],
    };
    expect(byKey['sale.default_payment'], '"cash"');
    expect(byKey['sale.show_discounts'], '"on"');
    expect(byKey['display.font_scale'], '"normal"');
  });

  test('ترقية قاعدة v2 قائمة: v3 تضيف العمود والمفاتيح بلا فقد القديمة', () async {
    // بناء قاعدة v2 يدوياً: تطبيق هجرتي v1/v2 فقط وتسجيلهما.
    final dir = await Directory.systemTemp.createTemp('finacc_v2');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v2.db';
    final db = await databaseFactory.openDatabase(path);
    addTearDown(db.close);
    await db.execute(migrationsTableDdl);
    for (final migration in migrations.where((m) => m.version <= 2)) {
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
    // v2: لا عمود logo_png بعد.
    final columnsV2 = await db.rawQuery('PRAGMA table_info(company)');
    expect(
      columnsV2.where((c) => c['name'] == 'logo_png'),
      isEmpty,
      reason: 'قبل v3 لا يوجد عمود الشعار',
    );

    // ترقية v3+v4+v5+v6 فوقها (نفس مسار onUpgrade الحقيقي).
    await applyMigrations(db);

    final applied = await db.query('_migrations');
    expect(applied.map((r) => r['version']).toList(), [1, 2, 3, 4, 5, 6]);
    final columnsV3 = await db.rawQuery('PRAGMA table_info(company)');
    final logoCol = columnsV3.firstWhere((c) => c['name'] == 'logo_png');
    expect(logoCol['type'], 'BLOB');
    final byKey = {
      for (final r in await db.query('settings'))
        r['key'] as String: r['value'],
    };
    // القديمة بقت + الجديدة أُضيفت.
    expect(byKey['dating.max_backdate_days'], '30');
    expect(byKey['sale.over_avail_policy'], '"warn"');
    expect(byKey['sale.default_payment'], '"cash"');
    expect(byKey['sale.show_discounts'], '"on"');
    expect(byKey['display.font_scale'], '"normal"');
  });

  test(
    'idempotent: إعادة applyMigrations فوق قاعدة v3 لا تكرر شيئاً',
    () async {
      final app = await openUniqueFileApp();
      addTearDown(app.close);
      await applyMigrations(app.db);
      final settingsCount = (await app.db.query('settings')).length;
      await applyMigrations(app.db);
      expect((await app.db.query('settings')).length, settingsCount);
      expect(await app.db.query('_migrations'), hasLength(6));
    },
  );

  test('بذور v3 بـ INSERT OR IGNORE لا تدوس قيمة موجودة قبل الترقية', () async {
    // قاعدة v2 حقيقية كتب المستخدم فيها `display.font_scale` يدوياً
    // قبل الترقية (ترقية مهوّاة أو إدارة قيمة سابقة).
    final dir = await Directory.systemTemp.createTemp('finacc_v2b');
    addTearDown(() => dir.delete(recursive: true));
    final db = await databaseFactory.openDatabase('${dir.path}/v2b.db');
    addTearDown(db.close);
    await db.execute(migrationsTableDdl);
    for (final migration in migrations.where((m) => m.version <= 2)) {
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
    await db.insert('settings', {
      'key': 'display.font_scale',
      'value': '"xlarge"',
      'updated_at': '2026-10-01T00:00:00Z',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // ترقية v3: العمود جديد فعلاً (قاعدة v2) والبذر يتجاهل المفتاح الموجود.
    await applyMigrations(db);
    final value = await db.rawQuery(
      "SELECT value FROM settings WHERE key = 'display.font_scale'",
    );
    expect(value.first['value'], '"xlarge"', reason: 'بذر v3 لا يدوس الموجود');
    // وبقية مفاتيح v3 زُرعت طبيعياً.
    final others = await db.rawQuery(
      "SELECT value FROM settings WHERE key = 'sale.default_payment'",
    );
    expect(others.first['value'], '"cash"');
  });
}
