/// مساعدات تنسيق الوردية المشتركة بين مكونات الشاشة (منازل/تاريخ/ISO).
library;

/// منازل العملة للعرض — قرار المستدعي: YER = 0 (قاعدة 5.4-9) والباقي 2.
int shiftDecimals(String? currencyCode) => currencyCode == 'YER' ? 0 : 2;

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
