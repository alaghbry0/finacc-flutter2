/// محرك النقدية والصناديق — جداول `cashbox` / `cash_tx` /
/// `expense_category` / `payment_allocation` — الوحدة 04 (FR-04).
///
/// **الخريطة الملزمة** (ملحق و + قواعد 5.4-1/4/6/7): كل كتابة معاملة
/// ذرّية واحدة (سند مرقّم RVT/PMT عبر doc_sequence + الحركة + تحديث
/// دفاتر الفواتير المخصصة + قيد التدقيق) — فشل أي خطوة يرجع الكل.
///
/// ## إشارات الأرصدة (ملحق و — حرفياً):
/// - **وارد (+) على `cashbox_id`**: receipt / capital_in / opening.
/// - **صادر (−) على `cashbox_id`**: payment / expense / owner_draw.
/// - **ذات الساقين** (box_transfer / bank_deposit / bank_withdraw):
///   `cashbox_id` = المصدر (−) و`to_cashbox_id` = الهدف (+ بالمبلغ
///   المحوّل `amount × settlement_rate` بعملة الهدف لحظة التحويل —
///   FR-04-07). البنك مجرد صندوق أنشأه المستخدم باسم بنك.
/// - **`is_voided = 1` تُستبعد دائماً** من كل الأرصدة، **والحركات
///   المعاكسة** (`reversal_of` غير فارغ) تُستبعد كذلك — فأثر الثنائي
///   (الأصل + معاكسته) على الأرصدة صفر، والمعاكسة تبقى ظاهرة في
///   السجل للتدقيق (FR-04-08).
/// - الرصيد **يجوز أن يكون سالباً** (FR-04-09) — التحذير مسؤولية
///   الواجهة، لا منع هنا أبداً.
///
/// ## اصطلاحات موثقة (قرارات معمارية لهذه الشريحة):
/// 1. **دلاء العملة**: رصيد الصندوق يُحسب **لكل عملة على حدة** (فصل
///    العملات 5.4-7): الحركة بعملة الصندوق تدلو عملتها، والساق الواردة
///    للتحويل تدلو عملة الهدف، وسند العملة المخالفة لعملة صندوقه
///    (`settlement_rate`) يدلو عملة الصندوق بالمبلغ المحوّل.
/// 2. **السند المخصص (FIFO)** يتبع حرفياً نمط تحصيل الإصدار في
///    `sale_repository`: تحديث `invoice.due_amount/paid_amount` +
///    صفوف `payment_allocation` + `customer_id/supplier_id = NULL`
///    (حتى لا تخصمه صيغ رصيد الطرف مرتين — نفس القرار الموثق هناك).
///    **السند الحر** «على الحساب» يحمل `customer_id/supplier_id` فيخصم
///    من رصيد الطرف مباشرة عبر صيغ FR-03-02/03 القائمة (`ref_type=
///    'on_account'`).
/// 3. **المديونية المفتوحة** لفاتورة = `due_amount − Σ تخصيصات السندات
///    المرقمة الحية عليها` — تخصيص الإصدار/المرتجع (`voucher_no` فارغ)
///    مستهلك داخل `due_amount` أصلاً فلا يُخصم مرتين (قاعدة 5.4-6).
/// 4. **السند بعملة مخالفة لعملة الصندوق** (عملة الطرف عبر صندوق مختلف
///    العملة): `currency_id` = عملة السند، `amount` = مبلغ الدين
///    المُسدَّد، `exchange_rate` = سعر يوم السند، `settlement_rate` =
///    (سعر عملة السند ÷ سعر عملة الصندوق) — وهو ما يُودع فعلياً في
///    الصندوق (`amount × settlement_rate` بعملة الصندوق) — والفرق عن
///    القيمة الدفترية للدين (`invoice.exchange_rate`) في `fx_gain_loss`
///    **بالعملة الأساسية** (قاعدة 5.4-7: «يُحسب الفرق في fx_gain_loss»).
/// 5. **التحويل بعملتين**: صف واحد بمبلغ المصدر؛ الهدف يستقبل
///    `amount × settlement_rate` بعملته؛ `fx_gain_loss` = (قيمة الوارد
///    بالأساس) − (قيمة الخارج بالأساس) — صفر عند التحويل بسعر اليوم
///    (فرق الصرّاف يُسجَّل مصروفاً مستقلاً إذا لزم — قرار V1).
/// 6. **الإبطال** (FR-04-08): لا حذف ولا تعديل — حركة معاكسة داخل
///    معاملة واحدة + `is_voided=1` على الأصل + استرجاع دفاتر الفواتير
///    وحذف روابط `payment_allocation` (رابط تخصيص لا حركة مالية) +
///    قيد تدقيق. **الرقم المرقّم لا يُعاد أبداً** (استمرارية الترقيم).
///    الحركات المرتبطة بمستند آخر (تحصيل الإصدار/رد المرتجع —
///    `ref_type='invoice'` مع `ref_id`) تُبطل عبر مستنداتها لا هنا.
/// 7. **سياسة FX المفقود** (FR-08-09): عملة غير الأساس بلا سعر اليوم →
///    رفض، إلا `fx.fallback=last_known` فيُستخدم آخر سعر معروف —
///    نفس نمط البيع/الشراء حرفياً.
/// 8. الوردية (shift) مؤجلة للشريحة 9 — لا كتابة لها هنا.
library;

import 'package:sqflite/sqflite.dart';

import '../../core/storage/doc_sequence.dart';
import '../../domain/core/result.dart';
import '../../domain/models/cash.dart';
import '../../domain/services/purchase_pricing.dart'
    show moneyEpsilon, roundMoney;
import 'exchange_rate_repository.dart';
import 'settings_repository.dart';

/// فشل تدفق داخلي برسالة عربية نظيفة — رميه داخل المعاملة يتراجعها
/// كاملة (نمط المستودعات القائمة).
class _FlowError implements Exception {
  const _FlowError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// سعر يوم مع سياسة الاحتياط — مخرج محلل الأسعار.
class _DayRate {
  const _DayRate(this.rate, this.fallback);
  final double rate;
  final bool fallback;
}

/// مستودع النقدية — الصناديق والفئات والسندات والحركات والإبطال.
class CashRepository {
  /// يبنى فوق قاعدة مفتوحة؛ يركّب المستودعات الشريكة فوق نفس القاعدة.
  CashRepository(Database db)
    : _db = db,
      _rates = ExchangeRateRepository(db),
      _settings = SettingsRepository(db);

  final Database _db;
  final ExchangeRateRepository _rates;
  final SettingsRepository _settings;

  // ─────────────────────────────────────────────────────────────────────
  // البذر (FR-04-05) والفئات
  // ─────────────────────────────────────────────────────────────────────

