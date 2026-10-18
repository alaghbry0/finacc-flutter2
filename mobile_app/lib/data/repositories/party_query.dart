/// استعلامات الأطراف الموحّدة — النواة المشتركة بين مستودعي العملاء
/// والموردين (FR-03-02 / FR-03-03 / FR-03-04) — R18-D2 (DRY).
///
/// المستودعان (عميل/مورد) كانا نسختين متطابقتين من نفس الاستعلامات
/// باتجاهين متقابلين (بيع/شراء)؛ هذا الملف يحمل النسخة الواحدة
/// والطرفان يمرّران [PartySide] فقط. صيغة الرصيد **لكل عملة على حدة،
/// بلا خلط إطلاقاً** (FR-08-11):
/// ```sql
/// الرصيد = Σ(due_amount لفواتير الاتجاه المكتملة بتلك العملة)
///        − Σ(مبالغ السندات النقدية المرتبطة بالطرف بتلك العملة)
///        − Σ(due_amount لمرتجعات الاتجاه المكتملة بتلك العملة)
///        + الرصيد الافتتاحي (بعملته الافتتاحية فقط)
/// ```
/// الموجب = دَين على الطرف لنا؛ السالب = رصيد دائن للطرف.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/dates.dart';
import '../../domain/models/party.dart';

/// اتجاه محور الأطراف — يحدد الجداول وأنواع المستندات والسندات التي
/// تُبنى عليها أرصدة الطرف وكشف حسابه.
enum PartySide {
  /// عميل: ديون فواتير البيع المكتملة وسندات القبض.
  customer(
    table: 'customer',
    partyColumn: 'customer_id',
    dueDocType: 'sale',
    returnDocType: 'sale_return',
    cashTxType: 'receipt',
    dueCode: StatementEntryCode.invoice,
    returnCode: StatementEntryCode.saleReturn,
    cashCode: StatementEntryCode.receipt,
  ),

  /// مورد: فواتير الشراء المكتملة وسندات الصرف.
  supplier(
    table: 'supplier',
    partyColumn: 'supplier_id',
    dueDocType: 'purchase',
    returnDocType: 'purchase_return',
    cashTxType: 'payment',
    dueCode: StatementEntryCode.purchase,
    returnCode: StatementEntryCode.purchaseReturn,
    cashCode: StatementEntryCode.payment,
  );

  const PartySide({
    required this.table,
    required this.partyColumn,
    required this.dueDocType,
    required this.returnDocType,
    required this.cashTxType,
    required this.dueCode,
    required this.returnCode,
    required this.cashCode,
  });

  /// جدول الطرف (`customer` / `supplier`).
  final String table;

  /// عمود ربط الطرف بجدولي `invoice` و`cash_tx`.
  final String partyColumn;

  /// نوع مستند الدين (فاتورة الاتجاه المكتملة).
  final String dueDocType;

  /// نوع مستند المرتجع المكتمل.
  final String returnDocType;

  /// نوع سند النقدية المقيّد للطرف.
  final String cashTxType;

  /// رمز قيد كشف الحساب لفاتورة الاتجاه.
  final StatementEntryCode dueCode;

  /// رمز قيد كشف الحساب لمرتجع الاتجاه.
  final StatementEntryCode returnCode;

  /// رمز قيد كشف الحساب لسند النقدية.
  final StatementEntryCode cashCode;
}

// ── الأرصدة ────────────────────────────────────────────────────────

