/// مساعدات ألوان القوالب (UX-3) — تحويل ARGB المخزَّن بالإعدادات إلى
/// `PdfColor` + مشتقات (تغميق للتعبئة الملونة ونص متباين فوقها).
library;

import 'package:pdf/pdf.dart' as pw;

/// يحوّل ARGB صحيحاً (0xFFRRGGBB) إلى PdfColor.
pw.PdfColor templatePdfColor(int argb) => pw.PdfColor.fromInt(argb);

/// يغمّق اللون بمعامل [factor] (1 = كما هو، 0.55 = صندوق العنوان الملون
/// بنموذج المالك — أزرق أغمق من رأس الجدول بنفس العائلة اللونية).
pw.PdfColor templateDarken(pw.PdfColor color, [double factor = 0.55]) =>
    pw.PdfColor(
      (color.red * factor).clamp(0.0, 1.0),
      (color.green * factor).clamp(0.0, 1.0),
      (color.blue * factor).clamp(0.0, 1.0),
      color.alpha,
    );

/// نص متباين فوق تعبئة: أبيض فوق الداكن وحبر داكن فوق الفاتح — يحمي
/// قابلية القراءة أيّ لونٍ يختاره المالك لرأس الجدول.
pw.PdfColor templateOnColor(pw.PdfColor fill) {
  // الإضاءة المدركَة (نسب WCAG التقريبية).
  final luminance =
      0.299 * fill.red + 0.587 * fill.green + 0.114 * fill.blue;
  return luminance >= 0.55
      ? const pw.PdfColor.fromInt(0xFF1A2420)
      : pw.PdfColors.white;
}
