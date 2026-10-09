/// اختبارات هجرة v6 (موجة R16-a — ثورة الكميات المجانية): حذف مفتاح
/// `sale.free_qty` المتقاعد من جدول `settings` idempotently بقرار المالك
/// (لا إعداد لإظهار/إخفاء حقل البونص — الشارة ديناميكية عند freeQty>0)،
/// مع الحفاظ الحرفي على عمود `invoice_item.free_qty` (بونصات المتاجر
/// القائمة) — وبنود الشراء (doc_type='purchase') تسكن الجدول نفسه فتحمل
/// البونص بلا أي DDL إضافي (لا يوجد جدول purchase_item بالمخطط المجمد).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/migrations.dart';
import 'package:mobile_app/core/storage/schema.dart';
import 'package:mobile_app/domain/models/purchase.dart';
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

  Future<List<Map<String, Object?>>> freeQtyKeyRows(DatabaseExecutor db) =>
      db.query('settings', where: "key = 'sale.free_qty'");

  test('قاعدة فارغة: v6 مسجّلة والمفتاح المتقاعد غير موجود والعمود سليم', () async {
    final app = await openUniqueFileApp();
    addTearDown(app.close);

    expect(await app.db.query('_migrations'), hasLength(6));
    expect(await freeQtyKeyRows(app.db), isEmpty,
        reason: 'v5 زرعت المفتاح ثم v6 حذفته (لا إعداد للبونص)');
    // العمود محفوظ حرفياً — بونصات المتاجر القائمة لا تُمسّ.
    final freeCol = (await app.db.rawQuery('PRAGMA table_info(invoice_item)'))
        .firstWhere((c) => c['name'] == 'free_qty');
    expect(freeCol['type'], 'NUMERIC(12,3)');
    expect(freeCol['notnull'], 1);
    expect(freeCol['dflt_value'], '0');
  });

  test('ترقية قاعدة v5 قائمة (المفتاح مزروع off): v6 تحذفه وحده', () async {
    final db = await buildDbAtVersion(5, '_upgrade');
    // v5: المفتاح موجود كما زرعته البذرة.
    expect((await freeQtyKeyRows(db)).single['value'], '"off"');

    await applyMigrations(db);

    expect(
      (await db.query('_migrations')).map((r) => r['version']).toList(),
      [1, 2, 3, 4, 5, 6],
    );
    expect(await freeQtyKeyRows(db), isEmpty,
        reason: 'v6 تحذف بوابة البونص المتقاعدة');
    // بقية المفاتيح لم تُمسّ (لا حذف واسع بالخطأ).
    final byKey = {
      for (final r in await db.query('settings')) r['key'] as String: r['value'],
    };
    expect(byKey['sale.default_payment'], '"cash"');
    expect(byKey['sale.show_discounts'], '"on"');
    expect(byKey['display.font_scale'], '"normal"');
    expect(byKey['invoicing.print_on_save'], '"ask"');
    // والعمود باقٍ بعد الترقية.
    expect(
      (await db.rawQuery('PRAGMA table_info(invoice_item)'))
          .where((c) => c['name'] == 'free_qty'),
      isNotEmpty,
    );
  });

  test('قيمة مستخدم قديمة (on): تُحذف أيضاً — الإعداد تقاعد بلا استثناء', () async {
    final db = await buildDbAtVersion(5, '_user_on');
    // المستخدم فعّل البونص يدوياً فوق بذرة v5 (دوس القيمة).
    await db.insert(
      'settings',
      {
        'key': 'sale.free_qty',
        'value': '"on"',
        'updated_at': '2026-10-01T00:00:00Z',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await applyMigrations(db);

    expect(await freeQtyKeyRows(db), isEmpty);
  });

  test('عبارة DELETE نفسها idempotent: تنفيذها مرتين لا يخطئ ولا يبقي أثراً', () async {
    final db = await buildDbAtVersion(5, '_idem');
    expect(await freeQtyKeyRows(db), isNotEmpty);

    await db.execute(deleteSaleFreeQtyKeyV6);
    expect(await freeQtyKeyRows(db), isEmpty);
    // إعادة التنفيذ فوق قاعدة بلا الصف — لا خطأ ولا تغيير.
    await db.execute(deleteSaleFreeQtyKeyV6);
    expect(await freeQtyKeyRows(db), isEmpty);

    // وإعادة applyMigrations كلية فوق v6 لا تفعل شيئاً.
    await applyMigrations(db);
    expect(await db.query('_migrations'), hasLength(6));
    expect(await freeQtyKeyRows(db), isEmpty);
  });

  test('بنود الشراء تحمل free_qty بلا DDL إضافي (invoice_item مشترك)', () async {
    // التكليف ذكر ALTER TABLE purchase_item — بالمخطط المجمد بنود الشراء
    // تسكن invoice_item (doc_type='purchase') وقد حملت العمود منذ v5؛
    // هذا الاختبار يثبت أن بند شراء جديد يخزن البونص ويُقرأ سليماً.
    final app = await openUniqueFileApp();
    addTearDown(app.close);

    await app.db.insert('warehouse', {
      'name': 'المخزن الرئيسي',
      'is_default': 1,
      'created_at': '2026-10-01T00:00:00Z',
      'updated_at': '2026-10-01T00:00:00Z',
    });
    final invoiceId = await app.db.insert('invoice', {
      'invoice_no': 'PUR-2026-09999',
      'doc_type': 'purchase',
      'pay_status': 'credit',
      'status': 'completed',
      'issued_at': '2026-10-01T10:00:00Z',
      'warehouse_id': 1,
      'currency_id': 1,
      'exchange_rate': 1,
      'total': 1200,
      'total_base': 1200,
    });
    await app.db.insert('invoice_item', {
      'invoice_id': invoiceId,
      'line_desc': 'شامبو مورد',
      'qty': 10,
      'free_qty': 2,
      'unit_price': 120,
      'line_total': 1200,
      'line_cost': 1200,
    });
    final row = (await app.db.query('invoice_item')).single;
    expect((row['free_qty'] as num?)?.toDouble(), 2);
    // والقارئ يعيده لعرض تفاصيل فاتورة الشراء «(+2 مجاني)».
    final line = PurchaseInvoiceItemLine.fromRow(row);
    expect(line.freeQty, 2);
    expect(line.qty, 10, reason: 'المدفوع للمورد وحده');
  });
}