/// قائمة الأطراف مع أرصدتهم — سطر لكل (طرف × عملة)؛ الطرف بلا أي
/// حركة يظهر بسطر واحد برصيد صفر بعملة القاعدة.
///
/// [search] يبحث بالاسم أو الهاتف (LIKE)، و[includeArchived] يضيف
/// المؤرشفين (افتراضياً مستثنون — FR-03-09).
Future<List<PartyBalance>> partyListWithBalances(
  Database db,
  PartySide side, {
  String? search,
  bool includeArchived = false,
}) async {
  final baseRows = await db.rawQuery(
    'SELECT id FROM currency WHERE is_base = 1 LIMIT 1',
  );
  final baseCurrencyId = baseRows.isEmpty ? null : baseRows.first['id'] as int;
  final rows = await db.rawQuery(
    '''
    WITH due_invoices AS (
      SELECT ${side.partyColumn} AS pid, currency_id AS cur, SUM(due_amount) AS amt
      FROM invoice
      WHERE doc_type = '${side.dueDocType}' AND status = 'completed'
        AND ${side.partyColumn} IS NOT NULL
      GROUP BY ${side.partyColumn}, currency_id
    ),
    return_credits AS (
      SELECT ${side.partyColumn} AS pid, currency_id AS cur, SUM(due_amount) AS amt
      FROM invoice
      WHERE doc_type = '${side.returnDocType}' AND status = 'completed'
        AND ${side.partyColumn} IS NOT NULL
      GROUP BY ${side.partyColumn}, currency_id
    ),
    cash_txs AS (
      SELECT ${side.partyColumn} AS pid, currency_id AS cur, SUM(amount) AS amt
      FROM cash_tx
      WHERE tx_type = '${side.cashTxType}' AND is_voided = 0
        AND ${side.partyColumn} IS NOT NULL
      GROUP BY ${side.partyColumn}, currency_id
    ),
    openings AS (
      SELECT id AS pid, opening_balance_currency_id AS cur,
             opening_balance AS amt
      FROM ${side.table}
      WHERE opening_balance_currency_id IS NOT NULL
        AND opening_balance <> 0
    ),
    combined AS (
      SELECT pid, cur, amt FROM due_invoices
      UNION ALL SELECT pid, cur, -amt FROM return_credits
      UNION ALL SELECT pid, cur, -amt FROM cash_txs
      UNION ALL SELECT pid, cur, amt FROM openings
    ),
    per_currency AS (
      SELECT pid, cur, SUM(amt) AS bal
      FROM combined
      GROUP BY pid, cur
    ),
    last_pay AS (
      SELECT ${side.partyColumn} AS pid, currency_id AS cur, MAX(tx_date) AS d
      FROM cash_tx
      WHERE tx_type = '${side.cashTxType}' AND is_voided = 0
        AND ${side.partyColumn} IS NOT NULL
      GROUP BY ${side.partyColumn}, currency_id
    ),
    oldest_open AS (
      SELECT ${side.partyColumn} AS pid, currency_id AS cur, MIN(issued_at) AS d
      FROM invoice
      WHERE doc_type = '${side.dueDocType}' AND status = 'completed'
        AND due_amount > 0 AND ${side.partyColumn} IS NOT NULL
      GROUP BY ${side.partyColumn}, currency_id
    )
    SELECT p.id AS party_id, p.name AS p_name, p.phone AS p_phone,
           cu.code AS cur_code,
           COALESCE(pc.bal, 0) AS balance,
           lp.d AS last_payment_date,
           oo.d AS oldest_open_invoice_date
    FROM ${side.table} p
    LEFT JOIN per_currency pc ON pc.pid = p.id
    LEFT JOIN currency cu
      ON cu.id = CASE WHEN pc.cur IS NULL THEN ? ELSE pc.cur END
    LEFT JOIN last_pay lp ON lp.pid = p.id AND lp.cur = pc.cur
    LEFT JOIN oldest_open oo ON oo.pid = p.id AND oo.cur = pc.cur
    WHERE (? = 1 OR p.is_archived = 0)
      AND (? IS NULL OR p.name LIKE '%' || ? || '%'
                     OR p.phone LIKE '%' || ? || '%')
    ORDER BY p.name COLLATE NOCASE ASC, cur_code ASC
    ''',
    <Object?>[baseCurrencyId, includeArchived ? 1 : 0, search, search, search],
  );
  return <PartyBalance>[
    for (final row in rows)
      PartyBalance(
        partyId: row['party_id'] as int,
        name: row['p_name'] as String,
        phone: row['p_phone'] as String?,
        currencyCode: (row['cur_code'] as String?) ?? '',
        balance: (row['balance'] as num?)?.toDouble() ?? 0,
        lastPaymentDate: tryParseUtc(row['last_payment_date'] as String?),
        oldestOpenInvoiceDate: utcMidnightOrNull(
          row['oldest_open_invoice_date'] as String?,
        ),
      ),
  ];
}

