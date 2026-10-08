/// وضع «الطباعة عند الحفظ» — إعداد `invoicing.print_on_save` (ملحق هـ).
///
/// **ask** (الافتراضي المزروع في الهجرة): إيصال نجاح البيع يعرض زري
/// «طباعة الفاتورة» و«مشاركة/واتساب»؛ **always**: تفتح معاينة PDF
/// تلقائياً فور نجاح الترحيل؛ **off**: الأزرار تُخفى كلياً.
///
/// الاستهلاك بنمط بوابة الائتمان القائمة (sell_screen): المستدعي يمرر
/// مستودع الإعدادات من AppController لحظة فتح نافذة الدفع.
library;

import '../../../../data/repositories/settings_repository.dart';

/// القيم المعتمدة للإعداد.
enum PrintOnSaveMode { ask, always, off }

/// مفتاح الإعداد (ملحق هـ).
const String kPrintOnSaveKey = 'invoicing.print_on_save';

/// يفكّ قيمة الإعداد الخام — أي قيمة مجهولة أو غياب ترجع `ask`
/// (الافتراضي المزروع في الهجرة v2).
PrintOnSaveMode parsePrintOnSave(String? raw) {
  switch (raw) {
    case 'always':
      return PrintOnSaveMode.always;
    case 'off':
      return PrintOnSaveMode.off;
    default:
      return PrintOnSaveMode.ask;
  }
}

/// يقرأ الوضع من مستودع الإعدادات — `null` (بلا مستودع) أو فشل قراءة
/// يعني `ask` (السلوك المحافظ الافتراضي).
Future<PrintOnSaveMode> resolvePrintOnSave(SettingsRepository? settings) async {
  if (settings == null) return PrintOnSaveMode.ask;
  try {
    return parsePrintOnSave(await settings.getString(kPrintOnSaveKey, 'ask'));
  } catch (_) {
    return PrintOnSaveMode.ask;
  }
}
