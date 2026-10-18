/// تنسيقات أسعار الصرف (سعر جدولي LTR) — مستخرجة من
/// exchange_rates_screen (R20-D3c: نقل حرفي بلا أي تغيير سلوكي؛
/// الدالتان الخاصتان صارتا علويتين بادئة exchangeRate).
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/exchange_rate.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../../../../domain/services/numerals.dart';

/// سعر كسعر معروض (أرقام سياقية) — من `_formatRate` ببطاقة العملة.
String exchangeRateFormatRate(BuildContext context, double rate) {
  final plain = rate == rate.truncateToDouble()
      ? rate.truncate().toString()
      : rate.toStringAsFixed(4);
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
}

/// سعر كسجل التاريخ (نص خام) — من `_plainRate` بسجل الأسعار.
String exchangeRatePlainRate(ExchangeRateEntry rate) {
  final value = rate.rate;
  if (value == value.truncateToDouble()) {
    return value.truncate().toString();
  }
  return value.toStringAsFixed(4);
}
