/// لوحة ألوان الطباعة (الشريحة 7) — تكييف صديق للطابعة بهوية التطبيق:
/// بذرة `0xFF00695C` (Deep Teal) + لمسة ذهبية + حبر أخضر داكن على ورق
/// أبيض نقي. القيم من صلب `FinColors` الفاتح حيثما أمكن حتى يبدو
/// المستند المطبوع امتداداً بصرياً للشاشة نفسها.
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import 'print_fonts.dart';

/// نظام ألوان PDF — ثابت، بلا أي I/O.
abstract final class PrintPalette {
  /// البذرة الرسمية للتطبيق (SRS §0.3) — تُطبع داكنة كفاية للورق.
  static const pw.PdfColor brand = pw.PdfColor.fromInt(0xFF00695C);

  /// حبر شريط الترويسة العميق (امتداد داكن للبذرة).
  static const pw.PdfColor brandDeep = pw.PdfColor.fromInt(0xFF032F29);

  /// اللمسة الذهبية (شريط رقم السند/التأكيدات) — ذهب `FinColors` الفاتح.
  static const pw.PdfColor gold = pw.PdfColor.fromInt(0xFFA87A2C);

  /// حبر جسم النص.
  static const pw.PdfColor ink = pw.PdfColor.fromInt(0xFF1A2420);

  /// حبر ثانوي (سطور البيانات والتذييل).
  static const pw.PdfColor inkSoft = pw.PdfColor.fromInt(0xFF5B6B65);

  /// خط فاصل/حدود خفيف.
  static const pw.PdfColor rule = pw.PdfColor.fromInt(0xFFDCE7E1);

  /// تعبئة شريط رأس الجدول.
  static const pw.PdfColor tableHead = pw.PdfColor.fromInt(0xFFDFEBE7);

  /// تعبئة صف Zebra الفردية.
  static const pw.PdfColor zebra = pw.PdfColor.fromInt(0xFFF2F7F4);

  /// خلفية الورق (أبيض نقي لجودة الرستر).
  static const pw.PdfColor paper = pw.PdfColor.fromInt(0xFFFFFFFF);
}

/// مساعدات أنماط النص فوق [PrintFonts]/[PrintPalette].
abstract final class PrintText {
  /// نص جسم (حبر، ~9.5pt بمقياس حزمة pdf).
  static pw.TextStyle body({
    pw.PdfColor color = PrintPalette.ink,
    double size = 9.5,
  }) => pw.TextStyle(font: PrintFonts.regular, color: color, fontSize: size);

  /// نص عريض (العناوين والإجماليات).
  static pw.TextStyle head({
    pw.PdfColor color = PrintPalette.ink,
    double size = 11,
  }) => pw.TextStyle(font: PrintFonts.bold, color: color, fontSize: size);

  /// نص ExtraBold (عناوين المستندات الكبيرة — «فاتورة مبيعات»/«سند قبض»).
  static pw.TextStyle extraHead({
    pw.PdfColor color = PrintPalette.ink,
    double size = 20,
  }) => pw.TextStyle(font: PrintFonts.extraBold, color: color, fontSize: size);

  /// مبلغ بأرقام جدولية (UX-2b — DS-18n): الخط المرافق NotoSansArabic
  /// بأرقام متساوية العرض افتراضياً، فتستقيم أعمدة المبالغ في الجداول
  /// والمجاميع على الورق (Almarai تناسبية فكانت الأعمدة ترتجّ).
  static pw.TextStyle tabular({
    pw.PdfColor color = PrintPalette.ink,
    double size = 9.5,
  }) => pw.TextStyle(font: PrintFonts.tabular, color: color, fontSize: size);

  /// مبلغ جدولي عريض (صف الإجمالي النهائي/المجاميع البارزة).
  static pw.TextStyle tabularHead({
    pw.PdfColor color = PrintPalette.ink,
    double size = 11,
  }) =>
      pw.TextStyle(font: PrintFonts.tabularBold, color: color, fontSize: size);
}