/// رصيد الطرف في عملة واحدة — صيغة الأرصدة حصراً (0 عند لا حركة).
Future<double> partyBalanceInCurrency(
  Database db,
  PartySide side,
  int partyId,
  int currencyId,
) async {
  final rows = await db.rawQuery(
    'SELECT '
    ' COALESCE((SELECT SUM(due_amount) FROM invoice '
    "   WHERE doc_type = '${side.dueDocType}' AND status = 'completed' "
    '     AND ${side.partyColumn} = ? AND currency_id = ?), 0) '
    ' - COALESCE((SELECT SUM(due_amount) FROM invoice '
    "   WHERE doc_type = '${side.returnDocType}' AND status = 'completed' "
    '     AND ${side.partyColumn} = ? AND currency_id = ?), 0) '
    ' - COALESCE((SELECT SUM(amount) FROM cash_tx '
    "   WHERE tx_type = '${side.cashTxType}' AND is_voided = 0 "
    '     AND ${side.partyColumn} = ? AND currency_id = ?), 0) '
    ' + COALESCE((SELECT CASE WHEN opening_balance_currency_id = ? '
    '     THEN opening_balance ELSE 0 END '
    '   FROM ${side.table} WHERE id = ?), 0) AS balance',
    <Object>[
      partyId,
      currencyId,
      partyId,
      currencyId,
      partyId,
      currencyId,
      currencyId,
      partyId,
    ],
  );
  return (rows.first['balance'] as num?)?.toDouble() ?? 0;
}

/// هل للطرف حركات (أي صف فاتورة، أو سند نقدي، أو رصيد افتتاحي
/// غير صفري)؟ — أساس قرار «أرشفة فقط» (FR-03-09).
Future<bool> partyHasMovements(Database db, PartySide side, int id) async {
  final rows = await db.rawQuery(
    'SELECT '
    ' (SELECT COUNT(*) FROM invoice WHERE ${side.partyColumn} = ?) '
    ' + (SELECT COUNT(*) FROM cash_tx WHERE ${side.partyColumn} = ?) '
    ' + (SELECT CASE WHEN opening_balance IS NOT NULL AND opening_balance <> 0 '
    '     THEN 1 ELSE 0 END FROM ${side.table} WHERE id = ?) AS n',
    <Object>[id, id, id],
  );
  return ((rows.first['n'] as int?) ?? 0) > 0;
}

/// قائمة المتعثرين بالاتجاهين (FR-03-06 عملاء / FR-03-03 موردون):
/// الأطراف برصيد موجب (>= [minBalance]) في أي عملة، مرتَّبين بأقدم
/// فاتورة آجلة مفتوحة تصاعدياً، مع [PartyBalance.daysLate] منذ
/// أقدم فاتورة («متأخر منذ X يوماً»).
Future<List<PartyBalance>> partyOverdueList(
  Database db,
  PartySide side, {
  int minBalance = 1,
  DateTime? now,
}) async {
  final reference = (now ?? DateTime.now()).toUtc();
  final all = await partyListWithBalances(db, side);
  final result = <PartyBalance>[
    for (final row in all)
      if (row.balance > 0 && row.balance >= minBalance)
        PartyBalance(
          partyId: row.partyId,
          name: row.name,
          phone: row.phone,
          currencyCode: row.currencyCode,
          balance: row.balance,
          lastPaymentDate: row.lastPaymentDate,
          oldestOpenInvoiceDate: row.oldestOpenInvoiceDate,
          daysLate: _daysLate(reference, row.oldestOpenInvoiceDate),
        ),
  ];
  result.sort((a, b) {
    final aOldest = a.oldestOpenInvoiceDate;
    final bOldest = b.oldestOpenInvoiceDate;
    if (aOldest == null && bOldest == null) {
      return a.partyId.compareTo(b.partyId);
    }
    if (aOldest == null) return 1;
    if (bOldest == null) return -1;
    return aOldest.compareTo(bOldest);
  });
  return result;
}

