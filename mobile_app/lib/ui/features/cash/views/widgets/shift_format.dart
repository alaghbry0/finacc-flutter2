/// مساعدات تنسيق الوردية المشتركة بين مكونات الشاشة (منازل/تاريخ/ISO).
library;

import '../../../../core/widgets/amount_text.dart';

/// منازل العملة للعرض (يفوّض إلى `AmountText.decimalsFor` — قاعدة 5.4-9
/// بمصدرها الموحد؛ الخرج مطابق حرفياً).
int shiftDecimals(String? currencyCode) => AmountText.decimalsFor(currencyCode);

/// تاريخ ووقت `يوم/شهر/سنة ساعة:دقيقة` بأرقام بسيطة (نمط الوحدة).
String shiftFormatDateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} $hour:$minute';
}

DateTime? shiftTryParseIso(String? iso) =>
    iso == null ? null : DateTime.tryParse(iso);
