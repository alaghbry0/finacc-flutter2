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

import '../../domain/core/dates.dart';
import '../../domain/core/result.dart';
import '../../domain/models/party.dart';
import 'party_query.dart';

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
  Future<bool> hasMovements(int id) =>
      partyHasMovements(_db, PartySide.customer, id);

  // ── الأرصدة (FR-03-02) ───────────────────────────────────────────

  /// قائمة العملاء مع أرصدتهم — سطر لكل (عميل × عملة)؛ العميل بلا أي
  /// حركة يظهر بسطر واحد برصيد صفر بعملة القاعدة.
  ///
  /// [search] يبحث بالاسم أو الهاتف (LIKE)، و[includeArchived] يضيف
  /// المؤرشفين (افتراضياً مستثنون — FR-03-09).
  Future<List<PartyBalance>> listWithBalances({
    String? search,
    bool includeArchived = false,
  }) => partyListWithBalances(
    _db,
    PartySide.customer,
    search: search,
    includeArchived: includeArchived,
  );

  /// رصيد العميل في عملة واحدة — صيغة FR-03-02 حصراً (0 عند لا حركة).
  Future<double> balanceInCurrency(int customerId, int currencyId) =>
      partyBalanceInCurrency(_db, PartySide.customer, customerId, currencyId);

  /// الأعمال المتعثرة (FR-03-06): العملاء برصيد موجب (>= [minBalance])
  /// في أي عملة، مرتَّبين بأقدم فاتورة آجلة مفتوحة تصاعدياً، مع
  /// [PartyBalance.daysLate] منذ أقدم فاتورة («متأخر منذ X يوماً»).
  ///
  /// [now] لحظة الاحتساب (تُمرَّر صريحة في الاختبارات؛ الافتراضي الآن).
  Future<List<PartyBalance>> receivablesList({
    int minBalance = 1,
    DateTime? now,
  }) => partyOverdueList(
    _db,
    PartySide.customer,
    minBalance: minBalance,
    now: now,
  );

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
  }) => partyStatement(
    _db,
    PartySide.customer,
    customerId,
    currencyId: currencyId,
    from: from,
    to: to,
  );

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
    dateOnly(date ?? fallback);