// ── كشف الحساب (FR-03-04) ──────────────────────────────────────────

/// كشف حساب الطرف بعملة واحدة وفترة اختيارية:
/// فواتير الاتجاه الآجلة (+)، سندات النقدية (−)، مرتجعات الاتجاه
/// الآجلة (−)، والرصيد الافتتاحي عند تطابق عملته (بتماريخ تسجيله).
///
/// القيود قبل [from] تُجمَّع في قيد «رصيد ماضٍ» واحد أول الكشف،
/// والقيود بعد [to] تُستبعد. `finalBalance` تطابق `partyBalanceInCurrency`
/// عند غياب [to].
///
/// ملاحظة عرض: فواتير الكاش التامة (due_amount = 0) لا تُنشئ قيداً في
/// حساب الطرف فتُستبعد — الكشف حساب دَين لا سجل مبيعات.
Future<StatementResult> partyStatement(
  Database db,
  PartySide side,
  int partyId, {
  required int currencyId,
  DateTime? from,
  DateTime? to,
}) async {
  final currencyCode = await _currencyCode(db, currencyId);
  final raw = await _statementRows(db, side, partyId, currencyId);
  final fromStr = from == null ? null : dateOnly(from);
  final toStr = to == null ? null : dateOnly(to);

  var carryIn = 0.0;
  var carryInEmitted = false;
  final entries = <StatementEntry>[];
  for (final row in raw) {
    final day = dayOfIso(row.dateStr);
    if (fromStr != null && day.compareTo(fromStr) < 0) {
      carryIn += row.amount;
      continue;
    }
    if (toStr != null && day.compareTo(toStr) > 0) {
      continue;
    }
    // أول قيد داخل الفترة: أظهر «رصيد ماضٍ» إن تراكم شيء قبله.
    if (fromStr != null && !carryInEmitted && carryIn != 0) {
      carryInEmitted = true;
      entries.add(
        StatementEntry(
          date: utcMidnightOf(from!),
          code: StatementEntryCode.carryIn,
          amount: carryIn,
          runningBalance: carryIn,
          currencyCode: currencyCode,
        ),
      );
    }
    final running = entries.isEmpty ? carryIn : entries.last.runningBalance;
    entries.add(
      StatementEntry(
        date: utcMidnightOrNull(row.dateStr) ?? _epoch,
        code: row.code,
        docNo: row.docNo,
        amount: row.amount,
        runningBalance: running + row.amount,
        currencyCode: currencyCode,
        refId: row.refId,
      ),
    );
  }
  // فترة محددة بلا قيود داخلها لكن برصيد ماضٍ — القيد وحده.
  if (fromStr != null && entries.isEmpty && carryIn != 0) {
    entries.add(
      StatementEntry(
        date: utcMidnightOf(from!),
        code: StatementEntryCode.carryIn,
        amount: carryIn,
        runningBalance: carryIn,
        currencyCode: currencyCode,
      ),
    );
  }
  return StatementResult(
    entries: entries,
    openingBalance: carryIn,
    finalBalance: entries.isEmpty ? carryIn : entries.last.runningBalance,
    currencyId: currencyId,
    currencyCode: currencyCode,
  );
}

/// رمز عملة من جدول `currency` (سلسلة فارغة عند الغياب).
Future<String> _currencyCode(Database db, int currencyId) async {
  final rows = await db.query(
    'currency',
    columns: ['code'],
    where: 'id = ?',
    whereArgs: [currencyId],
    limit: 1,
  );
  if (rows.isEmpty) return '';
  return rows.first['code'] as String;
}