  /// بذر **idempotent** لفئة «رواتب» (بديل وحدة الموظفين المؤجلة —
  /// SRS §9) — يُستدعى عند إقلاع الجلسة؛ التنفيذ شرطي فلا يكرر أبداً.
  Future<void> ensureSeeded() async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.rawInsert(
      "INSERT INTO expense_category(name, is_archived, created_at, updated_at) "
      "SELECT 'رواتب', 0, ?, ? WHERE NOT EXISTS "
      "(SELECT 1 FROM expense_category WHERE name = 'رواتب')",
      <Object>[now, now],
    );
  }

  /// فئات المصاريف (FR-04-05) — «رواتب» أولاً ومحمية من الأرشفة.
  Future<List<ExpenseCategoryInfo>> listCategories({
    bool includeArchived = false,
  }) async {
    final rows = await _db.query(
      'expense_category',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy:
          "CASE WHEN name = 'رواتب' THEN 0 ELSE 1 END, name COLLATE NOCASE",
    );
    return [
      for (final row in rows)
        ExpenseCategoryInfo.fromRow({
          ...row,
          'is_protected': (row['name'] as String) == 'رواتب' ? 1 : 0,
        }),
    ];
  }

  /// إضافة فئة — الاسم المكرر المؤرشف يُوقظ بدل الرفض (إضافة idempotent).
  Future<Result<ExpenseCategoryInfo, String>> addCategory(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      return const Err('اسم فئة المصروف مطلوب — أدخل الاسم ثم احفظ.');
    }
    try {
      final at = DateTime.now().toUtc().toIso8601String();
      return await _db.transaction((txn) async {
        final existing = await txn.query(
          'expense_category',
          where: 'name = ? COLLATE NOCASE',
          whereArgs: [clean],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final row = existing.first;
          if ((row['is_archived'] as int? ?? 0) == 1) {
            await txn.update(
              'expense_category',
              {'is_archived': 0, 'updated_at': at},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
            return Ok<ExpenseCategoryInfo, String>(
              ExpenseCategoryInfo.fromRow({
                ...row,
                'is_archived': 0,
                'is_protected': 0,
              }),
            );
          }
          return Err(
            'فئة «$clean» موجودة مسبقاً — اختر اسماً آخر أو استخدمها.',
          );
        }
        final id = await txn.insert('expense_category', {
          'name': clean,
          'is_archived': 0,
          'created_at': at,
          'updated_at': at,
        });
        return Ok<ExpenseCategoryInfo, String>(
          ExpenseCategoryInfo(
            id: id,
            name: clean,
            isArchived: false,
            isProtected: false,
          ),
        );
      });
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e, 'حفظ الفئة'));
    }
  }

  /// إعادة تسمية فئة.
  Future<Result<ExpenseCategoryInfo, String>> renameCategory(
    int id,
    String name,
  ) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      return const Err('اسم فئة المصروف مطلوب — أدخل الاسم ثم احفظ.');
    }
    try {
      final rows = await _db.query(
        'expense_category',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        return Err('الفئة رقم #$id غير موجودة.');
      }
      final dup = await _db.query(
        'expense_category',
        where: 'name = ? COLLATE NOCASE AND id <> ?',
        whereArgs: [clean, id],
        limit: 1,
      );
      if (dup.isNotEmpty) {
        return Err('فئة «$clean» موجودة مسبقاً — اختر اسماً آخر.');
      }
      await _db.update(
        'expense_category',
        {'name': clean, 'updated_at': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      return Ok<ExpenseCategoryInfo, String>(
        ExpenseCategoryInfo.fromRow({
          ...rows.first,
          'name': clean,
          'is_protected': clean == 'رواتب' ? 1 : 0,
        }),
      );
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e, 'تعديل الفئة'));
    }
  }

  /// أرشفة فئة — «رواتب» محمية (بديل V1 لوحدة الموظفين).
  Future<Result<void, String>> archiveCategory(int id) async {
    final rows = await _db.query(
      'expense_category',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return Err('الفئة رقم #$id غير موجودة.');
    }
    if ((rows.first['name'] as String) == 'رواتب') {
      return const Err(
        'فئة «رواتب» افتراضية نظامية — لا تُؤرشف (بديل الرواتب في V1).',
      );
    }
    await _db.update(
      'expense_category',
      {
        'is_archived': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return const Ok<void, String>(null);
  }

  /// إلغاء أرشفة فئة.
  Future<Result<void, String>> unarchiveCategory(int id) async {
    await _db.update(
      'expense_category',
      {
        'is_archived': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return const Ok<void, String>(null);
  }

  // ─────────────────────────────────────────────────────────────────────
  // الصناديق وأرصدتها الحية (FR-04-01/06/09)
  // ─────────────────────────────────────────────────────────────────────

  /// الصناديق بأرصدتها الحية — رصيد بعملة الصندوق + دلاء العملات الأخرى
  /// (إشارات ملحق و — انظر رأس الملف). السالب مسموح ويعود للواجهة.
  Future<List<CashboxWithBalance>> listBoxes({
    bool includeArchived = false,
  }) async {
    final rows = await _db.rawQuery(
      '''
      WITH legs AS (
        -- حركات ذات ساق واحدة (بعملتها أو بعملة صندوقها عند settlement)
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
        -- الساق الصادرة من المصدر (بعملة المصدر دائماً)
        SELECT t.cashbox_id, t.currency_id, -t.amount
        FROM cash_tx t
        WHERE t.is_voided = 0 AND t.reversal_of IS NULL
          AND t.tx_type IN ('box_transfer','bank_deposit','bank_withdraw')
        UNION ALL
        -- الساق الواردة إلى الهدف (بعملة الهدف وبالمبلغ المحوّل)
        SELECT t.to_cashbox_id, tc.currency_id,
               t.amount * COALESCE(t.settlement_rate, 1)
        FROM cash_tx t
        JOIN cashbox tc ON tc.id = t.to_cashbox_id
        WHERE t.is_voided = 0 AND t.reversal_of IS NULL
          AND t.tx_type IN ('box_transfer','bank_deposit','bank_withdraw')
          AND t.to_cashbox_id IS NOT NULL
      )
      SELECT cb.id, cb.name, cb.currency_id, cb.is_default, cb.is_archived,
             cu.code AS currency_code, cu.is_base,
             b.cur AS bucket_cur, bc.code AS bucket_code, b.amt AS bucket_amt
      FROM cashbox cb
      JOIN currency cu ON cu.id = cb.currency_id
      LEFT JOIN (
        SELECT box, cur, SUM(amt) AS amt FROM legs GROUP BY box, cur
      ) b ON b.box = cb.id
      LEFT JOIN currency bc ON bc.id = b.cur
      WHERE (? = 1 OR cb.is_archived = 0)
      ORDER BY cb.is_default DESC, cb.name COLLATE NOCASE ASC
    ''',
      <Object?>[includeArchived ? 1 : 0],
    );

    final bucketCodes = <int, String?>{
      for (final row in rows)
        if (row['bucket_cur'] != null)
          row['bucket_cur'] as int: row['bucket_code'] as String?,
    };
    final byBox = <int, _BoxAgg>{};
    for (final row in rows) {
      final id = row['id'] as int;
      var agg = byBox[id];
      if (agg == null) {
        agg = _BoxAgg(
          CashboxInfo(
            id: id,
            name: row['name'] as String,
            currencyId: row['currency_id'] as int,
            currencyCode: (row['currency_code'] as String?) ?? '',
            isDefault: (row['is_default'] as int? ?? 0) == 1,
            isArchived: (row['is_archived'] as int? ?? 0) == 1,
          ),
        );
        byBox[id] = agg;
      }
      final bucketCur = row['bucket_cur'] as int?;
      if (bucketCur != null) {
        final amount = (row['bucket_amt'] as num?)?.toDouble() ?? 0;
        agg.buckets[bucketCur] = (agg.buckets[bucketCur] ?? 0) + amount;
      }
    }
    return [
      for (final agg in byBox.values)
        CashboxWithBalance(
          box: agg.box,
          nativeBalance: agg.buckets[agg.box.currencyId] ?? 0,
          foreignBuckets: [
            for (final entry in agg.buckets.entries)
              if (entry.key != agg.box.currencyId)
                CashCurrencyBucket(
                  currencyId: entry.key,
                  currencyCode: bucketCodes[entry.key] ?? '',
                  amount: entry.value,
                ),
          ],
        ),
    ];
  }

  /// إضافة صندوق — العملة من عملات المنشأة (FR-04-01).
  Future<Result<CashboxInfo, String>> addBox(
    String name,
    int currencyId, {
    bool makeDefault = false,
    int? userId,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      return const Err('اسم الصندوق مطلوب — أدخل الاسم ثم احفظ.');
    }
    try {
      final at = DateTime.now().toUtc().toIso8601String();
      return await _db.transaction((txn) async {
        final currency = await txn.query(
          'currency',
          columns: ['code', 'is_active'],
          where: 'id = ?',
          whereArgs: [currencyId],
          limit: 1,
        );
        if (currency.isEmpty) {
          return Err('العملة رقم #$currencyId غير موجودة.');
        }
        if ((currency.first['is_active'] as int? ?? 0) == 0) {
          return const Err(
            'العملة غير مفعّلة — اختر عملة نشطة للصندوق (FR-04-01).',
          );
        }
        final code = currency.first['code'] as String;
        if (makeDefault) {
          await txn.update('cashbox', {
            'is_default': 0,
          }, where: 'is_default = 1');
        }
        final id = await txn.insert('cashbox', {
          'name': clean,
          'currency_id': currencyId,
          'is_default': makeDefault ? 1 : 0,
          'created_at': at,
          'updated_at': at,
        });
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'cashbox_create',
          'entity': 'cashbox',
          'entity_id': id,
          'details': 'name=$clean currency=$code default=$makeDefault',
          'at': at,
        });
        return Ok<CashboxInfo, String>(
          CashboxInfo(
            id: id,
            name: clean,
            currencyId: currencyId,
            currencyCode: code,
            isDefault: makeDefault,
            isArchived: false,
          ),
        );
      });
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e, 'حفظ الصندوق'));
    }
  }

  /// إعادة تسمية صندوق.
  Future<Result<void, String>> renameBox(int id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      return const Err('اسم الصندوق مطلوب — أدخل الاسم ثم احفظ.');
    }
    final updated = await _db.update(
      'cashbox',
      {'name': clean, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      return Err('الصندوق رقم #$id غير موجود.');
    }
    return const Ok<void, String>(null);
  }

  /// أرشفة صندوق (FR-04-01) — يُمنع الأرشفة للصندوق الافتراضي ولآخر
  /// صندوق نشط؛ الرصيد غير الصفري **لا يُمنع** (FR-04-09) لكن الواجهة
  /// تطلب تأكيداً صريحاً قبلها.
  Future<Result<void, String>> archiveBox(int id, {int? userId}) async {
    try {
      final at = DateTime.now().toUtc().toIso8601String();
      return await _db.transaction((txn) async {
        final rows = await txn.query(
          'cashbox',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) {
          return Err('الصندوق رقم #$id غير موجود.');
        }
        if ((rows.first['is_default'] as int? ?? 0) == 1) {
          return const Err(
            'هذا هو الصندوق الافتراضي — عيّن صندوقاً افتراضياً آخر '
            'قبل الأرشفة.',
          );
        }
        final active = await txn.rawQuery(
          'SELECT COUNT(*) AS n FROM cashbox WHERE is_archived = 0',
        );
        if ((active.first['n'] as int? ?? 0) <= 1) {
          return const Err('لا يمكن أرشفة آخر صندوق نشط في المنشأة.');
        }
        await txn.update(
          'cashbox',
          {'is_archived': 1, 'updated_at': at},
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'cashbox_archive',
          'entity': 'cashbox',
          'entity_id': id,
          'details': 'name=${rows.first['name']}',
          'at': at,
        });
        return const Ok<void, String>(null);
      });
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e, 'أرشفة الصندوق'));
    }
  }

  /// إلغاء أرشفة صندوق.
  Future<Result<void, String>> unarchiveBox(int id) async {
    final updated = await _db.update(
      'cashbox',
      {
        'is_archived': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      return Err('الصندوق رقم #$id غير موجود.');
    }
    return const Ok<void, String>(null);
  }

  /// تعيين الصندوق الافتراضي (FR-04-01) — ذرّياً (واحد فقط افتراضي).
  Future<Result<void, String>> setDefaultBox(int id, {int? userId}) async {
    try {
      final at = DateTime.now().toUtc().toIso8601String();
      return await _db.transaction((txn) async {
        final rows = await txn.query(
          'cashbox',
          columns: ['name'],
          where: 'id = ? AND is_archived = 0',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) {
          return const Err('الصندوق غير موجود أو مؤرشف — أزل الأرشفة أولاً.');
        }
        await txn.update(
          'cashbox',
          {'is_default': 0},
          where: 'is_default = 1 AND id <> ?',
          whereArgs: [id],
        );
        await txn.update(
          'cashbox',
          {'is_default': 1, 'updated_at': at},
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'cashbox_set_default',
          'entity': 'cashbox',
          'entity_id': id,
          'details': 'name=${rows.first['name']}',
          'at': at,
        });
        return const Ok<void, String>(null);
      });
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e, 'تعيين الصندوق الافتراضي'));
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // المديونيات المفتوحة للتخصيص FIFO (قاعدة 5.4-6 / FR-04-03)
  // ─────────────────────────────────────────────────────────────────────

  /// الفواتير المفتوحة لطرف بعملة — الأقدم أولاً (FIFO).
  ///
  /// المتبقي = `due_amount − تخصيصات السندات المرقمة الحية` (القرار 3).
  Future<List<OpenInvoiceLine>> openInvoicesForParty({
    required VoucherPartyType partyType,
    required int partyId,
    required int currencyId,
  }) async {
    final docType = partyType == VoucherPartyType.customer
        ? 'sale'
        : 'purchase';
    final partyColumn = partyType == VoucherPartyType.customer
        ? 'customer_id'
        : 'supplier_id';
    final rows = await _db.rawQuery(
      '''
      SELECT i.id, i.invoice_no, i.issued_at, i.due_amount,
             COALESCE((
               SELECT SUM(pa.allocated_amount)
               FROM payment_allocation pa
               JOIN cash_tx ct ON ct.id = pa.cash_tx_id
               WHERE pa.invoice_id = i.id
                 AND ct.voucher_no IS NOT NULL
                 AND ct.is_voided = 0
                 AND ct.reversal_of IS NULL
             ), 0) AS voucher_alloc
      FROM invoice i
      WHERE i.doc_type = ? AND i.status = 'completed'
        AND i.$partyColumn = ? AND i.currency_id = ?
        AND i.due_amount > 0
      ORDER BY i.issued_at ASC, i.id ASC
    ''',
      <Object?>[docType, partyId, currencyId],
    );
    return [
      for (final row in rows)
        OpenInvoiceLine(
          invoiceId: row['id'] as int,
          invoiceNo: row['invoice_no'] as String,
          issuedAt: DateTime.parse(row['issued_at'] as String),
          dueAmount: (row['due_amount'] as num?)?.toDouble() ?? 0,
          voucherAllocated: (row['voucher_alloc'] as num?)?.toDouble() ?? 0,
        ),
    ].where((line) => line.remaining > moneyEpsilon).toList();
  }

  // ─────────────────────────────────────────────────────────────────────
  // السند المرقّم (FR-04-02/03/10) — قبض RVT / صرف PMT
  // ─────────────────────────────────────────────────────────────────────

  /// **ترحيل سند قبض/صرف** — معاملة ذرّية واحدة: رقم RVT/PMT + حركة
  /// الصندوق + تحديث دفاتر الفواتير المخصصة (FIFO) + صفوف التخصيص +
  /// قيد التدقيق (الخريطة برأس الملف — القرارات 2/3/4).
  Future<Result<VoucherPostedReceipt, String>> createVoucher(
    VoucherDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final txDate = draft.txDate;
    final txIso = txDate.toUtc().toIso8601String();
    final isReceipt = draft.partyType == VoucherPartyType.customer;

    if (draft.amount.isNaN ||
        draft.amount.isInfinite ||
        draft.amount <= moneyEpsilon) {
      return const Err('مبلغ السند يجب أن يكون رقماً أكبر من صفر.');
    }
    final amount = roundMoney(draft.amount);

    try {
      // (1) الصندوق + الطرف + الأسعار (خارج المعاملة — نمط البيع).
      final boxRows = await _db.query(
        'cashbox',
        columns: ['name', 'currency_id', 'is_archived'],
        where: 'id = ?',
        whereArgs: [draft.cashboxId],
        limit: 1,
      );
      if (boxRows.isEmpty) {
        return Err('الصندوق رقم #${draft.cashboxId} غير موجود.');
      }
      if ((boxRows.first['is_archived'] as int? ?? 0) == 1) {
        return Err(
          'الصندوق «${boxRows.first['name']}» مؤرشف — اختر صندوقاً نشطاً.',
        );
      }
      final boxCurrencyId = boxRows.first['currency_id'] as int;

      final partyTable = isReceipt ? 'customer' : 'supplier';
      final partyRows = await _db.query(
        partyTable,
        columns: ['name', 'is_archived'],
        where: 'id = ?',
        whereArgs: [draft.partyId],
        limit: 1,
      );
      if (partyRows.isEmpty) {
        return Err(
          '${isReceipt ? 'العميل' : 'المورد'} رقم #${draft.partyId} غير موجود.',
        );
      }
      if ((partyRows.first['is_archived'] as int? ?? 0) == 1) {
        return Err(
          '${isReceipt ? 'العميل' : 'المورد'} '
          '«${partyRows.first['name']}» مؤرشف — أزل الأرشفة أولاً.',
        );
      }
      final partyName = partyRows.first['name'] as String;

      final vRate = await _rateForDay(draft.currencyId, txDate);
      if (vRate == null) {
        return Err(_missingRateMessage(draft.currencyId));
      }
      final crossCurrency = draft.currencyId != boxCurrencyId;
      double? settlementRate;
      if (crossCurrency) {
        final boxRate = await _rateForDay(boxCurrencyId, txDate);
        if (boxRate == null) {
          return Err(_missingRateMessage(boxCurrencyId));
        }
        // settlement = وحدات عملة الصندوق لكل وحدة عملة السند.
        settlementRate = roundMoney(vRate.rate / boxRate.rate);
      }

      // (2) خطة التخصيص FIFO (قراءة خارج المعاملة؛ الحراسة داخلها).
      final plan = <VoucherAllocationApplied>[];
      if (draft.allocateFifo) {
        final open = await openInvoicesForParty(
          partyType: draft.partyType,
          partyId: draft.partyId,
          currencyId: draft.currencyId,
        );
        var left = amount;
        for (final line in open) {
          if (left <= moneyEpsilon) break;
          final alloc = roundMoney(
            line.remaining < left ? line.remaining : left,
          );
          if (alloc <= moneyEpsilon) continue;
          plan.add(
            VoucherAllocationApplied(
              invoiceId: line.invoiceId,
              invoiceNo: line.invoiceNo,
              amount: alloc,
            ),
          );
          left = roundMoney(left - alloc);
        }
        if (left > moneyEpsilon) {
          return Err(
            'المبلغ ${_num(amount)} يتجاوز المديونية المفتوحة '
            '(${_num(roundMoney(amount - left))} بعملة السند) — قلّل '
            'المبلغ أو اختر «على الحساب».',
          );
        }
      }

      // (3) فرق الصرف المحقق (القرار 4) — بالعملة الأساسية.
      var fxGainLoss = 0.0;
      if (crossCurrency && plan.isNotEmpty) {
        final paidBase = amount * vRate.rate;
        var bookBase = 0.0;
        for (final alloc in plan) {
          final invRows = await _db.query(
            'invoice',
            columns: ['exchange_rate'],
            where: 'id = ?',
            whereArgs: [alloc.invoiceId],
            limit: 1,
          );
          final invRate =
              (invRows.first['exchange_rate'] as num?)?.toDouble() ?? 1;
          bookBase += alloc.amount * invRate;
        }
        // ربح = (ما دخل الشركة بالأساس) − (ما خرج منها بالأساس):
        // القبض: نقود − دين دفتري؛ الصرف: دين دفتري − نقود.
        fxGainLoss = roundMoney(
          isReceipt ? paidBase - bookBase : bookBase - paidBase,
        );
      }

      // (4) المعاملة الواحدة — كل الكتابات أو لا شيء.
      return await _db.transaction((txn) async {
        // 4-أ) رقم RVT/PMT ذرّي داخل المعاملة نفسها (قاعدة 5.4-1).
        final year = txDate.year;
        final seqType = isReceipt
            ? DocSequenceType.receiptVoucher
            : DocSequenceType.paymentVoucher;
        final seq = DocSequenceService(txn);
        final number = await seq.nextNumber(seqType, year);
        final voucherNo = formatDocNumber(seqType, year, number);

        final description = _composeVoucherDescription(
          isReceipt,
          partyName,
          draft.description,
        );

        final cashTxId = await txn.insert('cash_tx', {
          'tx_type': isReceipt ? 'receipt' : 'payment',
          'cashbox_id': draft.cashboxId,
          'currency_id': draft.currencyId,
          'amount': amount,
          'exchange_rate': vRate.rate,
          'settlement_rate': settlementRate,
          'fx_gain_loss': fxGainLoss,
          'voucher_no': voucherNo,
          'tx_date': txIso,
          // السند المخصص: رابط الطرف فارغ (القرار 2)؛ الحر يحمله ليخصم
          // من رصيد الطرف عبر صيغ FR-03-02/03 القائمة.
          'ref_type': draft.allocateFifo ? 'invoice' : 'on_account',
          'ref_id': null,
          'customer_id': (!isReceipt || draft.allocateFifo)
              ? null
              : draft.partyId,
          'supplier_id': (isReceipt || draft.allocateFifo)
              ? null
              : draft.partyId,
          'description': description,
          'created_at': at.toUtc().toIso8601String(),
          'created_by': userId,
        });

        // 4-ب) دفاتر الفواتير المخصصة + صفوف payment_allocation (FIFO).
        for (final alloc in plan) {
          final updated = await txn.rawUpdate(
            'UPDATE invoice SET due_amount = due_amount - ?, '
            'paid_amount = paid_amount + ?, updated_at = ? '
            'WHERE id = ? AND due_amount >= ? - ?',
            <Object>[
              alloc.amount,
              alloc.amount,
              at.toUtc().toIso8601String(),
              alloc.invoiceId,
              alloc.amount,
              moneyEpsilon,
            ],
          );
          if (updated == 0) {
            throw _FlowError(
              'فاتورة ${alloc.invoiceNo} تغيّر مستحقها من جهة أخرى — '
              'أعد فتح السند وحدّث المديونية.',
            );
          }
          await txn.insert('payment_allocation', {
            'cash_tx_id': cashTxId,
            'invoice_id': alloc.invoiceId,
            'allocated_amount': alloc.amount,
            'allocated_at': at.toUtc().toIso8601String(),
            'created_by': userId,
          });
        }

        // 4-ج) قيد التدقيق.
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': isReceipt ? 'voucher_receipt_post' : 'voucher_payment_post',
          'entity': 'cash_tx',
          'entity_id': cashTxId,
          'details':
              'no=$voucherNo party=$partyName amount=$amount '
              'currency=${draft.currencyId} rate=${vRate.rate}'
              '${crossCurrency ? ' settlement=$settlementRate' : ''} '
              'fx=$fxGainLoss allocations=${plan.length}'
              '${vRate.fallback ? ' fallback=1' : ''}',
          'at': at.toUtc().toIso8601String(),
        });

        return Ok<VoucherPostedReceipt, String>(
          VoucherPostedReceipt(
            cashTxId: cashTxId,
            voucherNo: voucherNo,
            amount: amount,
            currencyCode: '',
            allocations: plan,
            fxGainLoss: fxGainLoss,
          ),
        );
      });
    } on _FlowError catch (e) {
      return Err(e.message);
    } on StateError catch (e) {
      return Err(e.message);
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e, 'حفظ السند'));
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // الحركات السريعة (FR-04-02) — مصروف/مسحوبات/إيداع مالك/تحويل/بنكي
  // ─────────────────────────────────────────────────────────────────────

  /// مصروف — فئة إلزامية (FR-04-03: مصروف ← فئة مصروف).
  Future<Result<QuickMovementReceipt, String>> createExpense(
    QuickMovementDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    if (draft.expenseCategoryId == null) {
      return const Err('فئة المصروف إلزامية — اختر الفئة ثم احفظ.');
    }
    return _createSingleLegMovement(draft, userId: userId, now: now);
  }

  /// مسحوبات المالك (owner_draw) — بند مستقل خارج المصاريف (ملحق و).
  Future<Result<QuickMovementReceipt, String>> createOwnerDraw(
    QuickMovementDraft draft, {
    required int userId,
    DateTime? now,
  }) => _createSingleLegMovement(draft, userId: userId, now: now);

  /// إيداع المالك (capital_in) — رأس مال.
  Future<Result<QuickMovementReceipt, String>> createCapitalIn(
    QuickMovementDraft draft, {
    required int userId,
    DateTime? now,
  }) => _createSingleLegMovement(draft, userId: userId, now: now);

  /// تحويل بين صندوقين / إيداع بنكي / سحب بنكي — صف واحد بساقين
  /// (القرار 5): المصدر يخرج بمبلغه، والهدف يستقبل المحوّل
  /// `amount × settlement_rate` بعملته (FR-04-07).
  Future<Result<QuickMovementReceipt, String>> createTransfer(
    QuickMovementDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final txIso = draft.txDate.toUtc().toIso8601String();

    if (draft.amount.isNaN ||
        draft.amount.isInfinite ||
        draft.amount <= moneyEpsilon) {
      return const Err('مبلغ الحركة يجب أن يكون رقماً أكبر من صفر.');
    }
    final amount = roundMoney(draft.amount);
    if (draft.toCashboxId == null) {
      return const Err('اختر الصندوق الهدف لهذه الحركة.');
    }

    try {
      final sourceRows = await _db.query(
        'cashbox',
        columns: ['name', 'currency_id', 'is_archived'],
        where: 'id = ?',
        whereArgs: [draft.cashboxId],
        limit: 1,
      );
      if (sourceRows.isEmpty) {
        return Err('الصندوق رقم #${draft.cashboxId} غير موجود.');
      }
      if ((sourceRows.first['is_archived'] as int? ?? 0) == 1) {
        return Err(
          'الصندوق «${sourceRows.first['name']}» مؤرشف — اختر صندوقاً نشطاً.',
        );
      }
      final sourceCurrencyId = sourceRows.first['currency_id'] as int;

      final targetRows = await _db.query(
        'cashbox',
        columns: ['name', 'currency_id', 'is_archived'],
        where: 'id = ?',
        whereArgs: [draft.toCashboxId],
        limit: 1,
      );
      if (targetRows.isEmpty) {
        return Err('الصندوق الهدف رقم #${draft.toCashboxId} غير موجود.');
      }
      if ((targetRows.first['is_archived'] as int? ?? 0) == 1) {
        return Err(
          'الصندوق الهدف «${targetRows.first['name']}» مؤرشف — اختر '
          'صندوقاً نشطاً.',
        );
      }
      if (draft.cashboxId == draft.toCashboxId) {
        return const Err(
          'الصندوقان المصدر والهدف واحد — اختر صندوقين مختلفين.',
        );
      }
      final targetCurrencyId = targetRows.first['currency_id'] as int;

      final sRate = await _rateForDay(sourceCurrencyId, draft.txDate);
      if (sRate == null) {
        return Err(_missingRateMessage(sourceCurrencyId));
      }
      final cross = sourceCurrencyId != targetCurrencyId;
      double? settlementRate;
      double targetAmount = amount;
      var fxGainLoss = 0.0;
      if (cross) {
        final tRate = await _rateForDay(targetCurrencyId, draft.txDate);
        if (tRate == null) {
          return Err(_missingRateMessage(targetCurrencyId));
        }
        settlementRate = roundMoney(sRate.rate / tRate.rate);
        targetAmount = roundMoney(amount * settlementRate);
        // ربح = (الوارد بالأساس) − (الخارج بالأساس) — صفر بسعر اليوم
        // (القرار 5): فرق الصرّاف يُسجَّل مصروفاً مستقلاً إذا لزم.
        fxGainLoss = roundMoney(
          targetAmount * tRate.rate - amount * sRate.rate,
        );
      }

      return await _db.transaction((txn) async {
        final cashTxId = await txn.insert('cash_tx', {
          'tx_type': draft.kind.code,
          'cashbox_id': draft.cashboxId,
          'to_cashbox_id': draft.toCashboxId,
          'currency_id': sourceCurrencyId,
          'amount': amount,
          'exchange_rate': sRate.rate,
          'settlement_rate': settlementRate,
          'fx_gain_loss': fxGainLoss,
          'tx_date': txIso,
          'ref_type': 'transfer',
          'ref_id': null,
          'description': _composeQuickDescription(
            draft,
            sourceRows.first['name'] as String,
            targetRows.first['name'] as String,
            targetAmount,
            cross,
          ),
          'created_at': at.toUtc().toIso8601String(),
          'created_by': userId,
        });
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'cash_${draft.kind.code}_post',
          'entity': 'cash_tx',
          'entity_id': cashTxId,
          'details':
              'from=${sourceRows.first['name']} '
              'to=${targetRows.first['name']} amount=$amount '
              'currency=$sourceCurrencyId rate=${sRate.rate}'
              '${cross ? ' settlement=$settlementRate '
                        'target=$targetAmount fx=$fxGainLoss' : ''}'
              '${sRate.fallback ? ' fallback=1' : ''}',
          'at': at.toUtc().toIso8601String(),
        });
        return Ok<QuickMovementReceipt, String>(
          QuickMovementReceipt(
            cashTxId: cashTxId,
            kind: draft.kind,
            amount: amount,
            currencyCode: '',
            sourceBoxName: sourceRows.first['name'] as String,
            targetBoxName: targetRows.first['name'] as String,
            targetAmount: cross ? targetAmount : null,
          ),
        );
      });
    } on _FlowError catch (e) {
      return Err(e.message);
    } on StateError catch (e) {
      return Err(e.message);
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e, 'حفظ الحركة'));
    }
  }

  /// المحرك الموحّد للحركات ذات الساق الواحدة (بعملة الصندوق دائماً).
  Future<Result<QuickMovementReceipt, String>> _createSingleLegMovement(
    QuickMovementDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final txIso = draft.txDate.toUtc().toIso8601String();

    if (draft.amount.isNaN ||
        draft.amount.isInfinite ||
        draft.amount <= moneyEpsilon) {
      return const Err('مبلغ الحركة يجب أن يكون رقماً أكبر من صفر.');
    }
    final amount = roundMoney(draft.amount);
    if (draft.kind.needsTargetBox) {
      return createTransfer(draft, userId: userId, now: now);
    }

    try {
      final boxRows = await _db.query(
        'cashbox',
        columns: ['name', 'currency_id', 'is_archived'],
        where: 'id = ?',
        whereArgs: [draft.cashboxId],
        limit: 1,
      );
      if (boxRows.isEmpty) {
        return Err('الصندوق رقم #${draft.cashboxId} غير موجود.');
      }
      if ((boxRows.first['is_archived'] as int? ?? 0) == 1) {
        return Err(
          'الصندوق «${boxRows.first['name']}» مؤرشف — اختر صندوقاً نشطاً.',
        );
      }
      final boxCurrencyId = boxRows.first['currency_id'] as int;

      final rate = await _rateForDay(boxCurrencyId, draft.txDate);
      if (rate == null) {
        return Err(_missingRateMessage(boxCurrencyId));
      }

      // فئة المصروف: وجود + عدم أرشفة (إلزامية للمصروف — FR-04-03).
      if (draft.kind == QuickMovementKind.expense) {
        final catRows = await _db.query(
          'expense_category',
          columns: ['name', 'is_archived'],
          where: 'id = ?',
          whereArgs: [draft.expenseCategoryId],
          limit: 1,
        );
        if (catRows.isEmpty) {
          return Err('فئة المصروف رقم #${draft.expenseCategoryId} غير موجودة.');
        }
        if ((catRows.first['is_archived'] as int? ?? 0) == 1) {
          return Err('فئة «${catRows.first['name']}» مؤرشفة — اختر فئة نشطة.');
        }
      }

      return await _db.transaction((txn) async {
        final cashTxId = await txn.insert('cash_tx', {
          'tx_type': draft.kind.code,
          'cashbox_id': draft.cashboxId,
          'currency_id': boxCurrencyId,
          'amount': amount,
          'exchange_rate': rate.rate,
          'fx_gain_loss': 0,
          'tx_date': txIso,
          'ref_type': null,
          'ref_id': null,
          'expense_category_id': draft.kind == QuickMovementKind.expense
              ? draft.expenseCategoryId
              : null,
          'description': _composeQuickDescription(
            draft,
            boxRows.first['name'] as String,
            null,
            amount,
            false,
          ),
          'created_at': at.toUtc().toIso8601String(),
          'created_by': userId,
        });
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'cash_${draft.kind.code}_post',
          'entity': 'cash_tx',
          'entity_id': cashTxId,
          'details':
              'box=${boxRows.first['name']} amount=$amount '
              'currency=$boxCurrencyId rate=${rate.rate} '
              'category=${draft.expenseCategoryId ?? '-'}'
              '${rate.fallback ? ' fallback=1' : ''}',
          'at': at.toUtc().toIso8601String(),
        });
        return Ok<QuickMovementReceipt, String>(
          QuickMovementReceipt(
            cashTxId: cashTxId,
            kind: draft.kind,
            amount: amount,
            currencyCode: '',
            sourceBoxName: boxRows.first['name'] as String,
          ),
        );
      });
    } on _FlowError catch (e) {
      return Err(e.message);
    } on StateError catch (e) {
      return Err(e.message);
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e, 'حفظ الحركة'));
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // الإبطال (FR-04-08) — حركة معاكسة فقط، لا حذف ولا تعديل
  // ─────────────────────────────────────────────────────────────────────

  /// **إبطال حركة** — معاملة واحدة: حركة معاكسة (بإشارات مستعادة —
  /// للتحويل باعتبار الساقين معكوسة) + `is_voided=1` على الأصل +
  /// استرجاع دفاتر الفواتير + حذف روابط التخصيص + قيد تدقيق.
  ///
  /// القيود: حركة ملغاة/معاكسة لا تُبطل؛ الحركات المرتبطة بمستند آخر
  /// (تحصيل الإصدار/رد المرتجع) تُبطل عبر مستنداتها؛ الأنواع المؤجلة
  /// (V1.1) مرفوضة برسالة واضحة. **الرقم المرقّم لا يُعاد أبداً.**
  Future<Result<int, String>> voidMovement(
    int id, {
    required int userId,
    String? reason,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();

    try {
      // تحققات مسبقة (خارج المعاملة — قراءة فقط).
      final rows = await _db.query('cash_tx', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) {
        return Err('الحركة رقم #$id غير موجودة.');
      }
      final orig = rows.first;
      if ((orig['is_voided'] as int? ?? 0) == 1) {
        return const Err('هذه الحركة ملغاة سابقاً — لا تُبطل مرتين.');
      }
      if (orig['reversal_of'] != null) {
        return const Err(
          'هذه حركة معاكسة لإبطال سابق — لا تُبطل الحركات المعاكسة.',
        );
      }
      final type = CashTxType.tryParse(orig['tx_type'] as String);
      if (type == null) {
        return const Err(
          'نوع الحركة من وحدة مؤجلة (V1.1) — لا يُدعم إبطالها هنا بعد.',
        );
      }
      if (type == CashTxType.opening) {
        return const Err(
          'حركة الافتتاح لا تُبطل مباشرة — عدّل الرصيد الافتتاحي من مصدره.',
        );
      }
      final refType = orig['ref_type'] as String?;
      final refId = orig['ref_id'] as int?;
      if (refType == 'invoice' && refId != null) {
        return const Err(
          'هذه الحركة مرتبطة بمستند (فاتورة/مرتجع) — تُبطل عبر إبطال '
          'المستند نفسه من وحدته، لا من سجل الصندوق.',
        );
      }

      // النوع المعاكس (إشارات مستعادة — ملحق و).
      final reversalType = switch (type) {
        CashTxType.receipt => 'payment',
        CashTxType.payment => 'receipt',
        CashTxType.expense => 'receipt',
        CashTxType.ownerDraw => 'capital_in',
        CashTxType.capitalIn => 'owner_draw',
        CashTxType.boxTransfer => 'box_transfer',
        CashTxType.bankDeposit => 'bank_withdraw',
        CashTxType.bankWithdraw => 'bank_deposit',
        CashTxType.opening => 'receipt',
      };

      final txDateIso = at.toUtc().toIso8601String();
      final originalLabel =
          (orig['voucher_no'] as String?) ??
          (orig['description'] as String?) ??
          '#$id';
      final cleanReason = (reason ?? '').trim();

      return await _db.transaction((txn) async {
        // (أ) علامة الإبطال على الأصل — تحديث حالة لا تعديل مالي.
        await txn.rawUpdate(
          'UPDATE cash_tx SET is_voided = 1 WHERE id = ?',
          <Object>[id],
        );

        // (ب) استرجاع دفاتر الفواتير + حذف روابط التخصيص (رابط تخصيص
        //     لا حركة مالية — حذفه داخل المعاملة مسموح).
        final allocs = await txn.rawQuery(
          'SELECT invoice_id, allocated_amount FROM payment_allocation '
          'WHERE cash_tx_id = ?',
          <Object>[id],
        );
        for (final alloc in allocs) {
          final invoiceId = alloc['invoice_id'] as int;
          final allocAmount =
              (alloc['allocated_amount'] as num?)?.toDouble() ?? 0;
          final restored = await txn.rawUpdate(
            'UPDATE invoice SET due_amount = due_amount + ?, '
            'paid_amount = paid_amount - ?, updated_at = ? '
            'WHERE id = ? AND paid_amount >= ? - ?',
            <Object>[
              allocAmount,
              allocAmount,
              txDateIso,
              invoiceId,
              allocAmount,
              moneyEpsilon,
            ],
          );
          if (restored == 0) {
            throw _FlowError(
              'تعذر استرجاع تخصيص الفاتورة رقم #$invoiceId — بياناتها '
              'غير متسقة مع السند. لم يُكتب شيء (تراجعت المعاملة).',
            );
          }
        }
        if (allocs.isNotEmpty) {
          await txn.rawDelete(
            'DELETE FROM payment_allocation WHERE cash_tx_id = ?',
            <Object>[id],
          );
        }

        // (ج) الحركة المعاكسة — نفس الأنواع بإشارات مستعادة (للتحويل:
        //     معاكسة الساقين بتبديل المصدر والهدف)، تُولد حية
        //     (`is_voided=0`) وتُستبعد من الأرصدة عبر `reversal_of`.
        final reversalId = await txn.insert('cash_tx', {
          'tx_type': reversalType,
          'cashbox_id': type.isTwoLegged
              ? orig['to_cashbox_id']
              : orig['cashbox_id'],
          'to_cashbox_id': type.isTwoLegged ? orig['cashbox_id'] : null,
          'currency_id': orig['currency_id'],
          'amount': orig['amount'],
          'exchange_rate': orig['exchange_rate'],
          'settlement_rate': orig['settlement_rate'],
          'fx_gain_loss': -((orig['fx_gain_loss'] as num?)?.toDouble() ?? 0),
          'voucher_no': null, // رقم الأصل لا يُعاد ولا يُنسخ (استمرارية).
          'tx_date': txDateIso,
          'ref_type': orig['ref_type'],
          'ref_id': null,
          'expense_category_id': orig['expense_category_id'],
          'customer_id': orig['customer_id'],
          'supplier_id': orig['supplier_id'],
          'is_voided': 0,
          'reversal_of': id,
          'description':
              'إبطال: $originalLabel'
              '${cleanReason.isEmpty ? '' : ' — $cleanReason'}',
          'created_at': txDateIso,
          'created_by': userId,
        });

        // (د) قيد التدقيق.
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'cash_void',
          'entity': 'cash_tx',
          'entity_id': id,
          'details':
              'type=${orig['tx_type']} amount=${orig['amount']} '
              'reversal=$reversalId label=$originalLabel'
              '${cleanReason.isEmpty ? '' : ' reason=$cleanReason'}',
          'at': txDateIso,
        });

        return Ok<int, String>(reversalId);
      });
    } on _FlowError catch (e) {
      return Err(e.message);
    } on StateError catch (e) {
      return Err(e.message);
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e, 'إبطال الحركة'));
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // السجل والقراءات (FR-04-08 سجل كامل + مرشحات)
  // ─────────────────────────────────────────────────────────────────────

  /// سجل حركات الصندوق بمرشحات (صندوق/نوع/فترة/بحث نصي في الوصف
  /// والرقم واسم الطرف) — الأحدث أولاً.
  Future<List<CashMovementRow>> journal({
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
      if (from != null) _dateOnly(from),
      if (to != null) _dateOnly(to),
      if ((search ?? '').trim().isNotEmpty) ...[like, like, like, like, like],
    ];
    final rows = await _db.rawQuery(
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
    return [for (final row in rows) _movementFromRow(row)];
  }

  /// تفاصيل حركة واحدة + تخصيصاتها — `null` إن لم توجد.
  Future<CashMovementDetail?> movementDetail(int id) async {
    final rows = await _db.rawQuery(
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
    final allocRows = await _db.rawQuery(
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
      movement: _movementFromRow(rows.first),
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
  Future<List<CashNetLine>> netCashByCurrency() async {
    final rows = await _db.rawQuery('''
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
  // ─────────────────────────────────────────────────────────────────────

  CashMovementRow _movementFromRow(Map<String, Object?> row) => CashMovementRow(
    id: row['id'] as int,
    txTypeCode: row['tx_type'] as String,
    cashboxId: row['cashbox_id'] as int,
    cashboxName: (row['cashbox_name'] as String?) ?? '',
    currencyId: row['currency_id'] as int,
    currencyCode: (row['currency_code'] as String?) ?? '',
    amount: (row['amount'] as num?)?.toDouble() ?? 0,
    exchangeRate: (row['exchange_rate'] as num?)?.toDouble() ?? 1,
    settlementRate: (row['settlement_rate'] as num?)?.toDouble(),
    fxGainLoss: (row['fx_gain_loss'] as num?)?.toDouble() ?? 0,
    voucherNo: row['voucher_no'] as String?,
    txDate: DateTime.parse(row['tx_date'] as String),
    isVoided: (row['is_voided'] as int? ?? 0) == 1,
    reversalOf: row['reversal_of'] as int?,
    toCashboxId: row['to_cashbox_id'] as int?,
    toCashboxName: row['to_cashbox_name'] as String?,
    refType: row['ref_type'] as String?,
    refId: row['ref_id'] as int?,
    expenseCategoryId: row['expense_category_id'] as int?,
    expenseCategoryName: row['expense_category_name'] as String?,
    customerId: row['customer_id'] as int?,
    customerName: row['customer_name'] as String?,
    supplierId: row['supplier_id'] as int?,
    supplierName: row['supplier_name'] as String?,
    description: row['description'] as String?,
  );

  /// سعر عملة ليوم عمل — 1 للأساس؛ `null` عند الغياب وسياسة الاحتياط
  /// مغلقة (FR-08-09 — نفس نمط البيع/الشراء).
  Future<_DayRate?> _rateForDay(int currencyId, DateTime date) async {
    final rows = await _db.query(
      'currency',
      columns: ['is_base'],
      where: 'id = ?',
      whereArgs: [currencyId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    if ((rows.first['is_base'] as int? ?? 0) == 1) {
      return const _DayRate(1, false);
    }
    final todayRate = await _rates.rateFor(currencyId, date);
    if (todayRate != null && todayRate > 0) {
      return _DayRate(todayRate, false);
    }
    final fallbackOn =
        (await _settings.getString('fx.fallback', 'off')) == 'last_known';
    if (!fallbackOn) return null;
    final lastKnown = await _rates.latestBefore(currencyId, date);
    if (lastKnown == null || lastKnown <= 0) return null;
    return _DayRate(lastKnown, true);
  }

  String _missingRateMessage(int currencyId) =>
      'لا يوجد سعر صرف للعملة رقم #$currencyId بتاريخ اليوم — أدخل سعر '
      'اليوم أولاً ثم احفظ (لا يُحفظ بسعر افتراضي).';

  String _composeVoucherDescription(
    bool isReceipt,
    String partyName,
    String? userNotes,
  ) {
    final head = isReceipt ? 'قبض من $partyName' : 'صرف إلى $partyName';
    final notes = (userNotes ?? '').trim();
    return notes.isEmpty ? head : '$head — $notes';
  }

  String _composeQuickDescription(
    QuickMovementDraft draft,
    String sourceBoxName,
    String? targetBoxName,
    double targetAmount,
    bool cross,
  ) {
    final notes = (draft.description ?? '').trim();
    final String head;
    if (targetBoxName != null) {
      final transferLabel = switch (draft.kind) {
        QuickMovementKind.boxTransfer => 'تحويل',
        QuickMovementKind.bankDeposit => 'إيداع بنكي',
        QuickMovementKind.bankWithdraw => 'سحب بنكي',
        _ => '',
      };
      head =
          '$transferLabel من $sourceBoxName إلى $targetBoxName'
          '${cross ? ' (يصل ${_num(targetAmount)})' : ''}';
    } else {
      head = switch (draft.kind) {
        QuickMovementKind.expense => 'مصروف — $sourceBoxName',
        QuickMovementKind.ownerDraw => 'مسحوبات المالك — $sourceBoxName',
        QuickMovementKind.capitalIn => 'إيداع المالك — $sourceBoxName',
        _ => '',
      };
    }
    return notes.isEmpty ? head : '$head — $notes';
  }

  /// يصوغ خطأ قاعدة البيانات بكلمات المستخدم (نمط المستودعات القائمة).
  String _describeDbError(DatabaseException e, String action) {
    if (e.isUniqueConstraintError()) {
      return 'قيمة مكررة تخالف قيد التفرد أثناء $action';
    }
    if (e.toString().toUpperCase().contains('CHECK')) {
      return 'قيمة تخالف قيد سلامة محاسبي في القاعدة أثناء $action';
    }
    return 'تعذر $action في القاعدة: $e';
  }
}

/// تجميع دلاء صندوق واحد أثناء القراءة.
class _BoxAgg {
  _BoxAgg(this.box);
  final CashboxInfo box;
  final Map<int, double> buckets = <int, double>{};
}

/// `YYYY-MM-DD` بتاريخ التقويم المحلي ليوم العمل.
String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// يصيغ رقماً للعرض في الرسائل بلا أصفار زائدة.
String _num(double v) {
  if (v.isNaN || v.isInfinite) return v.toString();
  final rounded = (v * 1000).round() / 1000;
  if (rounded == rounded.round()) return rounded.toInt().toString();
  return rounded.toStringAsFixed(3);
}
