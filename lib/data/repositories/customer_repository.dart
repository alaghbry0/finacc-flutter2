/// مستودع العملاء — جدول `customer` وحساب أرصدتهم وكشوف حساباتهم
/// (وحدة FR-03 — SRS v1.5).
///
/// صيغة الرصيد (FR-03-02) — **لكل عملة على حدة، بلا خلط إطلاقاً**
/// (FR-08-11):
/// ```sql
/// الرصيد = Σ(due_amount لفواتير البيع المكتملة بتلك العملة)
///        − Σ(مبالغ سندات القبض المرتبطة بالعميل بتلك العملة)
///        − Σ(due_amount لمرتجعات البيع المكتملة بتلك العملة)
///        + الرصيد الافتتاحي (بعملته الافتتاحية فقط)
/// ```
/// الموجب = دَين على العميل لنا؛ السالب = رصيد دائن للعميل.
///
/// **اصطلاح معماري ملزم للموجات اللاحقة**: `due_amount` في جدول
/// `invoice` يُقرأ هنا كالجزء الآجل عند الإصدار (لا يُنقصه المستودع عند
/// التخصيص)؛ الخصم يأتي من سندات القبض (`cash_tx`) بشكل مستقل — محرك
/// البيع في موجته يجب أن يحترم هذا الاصطلاح وإلا تكرَّر الخصم.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/party.dart';

class CustomerRepository {
  CustomerRepository(this._db);

  final Database _db;

  // ── الإنشاء والتعديل والأرشفة ────────────────────────────────────

