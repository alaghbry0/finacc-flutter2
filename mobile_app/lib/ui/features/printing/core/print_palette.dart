/// لوحة ألوان الطباعة (الشريحة 7) — تكييف صديق للطابعة بهوية التطبيق:
/// بذرة `0xFF1976D2` (أزرق Simple Invoice Manager منذ V3 — كانت
/// `0xFF00695C` Deep Teal) + لمسة ذهبية + حبر أزرق داكن على ورق
/// أبيض نقي. القيم من صلب `FinColors` الفاتح حيثما أمكن حتى يبدو
/// المستند المطبوع امتداداً بصرياً للشاشة نفسها.
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import 'print_fonts.dart';

/// نظام ألوان PDF — ثابت، بلا أي I/O.
abstract final class PrintPalette {
  /// البذرة الرسمية للتطبيق (V3) — تُطبع داكنة كفاية للورق
  /// (أزرق 800 فوق بذرة 700 للشاشة — الطباعة تحتدي تبايناً أعلى).
  static const pw.PdfColor brand = pw.PdfColor.fromInt(0xFF1565C0);

  /// حبر شريط الترويسة العميق (امتداد داكن للبذرة — ليل أزرق).
  static const pw.PdfColor brandDeep = pw.PdfColor.fromInt(0xFF0D2B45);

  /// اللمسة الذهبية (شريط رقم السند/التأكيدات) — ذهب `FinColors` الفاتح.
  static const pw.PdfColor gold = pw.PdfColor.fromInt(0xFFA87A2C);

  /// حبر جسم النص.
  static const pw.PdfColor ink = pw.PdfColor.fromInt(0xFF1B242E);

  /// حبر ثانوي (سطور البيانات والتذييل).
  static const pw.PdfColor inkSoft = pw.PdfColor.fromInt(0xFF5A6B7C);

  /// خط فاصل/حدود خفيف.
  static const pw.PdfColor rule = pw.PdfColor.fromInt(0xFFDCE3EC);

  /// تعبئة شريط رأس الجدول.
  static const pw.PdfColor tableHead = pw.PdfColor.fromInt(0xFFDEE7F2);

  /// تعبئة صف Zebra الفردية.
  static const pw.PdfColor zebra = pw.PdfColor.fromInt(0xFFF2F6FB);

  /// حبر بيانات الاتصال الفاتح فوق شريط الترويسة الداكن (سماوي فاتح
  /// من عائلة البذرة — كان خاماً بخمسة بُناة قبل R19-D5).
  static const pw.PdfColor highlight = pw.PdfColor.fromInt(0xFFBAD6F2);

  /// حبر داكن فوق الشرائط/الرقاقات الذهبية (السند — من `FinColors`
  /// الفاتح onWarningContainer).
  static const pw.PdfColor inkOnGold = pw.PdfColor.fromInt(0xFF4A2B00);

  /// قيمة موجبة (فائض/زيادة/إسهام موجب) — أخضر `FinColors.positive`
  /// الفاتح للورق (لوحة V3). البيت الموحّد للزوج منذ R20-D2 (كان مكرراً
  /// حرفياً باسمَي `kProfitSurplus` بمساعدات تقرير الأرباح و`_surplus`
  /// الخاص ببنّاء الوردية — قيمة ARGB لم تُمس).
  static const pw.PdfColor surplus = pw.PdfColor.fromInt(0xFF2E7D32);

  /// قيمة سالبة (عجز/إسهام سالب) — أحمر `FinColors.negative` الفاتح
  /// للورق. قرين [surplus] — البيت الموحّد منذ R20-D2 (كان مكرراً
  /// باسمَي `kProfitDeficit` و`_deficit` — قيمة ARGB لم تُمس).
  static const pw.PdfColor deficit = pw.PdfColor.fromInt(0xFFB3261E);

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
