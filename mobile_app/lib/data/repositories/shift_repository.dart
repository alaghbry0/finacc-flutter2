/// مستودع الوردية (FR-04-04 — الشريحة 9): فتح/إقفال الوردية بالمعادلة
/// الشاملة على جدول `shift` القائم في المخطط.
///
/// ## المعادلة الشاملة (SRS حرفياً):
/// المتوقع = رصيد افتتاحي + Σ الوارد خلال النافذة − Σ الصادر:
/// - **وارد (+)**: مبيعات نقدية + تحصيلات + إيداعات مالك + تحويلات
///   واردة + إيداعات بنكية + شيكات محصّلة.
/// - **صادر (−)**: مدفوعات موردين + مصاريف + مسحوبات مالك + تحويلات
///   صادرة + سحب بنكي + شيكات مصروفة محصّلة.
///
/// ## قرارات معمارية موثقة (هذه الشريحة):
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
/// 3. **الشيكات مؤجلة لوحدة V1.1 (§11)**: `chequesCleared`/`chequesPaid`
///    = 0 دائماً في V1 — تظهر صفرية في الواجهة والتقرير.
/// 4. **دلاء التصنيف**:
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
/// 5. **الإبطال والمعاكسة** مثل كل أرصدة النقدية: `is_voided=1` مستبعدة
///    دائماً والحركات المعاكسة (`reversal_of` غير فارغ) مستبعدة —
///    أثر الثنائي صفر (FR-04-08).
/// 6. **الفارق** = المعدود − المتوقع (موجب = زيادة، سالب = عجز) —
///    يُسجَّل ولا يُمنع شيء أبداً (نفس فلسفة الرصيد السالب FR-04-09).
/// 7. نافذة المعادلة **مغلقة على تاريخ الحركة** `tx_date` بمقارنة
///    سلاسل ISO-UTC المتجانسة (`>= from AND <= to`) — كل كتابة
///    `cash_tx` في التطبيق تُخزَّن بالصيغة نفسها فالمقارنة المعجمية
///    سليمة زمنياً.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/services/purchase_pricing.dart' show roundMoney;

