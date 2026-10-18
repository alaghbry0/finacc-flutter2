/// عمليات كتابة الأصناف (إنشاء/تعديل/أرشفة) — جزء من تقسيم R19-D3d
/// لمستودع الأصناف: منقولة حرفياً من item_repository.dart (الواجهة
/// العامة والسلوك ثابتان — المستودع يفوِّض بتواقيعه نفسها).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/result.dart';
import '../../../domain/models/item.dart';
import '../../../domain/services/barcode_ean13.dart';

/// **إنشاء صنف ذرّياً**: صف `product` + أسعار `product_price` +
/// (لغير الخدمي مع كمية افتتاحية) `stock_level` وحركة `opening`
/// + (للمتتبع للدفعات) صف `batch` افتتاحي بصلاحية بعيدة
/// + قيد تدقيق `item_create` — كلها في معاملة واحدة.
///
/// - الباركود الفارغ يولّد EAN-13 داخلياً (حتى 5 محاولات عند التصادم).
/// - الصنف الخدمي لا يُنشئ أي صفوف مخزون مهما كانت [ItemDraft.openingQty].
/// - **المتتبع للدفعات**: الرصيد الافتتاحي يُدفَّع أيضاً دفعةً
///   (`expiry_date = 9999-12-31`) — بدونها يبقى الكتاب (stock_level)
///   حاملاً كمية تعجز FEFO عن تخصيصها فيُرفض البيع بمتاح = 0
///   رغم رصيد كتابي كبير (خلل الموجة 4 — مُصلح هنا وهجرةً v2).
Future<Result<int, String>> createItemFlow(
  Database db,
  Ean13Generator generator,
  ItemDraft draft, {
  required int warehouseId,
  required int userId,
  DateTime? now,
}) async {
  final validation = _validateDraft(draft);
  if (validation != null) return Err(validation);
  final at = now ?? DateTime.now();
  final iso = at.toUtc().toIso8601String();
  try {
    return await db.transaction((txn) async {
      var barcode = draft.barcode?.trim() ?? '';
      if (barcode.isEmpty) {
        final generated = await _generateUniqueBarcode(txn, generator);
        if (generated == null) {
          return const Err<int, String>(
            'تعذر توليد باركود فريد بعد 5 محاولات — أعد المحاولة',
          );
        }
        barcode = generated;
      }

      final productId = await txn.insert('product', {
        'name': draft.name.trim(),
        'barcode': barcode,
        'category_id': draft.categoryId,
        'unit_id': draft.unitId,
        'cost_price': draft.costPrice,
        'min_stock': draft.minStock,
        'is_service': draft.isService ? 1 : 0,
        'track_batches': draft.trackBatches ? 1 : 0,
        'notes': draft.notes,
        'created_at': iso,
        'updated_at': iso,
        'created_by': userId,
      });

      for (final price in draft.prices) {
        await txn.insert('product_price', {
          'product_id': productId,
          'currency_id': price.currencyId,
          'price': price.price,
          'price_level': price.priceLevel,
          'margin_percent': price.marginPercent,
          'updated_at': iso,
        });
      }

      if (!draft.isService && draft.openingQty > 0) {
        await txn.insert('stock_level', {
          'product_id': productId,
          'warehouse_id': warehouseId,
          'qty': draft.openingQty,
        });
        await txn.insert('stock_movement', {
          'product_id': productId,
          'warehouse_id': warehouseId,
          'movement_type': 'opening',
          'qty': draft.openingQty,
          'unit_cost': draft.costPrice,
          'ref_type': 'opening',
          'moved_at': iso,
          'notes': 'رصيد افتتاحي',
          'created_at': iso,
          'created_by': userId,
        });
        if (draft.trackBatches) {
          // الدفتر (stock_level) وحده لا يكفي للمتتبع: توافر البيع
          // يُحسب من دفعات FEFO النشطة — فنسجّل الرصيد الافتتاحي دفعةً
          // بصلاحية بعيدة (تُستهلك أخيراً ولا تمنع البيع أبداً).
          await txn.insert('batch', {
            'product_id': productId,
            'warehouse_id': warehouseId,
            'batch_number': 'افتتاحي-$productId',
            'expiry_date': '9999-12-31',
            'cost_price': draft.costPrice,
            'qty': draft.openingQty,
            'created_at': iso,
            'updated_at': iso,
          });
        }
      }

      await _audit(
        txn,
        action: 'item_create',
        entityId: productId,
        details: 'name=${draft.name.trim()} barcode=$barcode',
        userId: userId,
        at: at,
      );
      return Ok<int, String>(productId);
    });
  } on DatabaseException catch (e) {
    return Err(_describeDbError(e));
  }
}

