/// عمليات فئات الأصناف ووحدات القياس (FR-01-05 / FR-13-06) — جزء من
/// تقسيم R19-D3d لمستودع الأصناف: منقولة حرفياً من item_repository.dart
/// (الواجهة العامة والسلوك ثابتان — المستودع يفوِّض بتواقيعه نفسها).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/result.dart';
import '../../../domain/models/item.dart';

/// فئات الأصناف (المستوى الأول والثاني معاً — الترتيب بالاسم).
Future<List<ItemCategory>> listItemCategories(Database db) async {
  final rows = await db.query(
    'category',
    columns: ['id', 'name', 'parent_id'],
    where: 'is_archived = 0',
    orderBy: 'name ASC',
  );
  return rows.map(ItemCategory.fromRow).toList();
}

/// ينشئ فئة — شجرة بمستويين حصراً (FR-01-05): الجذر ثم الأبناء،
/// ولا يُقبل ابن لابن. الاسم فريد (فحص مسبق — المخطط لا يفرضه).
Future<Result<int, String>> createItemCategory(
  Database db,
  String name, {
  int? parentId,
  DateTime? now,
}) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return const Err('اسم الفئة مطلوب');
  final at = (now ?? DateTime.now()).toUtc().toIso8601String();

  if (parentId != null) {
    final parentRows = await db.rawQuery(
      'SELECT parent_id FROM category WHERE id = ?',
      [parentId],
    );
    if (parentRows.isEmpty) return const Err('الفئة الأصل غير موجودة');
    if (parentRows.first['parent_id'] != null) {
      return const Err('لا يمكن إنشاء أكثر من مستويين في شجرة الفئات');
    }
  }

  final duplicate = await db.rawQuery(
    'SELECT 1 FROM category WHERE name = ? LIMIT 1',
    [trimmed],
  );
  if (duplicate.isNotEmpty) return const Err('اسم الفئة مستخدم مسبقاً');

  final id = await db.insert('category', {
    'name': trimmed,
    'parent_id': parentId,
    'created_at': at,
    'updated_at': at,
  });
  return Ok(id);
}

/// وحدات القياس (قطعة/كرتون/… — مرتبة بالاسم).
Future<List<ItemUnit>> listItemUnits(Database db) async {
  final rows = await db.query(
    'unit',
    columns: ['id', 'name', 'factor', 'base_unit_id'],
    where: 'is_archived = 0',
    orderBy: 'name ASC',
  );
  return rows.map(ItemUnit.fromRow).toList();
}

/// ينشئ وحدة قياس — [factor] معامل التحويل إلى الوحدة الأساسية
/// (1 كرتون = 24 قطعة → factor = 24 — FR-13-06).
Future<Result<int, String>> createItemUnit(
  Database db,
  String name, {
  double factor = 1,
  DateTime? now,
}) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return const Err('اسم الوحدة مطلوب');
  if (factor <= 0) return const Err('معامل التحويل يجب أن يكون أكبر من صفر');
  final at = (now ?? DateTime.now()).toUtc().toIso8601String();

  final duplicate = await db.rawQuery(
    'SELECT 1 FROM unit WHERE name = ? LIMIT 1',
    [trimmed],
  );
  if (duplicate.isNotEmpty) return const Err('اسم الوحدة مستخدم مسبقاً');

  final id = await db.insert('unit', {
    'name': trimmed,
    'factor': factor,
    'created_at': at,
    'updated_at': at,
  });
  return Ok(id);
}
