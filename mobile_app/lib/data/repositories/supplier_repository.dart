/// مستودع الموردين — جدول `supplier` وحساب أرصدتهم وكشوف حساباتهم
/// (وحدة FR-03-03 — SRS v1.5).
///
/// مرآة كاملة لمستودع العملاء باتجاه الشراء. صيغة الرصيد — **لكل عملة
/// على حدة، بلا خلط إطلاقاً** (FR-08-11):
/// ```sql
/// الرصيد = Σ(due_amount لفواتير الشراء المكتملة بتلك العملة)
///        − Σ(مبالغ سندات الصرف المرتبطة بالمورد بتلك العملة)
///        − Σ(due_amount لمرتجعات الشراء المكتملة بتلك العملة)
///        + الرصيد الافتتاحي (بعملته الافتتاحية فقط)
/// ```
/// الموجب = دَين لنا في ذمة المورد («المبالغ المتبقية للموردين»)؛
/// السالب = دفعنا له أكثر مما استحققنا.
///
/// نفس اصطلاح `due_amount` عند الإصدار المعمول به لدى العملاء —
/// محرك المشتريات يجب ألا يُنقصه عند التخصيص (انظر تعليق المستودع
/// المقابل) وإلا تكرَّر الخصم.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/party.dart';

class SupplierRepository {
  SupplierRepository(this._db);

  final Database _db;

  // ── الإنشاء والتعديل والأرشفة ────────────────────────────────────

