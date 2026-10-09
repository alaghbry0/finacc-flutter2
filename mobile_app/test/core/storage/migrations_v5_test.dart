/// اختبارات هجرة v5 (موجة UX-4 — الكميات المجانية/بونص) بعد R16-a:
/// عمود `invoice_item.free_qty` (NUMERIC(12,3) NOT NULL DEFAULT 0) يبقى
/// محفوظاً إلى الأبد، بينما بذرة مفتاح `sale.free_qty` ('off') التي
/// زرعتها v5 **تحذفها هجرة v6** (قرار المالك: لا إعداد للبونص) — قاعدة
/// فارغة (إقلاع نظيف)، ترقية قاعدة v3 قائمة (v4+v5+v6 فوقها — نفس
/// مسار onUpgrade الحقيقي)، الصفوف القديمة بلا بونص تلقائياً،
/// وidempotency.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/migrations.dart';
import 'package:mobile_app/core/storage/schema.dart';
import 'package:mobile_app/domain/models/sale.dart';
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

  test('قاعدة فارغة: عمود free_qty بجداول البنود والمفتاح المتقاعد محذوف (v6)', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);

    final columns = await app.db.rawQuery('PRAGMA table_info(invoice_item)');
    final freeCol = columns.firstWhere((c) => c['name'] == 'free_qty');
    expect(freeCol['type'], 'NUMERIC(12,3)');
    expect(freeCol['notnull'], 1, reason: 'NOT NULL');
    expect(freeCol['dflt_value'], '0', reason: 'DEFAULT 0 — بلا بونص');
    // v5 زرعت المفتاح ثم v6 حذفه (قرار المالك R16-a: لا إعداد للبونص).
    final rows = await app.db.query(
      'settings',
      columns: ['value'],
      where: "key = 'sale.free_qty'",
    );
    expect(rows, isEmpty, reason: 'المفتاح المتقاعد غير موجود بقاعدة نظيفة');
  });

  test('ترقية قاعدة v3 قائمة: v4+v5+v6 فوقها والعمود ظاهر والمفتاح محذوف', () async {
    final db = await buildDbAtVersion(3, '_upgrade');
    // v3: لا عمود بونص بعد.
    expect(
      (await db.rawQuery('PRAGMA table_info(invoice_item)'))
          .where((c) => c['name'] == 'free_qty'),
      isEmpty,
      reason: 'قبل v5 لا يوجد عمود الكمية المجانية',
    );

    await applyMigrations(db);

    expect(
      (await db.query('_migrations')).map((r) => r['version']).toList(),
      [1, 2, 3, 4, 5, 6],
    );
    final freeCol = (await db.rawQuery('PRAGMA table_info(invoice_item)'))
        .firstWhere((c) => c['name'] == 'free_qty');
    expect(freeCol['dflt_value'], '0');
    final byKey = {
      for (final r in await db.query('settings')) r['key'] as String: r['value'],
    };
    // القديمة بقت + الجديدة أُضيفت (لا فقد بالترقية).
    expect(byKey['sale.default_payment'], '"cash"');
    expect(byKey.containsKey('sale.free_qty'), isFalse,
        reason: 'v6 حذفت بوابة البونص المتقاعدة');
    // وجدول قوالب v4 صعد معها (ترقية v3 كاملة إلى الرأس).
    expect(await db.query('print_template'), hasLength(2));
  });

  test('صفوف بنود قديمة (أُدرجت بلا free_qty): بلا بونص تلقائياً', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    // مستودع مرجعي (البذور تعطي العملات؛ المخازن لا تُبذر).
    await app.db.insert('warehouse', {
      'name': 'المخزن الرئيسي',
      'is_default': 1,
      'created_at': '2026-10-01T00:00:00Z',
      'updated_at': '2026-10-01T00:00:00Z',
    });
    // بند قديم كما كانت تكتبه الشيفرة قبل v5 — بلا free_qty أصلاً.
    await app.db.insert('invoice', {
      'invoice_no': 'INV-2026-09999',
      'doc_type': 'sale',
      'pay_status': 'cash',
      'status': 'completed',
      'issued_at': '2026-10-01T10:00:00Z',
      'warehouse_id': 1,
      'currency_id': 1,
      'exchange_rate': 1,
      'total': 100,
      'total_base': 100,
    });
    await app.db.insert('invoice_item', {
      'invoice_id': 1,
      'line_desc': 'قلم قديم',
      'qty': 4,
      'unit_price': 25,
      'line_total': 100,
    });
    final row = (await app.db.query('invoice_item')).single;
    expect((row['free_qty'] as num?)?.toDouble(), 0);
    // والقارئ يرى 0 (fromRow) — سلوك ما قبل الترقية.
    expect(SaleInvoiceItemLine.fromRow(row).freeQty, 0);
  });

  test('idempotent: إعادة applyMigrations فوق v6 لا تكرر الإعدادات', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);
    await applyMigrations(app.db);
    final settingsCount = (await app.db.query('settings')).length;
    await applyMigrations(app.db);
    expect((await app.db.query('settings')).length, settingsCount);
    expect(await app.db.query('_migrations'), hasLength(6));
  });

  test('قيمة المستخدم القديمة للمفتاح المتقاعد تُحذف أيضاً (v6 لا استثناء)', () async {
    final db = await buildDbAtVersion(3, '_user_value');
    // المستخدم فعّل البونص يدوياً قبل الترقية (ترقية مهوّاة أو قيمة سابقة).
    await db.insert('settings', {
      'key': 'sale.free_qty',
      'value': '"on"',
      'updated_at': '2026-10-01T00:00:00Z',
    });

    await applyMigrations(db);

    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: "key = 'sale.free_qty'",
    );
    expect(rows, isEmpty,
        reason: 'الإعداد تقاعد نهائياً — البوابة ديناميكية عند freeQty>0');
    // وعمود البونص نفسه لم يُمسّ (بونصات المتاجر محفوظة).
    expect(
      (await db.rawQuery('PRAGMA table_info(invoice_item)'))
          .where((c) => c['name'] == 'free_qty'),
      isNotEmpty,
    );
  });
}