/// صف الوردية — مرآة جدول `shift` في المخطط (لا تعديل عليه).
class ShiftRow {
  const ShiftRow({
    required this.id,
    required this.cashboxId,
    this.userId,
    required this.openedAt,
    this.closedAt,
    this.openingCount,
    this.expected,
    this.counted,
    this.difference,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory ShiftRow.fromMap(Map<String, Object?> map) => ShiftRow(
    id: map['id'] as int,
    cashboxId: map['cashbox_id'] as int,
    userId: map['user_id'] as int?,
    openedAt: map['opened_at'] as String,
    closedAt: map['closed_at'] as String?,
    openingCount: (map['opening_count'] as num?)?.toDouble(),
    expected: (map['expected'] as num?)?.toDouble(),
    counted: (map['counted'] as num?)?.toDouble(),
    difference: (map['difference'] as num?)?.toDouble(),
    notes: map['notes'] as String?,
    createdAt: map['created_at'] as String?,
    updatedAt: map['updated_at'] as String?,
  );

  final int id;
  final int cashboxId;
  final int? userId;
  final String openedAt;
  final String? closedAt;
  final double? openingCount;
  final double? expected;
  final double? counted;
  final double? difference;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  /// هل الوردية ما تزال مفتوحة؟
  bool get isOpen => closedAt == null;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'cashbox_id': cashboxId,
    'user_id': userId,
    'opened_at': openedAt,
    'closed_at': closedAt,
    'opening_count': openingCount,
    'expected': expected,
    'counted': counted,
    'difference': difference,
    'notes': notes,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

/// بنود المعادلة الشاملة — كل مكون **بعملة الصندوق** (دلو nativeBalance).
///
/// مكونات الوارد والصادر قيم موجبة (مقادير)، و`other` موقعي صافٍ
/// (موجب = صافي وارد) — انظر القرار 4 برأس الملف.
class ShiftEquation {
  const ShiftEquation({
    required this.cashSales,
    required this.collections,
    required this.ownerDeposits,
    required this.transfersIn,
    required this.bankIn,
    required this.chequesCleared,
    required this.supplierPayments,
    required this.expenses,
    required this.ownerDraws,
    required this.transfersOut,
    required this.bankOut,
    required this.chequesPaid,
    required this.other,
  });

  /// معادلة صفرية — وردية بلا أي حركة.
  const ShiftEquation.empty()
    : cashSales = 0,
      collections = 0,
      ownerDeposits = 0,
      transfersIn = 0,
      bankIn = 0,
      chequesCleared = 0,
      supplierPayments = 0,
      expenses = 0,
      ownerDraws = 0,
      transfersOut = 0,
      bankOut = 0,
      chequesPaid = 0,
      other = 0;

  /// مبيعات نقدية — سندات قبض فواتير البيع وقت الإصدار.
  final double cashSales;

  /// تحصيلات — سندات قبض العملاء (FIFO/على الحساب).
  final double collections;

  /// إيداعات المالك (`capital_in`).
  final double ownerDeposits;

  /// تحويلات واردة — ساق الهدف لكل ذات الساقين (بعملة الهدف).
  final double transfersIn;

  /// إيداعات بنكية — دائماً 0 في V1: **لا عمود بنك في جدول cashbox**
  /// فالساقات البنكية مدمجة في [transfersIn] (القرار 2 برأس الملف).
  final double bankIn;

  /// شيكات محصّلة — مؤجلة إلى V1.1 (وحدة الشيكات §11) — دائماً 0.
  final double chequesCleared;

  /// مدفوعات موردين (`payment` غير مرتبطة بردّ مرتجع بيع).
  final double supplierPayments;

  /// مصاريف (`expense`).
  final double expenses;

  /// مسحوبات المالك (`owner_draw`).
  final double ownerDraws;

  /// تحويلات صادرة — ساق المصدر لكل ذات الساقين (بعملة المصدر).
  final double transfersOut;

  /// سحب بنكي — دائماً 0 في V1: مدمج في [transfersOut] (القرار 2).
  final double bankOut;

  /// شيكات مصروفة محصّلة — مؤجلة إلى V1.1 — دائماً 0.
  final double chequesPaid;

  /// استردادات مرتجعات الشراء النقدية (+) وردود مرتجعات البيع (−)
  /// وأنواع الرواتب المؤجلة (−) — موقعاً صافياً حتى لا يختفي شيء من
  /// المعادلة الشاملة (القرار 4).
  final double other;

  /// إجمالي الوارد (مقادير موجبة).
  double get totalIn =>
      cashSales +
      collections +
      ownerDeposits +
      transfersIn +
      bankIn +
      chequesCleared;

  /// إجمالي الصادر (مقادير موجبة).
  double get totalOut =>
      supplierPayments +
      expenses +
      ownerDraws +
      transfersOut +
      bankOut +
      chequesPaid;

  /// صافي التدفق المتوقع خلال النافذة = Σ الوارد − Σ الصادر + أخرى.
  double get expectedDelta => roundMoney(totalIn - totalOut + other);
}

/// ناتج الإقفال — الصف المحدَّث + المعادلة التي أُقفل عليها.
class ShiftCloseResult {
  const ShiftCloseResult({required this.shift, required this.equation});

  /// صف الوردية بعد الإقفال (expected/counted/difference مسجَّلة).
  final ShiftRow shift;

  /// المعادلة لحظة الإقفال (نافذة [opened_at, closed_at]).
  final ShiftEquation equation;
}

/// مستودع الوردية — فتح/إقفال/معادلة/سجل، فوق قاعدة مفتوحة.
class ShiftRepository {
  ShiftRepository(Database db) : _db = db;

  final Database _db;

  // ─────────────────────────────────────────────────────────────────────
  // دورة الحياة (FR-04-04)
  // ─────────────────────────────────────────────────────────────────────

  /// يفتح وردية على الصندوق برصيد افتتاحي مُعدّ (افتراضي 0) — حارس
  /// الرفض: وردية مفتوحة قائمة على نفس الصندوق.
  Future<Result<ShiftRow, String>> openShift({
    required int cashboxId,
    double? openingCount,
    int? userId,
  }) async {
    try {
      final at = DateTime.now().toUtc().toIso8601String();
      return await _db.transaction((txn) async {
        final open = await txn.query(
          'shift',
          columns: ['id'],
          where: 'cashbox_id = ? AND closed_at IS NULL',
          whereArgs: [cashboxId],
          limit: 1,
        );
        if (open.isNotEmpty) {
          return const Err(
            'توجد وردية مفتوحة على هذا الصندوق بالفعل — أقفلها قبل فتح '
            'وردية جديدة.',
          );
        }
        final id = await txn.insert('shift', {
          'cashbox_id': cashboxId,
          'user_id': userId,
          'opened_at': at,
          'opening_count': openingCount ?? 0,
          'created_at': at,
          'updated_at': at,
        });
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'shift_open',
          'entity': 'shift',
          'entity_id': id,
          'details': 'box=$cashboxId opening=${openingCount ?? 0}',
          'at': at,
        });
        return Ok<ShiftRow, String>(
          ShiftRow(
            id: id,
            cashboxId: cashboxId,
            userId: userId,
            openedAt: at,
            openingCount: openingCount ?? 0,
            createdAt: at,
            updatedAt: at,
          ),
        );
      });
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e, 'فتح الوردية'));
    }
  }

  /// الوردية المفتوحة على الصندوق — `null` إن لا توجد.
  Future<ShiftRow?> currentShift(int cashboxId) async {
    final rows = await _db.query(
      'shift',
      where: 'cashbox_id = ? AND closed_at IS NULL',
      whereArgs: [cashboxId],
      orderBy: 'opened_at DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ShiftRow.fromMap(rows.first);
  }

  /// صف وردية بمعرّفها — `null` إن لم توجد.
  Future<ShiftRow?> shiftById(int id) async {
    final rows = await _db.query(
      'shift',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ShiftRow.fromMap(rows.first);
  }

  /// آخر الورديات المقفلة على الصندوق (الأحدث أولاً).
  Future<List<ShiftRow>> recentShifts({
    required int cashboxId,
    int limit = 20,
  }) async {
    final rows = await _db.query(
      'shift',
      where: 'cashbox_id = ? AND closed_at IS NOT NULL',
      whereArgs: [cashboxId],
      orderBy: 'closed_at DESC, id DESC',
      limit: limit,
    );
    return [for (final row in rows) ShiftRow.fromMap(row)];
  }

  // ─────────────────────────────────────────────────────────────────────
  // المعادلة الشاملة (FR-04-04)
  // ─────────────────────────────────────────────────────────────────────

  /// يحسب المعادلة الشاملة لصندوق خلال نافذة [fromIso, toIso] (سلاسل
  /// ISO-UTC) — بعملة الصندوق، مع استبعاد الملغاة/المعاكسة/الافتتاحية
  /// (القرارات 1/4/5 برأس الملف).
  Future<ShiftEquation> equationFor({
    required int cashboxId,
    required String fromIso,
    required String toIso,
  }) async {
    return _equationFor(
      _db,
      cashboxId: cashboxId,
      fromIso: fromIso,
      toIso: toIso,
    );
  }

  /// يُقفل الوردية ذرّياً داخل معاملة واحدة: يحسب المعادلة على نافذة
  /// [opened_at, الآن] ثم يحدّث expected/counted/difference/notes
  /// ويكتب قيد التدقيق — فشل أي خطوة يتراجع الكل.
  ///
  /// المتوقع = الرصيد الافتتاحي + Σ الوارد − Σ الصادر (+ أخرى الموقعية)،
  /// والفرق = المعدود − المتوقع (زيادة/عجز — القرار 6).
  Future<Result<ShiftCloseResult, String>> closeShift({
    required int shiftId,
    required double counted,
    String? notes,
  }) async {
    if (counted.isNaN || counted.isInfinite) {
      return const Err('المبلغ المعدود غير صالح — أدخل رقماً صحيحاً.');
    }
    try {
      return await _db.transaction((txn) async {
        final rows = await txn.query(
          'shift',
          where: 'id = ?',
          whereArgs: [shiftId],
          limit: 1,
        );
        if (rows.isEmpty) {
          return Err('الوردية رقم #$shiftId غير موجودة.');
        }
        final current = ShiftRow.fromMap(rows.first);
        if (current.isOpen) {
          final now = _nowIso();
          final equation = await _equationFor(
            txn,
            cashboxId: current.cashboxId,
            fromIso: current.openedAt,
            toIso: now,
          );
          final opening = current.openingCount ?? 0;
          final expected = roundMoney(opening + equation.expectedDelta);
          final difference = roundMoney(counted - expected);
          final cleanNotes = (notes ?? '').trim();
          final updated = await txn.update(
            'shift',
            {
              'closed_at': now,
              'expected': expected,
              'counted': roundMoney(counted),
              'difference': difference,
              'notes': cleanNotes.isEmpty ? null : cleanNotes,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [shiftId],
          );
          if (updated == 0) {
            return const Err('تعذّر إقفال الوردية — أعد المحاولة.');
          }
          await txn.insert('audit_log', {
            'user_id': current.userId,
            'action': 'shift_close',
            'entity': 'shift',
            'entity_id': shiftId,
            'details':
                'box=${current.cashboxId} expected=$expected '
                'counted=${roundMoney(counted)} difference=$difference',
            'at': now,
          });
          return Ok<ShiftCloseResult, String>(
            ShiftCloseResult(
              shift: ShiftRow(
                id: current.id,
                cashboxId: current.cashboxId,
                userId: current.userId,
                openedAt: current.openedAt,
                closedAt: now,
                openingCount: opening,
                expected: expected,
                counted: roundMoney(counted),
                difference: difference,
                notes: cleanNotes.isEmpty ? null : cleanNotes,
                createdAt: current.createdAt,
                updatedAt: now,
              ),
              equation: equation,
            ),
          );
        }
        return const Err('هذه الوردية مقفلة مسبقاً — لا تُقفل مرتين.');
      });
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e, 'إقفال الوردية'));
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // السباكة الداخلية
  // ─────────────────────────────────────────────────────────────────────

  /// الاستعلام الموحد للمعادلة — يعمل فوق اتصال أو معاملة (الذرّية).
  ///
  /// الساقات الثلاث مطابقة لاستعلام رصيد `listBoxes` في
  /// `cash_repository` (تحويل العملة حرفياً — القرار 1) مقيّدة بنافذة
  /// `tx_date` وصندوق واحد، والتجميع الخارجي لا يقرأ إلا دلو عملة
  /// الصندوق (`cur = (SELECT currency_id …)`) — **معرّف العملة يُستخرج
  /// من صف الصندوق نفسه** لا من معرّف الصندوق (المعرّفان مستقلان).
  Future<ShiftEquation> _equationFor(
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

  static double _money(Object? value) {
    final num? n = value as num?;
    if (n == null) return 0;
    final d = n.toDouble();
    if (d.isNaN || d.isInfinite) return 0;
    return roundMoney(d);
  }

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  static String _describeDbError(DatabaseException e, String action) {
    if (e.isUniqueConstraintError()) {
      return 'قيمة مكررة تخالف قيد التفرد أثناء $action';
    }
    if (e.toString().toUpperCase().contains('CHECK')) {
      return 'قيمة تخالف قيد سلامة محاسبي في القاعدة أثناء $action';
    }
    return 'تعذر $action في القاعدة: $e';
  }
}