  /// ينشئ مورداً ويعيد معرّفه (FR-03-03).
  ///
  /// الرصيد الافتتاحي غير الصفري يتطلب عملة وسعر صرف صحيحين، وتاريخه
  /// يفترض يوم [now] إن لم يُمرَّر صريحاً. الكتابة والتدقيق ذرّيتان.
  Future<Result<int, String>> createSupplier(
    SupplierDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final failure = _validate(draft);
    if (failure != null) {
      return Err<int, String>(failure);
    }
    final at = now ?? DateTime.now();
    final iso = at.toUtc().toIso8601String();
    final trimmed = draft.name.trim();

    return _db.transaction<Result<int, String>>((txn) async {
      // العملة الافتتاحية يجب أن توجد — رسالة عربية بدل خطأ FK خام.
      final currencyMissing = await _openingCurrencyMissing(txn, draft);
      if (currencyMissing != null) {
        return Err<int, String>(currencyMissing);
      }
      final id = await txn.insert('supplier', {
        'name': trimmed,
        'phone': _blankToNull(draft.phone),
        'address': _blankToNull(draft.address),
        'opening_balance': draft.openingBalance,
        'opening_balance_currency_id': draft.openingBalanceCurrencyId,
        'opening_balance_rate': draft.openingBalanceRate,
        'opening_balance_date': _dateOrNull(draft.openingBalanceDate, at),
        'notes': _blankToNull(draft.notes),
        'is_archived': 0,
        'created_at': iso,
        'updated_at': iso,
        'created_by': userId,
      });
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'supplier_create',
        'entity': 'supplier',
        'entity_id': id,
        'details': 'name=$trimmed',
        'at': iso,
      });
      return Ok<int, String>(id);
    });
  }

  /// يعدّل بيانات مورد ويعيد النسخة الجديدة (تدقيق `supplier_update`).
  Future<Result<Supplier, String>> updateSupplier(
    int id,
    SupplierDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final failure = _validate(draft);
    if (failure != null) {
      return Err<Supplier, String>(failure);
    }
    final at = now ?? DateTime.now();
    final iso = at.toUtc().toIso8601String();
    final trimmed = draft.name.trim();

    return _db.transaction<Result<Supplier, String>>((txn) async {
      final currencyMissing = await _openingCurrencyMissing(txn, draft);
      if (currencyMissing != null) {
        return Err<Supplier, String>(currencyMissing);
      }
      final updated = await txn.update(
        'supplier',
        {
          'name': trimmed,
          'phone': _blankToNull(draft.phone),
          'address': _blankToNull(draft.address),
          'opening_balance': draft.openingBalance,
          'opening_balance_currency_id': draft.openingBalanceCurrencyId,
          'opening_balance_rate': draft.openingBalanceRate,
          'opening_balance_date': _dateOrNull(draft.openingBalanceDate, at),
          'notes': _blankToNull(draft.notes),
          'updated_at': iso,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated == 0) {
        return Err<Supplier, String>('المورد رقم #$id غير موجود.');
      }
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'supplier_update',
        'entity': 'supplier',
        'entity_id': id,
        'details': 'name=$trimmed',
        'at': iso,
      });
      final rows = await txn.query(
        'supplier',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return Ok<Supplier, String>(Supplier.fromRow(rows.first));
    });
  }

  /// يؤرشف مورداً (FR-03-09): الطرف ذو الحركات يُؤرشف فقط — لا حذف
  /// أبداً في V1 — ويُستثنى من القوائم الافتراضية.
  Future<Result<void, String>> archiveSupplier(
    int id, {
    required int userId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final iso = at.toUtc().toIso8601String();
    return _db.transaction<Result<void, String>>((txn) async {
      final updated = await txn.update(
        'supplier',
        {'is_archived': 1, 'updated_at': iso},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated == 0) {
        return Err<void, String>('المورد رقم #$id غير موجود.');
      }
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'supplier_archive',
        'entity': 'supplier',
        'entity_id': id,
        'details': 'archived=1',
        'at': iso,
      });
      return const Ok<void, String>(null);
    });
  }

  /// هل للمورد حركات (أي صف فاتورة، أو سند نقدي، أو رصيد افتتاحي
  /// غير صفري)؟ — أساس قرار «أرشفة فقط» (FR-03-09).
  Future<bool> hasMovements(int id) async {
    final rows = await _db.rawQuery(
      'SELECT '
      ' (SELECT COUNT(*) FROM invoice WHERE supplier_id = ?) '
      ' + (SELECT COUNT(*) FROM cash_tx WHERE supplier_id = ?) '
      ' + (SELECT CASE WHEN opening_balance IS NOT NULL AND opening_balance <> 0 '
      '     THEN 1 ELSE 0 END FROM supplier WHERE id = ?) AS n',
      <Object>[id, id, id],
    );
    return ((rows.first['n'] as int?) ?? 0) > 0;
  }

  // ── الأرصدة (FR-03-03) ───────────────────────────────────────────

  /// قائمة الموردين مع أرصدتهم — سطر لكل (مورد × عملة)؛ المورد بلا أي
  /// حركة يظهر بسطر واحد برصيد صفر بعملة القاعدة.
  ///
  /// [search] يبحث بالاسم أو الهاتف (LIKE)، و[includeArchived] يضيف
  /// المؤرشفين (افتراضياً مستثنون).
  Future<List<PartyBalance>> listWithBalances({
    String? search,
    bool includeArchived = false,
  }) async {
    final baseRows = await _db.rawQuery(
      'SELECT id FROM currency WHERE is_base = 1 LIMIT 1',
    );
    final baseCurrencyId = baseRows.isEmpty
        ? null
        : baseRows.first['id'] as int;
    final rows = await _db.rawQuery(
      '''
      WITH purchase_dues AS (
        SELECT supplier_id AS pid, currency_id AS cur, SUM(due_amount) AS amt
        FROM invoice
        WHERE doc_type = 'purchase' AND status = 'completed'
          AND supplier_id IS NOT NULL
        GROUP BY supplier_id, currency_id
      ),
      return_credits AS (
        SELECT supplier_id AS pid, currency_id AS cur, SUM(due_amount) AS amt
        FROM invoice
        WHERE doc_type = 'purchase_return' AND status = 'completed'
          AND supplier_id IS NOT NULL
        GROUP BY supplier_id, currency_id
      ),
      payments AS (
        SELECT supplier_id AS pid, currency_id AS cur, SUM(amount) AS amt
        FROM cash_tx
        WHERE tx_type = 'payment' AND is_voided = 0
          AND supplier_id IS NOT NULL
        GROUP BY supplier_id, currency_id
      ),
      openings AS (
        SELECT id AS pid, opening_balance_currency_id AS cur,
               opening_balance AS amt
        FROM supplier
        WHERE opening_balance_currency_id IS NOT NULL
          AND opening_balance <> 0
      ),
      combined AS (
        SELECT pid, cur, amt FROM purchase_dues
        UNION ALL SELECT pid, cur, -amt FROM return_credits
        UNION ALL SELECT pid, cur, -amt FROM payments
        UNION ALL SELECT pid, cur, amt FROM openings
      ),
      per_currency AS (
        SELECT pid, cur, SUM(amt) AS bal
        FROM combined
        GROUP BY pid, cur
      ),
      last_pay AS (
        SELECT supplier_id AS pid, currency_id AS cur, MAX(tx_date) AS d
        FROM cash_tx
        WHERE tx_type = 'payment' AND is_voided = 0
          AND supplier_id IS NOT NULL
        GROUP BY supplier_id, currency_id
      ),
      oldest_open AS (
        SELECT supplier_id AS pid, currency_id AS cur, MIN(issued_at) AS d
        FROM invoice
        WHERE doc_type = 'purchase' AND status = 'completed'
          AND due_amount > 0 AND supplier_id IS NOT NULL
        GROUP BY supplier_id, currency_id
      )
      SELECT s.id AS party_id, s.name AS p_name, s.phone AS p_phone,
             cu.code AS cur_code,
             COALESCE(pc.bal, 0) AS balance,
             lp.d AS last_payment_date,
             oo.d AS oldest_open_invoice_date
      FROM supplier s
      LEFT JOIN per_currency pc ON pc.pid = s.id
      LEFT JOIN currency cu
        ON cu.id = CASE WHEN pc.cur IS NULL THEN ? ELSE pc.cur END
      LEFT JOIN last_pay lp ON lp.pid = s.id AND lp.cur = pc.cur
      LEFT JOIN oldest_open oo ON oo.pid = s.id AND oo.cur = pc.cur
      WHERE (? = 1 OR s.is_archived = 0)
        AND (? IS NULL OR s.name LIKE '%' || ? || '%'
                       OR s.phone LIKE '%' || ? || '%')
      ORDER BY s.name COLLATE NOCASE ASC, cur_code ASC
      ''',
      <Object?>[
        baseCurrencyId,
        includeArchived ? 1 : 0,
        search,
        search,
        search,
      ],
    );
    return <PartyBalance>[
      for (final row in rows)
        PartyBalance(
          partyId: row['party_id'] as int,
          name: row['p_name'] as String,
          phone: row['p_phone'] as String?,
          currencyCode: (row['cur_code'] as String?) ?? '',
          balance: (row['balance'] as num?)?.toDouble() ?? 0,
          lastPaymentDate: _tryParseUtc(row['last_payment_date'] as String?),
          oldestOpenInvoiceDate: _utcMidnightOrNull(
            row['oldest_open_invoice_date'] as String?,
          ),
        ),
    ];
  }

  /// رصيد المورد في عملة واحدة — الموجب = ما تبقّى علينا دفعه.
  Future<double> balanceInCurrency(int supplierId, int currencyId) async {
    final rows = await _db.rawQuery(
      'SELECT '
      ' COALESCE((SELECT SUM(due_amount) FROM invoice '
      "   WHERE doc_type = 'purchase' AND status = 'completed' "
      '     AND supplier_id = ? AND currency_id = ?), 0) '
      ' - COALESCE((SELECT SUM(due_amount) FROM invoice '
      "   WHERE doc_type = 'purchase_return' AND status = 'completed' "
      '     AND supplier_id = ? AND currency_id = ?), 0) '
      ' - COALESCE((SELECT SUM(amount) FROM cash_tx '
      "   WHERE tx_type = 'payment' AND is_voided = 0 "
      '     AND supplier_id = ? AND currency_id = ?), 0) '
      ' + COALESCE((SELECT CASE WHEN opening_balance_currency_id = ? '
      '     THEN opening_balance ELSE 0 END '
      '   FROM supplier WHERE id = ?), 0) AS balance',
      <Object>[
        supplierId,
        currencyId,
        supplierId,
        currencyId,
        supplierId,
        currencyId,
        currencyId,
        supplierId,
      ],
    );
    return (rows.first['balance'] as num?)?.toDouble() ?? 0;
  }

  /// المبالغ المتبقية للموردين (FR-03-03): الموردون برصيد موجب
  /// (>= [minBalance]) في أي عملة، مرتَّبين بأقدم فاتورة شراء آجلة
  /// مفتوحة تصاعدياً، مع [PartyBalance.daysLate] («متأخر منذ X يوماً»).
  ///
  /// [now] لحظة الاحتساب (تُمرَّر صريحة في الاختبارات؛ الافتراضي الآن).
  Future<List<PartyBalance>> payablesList({
    int minBalance = 1,
    DateTime? now,
  }) async {
    final reference = (now ?? DateTime.now()).toUtc();
    final all = await listWithBalances(includeArchived: false);
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

  // ── كشف الحساب (FR-03-04) ────────────────────────────────────────

  /// كشف حساب المورد بعملة واحدة وفترة اختيارية:
  /// فواتير الشراء الآجلة (+)، سندات الصرف (−)، مرتجعات الشراء الآجلة
  /// (−)، والرصيد الافتتاحي عند تطابق عملته.
  ///
  /// القيود قبل [from] تُجمَّع في قيد «رصيد ماضٍ» واحد أول الكشف،
  /// والقيود بعد [to] تُستبعد. `finalBalance` تطابق `balanceInCurrency`
  /// عند غياب [to].
  Future<StatementResult> statement(
    int supplierId, {
    required int currencyId,
    DateTime? from,
    DateTime? to,
  }) async {
    final currencyCode = await _currencyCode(currencyId);
    final raw = await _statementRows(supplierId, currencyId);
    final fromStr = from == null ? null : _dateOnly(from);
    final toStr = to == null ? null : _dateOnly(to);

    var carryIn = 0.0;
    var carryInEmitted = false;
    final entries = <StatementEntry>[];
    for (final row in raw) {
      final day = _dayOf(row.dateStr);
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
            date: _utcMidnightOf(from!),
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
          date: _utcMidnightOrNull(row.dateStr) ?? _epoch,
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
          date: _utcMidnightOf(from!),
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

  /// قيود كشف حساب المورد خاماً — الافتتاحي (عند تطابق العملة) ثم
  /// الحركات، مرتَّبة زمنياً (التاريخ، ثم نوع القيد، ثم المعرّف).
  Future<List<_StatementRow>> _statementRows(
    int supplierId,
    int currencyId,
  ) async {
    final raw = <_StatementRow>[];
    final supplierRows = await _db.query(
      'supplier',
      where: 'id = ?',
      whereArgs: [supplierId],
      limit: 1,
    );
    if (supplierRows.isNotEmpty) {
      final row = supplierRows.first;
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
    final movementRows = await _db.rawQuery(
      '''
      SELECT * FROM (
        SELECT issued_at AS d, 'purchase' AS kind, invoice_no AS doc_no,
               due_amount AS amt, id AS ref_id
        FROM invoice
        WHERE doc_type = 'purchase' AND status = 'completed'
          AND supplier_id = ? AND currency_id = ? AND due_amount <> 0
        UNION ALL
        SELECT issued_at, 'purchase_return', invoice_no, -due_amount, id
        FROM invoice
        WHERE doc_type = 'purchase_return' AND status = 'completed'
          AND supplier_id = ? AND currency_id = ? AND due_amount <> 0
        UNION ALL
        SELECT tx_date, 'payment', voucher_no, -amount, id
        FROM cash_tx
        WHERE tx_type = 'payment' AND is_voided = 0
          AND supplier_id = ? AND currency_id = ?
      ) ORDER BY d ASC,
          CASE kind WHEN 'purchase' THEN 0 WHEN 'purchase_return' THEN 1 ELSE 2 END ASC,
          ref_id ASC
      ''',
      <Object>[
        supplierId,
        currencyId,
        supplierId,
        currencyId,
        supplierId,
        currencyId,
      ],
    );
    raw.addAll(<_StatementRow>[
      for (final row in movementRows)
        _StatementRow(
          dateStr: row['d'] as String,
          rank: (row['kind'] as String) == 'purchase'
              ? 1
              : (row['kind'] as String) == 'purchase_return'
              ? 2
              : 3,
          refId: row['ref_id'] as int?,
          code: (row['kind'] as String) == 'purchase'
              ? StatementEntryCode.purchase
              : (row['kind'] as String) == 'purchase_return'
              ? StatementEntryCode.purchaseReturn
              : StatementEntryCode.payment,
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

  // ── مساعدات داخلية ───────────────────────────────────────────────

  /// تحقق مسودة المورد المشترك بين الإنشاء والتعديل — أو رسالة الخطأ.
  String? _validate(SupplierDraft draft) {
    if (draft.name.trim().isEmpty) {
      return 'اسم المورد مطلوب — أدخل الاسم ثم احفظ.';
    }
    if (draft.openingBalance != 0) {
      if (draft.openingBalanceCurrencyId == null) {
        return 'الرصيد الافتتاحي غير الصفري يتطلب اختيار عملة.';
      }
      final rate = draft.openingBalanceRate;
      if (rate == null || rate.isNaN || rate.isInfinite || rate <= 0) {
        return 'الرصيد الافتتاحي غير الصفري يتطلب سعر صرف صحيحاً أكبر '
            'من صفر.';
      }
    }
    return null;
  }

  /// رسالة الخطأ إن لم توجد عملة الرصيد الافتتاحي (داخل معاملة).
  Future<String?> _openingCurrencyMissing(
    DatabaseExecutor txn,
    SupplierDraft draft,
  ) async {
    final currencyId = draft.openingBalanceCurrencyId;
    if (currencyId == null) return null;
    final rows = await txn.query(
      'currency',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [currencyId],
      limit: 1,
    );
    return rows.isEmpty ? 'العملة المحددة للرصيد الافتتاحي غير موجودة.' : null;
  }

  Future<String> _currencyCode(int currencyId) async {
    final rows = await _db.query(
      'currency',
      columns: ['code'],
      where: 'id = ?',
      whereArgs: [currencyId],
      limit: 1,
    );
    if (rows.isEmpty) return '';
    return rows.first['code'] as String;
  }
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

// ── مساعدات تنسيق عامة للملف ──────────────────────────────────────

/// نص فارغ (فراغات فقط) → `null` — لتخزين نظيف للأعمدة الاختيارية.
String? _blankToNull(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// تاريخ بديل عند غيابه (تاريخ اليوم) بصيغة `YYYY-MM-DD`.
String? _dateOrNull(DateTime? date, DateTime fallback) =>
    _dateOnly(date ?? fallback);

/// `YYYY-MM-DD` بتاريخ التقويم المحلي ليوم العمل.
String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// يوم القيد من نص ISO (أول 10 محارف) — `YYYY-MM-DD`.
String _dayOf(String iso) => iso.length <= 10 ? iso : iso.substring(0, 10);

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// يحلّ نص ISO كاملاً (سندات/فواتير) إلى UTC — أو `null`.
DateTime? _tryParseUtc(String? iso) {
  if (iso == null) return null;
  final parsed = DateTime.tryParse(iso);
  return parsed?.toUtc();
}

/// منتصف ليل UTC ليوم التقويم من نص ISO — أو `null`.
DateTime? _utcMidnightOrNull(String? iso) {
  if (iso == null) return null;
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

/// منتصف ليل UTC ليوم التقويم من [DateTime].
DateTime _utcMidnightOf(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// أيام التأخير منذ أقدم فاتورة مفتوحة (صفر يوم كحد أدنى).
int? _daysLate(DateTime reference, DateTime? oldestOpenInvoiceDate) {
  if (oldestOpenInvoiceDate == null) return null;
  final days = reference.difference(oldestOpenInvoiceDate).inDays;
  return days < 0 ? 0 : days;
}
