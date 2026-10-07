/// مستودع أسعار الصرف — جدول `exchange_rate` (FR-08-03 / 08-05 / 08-09).
///
/// الإدخال اليدوي اليومي هو المصدر المعتمد في V1: لكل عملة (غير
/// الأساسية) سعر واحد على الأكثر في اليوم — `UNIQUE(currency_id,
/// rate_date)` — والإدخال المتكرر لنفس اليوم **تحديث** للسعر نفسه لا
/// صف جديد. العملة الأساسية سعرها 1 دائماً ولا يُدخل لها سعر.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/exchange_rate.dart';

class ExchangeRateRepository {
  ExchangeRateRepository(this._db);

  final Database _db;

  // ── الكتابة (FR-08-03) ───────────────────────────────────────────

  /// يضبط سعر [rate] للعملة [currencyId] في يوم [date] (UPSERT على
  /// `UNIQUE(currency_id, rate_date)` — التحديث لا يُنشئ تكراراً ولا
  /// يمسّ `created_at` الأصلي)، ويسجّل تدقيق `fx_rate_set` بتفاصيل
  /// `currency=CODE date=YYYY-MM-DD rate=...`.
  ///
  /// الرفض: سعر ≤ 0 أو غير عددي؛ العملة غير الموجودة؛ **العملة
  /// الأساسية** (سعرها 1 دائماً). الكتابة والتدقيق ذرّيتان.
  Future<Result<void, String>> setRate({
    required int currencyId,
    required DateTime date,
    required double rate,
    required int userId,
    DateTime? now,
  }) async {
    if (rate.isNaN || rate.isInfinite || rate <= 0) {
      return const Err<void, String>(
        'سعر الصرف يجب أن يكون رقماً أكبر من صفر.',
      );
    }
    final at = now ?? DateTime.now();
    final iso = at.toUtc().toIso8601String();
    final dateStr = _dateOnly(date);

    return _db.transaction<Result<void, String>>((txn) async {
      final currencyRows = await txn.query(
        'currency',
        where: 'id = ?',
        whereArgs: [currencyId],
        limit: 1,
      );
      if (currencyRows.isEmpty) {
        return Err<void, String>('العملة رقم #$currencyId غير موجودة.');
      }
      if ((currencyRows.first['is_base'] as int? ?? 0) == 1) {
        return const Err<void, String>('لا يُدخل سعر للعملة الأساسية.');
      }
      final code = currencyRows.first['code'] as String;
      await txn.rawInsert(
        'INSERT INTO exchange_rate(currency_id, rate_date, rate, source, '
        'created_at, created_by) VALUES(?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(currency_id, rate_date) DO UPDATE SET '
        'rate = excluded.rate, source = excluded.source',
        <Object>[currencyId, dateStr, rate, 'manual', iso, userId],
      );
      // معرّف الصف (إنشاءً أو تحديثاً) — لسجل التدقيق.
      final idRows = await txn.rawQuery(
        'SELECT id FROM exchange_rate WHERE currency_id = ? AND rate_date = ?',
        <Object>[currencyId, dateStr],
      );
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'fx_rate_set',
        'entity': 'exchange_rate',
        'entity_id': idRows.isEmpty ? null : idRows.first['id'] as int,
        'details': 'currency=$code date=$dateStr rate=$rate',
        'at': iso,
      });
      return const Ok<void, String>(null);
    });
  }

  // ── القراءة (FR-08-05 / 08-09) ───────────────────────────────────

  /// سعر اليوم نفسه بالضبط — أو `null` إن لم يُدخل (لا يُخمَّن هنا).
  Future<double?> rateFor(int currencyId, DateTime date) async {
    final rows = await _db.query(
      'exchange_rate',
      columns: ['rate'],
      where: 'currency_id = ? AND rate_date = ?',
      whereArgs: [currencyId, _dateOnly(date)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['rate'] as num?)?.toDouble();
  }

  /// أحدث سعر بتاريخ ≤ [date] (شاملاً اليوم نفسه) — للعرض والسعر
  /// الاحتياطي حسب إعداد `fx.fallback` — أو `null` إن لا تاريخ أقدم.
  Future<double?> latestBefore(int currencyId, DateTime date) async {
    final rows = await _db.rawQuery(
      'SELECT rate FROM exchange_rate '
      'WHERE currency_id = ? AND rate_date <= ? '
      'ORDER BY rate_date DESC LIMIT 1',
      <Object>[currencyId, _dateOnly(date)],
    );
    if (rows.isEmpty) return null;
    return (rows.first['rate'] as num?)?.toDouble();
  }

  /// سجل الأسعار تنازلياً (الأحدث أولاً) — لشاشة سجل الأسعار.
  Future<List<ExchangeRateEntry>> history(
    int currencyId, {
    int limit = 60,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT id, currency_id, rate_date, rate, source FROM exchange_rate '
      'WHERE currency_id = ? ORDER BY rate_date DESC LIMIT ?',
      <Object>[currencyId, limit],
    );
    return rows.map(ExchangeRateEntry.fromRow).toList();
  }

  /// أسعار اليوم للعملات النشطة كلها — العملة بلا سعر اليوم **غائبة
  /// من الخريطة** (تنبيه الإدخال اليومي FR-08-09 يقرأ الغياب).
  Future<Map<int, double>> todayRates(DateTime today) async {
    final rows = await _db.rawQuery(
      'SELECT er.currency_id AS cid, er.rate AS r '
      'FROM exchange_rate er '
      'JOIN currency c ON c.id = er.currency_id AND c.is_active = 1 '
      'WHERE er.rate_date = ?',
      <Object>[_dateOnly(today)],
    );
    return <int, double>{
      for (final row in rows)
        row['cid'] as int: (row['r'] as num?)?.toDouble() ?? 0,
    };
  }

  /// هل أُدخل سعر للعملة في هذا اليوم بالضبط؟
  Future<bool> hasRateFor(int currencyId, DateTime date) async {
    final rows = await _db.rawQuery(
      'SELECT EXISTS(SELECT 1 FROM exchange_rate '
      'WHERE currency_id = ? AND rate_date = ?) AS ok',
      <Object>[currencyId, _dateOnly(date)],
    );
    return ((rows.first['ok'] as int?) ?? 0) == 1;
  }
}

/// `YYYY-MM-DD` بتاريخ التقويم المحلي ليوم العمل.
String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
