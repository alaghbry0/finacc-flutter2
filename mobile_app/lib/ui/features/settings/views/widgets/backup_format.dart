/// مساعدات تنسيق مشتركة لشاشة النسخ الاحتياطي — تواريخ/أرقام/أحجام
/// بأرقام النظام الحي (عربية-هندية أو لاتينية).
library;

import 'package:flutter/material.dart';
// إخفاء TextDirection الخاصة بintl (قيمها LTR/RTL كبيرة) كي لا تحجب
// TextDirection الخاصة بFlutter (قيمها ltr/rtl صغيرة) — مطلوبة أدناه.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/numerals_scope.dart';

/// تاريخ/وقت مقروء بأرقام النظام الحي.
String backupFormatDateTime(BuildContext context, DateTime local) {
  final formatted = DateFormat('yyyy/MM/dd • HH:mm').format(local);
  return NumeralsScope.of(context)
      ? Numerals.toArabicIndic(formatted)
      : formatted;
}

/// أرقام بأرقام النظام الحي.
String backupFormatDigits(BuildContext context, String digits) {
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(digits) : digits;
}

/// حجم ملف مقروء (ك.ب / م.ب) بأرقام النظام الحي.
String backupFormatSize(BuildContext context, int bytes) {
  final l10n = AppLocalizations.of(context)!;
  final kb = bytes / 1024;
  if (kb < 1024) {
    final value = backupFormatDigits(context, kb.round().toString());
    return l10n.backupSizeKb(value);
  }
  final mb = backupFormatDigits(context, (kb / 1024).toStringAsFixed(1));
  return l10n.backupSizeMb(mb);
}
