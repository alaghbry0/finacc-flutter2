/// دلالات أنواع حركات النقدية (ملحق و — إشارات الأرصدة الحرفية):
/// اتجاه الساق، أيقونة، تسمية عربية، لون دلالي، وتنسيقا التاريخ.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// هل الحركة واردة (+) على صندوق المصدر `cashbox_id`؟
/// (receipt/capital_in/opening فقط — كل ذات الساقين صادرة من مصدرها
/// والهدف يستقبل ساقه المحوّلة باسمه.)
bool cashTxInflowOnMainBox(CashTxType? type) =>
    type == CashTxType.receipt ||
    type == CashTxType.capitalIn ||
    type == CashTxType.opening;

/// أيقونة تمثيلية لنوع الحركة.
IconData cashTxIcon(CashTxType? type) => switch (type) {
  CashTxType.receipt => Icons.south_west_rounded,
  CashTxType.payment => Icons.north_east_rounded,
  CashTxType.expense => Icons.receipt_long_rounded,
  CashTxType.ownerDraw => Icons.person_remove_rounded,
  CashTxType.capitalIn => Icons.person_add_rounded,
  CashTxType.boxTransfer => Icons.swap_horiz_rounded,
  CashTxType.bankDeposit => Icons.account_balance_rounded,
  CashTxType.bankWithdraw => Icons.local_atm_rounded,
  CashTxType.opening => Icons.flag_rounded,
  null => Icons.help_outline_rounded,
};

/// تسمية النوع بالعربية (مفاتيح cashType*).
String cashTxLabel(AppLocalizations l10n, CashTxType? type) => switch (type) {
  CashTxType.receipt => l10n.cashTypeReceipt,
  CashTxType.payment => l10n.cashTypePayment,
  CashTxType.expense => l10n.cashTypeExpense,
  CashTxType.ownerDraw => l10n.cashTypeOwnerDraw,
  CashTxType.capitalIn => l10n.cashTypeCapitalIn,
  CashTxType.boxTransfer => l10n.cashTypeBoxTransfer,
  CashTxType.bankDeposit => l10n.cashTypeBankDeposit,
  CashTxType.bankWithdraw => l10n.cashTypeBankWithdraw,
  CashTxType.opening => l10n.cashTypeOpening,
  null => '—',
};

/// لون دلالي لنوع الحركة (للأفاتار والبلاطات).
Color cashTxTone(ColorScheme scheme, FinColors colors, CashTxType? type) {
  if (cashTxInflowOnMainBox(type)) return colors.positive;
  return switch (type) {
    CashTxType.payment => colors.negative,
    CashTxType.expense => colors.warning,
    CashTxType.ownerDraw => scheme.tertiary,
    _ => colors.negative,
  };
}

/// تاريخ `يوم/شهر/سنة` بأرقام بسيطة (نمط باقي الوحدات).
String cashFormatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

/// تاريخ `سنة-شهر-يوم` (صيغة القاعدة).
String cashFormatIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