  /// ينشئ عميلاً ويعيد معرّفه (FR-03-01).
  ///
  /// الرصيد الافتتاحي غير الصفري يتطلب عملة وسعر صرف صحيحين، وتاريخه
  /// يفترض يوم [now] إن لم يُمرَّر صريحاً. الكتابة والتدقيق ذرّيتان.
  Future<Result<int, String>> createCustomer(
    CustomerDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final failure = _validate(draft, label: 'العميل');
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
      final id = await txn.insert('customer', {
        'name': trimmed,
        'phone': _blankToNull(draft.phone),
        'whatsapp': _blankToNull(draft.whatsapp),
        'address': _blankToNull(draft.address),
        'area': _blankToNull(draft.area),
        'credit_limit': draft.creditLimit,
        'opening_balance': draft.openingBalance,
        'opening_balance_currency_id': draft.openingBalanceCurrencyId,
        'opening_balance_rate': draft.openingBalanceRate,
        'opening_balance_date': _dateOrNull(draft.openingBalanceDate, at),
        'notes': _blankToNull(draft.notes),
        'image_path': _blankToNull(draft.imagePath),
        'is_archived': 0,
        'created_at': iso,
        'updated_at': iso,
        'created_by': userId,
      });
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'customer_create',
        'entity': 'customer',
        'entity_id': id,
        'details': 'name=$trimmed',
        'at': iso,
      });
      return Ok<int, String>(id);
    });
  }

  /// يعدّل بيانات عميل ويعيد النسخة الجديدة (تدقيق `customer_update`).
  Future<Result<Customer, String>> updateCustomer(
    int id,
    CustomerDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final failure = _validate(draft, label: 'العميل');
    if (failure != null) {
      return Err<Customer, String>(failure);
    }
    final at = now ?? DateTime.now();
    final iso = at.toUtc().toIso8601String();
    final trimmed = draft.name.trim();

    return _db.transaction<Result<Customer, String>>((txn) async {
      final currencyMissing = await _openingCurrencyMissing(txn, draft);
      if (currencyMissing != null) {
        return Err<Customer, String>(currencyMissing);
      }
      final updated = await txn.update(
        'customer',
        {
          'name': trimmed,
          'phone': _blankToNull(draft.phone),
          'whatsapp': _blankToNull(draft.whatsapp),
          'address': _blankToNull(draft.address),
          'area': _blankToNull(draft.area),
          'credit_limit': draft.creditLimit,
          'opening_balance': draft.openingBalance,
          'opening_balance_currency_id': draft.openingBalanceCurrencyId,
          'opening_balance_rate': draft.openingBalanceRate,
          'opening_balance_date': _dateOrNull(draft.openingBalanceDate, at),
          'notes': _blankToNull(draft.notes),
          'image_path': _blankToNull(draft.imagePath),
          'updated_at': iso,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated == 0) {
        return Err<Customer, String>('العميل رقم #$id غير موجود.');
      }
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'customer_update',
        'entity': 'customer',
        'entity_id': id,
        'details': 'name=$trimmed',
        'at': iso,
      });
      final rows = await txn.query(
        'customer',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return Ok<Customer, String>(Customer.fromRow(rows.first));
    });
  }

  /// يؤرشف عميلاً (FR-03-09): الطرف ذو الحركات يُؤرشف فقط — لا حذف
  /// أبداً في V1 — ويُستثنى من القوائم الافتراضية مع بقاء أرصدته
  /// محسوبة عند الطلب الصريح.
  Future<Result<void, String>> archiveCustomer(
    int id, {
    required int userId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final iso = at.toUtc().toIso8601String();
    return _db.transaction<Result<void, String>>((txn) async {
      final updated = await txn.update(
        'customer',
        {'is_archived': 1, 'updated_at': iso},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated == 0) {
        return Err<void, String>('العميل رقم #$id غير موجود.');
      }
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'customer_archive',
        'entity': 'customer',
        'entity_id': id,
        'details': 'archived=1',
        'at': iso,
      });
      return const Ok<void, String>(null);
    });
  }

  /// هل للعميل حركات (أي صف فاتورة، أو سند نقدي، أو رصيد افتتاحي
  /// غير صفري)؟ — أساس قرار «أرشفة فقط» (FR-03-09).
  Future<bool> hasMovements(int id) async {
    final rows = await _db.rawQuery(
      'SELECT '
      ' (SELECT COUNT(*) FROM invoice WHERE customer_id = ?) '
      ' + (SELECT COUNT(*) FROM cash_tx WHERE customer_id = ?) '
      ' + (SELECT CASE WHEN opening_balance IS NOT NULL AND opening_balance <> 0 '
      '     THEN 1 ELSE 0 END FROM customer WHERE id = ?) AS n',
      <Object>[id, id, id],
    );
    return ((rows.first['n'] as int?) ?? 0) > 0;
  }

  // ── الأرصدة (FR-03-02) ───────────────────────────────────────────

  /// قائمة العملاء مع أرصدتهم — سطر لكل (عميل × عملة)؛ العميل بلا أي
  /// حركة يظهر بسطر واحد برصيد صفر بعملة القاعدة.
  ///
  /// [search] يبحث بالاسم أو الهاتف (LIKE)، و[includeArchived] يضيف
  /// المؤرشفين (افتراضياً مستثنون — FR-03-09).
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
      WITH sale_dues AS (
        SELECT customer_id AS pid, currency_id AS cur, SUM(due_amount) AS amt
        FROM invoice
        WHERE doc_type = 'sale' AND status = 'completed'
          AND customer_id IS NOT NULL
        GROUP BY customer_id, currency_id
      ),
      return_credits AS (
        SELECT customer_id AS pid, currency_id AS cur, SUM(due_amount) AS amt
        FROM invoice
        WHERE doc_type = 'sale_return' AND status = 'completed'
          AND customer_id IS NOT NULL
        GROUP BY customer_id, currency_id
      ),
      receipts AS (
        SELECT customer_id AS pid, currency_id AS cur, SUM(amount) AS amt
        FROM cash_tx
        WHERE tx_type = 'receipt' AND is_voided = 0
          AND customer_id IS NOT NULL
        GROUP BY customer_id, currency_id
      ),
      openings AS (
        SELECT id AS pid, opening_balance_currency_id AS cur,
               opening_balance AS amt
        FROM customer
        WHERE opening_balance_currency_id IS NOT NULL
          AND opening_balance <> 0
      ),
      combined AS (
        SELECT pid, cur, amt FROM sale_dues
        UNION ALL SELECT pid, cur, -amt FROM return_credits
        UNION ALL SELECT pid, cur, -amt FROM receipts
        UNION ALL SELECT pid, cur, amt FROM openings
      ),
      per_currency AS (
        SELECT pid, cur, SUM(amt) AS bal
        FROM combined
        GROUP BY pid, cur
      ),
      last_pay AS (
        SELECT customer_id AS pid, currency_id AS cur, MAX(tx_date) AS d
        FROM cash_tx
        WHERE tx_type = 'receipt' AND is_voided = 0
          AND customer_id IS NOT NULL
        GROUP BY customer_id, currency_id
      ),
      oldest_open AS (
        SELECT customer_id AS pid, currency_id AS cur, MIN(issued_at) AS d
        FROM invoice
        WHERE doc_type = 'sale' AND status = 'completed'
          AND due_amount > 0 AND customer_id IS NOT NULL
        GROUP BY customer_id, currency_id
      )
      SELECT c.id AS party_id, c.name AS p_name, c.phone AS p_phone,
             cu.code AS cur_code,
             COALESCE(pc.bal, 0) AS balance,
             lp.d AS last_payment_date,
             oo.d AS oldest_open_invoice_date
      FROM customer c
      LEFT JOIN per_currency pc ON pc.pid = c.id
      LEFT JOIN currency cu
        ON cu.id = CASE WHEN pc.cur IS NULL THEN ? ELSE pc.cur END
      LEFT JOIN last_pay lp ON lp.pid = c.id AND lp.cur = pc.cur
      LEFT JOIN oldest_open oo ON oo.pid = c.id AND oo.cur = pc.cur
      WHERE (? = 1 OR c.is_archived = 0)
        AND (? IS NULL OR c.name LIKE '%' || ? || '%'
                       OR c.phone LIKE '%' || ? || '%')
      ORDER BY c.name COLLATE NOCASE ASC, cur_code ASC
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

  /// رصيد العميل في عملة واحدة — صيغة FR-03-02 حصراً (0 عند لا حركة).
  Future<double> balanceInCurrency(int customerId, int currencyId) async {
    final rows = await _db.rawQuery(
      'SELECT '
      ' COALESCE((SELECT SUM(due_amount) FROM invoice '
      "   WHERE doc_type = 'sale' AND status = 'completed' "
      '     AND customer_id = ? AND currency_id = ?), 0) '
      ' - COALESCE((SELECT SUM(due_amount) FROM invoice '
      "   WHERE doc_type = 'sale_return' AND status = 'completed' "
      '     AND customer_id = ? AND currency_id = ?), 0) '
      ' - COALESCE((SELECT SUM(amount) FROM cash_tx '
      "   WHERE tx_type = 'receipt' AND is_voided = 0 "
      '     AND customer_id = ? AND currency_id = ?), 0) '
      ' + COALESCE((SELECT CASE WHEN opening_balance_currency_id = ? '
      '     THEN opening_balance ELSE 0 END '
      '   FROM customer WHERE id = ?), 0) AS balance',
      <Object>[
        customerId,
        currencyId,
        customerId,
        currencyId,
        customerId,
        currencyId,
        currencyId,
        customerId,
      ],
    );
    return (rows.first['balance'] as num?)?.toDouble() ?? 0;
  }

  /// الأعمال المتعثرة (FR-03-06): العملاء برصيد موجب (>= [minBalance])
  /// في أي عملة، مرتَّبين بأقدم فاتورة آجلة مفتوحة تصاعدياً، مع
  /// [PartyBalance.daysLate] منذ أقدم فاتورة («متأخر منذ X يوماً»).
  ///
  /// [now] لحظة الاحتساب (تُمرَّر صريحة في الاختبارات؛ الافتراضي الآن).
  Future<List<PartyBalance>> receivablesList({
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

  // ── حد الائتمان (FR-03-05) ───────────────────────────────────────

  /// يفحص حد الائتمان لفاتورة آجلة جديدة بعملة [currencyId]:
  /// - حد `null` (بلا حد): لا تجاوز أبداً.
  /// - حد `0`: أي آجل تجاوز (الرصيد + الإضافة > 0).
  /// - قيمة موجبة: التجاوز عند (الرصيد + [additionalAmount]) > الحد.
  ///
  /// العميل غير الموجود يُعامل كـ «بلا حد» (رصيد 0) — الوجودية تُفحص
  /// في الواجهة قبل الاستدعاء.
  Future<({double balance, double? creditLimit, bool overLimit})> checkCredit(
    int customerId,
    int currencyId,
    double additionalAmount,
  ) async {
    final rows = await _db.query(
      'customer',
      columns: ['credit_limit'],
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    final limit = rows.isEmpty
        ? null
        : (rows.first['credit_limit'] as num?)?.toDouble();
    final balance = await balanceInCurrency(customerId, currencyId);
    final over = limit == null ? false : balance + additionalAmount > limit;
    return (balance: balance, creditLimit: limit, overLimit: over);
  }

  // ── كشف الحساب (FR-03-04) ────────────────────────────────────────

  /// كشف حساب العميل بعملة واحدة وفترة اختيارية:
  /// فواتير البيع الآجلة (+)، سندات القبض (−)، مرتجعات البيع الآجلة (−)،
  /// والرصيد الافتتاحي عند تطابق عملته (بتماريخ تسجيله).
  ///
  /// القيود قبل [from] تُجمَّع في قيد «رصيد ماضٍ» واحد أول الكشف،
  /// والقيود بعد [to] تُستبعد. `finalBalance` تطابق `balanceInCurrency`
  /// عند غياب [to].
  ///
  /// ملاحظة عرض: فواتير الكاش التامة (due_amount = 0) لا تُنشئ قيداً في
  /// حساب الطرف فتُستبعد — الكشف حساب دَين لا سجل مبيعات.
  Future<StatementResult> statement(
    int customerId, {
    required int currencyId,
    DateTime? from,
    DateTime? to,
  }) async {
    final currencyCode = await _currencyCode(currencyId);
    final raw = await _statementRows(customerId, currencyId);
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

  /// قيود كشف حساب العميل خاماً — الافتتاحي (عند تطابق العملة) ثم
  /// الحركات، مرتَّبة زمنياً (التاريخ، ثم نوع القيد، ثم المعرّف).
  Future<List<_StatementRow>> _statementRows(
    int customerId,
    int currencyId,
  ) async {
    final raw = <_StatementRow>[];
    final customerRows = await _db.query(
      'customer',
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (customerRows.isNotEmpty) {
      final row = customerRows.first;
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
        SELECT issued_at AS d, 'invoice' AS kind, invoice_no AS doc_no,
               due_amount AS amt, id AS ref_id
        FROM invoice
        WHERE doc_type = 'sale' AND status = 'completed'
          AND customer_id = ? AND currency_id = ? AND due_amount <> 0
        UNION ALL
        SELECT issued_at, 'sale_return', invoice_no, -due_amount, id
        FROM invoice
        WHERE doc_type = 'sale_return' AND status = 'completed'
          AND customer_id = ? AND currency_id = ? AND due_amount <> 0
        UNION ALL
        SELECT tx_date, 'receipt', voucher_no, -amount, id
        FROM cash_tx
        WHERE tx_type = 'receipt' AND is_voided = 0
          AND customer_id = ? AND currency_id = ?
      ) ORDER BY d ASC,
          CASE kind WHEN 'invoice' THEN 0 WHEN 'sale_return' THEN 1 ELSE 2 END ASC,
          ref_id ASC
      ''',
      <Object>[
        customerId,
        currencyId,
        customerId,
        currencyId,
        customerId,
        currencyId,
      ],
    );
    raw.addAll(<_StatementRow>[
      for (final row in movementRows)
        _StatementRow(
          dateStr: row['d'] as String,
          rank: (row['kind'] as String) == 'invoice'
              ? 1
              : (row['kind'] as String) == 'sale_return'
              ? 2
              : 3,
          refId: row['ref_id'] as int?,
          code: (row['kind'] as String) == 'invoice'
              ? StatementEntryCode.invoice
              : (row['kind'] as String) == 'sale_return'
              ? StatementEntryCode.saleReturn
              : StatementEntryCode.receipt,
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

  /// تحقق مسودة العميل المشترك بين الإنشاء والتعديل — أو رسالة الخطأ.
  String? _validate(CustomerDraft draft, {required String label}) {
    if (draft.name.trim().isEmpty) {
      return 'اسم $label مطلوب — أدخل الاسم ثم احفظ.';
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
    CustomerDraft draft,
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