/// **تعديل صنف ذرّياً**: استبدال كامل لحقول الصنف + الأسعار (حذف ثم
/// إدراج داخل المعاملة) + قيد تدقيق `item_update`.
///
/// - [ItemDraft.openingQty] **يُتجاهل** هنا — المخزون يُعدَّل بحركات
///   (شراء/بيع/جرد) لا بتعديل مباشر.
/// - الباركود الفارغ في المسودة **يمسح** باركود الصنف (استبدال كامل؛
///   لا توليد تلقائي عند التعديل).
Future<Result<Item, String>> updateItemFlow(
  Database db,
  int id,
  ItemDraft draft, {
  required int userId,
  DateTime? now,
}) async {
  final validation = _validateDraft(draft);
  if (validation != null) return Err(validation);
  final at = now ?? DateTime.now();
  final iso = at.toUtc().toIso8601String();
  try {
    return await db.transaction((txn) async {
      final affected = await txn.update(
        'product',
        {
          'name': draft.name.trim(),
          'barcode': draft.barcode?.trim(),
          'category_id': draft.categoryId,
          'unit_id': draft.unitId,
          'cost_price': draft.costPrice,
          'min_stock': draft.minStock,
          'is_service': draft.isService ? 1 : 0,
          'track_batches': draft.trackBatches ? 1 : 0,
          'notes': draft.notes,
          'updated_at': iso,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (affected == 0) {
        return const Err<Item, String>('الصنف غير موجود');
      }

      // استبدال الأسعار كاملة — نفس المعاملة (الكل أو لا شيء).
      await txn.delete(
        'product_price',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      for (final price in draft.prices) {
        await txn.insert('product_price', {
          'product_id': id,
          'currency_id': price.currencyId,
          'price': price.price,
          'price_level': price.priceLevel,
          'margin_percent': price.marginPercent,
          'updated_at': iso,
        });
      }

      await _audit(
        txn,
        action: 'item_update',
        entityId: id,
        details: 'name=${draft.name.trim()}',
        userId: userId,
        at: at,
      );

      final fresh = await txn.query(
        'product',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return Ok<Item, String>(Item.fromRow(fresh.first));
    });
  } on DatabaseException catch (e) {
    return Err(_describeDbError(e));
  }
}

/// **أرشفة صنف** (FR-01-15: لا حذف — الأرشفة تُخفي الصنف من البحث
/// والبيع مع بقاء التاريخ الكامل) + قيد تدقيق `item_archive`.
Future<Result<void, String>> archiveItemFlow(
  Database db,
  int id, {
  required int userId,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  try {
    return await db.transaction((txn) async {
      final rows = await txn.query(
        'product',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Err<void, String>('الصنف غير موجود');
      }
      await txn.update(
        'product',
        {'is_archived': 1, 'updated_at': at.toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _audit(
        txn,
        action: 'item_archive',
        entityId: id,
        details: 'name=${rows.first['name']}',
        userId: userId,
        at: at,
      );
      return const Ok<void, String>(null);
    });
  } on DatabaseException catch (e) {
    return Err(_describeDbError(e));
  }
}

// ─────────────────────────────────────────────────────────────────────
// مساعدات خاصة
// ─────────────────────────────────────────────────────────────────────

/// يتحقق من مسودة الصنف ويعيد رسالة الخطأ العربية أو null.
String? _validateDraft(ItemDraft draft) {
  if (draft.name.trim().isEmpty) return 'اسم الصنف مطلوب';
  if (draft.costPrice < 0) return 'سعر التكلفة لا يمكن أن يكون سالباً';
  if (draft.minStock < 0) return 'حد إعادة الطلب لا يمكن أن يكون سالباً';
  if (draft.openingQty < 0) return 'الكمية الافتتاحية لا يمكن أن تكون سالبة';
  final seen = <String>{};
  for (final price in draft.prices) {
    if (price.price < 0) return 'سعر البيع لا يمكن أن يكون سالباً';
    if (!seen.add('${price.currencyId}:${price.priceLevel}')) {
      return 'سعر مكرر لنفس العملة والمستوى';
    }
  }
  return null;
}

/// يولّد باركوداً داخلياً فريداً — حتى 5 محاولات عند التصادم (FR-01-02).
Future<String?> _generateUniqueBarcode(
  DatabaseExecutor txn,
  Ean13Generator generator,
) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    final candidate = generator.generate();
    final clash = await txn.rawQuery(
      'SELECT 1 FROM product WHERE barcode = ? LIMIT 1',
      [candidate],
    );
    if (clash.isEmpty) return candidate;
  }
  return null;
}

/// قيد تدقيق داخل المعاملة (نمط user_repository — الإضافة فقط).
Future<void> _audit(
  DatabaseExecutor txn, {
  required String action,
  int? entityId,
  required String details,
  required int userId,
  required DateTime at,
}) async {
  await txn.insert('audit_log', {
    'user_id': userId,
    'action': action,
    'entity': 'product',
    'entity_id': entityId,
    'details': details,
    'at': at.toUtc().toIso8601String(),
  });
}

/// يصوغ خطأ قاعدة البيانات بكلمات المستخدم (نمط §6.3 دون رمي).
String _describeDbError(DatabaseException e) {
  if (e.isUniqueConstraintError()) {
    final text = e.toString();
    if (text.contains('barcode')) {
      return 'الباركود مستخدم مسبقاً لصنف آخر';
    }
    if (text.contains('product_price')) {
      return 'سعر مكرر لنفس العملة والمستوى';
    }
    return 'قيمة مكررة تخالف قيد التفرد في القاعدة';
  }
  return 'تعذر حفظ الصنف في القاعدة: $e';
}
