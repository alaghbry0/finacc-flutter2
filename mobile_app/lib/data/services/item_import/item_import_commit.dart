/// المرحلة 2 من الاستيراد — التنفيذ (AC-14) — جزء من تقسيم R20-D3a
/// لخدمة الاستيراد (نمط R19-D3d): منقول حرفياً من item_import_service.dart
/// (الواجهة العامة والسلوك ثابتان — الخدمة تفوِّض بتواقيعها نفسها).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/result.dart';
import '../../repositories/item_repository.dart';
import 'item_import_models.dart';

/// **المرحلة 2 — التنفيذ** (AC-14): إدراج الصفوف الصالحة فقط.
///
/// - إن وُجدت صفوف فاشلة ولم يُقرّ المستخدم ([confirmed] = false)
///   فالعملية مرفوضة برسالة الإقرار — **لا يُدرج أي صف**.
/// - الفئات/الوحدات الجديدة تُنشأ أولاً، ثم كل صف عبر [ItemRepository]
///   .createItem (ذرّي لكل صف) — الصف كلِّي أو لا شيء دائماً.
/// - قيد تدقيق `items_import` واحد بتفاصيل `ok=N failed=M`.
Future<Result<ItemImportCommitResult, String>> commitValidImport(
  Database db,
  ItemImportPreview preview, {
  required int warehouseId,
  required int userId,
  required bool confirmed,
  DateTime? now,
}) async {
  if (!confirmed && preview.failedRows.isNotEmpty) {
    return const Err('يوجد صفوف فاشلة — الإقرار مطلوب');
  }

  final items = ItemRepository(db);
  final at = now ?? DateTime.now();

  // 1) إنشاء الفئات والوحدات الناقصة أولاً (مع تحمّل سباق غير محتمل
  //    باستبعاد الفشل — القيمة الموجودة تُعاد استخدامها).
  final categoryIdByName = <String, int>{};
  var createdCategories = 0;
  for (final name in preview.suggestedNewCategories) {
    final result = await items.createCategory(name, now: at);
    final id = switch (result) {
      final Ok<int, String> ok => ok.value,
      final Err<int, String> _ => await _existingId(db, 'category', name),
    };
    if (id != null) {
      categoryIdByName[name] = id;
      createdCategories++;
    }
  }

  final unitIdByName = <String, int>{};
  var createdUnits = 0;
  for (final name in preview.suggestedNewUnits) {
    final result = await items.createUnit(name, now: at);
    final id = switch (result) {
      final Ok<int, String> ok => ok.value,
      final Err<int, String> _ => await _existingId(db, 'unit', name),
    };
    if (id != null) {
      unitIdByName[name] = id;
      createdUnits++;
    }
  }

  // 2) إدراج كل صف صالح (كل صف عبر createItem الذرّية — لا إدراج جزئي).
  final commitFailures = <ImportRowFailure>[];
  var inserted = 0;
  for (final row in preview.validRows) {
    final categoryId = row.categoryName == null
        ? null
        : categoryIdByName[row.categoryName] ??
              await _existingId(db, 'category', row.categoryName!);
    final unitId = row.unitName == null
        ? null
        : unitIdByName[row.unitName] ??
              await _existingId(db, 'unit', row.unitName!);
    final result = await items.createItem(
      row.draft,
      warehouseId: warehouseId,
      userId: userId,
      now: at,
    );
    switch (result) {
      case final Ok<int, String> ok:
        // إرفاق الفئة/الوحدة بالصنف بعد إنشائه (تحديث مباشر بلا مسودة
        // كاملة — الحقول الاختيارية فقط).
        if (categoryId != null || unitId != null) {
          await db.update(
            'product',
            {
              'category_id': ?categoryId,
              'unit_id': ?unitId,
              'updated_at': at.toUtc().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [ok.value],
          );
        }
        inserted++;
      case final Err<int, String> err:
        commitFailures.add(
          ImportRowFailure(rowNumber: row.rowNumber, reason: err.error),
        );
    }
  }

  // 3) قيد تدقيق واحد لعملية الاستيراد (نمط user_repository).
  final failedTotal = preview.failedRows.length + commitFailures.length;
  await db.insert('audit_log', {
    'user_id': userId,
    'action': 'items_import',
    'entity': 'product',
    'entity_id': null,
    'details': 'ok=$inserted failed=$failedTotal',
    'at': at.toUtc().toIso8601String(),
  });

  return Ok(
    ItemImportCommitResult(
      inserted: inserted,
      failures: [...preview.failedRows, ...commitFailures],
      createdCategories: createdCategories,
      createdUnits: createdUnits,
      totalRows: preview.totalRows,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────
// مساعدات خاصة
// ─────────────────────────────────────────────────────────────────────

/// معرّف اسم موجود في جدول مرجعي (أو null).
Future<int?> _existingId(Database db, String table, String name) async {
  final rows = await db.rawQuery(
    'SELECT id FROM $table WHERE name = ? LIMIT 1',
    [name],
  );
  if (rows.isEmpty) return null;
  return rows.first['id'] as int;
}
