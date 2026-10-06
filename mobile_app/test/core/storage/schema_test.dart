/// اختبارات المخطط المجمّد — 34 جدولاً + الفهارس + Triggers الحماية (§5.3).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;

  setUp(() async {
    app = await openUniqueFileApp();
  });

  tearDown(() async {
    await app.close();
  });

  test(
    'المخطط الكامل: 33 جدول أعمال + _migrations (+sqlite_sequence تلقائي)',
    () async {
      final rows = await app.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = rows.map((r) => r['name'] as String).toSet();
      const expected = [
        'doc_sequence',
        'company',
        'currency',
        'exchange_rate',
        'category',
        'unit',
        'warehouse',
        'cashbox',
        'expense_category',
        'fiscal_year',
        'product',
        'product_price',
        'stock_level',
        'stock_movement',
        'batch',
        'stocktake',
        'stocktake_line',
        'customer',
        'supplier',
        'invoice',
        'invoice_item',
        'quotation',
        'quotation_item',
        'cash_tx',
        'payment_allocation',
        'shift',
        'cheque',
        'installment_plan',
        'installment',
        'app_user',
        'audit_log',
        'backup_log',
        'settings',
        '_migrations',
      ];
      for (final table in expected) {
        expect(names, contains(table), reason: 'الجدول $table مفقود من المخطط');
      }
    },
  );

  test('فهارس الأداء الأساسية موجودة (فواتير/حركات/أصناف)', () async {
    final rows = await app.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index'",
    );
    final names = rows.map((r) => r['name'] as String).toSet();
    const expected = [
      'idx_invoice_type_date',
      'idx_invoice_no',
      'idx_item_invoice',
      'idx_cash_tx_date',
      'idx_move_product_date',
      'idx_product_name',
      'idx_customer_name',
      'idx_batch_expiry',
    ];
    for (final index in expected) {
      expect(names, contains(index), reason: 'الفهرس $index مفقود');
    }
  });

  test('Triggers حماية audit_log تمنع التعديل والحذف من أي جهة', () async {
    await app.db.insert('audit_log', {
      'user_id': null,
      'action': 'test_event',
      'entity': null,
      'entity_id': null,
      'details': 'probe',
      'at': '2026-10-06T00:00:00Z',
    });
    final id =
        (await app.db.query(
              'audit_log',
              where: "action = 'test_event'",
            )).first['id']
            as int;

    expect(
      () => app.db.update(
        'audit_log',
        {'details': 'tampered'},
        where: 'id = ?',
        whereArgs: [id],
      ),
      throwsA(isA<DatabaseException>()),
      reason: 'UPDATE على audit_log يجب أن يرفضه الـ Trigger',
    );
    expect(
      () => app.db.delete('audit_log', where: 'id = ?', whereArgs: [id]),
      throwsA(isA<DatabaseException>()),
      reason: 'DELETE على audit_log يجب أن يرفضه الـ Trigger',
    );
  });

  test('قيود المفاتيح الأجنبية مفعّلة (foreign_keys=ON)', () async {
    final rows = await app.db.rawQuery('PRAGMA foreign_keys');
    expect(rows.first.values.first as int, 1);
  });

  test('وضع WAL مفعّل للمعاملات المتزامنة', () async {
    final rows = await app.db.rawQuery('PRAGMA journal_mode');
    // الوضع قد يكون wal أو persist(WAL) — الأساس ليس delete.
    final mode = (rows.first.values.first as String).toLowerCase();
    expect(
      mode,
      contains('wal'),
      reason: 'وضع اليومية يجب أن يكون WAL وليس $mode',
    );
    expect(app.journalMode.toLowerCase(), contains('wal'));
  });

  test('نسخة SQLite مقروءة وموثقة', () async {
    expect(app.sqliteVersion, isNotEmpty);
    final major = int.tryParse(app.sqliteVersion.split('.').first) ?? 0;
    expect(major, greaterThanOrEqualTo(3));
  });
}
