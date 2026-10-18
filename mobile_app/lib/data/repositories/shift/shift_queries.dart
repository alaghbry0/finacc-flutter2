/// قراءات الوردية (الحالية/بالمعرّف/الأحدث/المعادلة الشاملة) — جزء من
/// تقسيم R20-D3a لمستودع الوردية (نمط R19-D3d): منقولة حرفياً من
/// shift_repository.dart (الواجهة العامة والسلوك ثابتان — المستودع
/// يفوِّض بتواقيعه نفسها).
///
/// ## قرارات معمارية موثقة (منقولة من رأس المستودع الأصلي بترقيمها
/// الجديد — الشيكات عند الأنواع والفرق عند التدفق):
/// 1. **تحويل العملة** يطابق حرفياً استعلام رصيد الصندوق في
///    `cash_repository.listBoxes` (رأس ملفها — إشارات ملحق و):
///    السند المفرد `settlement_rate IS NULL` → مبلغ بعملته، وإلا
///    `amount × settlement_rate` بعملة الصندوق؛ ساق المصدر للتحويل
///    بعملة المصدر؛ ساق الهدف `amount × COALESCE(settlement_rate, 1)`
///    بعملة الهدف. المعادلة تُحتسب **بدلو عملة الصندوق حصراً** (نفس
///    دلو `nativeBalance`) — الساقات التي تستقر بدلو أجنبي داخل
///    الصندوق خارج نطاق عدّ النقد بعملة الصندوق.
/// 2. **لا عمود `is_bank`/نوع في جدول `cashbox`** (المخطط لا يميّز
///    البنك) — فالساقات البنكية (`bank_deposit`/`bank_withdraw`) تُدمج
///    في `transfersIn`/`transfersOut` («البنك مجرد صندوق» — ملحق و)،
///    و`bankIn`/`bankOut` تبقى حقول نموذج بقيمة 0 مع توثيق الدمج.
/// 3. **دلاء التصنيف**:
///    - مبيعات نقدية = سند قبض مرتبط بفاتورة **بيع** وقت الإصدار
///      (`ref_type='invoice'` + `ref_id` لفاتورة `doc_type='sale'` +
///      `customer_id IS NULL` — القرار 2 في `sale_repository`).
///    - تحصيلات = بقية سندات القبض (سند FIFO المرقّم `ref_id=NULL`
///      أو الحر `on_account` مع `customer_id`).
///    - استرداد مرتجع شراء نقدي (قبض مرتبط بمستند `purchase_return`)
///      وردّ مرتجع بيع نقدي (صرف مرتبط بمستند `sale_return`) وأنواع
///      الرواتب المؤجلة (`salary_batch`/`employee_advance`/
///      `commission_payout`) — كلها في دلو **«أخرى» موقعي** حتى لا
///      يختفي شيء بصمت (المعادلة الشاملة = كل حركة الصندوق).
///    - `tx_type='opening'` **مستبعد** من المعادلة عمداً (رصيد افتتاحي
///      ليس تدفق وردية — يُحتسب مرة واحدة في `opening_count`).
/// 4. **الإبطال والمعاكسة** مثل كل أرصدة النقدية: `is_voided=1` مستبعدة
///    دائماً والحركات المعاكسة (`reversal_of` غير فارغ) مستبعدة —
///    أثر الثنائي صفر (FR-04-08).
/// 5. نافذة المعادلة **مغلقة على تاريخ الحركة** `tx_date` بمقارنة
///    سلاسل ISO-UTC المتجانسة (`>= from AND <= to`) — كل كتابة
///    `cash_tx` في التطبيق تُخزَّن بالصيغة نفسها فالمقارنة المعجمية
///    سليمة زمنياً.
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/services/purchase_pricing.dart' show roundMoney;
import 'shift_models.dart';

/// الوردية المفتوحة على الصندوق — `null` إن لا توجد.
Future<ShiftRow?> currentShiftOnBox(Database db, int cashboxId) async {
  final rows = await db.query(
    'shift',
    where: 'cashbox_id = ? AND closed_at IS NULL',
    whereArgs: [cashboxId],
    orderBy: 'opened_at DESC, id DESC',
    limit: 1,
  );
  return rows.isEmpty ? null : ShiftRow.fromMap(rows.first);
}

