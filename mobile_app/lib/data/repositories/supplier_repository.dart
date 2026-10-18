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

import '../../domain/core/dates.dart';
import '../../domain/core/result.dart';
import '../../domain/models/party.dart';
import 'party_query.dart';

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
  Future<bool> hasMovements(int id) =>
      partyHasMovements(_db, PartySide.supplier, id);

  // ── قراءة السجل الكامل ───────────────────────────────────────────

  /// سجل المورد الكامل بمعرّفه — أو `null` إن لم يوجد.
  ///
  /// يقرأ كل الأعمدة (العنوان، الملاحظات…) لا الأرصدة وحدها — كان
  /// استعلامه جسر `party_lookup` بواجهة الطبقات قبل أن ينتقل هنا
  /// (R20-D1).
  Future<Supplier?> findById(int id) async {
    final rows = await _db.query(
      'supplier',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Supplier.fromRow(rows.first);
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
  }) => partyListWithBalances(
    _db,
    PartySide.supplier,
    search: search,
    includeArchived: includeArchived,
  );

  /// رصيد المورد في عملة واحدة — الموجب = ما تبقّى علينا دفعه.
  Future<double> balanceInCurrency(int supplierId, int currencyId) =>
      partyBalanceInCurrency(_db, PartySide.supplier, supplierId, currencyId);

  /// المبالغ المتبقية للموردين (FR-03-03): الموردون برصيد موجب
  /// (>= [minBalance]) في أي عملة، مرتَّبين بأقدم فاتورة شراء آجلة
  /// مفتوحة تصاعدياً، مع [PartyBalance.daysLate] («متأخر منذ X يوماً»).
  ///
  /// [now] لحظة الاحتساب (تُمرَّر صريحة في الاختبارات؛ الافتراضي الآن).
  Future<List<PartyBalance>> payablesList({
    int minBalance = 1,
    DateTime? now,
  }) => partyOverdueList(
    _db,
    PartySide.supplier,
    minBalance: minBalance,
    now: now,
  );

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
  }) => partyStatement(
    _db,
    PartySide.supplier,
    supplierId,
    currencyId: currencyId,
    from: from,
    to: to,
  );

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
