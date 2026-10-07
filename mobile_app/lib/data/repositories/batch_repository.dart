/// مستودع الدفعات — جدول `batch` (§5.3) — المرحلة 2 (FR-01-10 / FR-09-15).
///
/// هذا المستودع **نقي** حول جدول الدفعات: لا يلمس `stock_level` ولا
/// `stock_movement` (محرك المشتريات/المبيعات في موجة لاحقة يدمج التخصيص
/// مع تحديث المخزون والتكاليف داخل معاملته الخاصة).
///
/// قاعدة FEFO الملزمة (AC-05): [allocateFefo] تعيد الحصص من الدفعات
/// الأقرب انتهاءً أولاً، تتخطى المنتهية (منع البيع من دفعة منتهية)،
/// وتكشف النقص بعلم `shorted` دون رفض — القرار بيد المستدعي.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/batch.dart';

/// مستودع الدفعات وتواريخ الصلاحية.
class BatchRepository {
  BatchRepository(this._db);

  final Database _db;

  /// دفعات الصنف النشطة (كمية > 0) مرتبة **FEFO** — الأقرب انتهاءً أولاً —
  /// مع أيام الصلاحية المحسوبة (سالب = منتهية).
  Future<List<BatchInfo>> batchesForProduct(
    int productId, {
    int? warehouseId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final conditions = [
      'product_id = ?',
      'qty > 0',
      'is_archived = 0',
      if (warehouseId != null) 'warehouse_id = ?',
    ];
    final rows = await _db.rawQuery(
      '''
      SELECT * FROM batch
      WHERE ${conditions.join(' AND ')}
      ORDER BY expiry_date ASC, id ASC
    ''',
      [productId, ?warehouseId],
    );
    return [for (final row in rows) BatchInfo.fromRow(row, asOf: at)];
  }

  /// ينشئ دفعة جديدة (كمية ومستودن ورقم دفعة وصلاحية وتكلفة).
  ///
  /// لا يعدّل المخزون — تسجيل الدفعة مستقل عن حركة الشراء التي ستمر
  /// لاحقاً عبر محرك المشتريات (هذا المستودع نقي بالتصميم).
  Future<Result<int, String>> createBatch({
    required int productId,
    required int warehouseId,
    required String batchNumber,
    required DateTime expiryDate,
    double costPrice = 0,
    required double qty,
    DateTime? now,
  }) async {
    if (batchNumber.trim().isEmpty) {
      return const Err('رقم الدفعة مطلوب');
    }
    if (qty <= 0) return const Err('كمية الدفعة يجب أن تكون أكبر من صفر');
    if (costPrice < 0) return const Err('تكلفة الدفعة لا يمكن أن تكون سالبة');
    final at = now ?? DateTime.now();
    final iso = at.toUtc().toIso8601String();
    final id = await _db.insert('batch', {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'batch_number': batchNumber.trim(),
      'expiry_date': _isoDate(expiryDate),
      'cost_price': costPrice,
      'qty': qty,
      'created_at': iso,
      'updated_at': iso,
    });
    return Ok(id);
  }

  /// **قلب FEFO** (FR-01-10 / AC-05): يوزّع [qty] على دفعات الصنف في
  /// المخزن المحدد بدءاً من الأقرب انتهاءً، متخطياً الدفعات المنتهية
  /// قبل [asOf] (افتراضياً الآن) إلا بـ [includeExpired].
  ///
  /// - النتيجة جزئية عند نقص المخزون: `shorted = true` و`remaining`
  ///   هو غير المغطى — **لا رفض هنا**؛ المستدعي (POS/المشتريات) يقرر.
  /// - يجب استدعاؤها داخل معاملة المستند (تمرير الـ [DatabaseExecutor]
  ///   نفسها) ثم تطبيق الحصص بـ [applyAllocation] ضمنها.
  Future<FefoResult> allocateFefo(
    DatabaseExecutor txn, {
    required int productId,
    required int warehouseId,
    required double qty,
    DateTime? asOf,
    bool includeExpired = false,
  }) async {
    final cutoff = _isoDate(asOf ?? DateTime.now());
    final conditions = [
      'product_id = ?',
      'warehouse_id = ?',
      'qty > 0',
      'is_archived = 0',
      if (!includeExpired) 'expiry_date >= ?', // منع البيع من دفعة منتهية.
    ];
    final rows = await txn.rawQuery(
      '''
      SELECT id, batch_number, expiry_date, cost_price, qty
      FROM batch
      WHERE ${conditions.join(' AND ')}
      ORDER BY expiry_date ASC, id ASC
    ''',
      [productId, warehouseId, if (!includeExpired) cutoff],
    );

    final allocations = <BatchAllocation>[];
    var remaining = qty;
    for (final row in rows) {
      if (remaining <= _epsilon) break;
      final available = (row['qty'] as num?)?.toDouble() ?? 0;
      if (available <= _epsilon) continue;
      final take = available < remaining ? available : remaining;
      allocations.add(
        BatchAllocation(
          batchId: row['id'] as int,
          batchNumber: row['batch_number'] as String,
          expiryDate: DateTime.parse(row['expiry_date'] as String),
          qty: take,
          costPrice: (row['cost_price'] as num?)?.toDouble() ?? 0,
        ),
      );
      remaining -= take;
    }
    final shorted = remaining > _epsilon;
    return FefoResult(
      allocations: allocations,
      shorted: shorted,
      remaining: shorted ? remaining : 0,
    );
  }

  /// يطبّق الحصص خصماً من كميات الدفعات داخل معاملة المستدعي —
  /// حارس السالب: `WHERE qty >= ?` فلا تنزل أي دفعة تحت الصفر،
  /// وأي دفعة لا تكفي ترمي [StateError] فتتراجع المعاملة كاملة.
  Future<void> applyAllocation(
    DatabaseExecutor txn,
    List<BatchAllocation> allocations, {
    DateTime? now,
  }) async {
    final iso = (now ?? DateTime.now()).toUtc().toIso8601String();
    for (final allocation in allocations) {
      if (allocation.qty <= _epsilon) continue;
      final affected = await txn.rawUpdate(
        'UPDATE batch SET qty = qty - ?, updated_at = ? '
        'WHERE id = ? AND qty >= ?',
        [allocation.qty, iso, allocation.batchId, allocation.qty],
      );
      if (affected == 0) {
        throw StateError(
          'الدفعة ${allocation.batchNumber} لا تكفي كميتها لخصم '
          '${allocation.qty} — رفض السالب ومنع تراجع الكميات دون قيد',
        );
      }
    }
  }

  /// **تنبيهات الصلاحية** (FR-09-15): الدفعات النشطة التي تنتهي خلال
  /// [withinDays] يوماً (المنتهية مشمولة — أشد إلحاحاً) مع اسم الصنف،
  /// مرتبة بالأقرب انتهاءً.
  Future<List<BatchExpiryAlert>> expiryAlerts({
    int withinDays = 30,
    int? warehouseId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final horizon = _isoDate(at.add(Duration(days: withinDays)));
    final conditions = [
      'b.qty > 0',
      'b.is_archived = 0',
      'b.expiry_date <= ?',
      if (warehouseId != null) 'b.warehouse_id = ?',
    ];
    final rows = await _db.rawQuery(
      '''
      SELECT b.id, b.product_id, b.warehouse_id, b.batch_number,
             b.expiry_date, b.qty, p.name AS product_name
      FROM batch b
      JOIN product p ON p.id = b.product_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY b.expiry_date ASC
    ''',
      [horizon, ?warehouseId],
    );
    return [
      for (final row in rows)
        BatchExpiryAlert(
          batchId: row['id'] as int,
          productId: row['product_id'] as int,
          productName: row['product_name'] as String,
          warehouseId: row['warehouse_id'] as int,
          batchNumber: row['batch_number'] as String,
          expiryDate: DateTime.parse(row['expiry_date'] as String),
          qty: (row['qty'] as num?)?.toDouble() ?? 0,
          daysToExpiry: DateTime.parse(row['expiry_date'] as String)
              .difference(_dateOnly(at))
              .inDays,
        ),
    ];
  }

  /// **سلالم الصلاحية** (لوحة FR-09-15): عدّادات الدفعات النشطة في
  /// سلالم منفصلة — منتهية / ≤30 / 31–60 / 61–90 يوماً — بصيغة
  /// `{'expired': n, '30': n, '60': n, '90': n}`.
  Future<Map<String, int>> expiryBuckets({
    int? warehouseId,
    DateTime? now,
  }) async {
    final alerts = await expiryAlerts(
      withinDays: 90,
      warehouseId: warehouseId,
      now: now,
    );
    var expired = 0, d30 = 0, d60 = 0, d90 = 0;
    for (final alert in alerts) {
      final days = alert.daysToExpiry;
      if (days < 0) {
        expired++;
      } else if (days <= 30) {
        d30++;
      } else if (days <= 60) {
        d60++;
      } else {
        d90++;
      }
    }
    return {'expired': expired, '30': d30, '60': d60, '90': d90};
  }
}

/// تفاوت عشري مقبول في مقارنات الكميات (NUMERIC(12,3) في القاعدة).
const double _epsilon = 0.0000001;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// تاريخ فقط بصيغة `YYYY-MM-DD` — صيغة تخزين `expiry_date` الموحدة
/// (مقارنات النصوص فيها مرتبة زمنياً بشكل صحيح).
String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