/// صف وردية بمعرّفها — `null` إن لم توجد.
Future<ShiftRow?> shiftRowById(Database db, int id) async {
  final rows = await db.query(
    'shift',
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  return rows.isEmpty ? null : ShiftRow.fromMap(rows.first);
}

/// آخر الورديات المقفلة على الصندوق (الأحدث أولاً).
Future<List<ShiftRow>> recentClosedShifts(
  Database db, {
  required int cashboxId,
  int limit = 20,
}) async {
  final rows = await db.query(
    'shift',
    where: 'cashbox_id = ? AND closed_at IS NOT NULL',
    whereArgs: [cashboxId],
    orderBy: 'closed_at DESC, id DESC',
    limit: limit,
  );
  return [for (final row in rows) ShiftRow.fromMap(row)];
}

/// الاستعلام الموحد للمعادلة — يعمل فوق اتصال أو معاملة (الذرّية).
///
/// الساقات الثلاث مطابقة لاستعلام رصيد `listBoxes` في
/// `cash_repository` (تحويل العملة حرفياً — القرار 1) مقيّدة بنافذة
/// `tx_date` وصندوق واحد، والتجميع الخارجي لا يقرأ إلا دلو عملة
/// الصندوق (`cur = (SELECT currency_id …)`) — **معرّف العملة يُستخرج
/// من صف الصندوق نفسه** لا من معرّف الصندوق (المعرّفان مستقلان).
Future<ShiftEquation> shiftEquationFor(
  DatabaseExecutor db, {
  required int cashboxId,
  required String fromIso,
  required String toIso,
}) async {
  final row = await db.rawQuery(
    '''
      WITH legs AS (
        -- الساق المفردة على هذا الصندوق (بعملتها أو بعملة الصندوق عند
        -- settlement) + نوع مستند الارتباط إن كان سند فاتورة.
        SELECT 'one' AS leg, t.tx_type AS tx_type,
               t.customer_id AS customer_id, i.doc_type AS ref_doc,
               CASE WHEN t.settlement_rate IS NULL THEN t.amount
                    ELSE t.amount * t.settlement_rate END
                 * CASE WHEN t.tx_type IN ('receipt','capital_in','opening')
                        THEN 1 ELSE -1 END AS amt,
               CASE WHEN t.settlement_rate IS NULL THEN t.currency_id
                    ELSE cb.currency_id END AS cur
        FROM cash_tx t
        JOIN cashbox cb ON cb.id = t.cashbox_id
        LEFT JOIN invoice i ON t.ref_type = 'invoice' AND i.id = t.ref_id
        WHERE t.cashbox_id = ?
          AND t.is_voided = 0 AND t.reversal_of IS NULL
          AND t.tx_type NOT IN ('box_transfer','bank_deposit','bank_withdraw')
          AND t.tx_date >= ? AND t.tx_date <= ?
        UNION ALL
        -- الساق الصادرة لذات الساقين (بعملة المصدر دائماً — سالبة).
        SELECT 'src', t.tx_type, t.customer_id, NULL, -t.amount,
               t.currency_id
        FROM cash_tx t
        WHERE t.cashbox_id = ?
          AND t.is_voided = 0 AND t.reversal_of IS NULL
          AND t.tx_type IN ('box_transfer','bank_deposit','bank_withdraw')
          AND t.tx_date >= ? AND t.tx_date <= ?
        UNION ALL
        -- الساق الواردة إلى الهدف (بعملة الهدف وبالمبلغ المحوّل).
        SELECT 'tgt', t.tx_type, t.customer_id, NULL,
               t.amount * COALESCE(t.settlement_rate, 1), tc.currency_id
        FROM cash_tx t
        JOIN cashbox tc ON tc.id = t.to_cashbox_id
        WHERE t.to_cashbox_id = ?
          AND t.is_voided = 0 AND t.reversal_of IS NULL
          AND t.tx_type IN ('box_transfer','bank_deposit','bank_withdraw')
          AND t.tx_date >= ? AND t.tx_date <= ?
      )
      SELECT
        COALESCE(SUM(CASE WHEN tx_type = 'receipt'
                            AND ref_doc = 'sale'
                            AND customer_id IS NULL
                       THEN amt END), 0) AS cash_sales,
        COALESCE(SUM(CASE WHEN tx_type = 'receipt'
                            AND (ref_doc IS NULL OR ref_doc <> 'sale'
                                 OR customer_id IS NOT NULL)
                            AND (ref_doc IS NULL OR ref_doc <> 'purchase_return')
                       THEN amt END), 0) AS collections,
        COALESCE(SUM(CASE WHEN tx_type = 'capital_in' THEN amt END), 0)
          AS owner_deposits,
        COALESCE(SUM(CASE WHEN tx_type = 'payment'
                            AND (ref_doc IS NULL OR ref_doc <> 'sale_return')
                       THEN -amt END), 0) AS supplier_payments,
        COALESCE(SUM(CASE WHEN tx_type = 'expense' THEN -amt END), 0)
          AS expenses,
        COALESCE(SUM(CASE WHEN tx_type = 'owner_draw' THEN -amt END), 0)
          AS owner_draws,
        COALESCE(SUM(CASE WHEN leg = 'src' THEN -amt END), 0)
          AS transfers_out,
        COALESCE(SUM(CASE WHEN leg = 'tgt' THEN amt END), 0)
          AS transfers_in,
        COALESCE(SUM(CASE WHEN tx_type IN ('salary_batch','employee_advance',
                                           'commission_payout')
                            OR (tx_type = 'receipt'
                                AND ref_doc = 'purchase_return')
                            OR (tx_type = 'payment'
                                AND ref_doc = 'sale_return')
                       THEN amt END), 0) AS other
      FROM legs
      WHERE cur = (SELECT currency_id FROM cashbox WHERE id = ?)
      ''',
    <Object?>[
      cashboxId,
      fromIso,
      toIso,
      cashboxId,
      fromIso,
      toIso,
      cashboxId,
      fromIso,
      toIso,
      cashboxId,
    ],
  );
  final map = row.isEmpty ? const <String, Object?>{} : row.first;
  return ShiftEquation(
    cashSales: _money(map['cash_sales']),
    collections: _money(map['collections']),
    ownerDeposits: _money(map['owner_deposits']),
    transfersIn: _money(map['transfers_in']),
    bankIn: 0,
    chequesCleared: 0,
    supplierPayments: _money(map['supplier_payments']),
    expenses: _money(map['expenses']),
    ownerDraws: _money(map['owner_draws']),
    transfersOut: _money(map['transfers_out']),
    bankOut: 0,
    chequesPaid: 0,
    other: _money(map['other']),
  );
}

double _money(Object? value) {
  final num? n = value as num?;
  if (n == null) return 0;
  final d = n.toDouble();
  if (d.isNaN || d.isInfinite) return 0;
  return roundMoney(d);
}
