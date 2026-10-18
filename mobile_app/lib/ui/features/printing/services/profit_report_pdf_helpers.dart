/// مساعدات تخطيط PDF تقرير الأرباح — مشتركة بين أقسام التخطيط
/// (الترويسة/الجدول/الإجماليات): ألوان الإسهام الموقّع والتنسيق
/// الموقّع وسطر «تسمية يميناً» — مستخرجة من profit_report_pdf_builder
/// (R19-D3d: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../../../core/widgets/amount_text.dart';
import '../core/print_palette.dart';
import 'profit_report_pdf_doc.dart';

/// إسهام موجب — أخضر `FinColors.positive` الفاتح للورق.
///
/// الاسم العام التاريخي (تستورده أقسام الجدول) — منذ R20-D2 غلافٌ ثابت
/// لـ[PrintPalette.surplus] البيت الموحّد لألوان الطباعة (قيمة ARGB
/// نفسها حرفياً — صفر تغيير بالمستند المرسوم).
const pw.PdfColor kProfitSurplus = PrintPalette.surplus;

/// إسهام سالب — أحمر `FinColors.negative` الفاتح للورق.
///
/// الاسم العام التاريخي — منذ R20-D2 غلافٌ ثابت لـ[PrintPalette.deficit]
/// (قيمة ARGB نفسها حرفياً).
const pw.PdfColor kProfitDeficit = PrintPalette.deficit;

pw.PdfColor profitToneColor(double value) => value > 0.005
    ? kProfitSurplus
    : value < -0.005
    ? kProfitDeficit
    : PrintPalette.brandDeep;

String profitFmtSigned(ProfitPrintDoc doc, double value) {
  final magnitude = AmountText.format(value.abs(), doc.decimals);
  if (value > 0.005) return '+$magnitude';
  if (value < -0.005) return '−$magnitude';
  return magnitude;
}

/// سطر «تسمية يميناً» — عمود واحد ممتد (نمط بطاقات الوردية).
pw.Widget profitKvLine(String label, String value, {double size = 9.5}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 1.5),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.SizedBox()),
        pw.Text(
          value.isEmpty ? label : '$label: $value',
          style: PrintText.body(color: PrintPalette.inkSoft, size: size),
          textDirection: pw.TextDirection.rtl,
        ),
      ],
    ),
  );
}
