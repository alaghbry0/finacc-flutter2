/// مساعدات ويدجت PDF المشتركة بين بنّائي المستندات (R19-D2: توحيد
/// النسخ المتطابقة حرفياً من `_monogram` في ستة بنّائين و`_footerLine`
/// في خمسة — مصدر واحد بقلب منظومة الطباعة).
///
/// كل الدوال بلا حالة وتعمل فوق [PrintPalette]/[PrintText] حصراً.
library;

import 'package:pdf/widgets.dart' as pw;

import '../docs/print_docs.dart';
import 'print_palette.dart';

/// حرف أول لاسم المنشأة داخل الشعار الدائري — «ف» عند الفراغ.
String printMonogram(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'ف' : trimmed.substring(0, 1);
}

/// سطر التذييل الموحد: فاصل رفيع + «شكراً · نص المنشأة» يميناً ونسب
/// التطبيق يساراً (كلاهما RTL).
pw.Widget printFooterLine(String? companyFooterText, String thanks) {
  final companyFooter = (companyFooterText ?? '').trim();
  final right = companyFooter.isEmpty ? thanks : '$thanks · $companyFooter';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Divider(color: PrintPalette.rule, thickness: 0.6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            kPrintAppCredit,
            style: PrintText.body(color: PrintPalette.inkSoft, size: 7.5),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.Text(
            right,
            style: PrintText.body(color: PrintPalette.inkSoft, size: 8),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    ],
  );
}
