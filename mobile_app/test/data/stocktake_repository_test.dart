/// اختبارات مستودع الجرد (FR-01-08 + AC-04): كشف الجرد (استبعاد
/// الخدمي/المؤرشف، دفتري 0 عند الغياب، لقطة التكلفة) + الترحيل الذرّي
/// الذهبي (سطر لكل بند، حركة جرد موقَّعة بتاريخ المستخدم واسم الجانِد
/// بتكلفة لقطة داخل المعاملة، قفل الأرصدة، قيد التدقيق) + لقطة التكلفة
/// وقت الجرد + الفروقات الصفرية + تجاوز غير المعدود + إعادة قراءة
/// الدفتري داخل المعاملة + اتساق الدفعات FEFO (عجز/زيادة/نقص/بلا
/// دفعات) + السجل + الذرّية + حراس التحقق.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/stocktake_repository.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late StocktakeRepository repo;
  late int warehouseId;
  late int otherWarehouseId;

  /// لحظة عدّ ثابتة (بتاريخ المستخدم — لا ساعة الجهاز).
  final countedAt = DateTime.utc(2026, 10, 8, 9, 30);
  final countedIso = countedAt.toUtc().toIso8601String();

  setUp(() async {
    app = await openUniqueFileApp();
    repo = StocktakeRepository(app.db);
    warehouseId = await app.db.insert('warehouse', {
      'name': 'المخزن الرئيسي',
      'is_default': 1,
    });
    otherWarehouseId = await app.db.insert('warehouse', {
      'name': 'مخزن فرعي',
      'is_default': 0,
    });
    // منفّذ التدقيق (audit_log.user_id REFERENCES app_user).
    await app.db.insert('app_user', {
      'username': 'admin',
      'display_name': 'أبو نور',
      'role': 'admin',
    });
  });

  tearDown(() async {
    await app.close();
  });

  /// يبذر صنفاً مخزنياً ويرجع معرّفه.
  Future<int> seedProduct(String name, {double cost = 0}) {
    return app.db.insert('product', {
      'name': name,
      'cost_price': cost,
      'is_service': 0,
      'track_batches': 0,
    });
  }

  /// يضبط رصيد صنف في مخزن.
  Future<void> setLevel(int productId, double qty) async {
    await app.db.rawInsert(
      'INSERT OR IGNORE INTO stock_level (product_id, warehouse_id, qty) '
      'VALUES (?, ?, 0)',
      <Object?>[productId, warehouseId],
    );
    await app.db.rawUpdate(
      'UPDATE stock_level SET qty = ? WHERE product_id = ? AND warehouse_id = ?',
      <Object?>[qty, productId, warehouseId],
    );
  }

  /// يبذر دفعة لصنف متتبع.
  Future<int> seedBatch(
    int productId,
    String number,
    String expiry,
    double qty,
  ) {
    return app.db.insert('batch', {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'batch_number': number,
      'expiry_date': expiry,
      'cost_price': 0,
      'qty': qty,
    });
  }

  Future<double> levelOf(int productId) async {
    final rows = await app.db.query(
      'stock_level',
      columns: ['qty'],
      where: 'product_id = ? AND warehouse_id = ?',
      whereArgs: [productId, warehouseId],
      limit: 1,
    );
    if (rows.isEmpty) return -1;
    return (rows.first['qty'] as num).toDouble();
  }

  test('loadDraft: مخزن بلا أصناف → قائمة فارغة', () async {
    expect(await repo.loadDraft(warehouseId), isEmpty);
    // مخزن لا وجود له أصلاً كذلك.
    expect(await repo.loadDraft(999), isEmpty);
  });

  test('loadDraft: كل الأصناف المخزنية بدفتريها ووحدتها وتكلفتها — الخدمي '
      'والمؤرشف مستبعدان وبلا مستوى = 0', () async {
    final unitId = await app.db.insert('unit', {'name': 'كرتونة'});
    final a = await seedProduct('صنف ألف', cost: 150);
    await app.db.update(
      'product',
      {'unit_id': unitId},
      where: 'id = ?',
      whereArgs: [a],
    );
    await setLevel(a, 10);
    final b = await seedProduct('صنف باء', cost: 200);
    await setLevel(b, 5);
    await app.db.insert('product', {
      'name': 'خدمة نقل',
      'cost_price': 0,
      'is_service': 1,
    });
    await app.db.insert('product', {
      'name': 'صنف مؤرشف',
      'cost_price': 10,
      'is_archived': 1,
    });
    final d = await seedProduct('صنف دال بلا رصيد', cost: 40);

    final draft = await repo.loadDraft(warehouseId);

    expect(draft.map((l) => l.productId), [a, b, d], reason: 'بالاسم');
    final la = draft[0];
    expect(la.name, 'صنف ألف');
    expect(la.unitName, 'كرتونة');
    expect(la.bookQty, 10);
    expect(la.unitCost, 150);
    expect(la.countedQty, isNull, reason: 'لم يُعدّ بعد');
    expect(draft[1].unitName, isNull);
    expect(draft[2].bookQty, 0, reason: 'لا صف stock_level → دفتري 0');
    expect(draft[2].unitCost, 40);
  });

  test('AC-04 الذهبي: فروقات → حركات جرد بتكلفة لقطة + سطر لكل بند + قفل '
      'الأرصدة + قيد تدقيق', () async {
    final a = await seedProduct('صنف ألف', cost: 150);
    await setLevel(a, 10);
    final b = await seedProduct('صنف باء', cost: 200);
    await setLevel(b, 5);

    final id = await repo.post(
      warehouseId: warehouseId,
      countedAt: countedAt,
      countedBy: 'أحمد الجانِد',
      notes: 'جرد نهاية الأسبوع',
      lines: [(a, 10, 8), (b, 5, 6)],
      userId: 1,
    );

    // صف الجرد: المجموع بعملة الأساس + التوقيع.
    final st = (await app.db.query(
      'stocktake',
      where: 'id = ?',
      whereArgs: [id],
    )).first;
    expect(st['warehouse_id'], warehouseId);
    expect(st['counted_at'], countedIso, reason: 'بتاريخ المستخدم');
    expect((st['total_diff'] as num).toDouble(), -100);
    expect(st['status'], 'completed');
    expect(st['notes'] as String, contains('جرد نهاية الأسبوع'));
    expect(st['notes'] as String, contains('أحمد الجانِد'));
    expect(st['created_by'], 1);

    // سطر لكل بند (المطابق والفارق معاً — أثر تدقيق كامل).
    final linesRows = await app.db.query(
      'stocktake_line',
      where: 'stocktake_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    expect(linesRows, hasLength(2));
    final la = linesRows[0];
    expect(la['product_id'], a);
    expect((la['book_qty'] as num).toDouble(), 10);
    expect((la['counted_qty'] as num).toDouble(), 8);
    expect((la['diff_qty'] as num).toDouble(), -2);
    expect((la['unit_cost'] as num).toDouble(), 150);
    final lb = linesRows[1];
    expect((lb['diff_qty'] as num).toDouble(), 1);
    expect((lb['unit_cost'] as num).toDouble(), 200);

    // حركتا جرد بتكلفة اللقطة وتوقيع المستخدم.
    final moves = await app.db.query(
      'stock_movement',
      where: "ref_type = 'stocktake' AND ref_id = ?",
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    expect(moves, hasLength(2));
    expect(moves[0]['product_id'], a);
    expect(moves[0]['movement_type'], 'stocktake_adjust');
    expect((moves[0]['qty'] as num).toDouble(), -2);
    expect((moves[0]['unit_cost'] as num).toDouble(), 150);
    expect(moves[0]['moved_at'], countedIso, reason: 'بتاريخ المستخدم');
    expect(moves[0]['notes'] as String, contains('أحمد الجانِد'));
    expect((moves[1]['qty'] as num).toDouble(), 1);
    expect((moves[1]['unit_cost'] as num).toDouble(), 200);

    // قفل الأرصدة على المقيس.
    expect(await levelOf(a), 8);
    expect(await levelOf(b), 6);

    // قيد التدقيق.
    final audit = await app.db.query(
      'audit_log',
      where: "action = 'stocktake_post' AND entity = 'stocktake'",
    );
    expect(audit, hasLength(1));
    expect(audit.first['entity_id'], id);
    expect(audit.first['user_id'], 1);
    expect(audit.first['details'] as String, contains('diffs=2'));
    expect(audit.first['details'] as String, contains('net=-100.0'));
  });

  test('لقطة التكلفة تُلتقط وقت الجرد داخل المعاملة — تغيّر WAC بعد فتح '
      'الكشف لا يغيّر ما يُخزَّن عن اللقطة الحالية', () async {
    final a = await seedProduct('صنف ألف', cost: 150);
    await setLevel(a, 10);
    final draft = await repo.loadDraft(warehouseId);
    expect(draft.first.unitCost, 150, reason: 'لقطة العرض وقت الفتح');

    // شراء لاحق رفع WAC إلى 200 أثناء العدّ.
    await app.db.update(
      'product',
      {'cost_price': 200},
      where: 'id = ?',
      whereArgs: [a],
    );

    final id = await repo.post(
      warehouseId: warehouseId,
      countedAt: countedAt,
      countedBy: 'أحمد',
      lines: [(a, 10, 8)],
      userId: 1,
    );

    final line = (await app.db.query(
      'stocktake_line',
      where: 'stocktake_id = ?',
      whereArgs: [id],
    )).first;
    expect(
      (line['unit_cost'] as num).toDouble(),
      200,
      reason: 'لقطة وقت الجرد (لا نسخة الكشف القديمة)',
    );
    final move = (await app.db.query(
      'stock_movement',
      where: "ref_type = 'stocktake' AND ref_id = ?",
      whereArgs: [id],
    )).first;
    expect((move['unit_cost'] as num).toDouble(), 200);
    final st = (await app.db.query(
      'stocktake',
      where: 'id = ?',
      whereArgs: [id],
    )).first;
    expect(
      (st['total_diff'] as num).toDouble(),
      -400,
      reason: 'الفرق −2 × تكلفة اللقطة 200',
    );
  });

  test('الفروقات الصفرية: لا حركات والجرد مخزَّن والأرصدة ثابتة', () async {
    final a = await seedProduct('صنف ألف', cost: 150);
    await setLevel(a, 10);

    final id = await repo.post(
      warehouseId: warehouseId,
      countedAt: countedAt,
      countedBy: 'أحمد',
      lines: [(a, 10, 10)],
      userId: 1,
    );

    expect(
      await app.db.query('stock_movement', where: "ref_type = 'stocktake'"),
      isEmpty,
      reason: 'لا فرق → لا حركة',
    );
    expect(
      await app.db.query('stocktake_line', where: 'stocktake_id = $id'),
      hasLength(1),
      reason: 'السطر المطابق مخزَّن (أثر تدقيق كامل)',
    );
    expect(await levelOf(a), 10);
    final st = (await app.db.query('stocktake')).first;
    expect((st['total_diff'] as num).toDouble(), 0);
  });

  test(
    'البنود غير المعدودة لا تصل المستودع — ما لم يُمرَّر لا سطر ولا حركة',
    () async {
      final a = await seedProduct('صنف ألف', cost: 150);
      await setLevel(a, 10);
      final b = await seedProduct('صنف باء', cost: 200);
      await setLevel(b, 5);

      // نموذج العرض يمرّر المعدودة حصراً — هنا باء غير معدود.
      final id = await repo.post(
        warehouseId: warehouseId,
        countedAt: countedAt,
        countedBy: 'أحمد',
        lines: [(a, 10, 8)],
        userId: 1,
      );

      final lines = await app.db.query(
        'stocktake_line',
        where: 'stocktake_id = ?',
        whereArgs: [id],
      );
      expect(lines, hasLength(1));
      expect(lines.first['product_id'], a);
      expect(await levelOf(b), 5, reason: 'غير المعدود برصيده لم يُمسّ');
    },
  );

  test(
    'الرصيد الدفتري يُعاد قراءته داخل المعاملة لا من نسخة الواجهة',
    () async {
      final a = await seedProduct('صنف ألف', cost: 100);
      await setLevel(a, 10);
      // واجهة فتحت الكشف على دفتري 10 ثم شراء رفعه إلى 14 قبل الاعتماد.
      await setLevel(a, 14);

      final id = await repo.post(
        warehouseId: warehouseId,
        countedAt: countedAt,
        countedBy: 'أحمد',
        lines: [(a, 10, 12)], // bookQty الاستشاري = 10 (قديم).
        userId: 1,
      );

      final line = (await app.db.query(
        'stocktake_line',
        where: 'stocktake_id = ?',
        whereArgs: [id],
      )).first;
      expect(
        (line['book_qty'] as num).toDouble(),
        14,
        reason: 'الدفتري المخزَّن = قيمة المعاملة',
      );
      expect((line['diff_qty'] as num).toDouble(), -2);
      final move = (await app.db.query('stock_movement')).first;
      expect((move['qty'] as num).toDouble(), -2);
      expect(await levelOf(a), 12);
    },
  );

  test('الدفعات: العجز يُخصم FEFO من الأقرب انتهاءً أولاً', () async {
    final p = await app.db.insert('product', {
      'name': 'صنف متتبع',
      'cost_price': 50,
      'track_batches': 1,
    });
    final early = await seedBatch(p, 'B-1', '2026-11-01', 5);
    final late = await seedBatch(p, 'B-2', '2027-05-01', 3);
    await setLevel(p, 8);

    await repo.post(
      warehouseId: warehouseId,
      countedAt: countedAt,
      countedBy: 'أحمد',
      lines: [(p, 8, 6)],
      userId: 1,
    );

    Future<double> batchQty(int id) async {
      final row = (await app.db.query(
        'batch',
        columns: ['qty'],
        where: 'id = ?',
        whereArgs: [id],
      )).first;
      return (row['qty'] as num).toDouble();
    }

    expect(await batchQty(early), 3, reason: 'الأقرب انتهاءً 5 → 3');
    expect(await batchQty(late), 3, reason: 'الأبعد لم يُمسّ');
    expect(await levelOf(p), 6);
    expect((await app.db.query('stock_movement')).first['qty'] as num, -2);
  });

  test('الدفعات: الزيادة تُضاف إلى الدفعة الأبعد انتهاءً', () async {
    final p = await app.db.insert('product', {
      'name': 'صنف متتبع',
      'cost_price': 50,
      'track_batches': 1,
    });
    final early = await seedBatch(p, 'B-1', '2026-11-01', 5);
    final late = await seedBatch(p, 'B-2', '2027-05-01', 3);
    await setLevel(p, 8);

    await repo.post(
      warehouseId: warehouseId,
      countedAt: countedAt,
      countedBy: 'أحمد',
      lines: [(p, 8, 10)],
      userId: 1,
    );

    Future<double> batchQty(int id) async {
      final row = (await app.db.query(
        'batch',
        columns: ['qty'],
        where: 'id = ?',
        whereArgs: [id],
      )).first;
      return (row['qty'] as num).toDouble();
    }

    expect(await batchQty(early), 5, reason: 'الأقرب لم يُمسّ');
    expect(await batchQty(late), 5, reason: 'الأبعد 3 + 2 = 5');
    expect(await levelOf(p), 10);
    expect((await app.db.query('stock_movement')).first['qty'] as num, 2);
  });

  test('الدفعات: مجموعها أقل من العجز → تُصفَّر كل الدفعات', () async {
    final p = await app.db.insert('product', {
      'name': 'صنف متتبع',
      'cost_price': 50,
      'track_batches': 1,
    });
    final b1 = await seedBatch(p, 'B-1', '2026-11-01', 2);
    final b2 = await seedBatch(p, 'B-2', '2027-05-01', 1);
    await setLevel(p, 3);

    await repo.post(
      warehouseId: warehouseId,
      countedAt: countedAt,
      countedBy: 'أحمد',
      lines: [(p, 3, 0)],
      userId: 1,
    );

    final rows = await app.db.query('batch', where: 'product_id = $p');
    expect(rows, hasLength(2));
    expect((rows[0]['qty'] as num).toDouble(), 0, reason: 'صُفِّرت كلها');
    expect((rows[1]['qty'] as num).toDouble(), 0);
    expect(await levelOf(p), 0);
    expect((await app.db.query('stock_movement')).first['qty'] as num, -3);
    // معرفا الدفعتين محفوظان للتوثيق (لا حذف).
    expect(rows[0]['id'], b1);
    expect(rows[1]['id'], b2);
  });

  test('صنف متتبع بلا دفعات أصلاً → تجاوز صامت والرصيد يُقفل', () async {
    final p = await app.db.insert('product', {
      'name': 'صنف متتبع بلا دفعات',
      'cost_price': 50,
      'track_batches': 1,
    });
    await setLevel(p, 4);

    await repo.post(
      warehouseId: warehouseId,
      countedAt: countedAt,
      countedBy: 'أحمد',
      lines: [(p, 4, 6)],
      userId: 1,
    );

    expect(await app.db.query('batch'), isEmpty);
    expect(await levelOf(p), 6);
    expect((await app.db.query('stock_movement')).first['qty'] as num, 2);
  });

  test('السجل: الأحدث أولاً مع عدد الأسطر والصافي', () async {
    final a = await seedProduct('صنف ألف', cost: 150);
    await setLevel(a, 10);
    final b = await seedProduct('صنف باء', cost: 200);
    await setLevel(b, 5);

    final older = await repo.post(
      warehouseId: warehouseId,
      countedAt: DateTime.utc(2026, 10, 1),
      countedBy: 'أحمد',
      lines: [(a, 10, 8)],
      userId: 1,
    );
    final newer = await repo.post(
      warehouseId: warehouseId,
      countedAt: DateTime.utc(2026, 10, 8),
      countedBy: 'سالم',
      lines: [(a, 8, 8), (b, 5, 6)],
      userId: 1,
    );

    final rows = await repo.history(warehouseId: warehouseId);
    expect(rows.map((r) => r.id).toList(), [newer, older]);
    expect(rows.first.linesCount, 2);
    expect(rows.last.linesCount, 1);
    expect(rows.first.totalDiff, 200);
    expect(rows.last.totalDiff, -300);
    expect(rows.first.notes, contains('سالم'));
    // السجل لكل مخزن على حدة.
    expect(await repo.history(warehouseId: otherWarehouseId), isEmpty);
  });

  test('الذرّية: فشل داخل المعاملة لا يترك أثراً جزئياً', () async {
    final a = await seedProduct('صنف ألف', cost: 150);
    await setLevel(a, 10);

    expect(
      () => repo.post(
        warehouseId: warehouseId,
        countedAt: countedAt,
        countedBy: 'أحمد',
        lines: [(a, 10, 8), (999, 3, 2)], // صنف مهلك يخالف المفتاح الأجنبي.
        userId: 1,
      ),
      throwsA(isA<StocktakeException>()),
    );

    expect(await app.db.query('stocktake'), isEmpty, reason: 'لا جرد');
    expect(await app.db.query('stocktake_line'), isEmpty, reason: 'لا أسطر');
    expect(await app.db.query('stock_movement'), isEmpty, reason: 'لا حركات');
    expect(
      await app.db.query('audit_log', where: "action = 'stocktake_post'"),
      isEmpty,
      reason: 'لا قيد تدقيق',
    );
    expect(await levelOf(a), 10, reason: 'الرصيد لم يُقفل');
  });

  test(
    'الحراس: الكمية السالبة/الاسم الفارغ/لا بنود — رفض عربي بلا كتابة',
    () async {
      final a = await seedProduct('صنف ألف', cost: 150);
      await setLevel(a, 10);

      await expectLater(
        repo.post(
          warehouseId: warehouseId,
          countedAt: countedAt,
          countedBy: 'أحمد',
          lines: [(a, 10, -1)],
          userId: 1,
        ),
        throwsA(
          isA<StocktakeException>().having(
            (e) => e.message,
            'message',
            contains('سالب'),
          ),
        ),
      );

      await expectLater(
        repo.post(
          warehouseId: warehouseId,
          countedAt: countedAt,
          countedBy: '   ',
          lines: [(a, 10, 8)],
          userId: 1,
        ),
        throwsA(
          isA<StocktakeException>().having(
            (e) => e.message,
            'message',
            contains('الجانِد'),
          ),
        ),
      );

      await expectLater(
        repo.post(
          warehouseId: warehouseId,
          countedAt: countedAt,
          countedBy: 'أحمد',
          lines: const <(int, double, double)>[],
          userId: 1,
        ),
        throwsA(
          isA<StocktakeException>().having(
            (e) => e.message,
            'message',
            contains('صنفاً'),
          ),
        ),
      );

      expect(await app.db.query('stocktake'), isEmpty);
      expect(await app.db.query('stocktake_line'), isEmpty);
      expect(await app.db.query('stock_movement'), isEmpty);
      expect(await levelOf(a), 10);
    },
  );

  test('warehouses: غير المؤرشفة فقط والافتراضي أولاً', () async {
    await app.db.insert('warehouse', {'name': 'مخزن مؤرشف', 'is_archived': 1});
    final rows = await repo.warehouses();
    expect(rows, hasLength(2));
    expect(rows.first.id, warehouseId, reason: 'الافتراضي أولاً');
    expect(rows.first.isDefault, isTrue);
    expect(rows.first.name, 'المخزن الرئيسي');
    expect(rows.last.id, otherWarehouseId);
  });
}
