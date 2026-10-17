/// جزء من تقسيم R18-D3a لمستودع النقدية — مستخرج حرفياً من
/// cash_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/result.dart';
import '../../../domain/models/cash.dart';
import 'cash_helpers.dart';

// ─────────────────────────────────────────────────────────────────────

/// بذر **idempotent** لفئة «رواتب» (بديل وحدة الموظفين المؤجلة —
/// SRS §9) — يُستدعى عند إقلاع الجلسة؛ التنفيذ شرطي فلا يكرر أبداً.
Future<void> seedCashRepository(Database db) async {
  final now = DateTime.now().toUtc().toIso8601String();
  await db.rawInsert(
    "INSERT INTO expense_category(name, is_archived, created_at, updated_at) "
    "SELECT 'رواتب', 0, ?, ? WHERE NOT EXISTS "
    "(SELECT 1 FROM expense_category WHERE name = 'رواتب')",
    <Object>[now, now],
  );
}

/// فئات المصاريف (FR-04-05) — «رواتب» أولاً ومحمية من الأرشفة.
Future<List<ExpenseCategoryInfo>> listExpenseCategories(
  Database db, {
  bool includeArchived = false,
}) async {
  final rows = await db.query(
    'expense_category',
    where: includeArchived ? null : 'is_archived = 0',
    orderBy: "CASE WHEN name = 'رواتب' THEN 0 ELSE 1 END, name COLLATE NOCASE",
  );
  return [
    for (final row in rows)
      ExpenseCategoryInfo.fromRow({
        ...row,
        'is_protected': (row['name'] as String) == 'رواتب' ? 1 : 0,
      }),
  ];
}

/// إضافة فئة — الاسم المكرر المؤرشف يُوقظ بدل الرفض (إضافة idempotent).
Future<Result<ExpenseCategoryInfo, String>> addExpenseCategory(
  Database db,
  String name,
) async {
  final clean = name.trim();
  if (clean.isEmpty) {
    return const Err('اسم فئة المصروف مطلوب — أدخل الاسم ثم احفظ.');
  }
  try {
    final at = DateTime.now().toUtc().toIso8601String();
    return await db.transaction((txn) async {
      final existing = await txn.query(
        'expense_category',
        where: 'name = ? COLLATE NOCASE',
        whereArgs: [clean],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final row = existing.first;
        if ((row['is_archived'] as int? ?? 0) == 1) {
          await txn.update(
            'expense_category',
            {'is_archived': 0, 'updated_at': at},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          return Ok<ExpenseCategoryInfo, String>(
            ExpenseCategoryInfo.fromRow({
              ...row,
              'is_archived': 0,
              'is_protected': 0,
            }),
          );
        }
        return Err('فئة «$clean» موجودة مسبقاً — اختر اسماً آخر أو استخدمها.');
      }
      final id = await txn.insert('expense_category', {
        'name': clean,
        'is_archived': 0,
        'created_at': at,
        'updated_at': at,
      });
      return Ok<ExpenseCategoryInfo, String>(
        ExpenseCategoryInfo(
          id: id,
          name: clean,
          isArchived: false,
          isProtected: false,
        ),
      );
    });
  } on DatabaseException catch (e) {
    return Err(describeCashDbError(e, 'حفظ الفئة'));
  }
}

/// إعادة تسمية فئة.
Future<Result<ExpenseCategoryInfo, String>> renameExpenseCategory(
  Database db,

  int id,
  String name,
) async {
  final clean = name.trim();
  if (clean.isEmpty) {
    return const Err('اسم فئة المصروف مطلوب — أدخل الاسم ثم احفظ.');
  }
  try {
    final rows = await db.query(
      'expense_category',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return Err('الفئة رقم #$id غير موجودة.');
    }
    final dup = await db.query(
      'expense_category',
      where: 'name = ? COLLATE NOCASE AND id <> ?',
      whereArgs: [clean, id],
      limit: 1,
    );
    if (dup.isNotEmpty) {
      return Err('فئة «$clean» موجودة مسبقاً — اختر اسماً آخر.');
    }
    await db.update(
      'expense_category',
      {'name': clean, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    return Ok<ExpenseCategoryInfo, String>(
      ExpenseCategoryInfo.fromRow({
        ...rows.first,
        'name': clean,
        'is_protected': clean == 'رواتب' ? 1 : 0,
      }),
    );
  } on DatabaseException catch (e) {
    return Err(describeCashDbError(e, 'تعديل الفئة'));
  }
}

/// أرشفة فئة — «رواتب» محمية (بديل V1 لوحدة الموظفين).
Future<Result<void, String>> archiveExpenseCategory(Database db, int id) async {
  final rows = await db.query(
    'expense_category',
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  if (rows.isEmpty) {
    return Err('الفئة رقم #$id غير موجودة.');
  }
  if ((rows.first['name'] as String) == 'رواتب') {
    return const Err(
      'فئة «رواتب» افتراضية نظامية — لا تُؤرشف (بديل الرواتب في V1).',
    );
  }
  await db.update(
    'expense_category',
    {'is_archived': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
    where: 'id = ?',
    whereArgs: [id],
  );
  return const Ok<void, String>(null);
}

/// إلغاء أرشفة فئة.
Future<Result<void, String>> unarchiveExpenseCategory(
  Database db,
  int id,
) async {
  await db.update(
    'expense_category',
    {'is_archived': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
    where: 'id = ?',
    whereArgs: [id],
  );
  return const Ok<void, String>(null);
}

// ─────────────────────────────────────────────────────────────────────
// الصناديق وأرصدتها الحية (FR-04-01/06/09)