/// قيود كشف حساب الطرف خاماً — الافتتاحي (عند تطابق العملة) ثم
/// الحركات، مرتَّبة زمنياً (التاريخ، ثم نوع القيد، ثم المعرّف).
Future<List<_StatementRow>> _statementRows(
  Database db,
  PartySide side,
  int partyId,
  int currencyId,
) async {
  final raw = <_StatementRow>[];
  final partyRows = await db.query(
    side.table,
    where: 'id = ?',
    whereArgs: [partyId],
    limit: 1,
  );
  if (partyRows.isNotEmpty) {
    final row = partyRows.first;
    final openingCurrency = row['opening_balance_currency_id'] as int?;
    final openingAmount = (row['opening_balance'] as num?)?.toDouble() ?? 0;
    if (openingCurrency == currencyId && openingAmount != 0) {
      raw.add(
        _StatementRow(
          dateStr: (row['opening_balance_date'] as String?) ?? '',
          rank: 0,
          refId: null,
          code: StatementEntryCode.opening,
          docNo: null,
          amount: openingAmount,
        ),
      );
    }
  }
  final movementRows = await db.rawQuery(
    '''
    SELECT * FROM (
      SELECT issued_at AS d, '${side.dueDocType}' AS kind, invoice_no AS doc_no,
             due_amount AS amt, id AS ref_id
      FROM invoice
      WHERE doc_type = '${side.dueDocType}' AND status = 'completed'
        AND ${side.partyColumn} = ? AND currency_id = ? AND due_amount <> 0
      UNION ALL
      SELECT issued_at, '${side.returnDocType}', invoice_no, -due_amount, id
      FROM invoice
      WHERE doc_type = '${side.returnDocType}' AND status = 'completed'
        AND ${side.partyColumn} = ? AND currency_id = ? AND due_amount <> 0
      UNION ALL
      SELECT tx_date, '${side.cashTxType}', voucher_no, -amount, id
      FROM cash_tx
      WHERE tx_type = '${side.cashTxType}' AND is_voided = 0
        AND ${side.partyColumn} = ? AND currency_id = ?
    ) ORDER BY d ASC,
        CASE kind WHEN '${side.dueDocType}' THEN 0 WHEN '${side.returnDocType}' THEN 1 ELSE 2 END ASC,
        ref_id ASC
    ''',
    <Object>[partyId, currencyId, partyId, currencyId, partyId, currencyId],
  );
  raw.addAll(<_StatementRow>[
    for (final row in movementRows)
      _StatementRow(
        dateStr: row['d'] as String,
        rank: (row['kind'] as String) == side.dueDocType
            ? 1
            : (row['kind'] as String) == side.returnDocType
            ? 2
            : 3,
        refId: row['ref_id'] as int?,
        code: (row['kind'] as String) == side.dueDocType
            ? side.dueCode
            : (row['kind'] as String) == side.returnDocType
            ? side.returnCode
            : side.cashCode,
        docNo: row['doc_no'] as String?,
        amount: (row['amt'] as num?)?.toDouble() ?? 0,
      ),
  ]);
  raw.sort(
    (a, b) => a.dateStr.compareTo(b.dateStr) != 0
        ? a.dateStr.compareTo(b.dateStr)
        : a.rank != b.rank
        ? a.rank.compareTo(b.rank)
        : (a.refId ?? 0).compareTo(b.refId ?? 0),
  );
  return raw;
}

/// قيد خام في كشف الحساب قبل بناء الأرصدة الرأسية.
class _StatementRow {
  const _StatementRow({
    required this.dateStr,
    required this.rank,
    required this.refId,
    required this.code,
    required this.docNo,
    required this.amount,
  });

  /// التاريخ كما في القاعدة (ISO كامل أو `YYYY-MM-DD` للافتتاحي).
  final String dateStr;

  /// رتبة الترتيب داخل اليوم نفسه (افتتاحي 0 / دَين 1 / مرتجع 2 / سند 3).
  final int rank;

  /// معرّف المستند المرجعي أو `null`.
  final int? refId;

  /// نوع القيد.
  final StatementEntryCode code;

  /// رقم المستند أو `null`.
  final String? docNo;

  /// المبلغ الموقَّع.
  final double amount;
}

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// أيام التأخير منذ أقدم فاتورة مفتوحة (صفر يوم كحد أدنى).
int? _daysLate(DateTime reference, DateTime? oldestOpenInvoiceDate) {
  if (oldestOpenInvoiceDate == null) return null;
  final days = reference.difference(oldestOpenInvoiceDate).inDays;
  return days < 0 ? 0 : days;
}
