/// جزء من تقسيم R18-D3a لمستودع النقدية — مستخرج حرفياً من
/// cash_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/dates.dart';
import '../../../domain/models/cash.dart';
import 'cash_helpers.dart';

// ─────────────────────────────────────────────────────────────────────

/// سجل حركات الصندوق بمرشحات (صندوق/نوع/فترة/بحث نصي في الوصف
/// والرقم واسم الطرف) — الأحدث أولاً.
Future<List<CashMovementRow>> cashJournal(
  Database db, {
  int? cashboxId,
  String? txType,
  DateTime? from,
  DateTime? to,
  String? search,
  int limit = 300,
}) async {
  final where = <String>[
    if (cashboxId != null) 't.cashbox_id = ?',
    if (txType != null) 't.tx_type = ?',
    if (from != null) 'date(t.tx_date) >= ?',
    if (to != null) 'date(t.tx_date) <= ?',
    if ((search ?? '').trim().isNotEmpty)
      '(t.description LIKE ? OR t.voucher_no LIKE ? OR c.name LIKE ? '
          'OR s.name LIKE ? OR ec.name LIKE ?)',
  ].join(' AND ');
  final like = '%${(search ?? '').trim()}%';
  final args = <Object?>[
    ?cashboxId,
    ?txType,
    if (from != null) dateOnly(from),
    if (to != null) dateOnly(to),
    if ((search ?? '').trim().isNotEmpty) ...[like, like, like, like, like],
  ];
  final rows = await db.rawQuery(
    '''
    SELECT t.*, cb.name AS cashbox_name,
           cu.code AS currency_code,
           tb.name AS to_cashbox_name,
           ec.name AS expense_category_name,
           c.name AS customer_name, s.name AS supplier_name
    FROM cash_tx t
    JOIN cashbox cb ON cb.id = t.cashbox_id
    JOIN currency cu ON cu.id = t.currency_id
    LEFT JOIN cashbox tb ON tb.id = t.to_cashbox_id
    LEFT JOIN expense_category ec ON ec.id = t.expense_category_id
    LEFT JOIN customer c ON c.id = t.customer_id
    LEFT JOIN supplier s ON s.id = t.supplier_id
    ${where.isEmpty ? '' : 'WHERE $where'}
    ORDER BY t.tx_date DESC, t.id DESC
    LIMIT ?
  ''',
    <Object?>[...args, limit],
  );
  return [for (final row in rows) movementFromRow(row)];
}

/// تفاصيل حركة واحدة + تخصيصاتها — `null` إن لم توجد.
Future<CashMovementDetail?> cashMovementDetail(Database db, int id) async {
  final rows = await db.rawQuery(
    '''
    SELECT t.*, cb.name AS cashbox_name,
           cu.code AS currency_code,
           tb.name AS to_cashbox_name,
           ec.name AS expense_category_name,
           c.name AS customer_name, s.name AS supplier_name
    FROM cash_tx t
    JOIN cashbox cb ON cb.id = t.cashbox_id
    JOIN currency cu ON cu.id = t.currency_id
    LEFT JOIN cashbox tb ON tb.id = t.to_cashbox_id
    LEFT JOIN expense_category ec ON ec.id = t.expense_category_id
    LEFT JOIN customer c ON c.id = t.customer_id
    LEFT JOIN supplier s ON s.id = t.supplier_id
    WHERE t.id = ? LIMIT 1
  ''',
    <Object?>[id],
  );
  if (rows.isEmpty) return null;
  final allocRows = await db.rawQuery(
    '''
    SELECT pa.invoice_id, pa.allocated_amount, i.invoice_no, i.doc_type,
           i.issued_at, cu.code AS currency_code
    FROM payment_allocation pa
    JOIN invoice i ON i.id = pa.invoice_id
    JOIN currency cu ON cu.id = i.currency_id
    WHERE pa.cash_tx_id = ?
    ORDER BY i.issued_at ASC
  ''',
    <Object?>[id],
  );
  return CashMovementDetail(
    movement: movementFromRow(rows.first),
    allocations: [
      for (final row in allocRows)
        CashAllocationLine(
          invoiceId: row['invoice_id'] as int,
          invoiceNo: row['invoice_no'] as String,
          invoiceTypeCode: row['doc_type'] as String,
          issuedAt: DateTime.parse(row['issued_at'] as String),
          allocatedAmount: (row['allocated_amount'] as num?)?.toDouble() ?? 0,
          currencyCode: (row['currency_code'] as String?) ?? '',
        ),
    ],
  );
}

/// صافي النقدية لكل عملة (بطاقة المحور) — تجميع دلاء كل الصناديق
/// بعملة كل دلو (لا خلط عملات — الأمانة المحاسبية 5.4-7).
Future<List<CashNetLine>> cashNetByCurrency(Database db) async {
  final rows = await db.rawQuery('''
    WITH legs AS (
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
      SELECT t.cashbox_id, t.currency_id, -t.amount
      FROM cash_tx t
      WHERE t.is_voided = 0 AND t.reversal_of IS NULL
        AND t.tx_type IN ('box_transfer','bank_deposit','bank_withdraw')
      UNION ALL
      SELECT t.to_cashbox_id, tc.currency_id,
             t.amount * COALESCE(t.settlement_rate, 1)
      FROM cash_tx t
      JOIN cashbox tc ON tc.id = t.to_cashbox_id
      WHERE t.is_voided = 0 AND t.reversal_of IS NULL
        AND t.tx_type IN ('box_transfer','bank_deposit','bank_withdraw')
        AND t.to_cashbox_id IS NOT NULL
    )
    SELECT l.cur AS currency_id, cu.code AS currency_code,
           cu.is_base, SUM(l.amt) AS amt
    FROM legs l JOIN currency cu ON cu.id = l.cur
    GROUP BY l.cur, cu.code, cu.is_base
    ORDER BY cu.is_base DESC, cu.code ASC
  ''');
  return [
    for (final row in rows)
      CashNetLine(
        currencyId: row['currency_id'] as int,
        currencyCode: (row['currency_code'] as String?) ?? '',
        amount: (row['amt'] as num?)?.toDouble() ?? 0,
        isBase: (row['is_base'] as int? ?? 0) == 1,
      ),
  ];
}

// ─────────────────────────────────────────────────────────────────────
// مساعدات داخلية
