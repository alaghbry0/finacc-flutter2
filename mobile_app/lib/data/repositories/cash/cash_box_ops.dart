/// جزء من تقسيم R18-D3a لمستودع النقدية — مستخرج حرفياً من
/// cash_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/result.dart';
import '../../../domain/models/cash.dart';
import 'cash_flow_types.dart';
import 'cash_helpers.dart';

// ─────────────────────────────────────────────────────────────────────

/// الصناديق بأرصدتها الحية — رصيد بعملة الصندوق + دلاء العملات الأخرى
/// (إشارات ملحق و — انظر رأس الملف). السالب مسموح ويعود للواجهة.
Future<List<CashboxWithBalance>> listBoxesWithBalances(
  Database db, {
  bool includeArchived = false,
}) async {
  final rows = await db.rawQuery(
    '''
    WITH legs AS (
      -- حركات ذات ساق واحدة (بعملتها أو بعملة صندوقها عند settlement)
      SELECT t.cashbox_id AS box,
        CASE WHEN t.settlement_rate IS NULL THEN t.currency_id
             ELSE cb.currency_id END AS cur,
        CASE WHEN t.settlement_rate IS NULL THEN t.amount
             ELSE t.amount * t.settlement_rate END
          * CASE WHEN t.tx_type IN ('receipt','capital_in','opening')
                 THEN 1 ELSE -1 END AS amt
      FROM cash_tx t
      JOIN cashbox cb ON cb.id = t.cashbox_id
      WHERE t.is_voided = 0 AND t.reversal_of IS NULL
        AND t.tx_type NOT IN
          ('box_transfer','bank_deposit','bank_withdraw')
      UNION ALL
      -- الساق الصادرة من المصدر (بعملة المصدر دائماً)
      SELECT t.cashbox_id, t.currency_id, -t.amount
      FROM cash_tx t
      WHERE t.is_voided = 0 AND t.reversal_of IS NULL
        AND t.tx_type IN ('box_transfer','bank_deposit','bank_withdraw')
      UNION ALL
      -- الساق الواردة إلى الهدف (بعملة الهدف وبالمبلغ المحوّل)
      SELECT t.to_cashbox_id, tc.currency_id,
             t.amount * COALESCE(t.settlement_rate, 1)
      FROM cash_tx t
      JOIN cashbox tc ON tc.id = t.to_cashbox_id
      WHERE t.is_voided = 0 AND t.reversal_of IS NULL
        AND t.tx_type IN ('box_transfer','bank_deposit','bank_withdraw')
        AND t.to_cashbox_id IS NOT NULL
    )
    SELECT cb.id, cb.name, cb.currency_id, cb.is_default, cb.is_archived,
           cu.code AS currency_code, cu.is_base,
           b.cur AS bucket_cur, bc.code AS bucket_code, b.amt AS bucket_amt
    FROM cashbox cb
    JOIN currency cu ON cu.id = cb.currency_id
    LEFT JOIN (
      SELECT box, cur, SUM(amt) AS amt FROM legs GROUP BY box, cur
    ) b ON b.box = cb.id
    LEFT JOIN currency bc ON bc.id = b.cur
    WHERE (? = 1 OR cb.is_archived = 0)
    ORDER BY cb.is_default DESC, cb.name COLLATE NOCASE ASC
  ''',
    <Object?>[includeArchived ? 1 : 0],
  );

  final bucketCodes = <int, String?>{
    for (final row in rows)
      if (row['bucket_cur'] != null)
        row['bucket_cur'] as int: row['bucket_code'] as String?,
  };
  final byBox = <int, CashBoxAgg>{};
  for (final row in rows) {
    final id = row['id'] as int;
    var agg = byBox[id];
    if (agg == null) {
      agg = CashBoxAgg(
        CashboxInfo(
          id: id,
          name: row['name'] as String,
          currencyId: row['currency_id'] as int,
          currencyCode: (row['currency_code'] as String?) ?? '',
          isDefault: (row['is_default'] as int? ?? 0) == 1,
          isArchived: (row['is_archived'] as int? ?? 0) == 1,
        ),
      );
      byBox[id] = agg;
    }
    final bucketCur = row['bucket_cur'] as int?;
    if (bucketCur != null) {
      final amount = (row['bucket_amt'] as num?)?.toDouble() ?? 0;
      agg.buckets[bucketCur] = (agg.buckets[bucketCur] ?? 0) + amount;
    }
  }
  return [
    for (final agg in byBox.values)
      CashboxWithBalance(
        box: agg.box,
        nativeBalance: agg.buckets[agg.box.currencyId] ?? 0,
        foreignBuckets: [
          for (final entry in agg.buckets.entries)
            if (entry.key != agg.box.currencyId)
              CashCurrencyBucket(
                currencyId: entry.key,
                currencyCode: bucketCodes[entry.key] ?? '',
                amount: entry.value,
              ),
        ],
      ),
  ];
}

