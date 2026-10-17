/// جزء من تقسيم R18-D3a لمستودع النقدية — مستخرج حرفياً من
/// cash_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/result.dart';
import '../../../domain/services/purchase_pricing.dart';
import '../../../domain/models/cash.dart';
import '../exchange_rate_repository.dart' show ExchangeRateRepository;
import '../settings_repository.dart' show SettingsRepository;
import 'cash_flow_types.dart';
import 'cash_helpers.dart';

// ─────────────────────────────────────────────────────────────────────

/// مصروف — فئة إلزامية (FR-04-03: مصروف ← فئة مصروف).
Future<Result<QuickMovementReceipt, String>> createExpenseFlow(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,

  QuickMovementDraft draft, {
  required int userId,
  DateTime? now,
}) async {
  if (draft.expenseCategoryId == null) {
    return const Err('فئة المصروف إلزامية — اختر الفئة ثم احفظ.');
  }
  return createSingleLegMovement(
    db,
    rates,
    settings,
    draft,
    userId: userId,
    now: now,
  );
}

/// مسحوبات المالك (owner_draw) — بند مستقل خارج المصاريف (ملحق و).
Future<Result<QuickMovementReceipt, String>> createOwnerDrawFlow(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,

  QuickMovementDraft draft, {
  required int userId,
  DateTime? now,
}) => createSingleLegMovement(
  db,
  rates,
  settings,
  draft,
  userId: userId,
  now: now,
);

/// إيداع المالك (capital_in) — رأس مال.
Future<Result<QuickMovementReceipt, String>> createCapitalInFlow(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,

  QuickMovementDraft draft, {
  required int userId,
  DateTime? now,
}) => createSingleLegMovement(
  db,
  rates,
  settings,
  draft,
  userId: userId,
  now: now,
);

/// تحويل بين صندوقين / إيداع بنكي / سحب بنكي — صف واحد بساقين
/// (القرار 5): المصدر يخرج بمبلغه، والهدف يستقبل المحوّل
/// `amount × settlement_rate` بعملته (FR-04-07).
Future<Result<QuickMovementReceipt, String>> createTransferFlow(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,

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
    final sourceRows = await db.query(
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

    final targetRows = await db.query(
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
      return const Err('الصندوقان المصدر والهدف واحد — اختر صندوقين مختلفين.');
    }
    final targetCurrencyId = targetRows.first['currency_id'] as int;

    final sRate = await cashRateForDay(
      db,
      rates,
      settings,
      sourceCurrencyId,
      draft.txDate,
    );
    if (sRate == null) {
      return Err(missingRateMessage(sourceCurrencyId));
    }
    final cross = sourceCurrencyId != targetCurrencyId;
    double? settlementRate;
    double targetAmount = amount;
    var fxGainLoss = 0.0;
    if (cross) {
      final tRate = await cashRateForDay(
        db,
        rates,
        settings,
        targetCurrencyId,
        draft.txDate,
      );
      if (tRate == null) {
        return Err(missingRateMessage(targetCurrencyId));
      }
      settlementRate = roundMoney(sRate.rate / tRate.rate);
      targetAmount = roundMoney(amount * settlementRate);
      // ربح = (الوارد بالأساس) − (الخارج بالأساس) — صفر بسعر اليوم
      // (القرار 5): فرق الصرّاف يُسجَّل مصروفاً مستقلاً إذا لزم.
      fxGainLoss = roundMoney(targetAmount * tRate.rate - amount * sRate.rate);
    }

    return await db.transaction((txn) async {
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
        'description': composeQuickDescription(
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
  } on CashFlowError catch (e) {
    return Err(e.message);
  } on StateError catch (e) {
    return Err(e.message);
  } on DatabaseException catch (e) {
    return Err(describeCashDbError(e, 'حفظ الحركة'));
  }
}

/// المحرك الموحّد للحركات ذات الساق الواحدة (بعملة الصندوق دائماً).
Future<Result<QuickMovementReceipt, String>> createSingleLegMovement(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,

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
    return createTransferFlow(
      db,
      rates,
      settings,
      draft,
      userId: userId,
      now: now,
    );
  }

  try {
    final boxRows = await db.query(
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

    final rate = await cashRateForDay(
      db,
      rates,
      settings,
      boxCurrencyId,
      draft.txDate,
    );
    if (rate == null) {
      return Err(missingRateMessage(boxCurrencyId));
    }

    // فئة المصروف: وجود + عدم أرشفة (إلزامية للمصروف — FR-04-03).
    if (draft.kind == QuickMovementKind.expense) {
      final catRows = await db.query(
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

    return await db.transaction((txn) async {
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
        'description': composeQuickDescription(
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
  } on CashFlowError catch (e) {
    return Err(e.message);
  } on StateError catch (e) {
    return Err(e.message);
  } on DatabaseException catch (e) {
    return Err(describeCashDbError(e, 'حفظ الحركة'));
  }
}

// ─────────────────────────────────────────────────────────────────────
// الإبطال (FR-04-08) — حركة معاكسة فقط، لا حذف ولا تعديل
