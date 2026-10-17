/// جزء من تقسيم R18-D3a لمستودع النقدية — مستخرج حرفياً من
/// cash_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/numbers.dart';
import '../../../domain/models/cash.dart';
import '../exchange_rate_repository.dart' show ExchangeRateRepository;
import '../settings_repository.dart' show SettingsRepository;
import 'cash_flow_types.dart';

// ─────────────────────────────────────────────────────────────────────

CashMovementRow movementFromRow(Map<String, Object?> row) => CashMovementRow(
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
Future<CashDayRate?> cashRateForDay(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,
  int currencyId,
  DateTime date,
) async {
  final rows = await db.query(
    'currency',
    columns: ['is_base'],
    where: 'id = ?',
    whereArgs: [currencyId],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  if ((rows.first['is_base'] as int? ?? 0) == 1) {
    return const CashDayRate(1, false);
  }
  final todayRate = await rates.rateFor(currencyId, date);
  if (todayRate != null && todayRate > 0) {
    return CashDayRate(todayRate, false);
  }
  final fallbackOn =
      (await settings.getString('fx.fallback', 'off')) == 'last_known';
  if (!fallbackOn) return null;
  final lastKnown = await rates.latestBefore(currencyId, date);
  if (lastKnown == null || lastKnown <= 0) return null;
  return CashDayRate(lastKnown, true);
}

String missingRateMessage(int currencyId) =>
    'لا يوجد سعر صرف للعملة رقم #$currencyId بتاريخ اليوم — أدخل سعر '
    'اليوم أولاً ثم احفظ (لا يُحفظ بسعر افتراضي).';

String composeVoucherDescription(
  bool isReceipt,
  String partyName,
  String? userNotes,
) {
  final head = isReceipt ? 'قبض من $partyName' : 'صرف إلى $partyName';
  final notes = (userNotes ?? '').trim();
  return notes.isEmpty ? head : '$head — $notes';
}

String composeQuickDescription(
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
        '${cross ? ' (يصل ${formatNum(targetAmount)})' : ''}';
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
String describeCashDbError(DatabaseException e, String action) {
  if (e.isUniqueConstraintError()) {
    return 'قيمة مكررة تخالف قيد التفرد أثناء $action';
  }
  if (e.toString().toUpperCase().contains('CHECK')) {
    return 'قيمة تخالف قيد سلامة محاسبي في القاعدة أثناء $action';
  }
  return 'تعذر $action في القاعدة: $e';
}