/// إضافة صندوق — العملة من عملات المنشأة (FR-04-01).
Future<Result<CashboxInfo, String>> addCashbox(
  Database db,

  String name,
  int currencyId, {
  bool makeDefault = false,
  int? userId,
}) async {
  final clean = name.trim();
  if (clean.isEmpty) {
    return const Err('اسم الصندوق مطلوب — أدخل الاسم ثم احفظ.');
  }
  try {
    final at = DateTime.now().toUtc().toIso8601String();
    return await db.transaction((txn) async {
      final currency = await txn.query(
        'currency',
        columns: ['code', 'is_active'],
        where: 'id = ?',
        whereArgs: [currencyId],
        limit: 1,
      );
      if (currency.isEmpty) {
        return Err('العملة رقم #$currencyId غير موجودة.');
      }
      if ((currency.first['is_active'] as int? ?? 0) == 0) {
        return const Err(
          'العملة غير مفعّلة — اختر عملة نشطة للصندوق (FR-04-01).',
        );
      }
      final code = currency.first['code'] as String;
      if (makeDefault) {
        await txn.update('cashbox', {'is_default': 0}, where: 'is_default = 1');
      }
      final id = await txn.insert('cashbox', {
        'name': clean,
        'currency_id': currencyId,
        'is_default': makeDefault ? 1 : 0,
        'created_at': at,
        'updated_at': at,
      });
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'cashbox_create',
        'entity': 'cashbox',
        'entity_id': id,
        'details': 'name=$clean currency=$code default=$makeDefault',
        'at': at,
      });
      return Ok<CashboxInfo, String>(
        CashboxInfo(
          id: id,
          name: clean,
          currencyId: currencyId,
          currencyCode: code,
          isDefault: makeDefault,
          isArchived: false,
        ),
      );
    });
  } on DatabaseException catch (e) {
    return Err(describeCashDbError(e, 'حفظ الصندوق'));
  }
}

/// إعادة تسمية صندوق.
Future<Result<void, String>> renameCashbox(
  Database db,
  int id,
  String name,
) async {
  final clean = name.trim();
  if (clean.isEmpty) {
    return const Err('اسم الصندوق مطلوب — أدخل الاسم ثم احفظ.');
  }
  final updated = await db.update(
    'cashbox',
    {'name': clean, 'updated_at': DateTime.now().toUtc().toIso8601String()},
    where: 'id = ?',
    whereArgs: [id],
  );
  if (updated == 0) {
    return Err('الصندوق رقم #$id غير موجود.');
  }
  return const Ok<void, String>(null);
}

/// أرشفة صندوق (FR-04-01) — يُمنع الأرشفة للصندوق الافتراضي ولآخر
/// صندوق نشط؛ الرصيد غير الصفري **لا يُمنع** (FR-04-09) لكن الواجهة
/// تطلب تأكيداً صريحاً قبلها.
Future<Result<void, String>> archiveCashbox(
  Database db,
  int id, {
  int? userId,
}) async {
  try {
    final at = DateTime.now().toUtc().toIso8601String();
    return await db.transaction((txn) async {
      final rows = await txn.query(
        'cashbox',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        return Err('الصندوق رقم #$id غير موجود.');
      }
      if ((rows.first['is_default'] as int? ?? 0) == 1) {
        return const Err(
          'هذا هو الصندوق الافتراضي — عيّن صندوقاً افتراضياً آخر '
          'قبل الأرشفة.',
        );
      }
      final active = await txn.rawQuery(
        'SELECT COUNT(*) AS n FROM cashbox WHERE is_archived = 0',
      );
      if ((active.first['n'] as int? ?? 0) <= 1) {
        return const Err('لا يمكن أرشفة آخر صندوق نشط في المنشأة.');
      }
      await txn.update(
        'cashbox',
        {'is_archived': 1, 'updated_at': at},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'cashbox_archive',
        'entity': 'cashbox',
        'entity_id': id,
        'details': 'name=${rows.first['name']}',
        'at': at,
      });
      return const Ok<void, String>(null);
    });
  } on DatabaseException catch (e) {
    return Err(describeCashDbError(e, 'أرشفة الصندوق'));
  }
}

/// إلغاء أرشفة صندوق.
Future<Result<void, String>> unarchiveCashbox(Database db, int id) async {
  final updated = await db.update(
    'cashbox',
    {'is_archived': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
    where: 'id = ?',
    whereArgs: [id],
  );
  if (updated == 0) {
    return Err('الصندوق رقم #$id غير موجود.');
  }
  return const Ok<void, String>(null);
}

/// تعيين الصندوق الافتراضي (FR-04-01) — ذرّياً (واحد فقط افتراضي).
Future<Result<void, String>> setDefaultCashbox(
  Database db,
  int id, {
  int? userId,
}) async {
  try {
    final at = DateTime.now().toUtc().toIso8601String();
    return await db.transaction((txn) async {
      final rows = await txn.query(
        'cashbox',
        columns: ['name'],
        where: 'id = ? AND is_archived = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Err('الصندوق غير موجود أو مؤرشف — أزل الأرشفة أولاً.');
      }
      await txn.update(
        'cashbox',
        {'is_default': 0},
        where: 'is_default = 1 AND id <> ?',
        whereArgs: [id],
      );
      await txn.update(
        'cashbox',
        {'is_default': 1, 'updated_at': at},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'cashbox_set_default',
        'entity': 'cashbox',
        'entity_id': id,
        'details': 'name=${rows.first['name']}',
        'at': at,
      });
      return const Ok<void, String>(null);
    });
  } on DatabaseException catch (e) {
    return Err(describeCashDbError(e, 'تعيين الصندوق الافتراضي'));
  }
}

// ─────────────────────────────────────────────────────────────────────
// المديونيات المفتوحة للتخصيص FIFO (قاعدة 5.4-6 / FR-04-03)
